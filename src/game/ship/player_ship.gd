extends CharacterBody2D
class_name PlayerShip

signal movement_started
signal bumped(intensity: float, normal: Vector2)
signal cargo_changed(used_units: int, capacity: int)
signal tractor_target_changed(definition)
signal tractor_progress_changed(progress: float)
signal salvage_collected(definition, used_units: int, capacity: int)
signal cargo_collection_blocked
signal boost_started
signal boost_ended

@export var tuning: ShipMovementTuning

@onready var visuals: ShipVisuals = %FeedbackRoot
@onready var ship_camera: ShipCamera = %ShipCamera
@onready var cargo_hold: CargoHold = %CargoHold
@onready var tractor_beam: TractorBeam = %TractorBeam

var _input_service: InputService
var _world_bounds := Rect2()
var _has_started_moving := false
var _bump_feedback_cooldown := 0.0
var _smoothed_intent := Vector2.ZERO
var _facing_rotation := 0.0
var _pending_cosmetics: Dictionary = {}
var _environment_force := Vector2.ZERO
var _environment_speed_multiplier := 1.0
var _controls_enabled := true
var _travel_mode := false
var _travel_visual_intensity := 0.0
var _travel_direction := Vector2.RIGHT
var _boost_recharge_rate := 1.0
var _boost_duration_bonus := 0.0
var _boost_charge_capacity := 1
var _boost_charges := 1
var _boost_recharge_elapsed := 0.0
var _boost_remaining := 0.0
var _boost_direction := Vector2.UP

func configure(
	input_service: InputService,
	world_bounds: Rect2 = Rect2(),
	ship_modifiers: Dictionary = {},
	ship_cosmetics: Dictionary = {}
) -> void:
	assert(input_service != null, "PlayerShip requires InputService.")
	_input_service = input_service
	if not _input_service.boost_requested.is_connected(_on_boost_requested):
		_input_service.boost_requested.connect(_on_boost_requested)
	_world_bounds = world_bounds
	_pending_cosmetics = ship_cosmetics.duplicate(true)

	if not ship_modifiers.is_empty():
		var cargo := get_node("CargoHold") as CargoHold
		var beam := get_node("TractorBeam") as TractorBeam
		assert(cargo != null and beam != null, "PlayerShip upgrade targets must exist.")
		cargo.capacity = maxi(int(round(float(ship_modifiers.get("cargo_capacity", cargo.capacity)))), 1)
		beam.scan_range = maxf(float(ship_modifiers.get("scan_range", beam.scan_range)), 80.0)
		beam.collection_speed_multiplier = maxf(
			float(ship_modifiers.get("collection_speed_multiplier", beam.collection_speed_multiplier)),
			0.1
		)

	_boost_recharge_rate = maxf(float(ship_modifiers.get("boost_recharge_rate", 1.0)), 0.5)
	_boost_duration_bonus = maxf(float(ship_modifiers.get("boost_duration_bonus", 0.0)), 0.0)
	_boost_charge_capacity = clampi(int(round(float(ship_modifiers.get("boost_charge_capacity", 1.0)))), 1, 2)
	_boost_charges = _boost_charge_capacity
	_boost_recharge_elapsed = 0.0

func _ready() -> void:
	assert(tuning != null, "PlayerShip requires ShipMovementTuning.")
	assert(cargo_hold != null, "PlayerShip requires CargoHold.")
	assert(tractor_beam != null, "PlayerShip requires TractorBeam.")
	tuning.validate()
	assert(_input_service != null, "PlayerShip must be configured with InputService before entering the tree.")
	ship_camera.configure(tuning)

	if not _pending_cosmetics.is_empty():
		visuals.apply_cosmetics(_pending_cosmetics)
		tractor_beam.apply_style(_pending_cosmetics["beam"] as Dictionary)
		print("[Ship] COSMETICS hull=%s paint=%s trail=%s beam=%s" % [
			String((_pending_cosmetics["hull"] as Dictionary).get("id", "")),
			String((_pending_cosmetics["paint"] as Dictionary).get("id", "")),
			String((_pending_cosmetics["trail"] as Dictionary).get("id", "")),
			String((_pending_cosmetics["beam"] as Dictionary).get("id", "")),
		])

	cargo_hold.cargo_changed.connect(_on_cargo_changed)
	tractor_beam.target_changed.connect(_on_tractor_target_changed)
	tractor_beam.progress_changed.connect(_on_tractor_progress_changed)
	tractor_beam.salvage_collected.connect(_on_salvage_collected)
	tractor_beam.blocked_by_cargo_space.connect(_on_cargo_collection_blocked)

	cargo_changed.emit(cargo_hold.used_units, cargo_hold.capacity)
	print("[Ship] READY")

func set_environment_motion(force: Vector2, speed_multiplier: float = 1.0) -> void:
	_environment_force = force.limit_length(220.0)
	_environment_speed_multiplier = clampf(speed_multiplier, 0.82, 1.08)

func unload_cargo() -> int:
	return cargo_hold.unload_all()

func get_cargo_used() -> int:
	return cargo_hold.used_units

func get_cargo_capacity() -> int:
	return cargo_hold.capacity

func set_flight_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		_smoothed_intent = Vector2.ZERO
		_input_service.clear_touch_navigation()
		_cancel_boost()
		ship_camera.set_motion_velocity(Vector2.ZERO)

func set_collection_enabled(enabled: bool) -> void:
	tractor_beam.set_interaction_enabled(enabled)

func begin_travel(direction: Vector2) -> void:
	_travel_mode = true
	_travel_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_travel_visual_intensity = 0.12
	_facing_rotation = _travel_direction.angle() + PI * 0.5
	set_flight_controls_enabled(false)
	set_collection_enabled(false)
	ship_camera.set_motion_velocity(Vector2.ZERO)
	ship_camera.set_framing_offset(Vector2.ZERO)
	ship_camera.offset = Vector2.ZERO
	ship_camera.top_level = true
	ship_camera.global_position = global_position
	ship_camera.process_mode = Node.PROCESS_MODE_DISABLED

func set_travel_visual_intensity(value: float) -> void:
	_travel_visual_intensity = clampf(value, 0.0, 1.0)

func end_travel(restore_collection: bool = true) -> void:
	_travel_mode = false
	_travel_visual_intensity = 0.0
	ship_camera.top_level = false
	ship_camera.position = Vector2.ZERO
	ship_camera.process_mode = Node.PROCESS_MODE_INHERIT
	set_flight_controls_enabled(true)
	set_collection_enabled(restore_collection)
	visuals.update_motion(0.0, 0.0, _facing_rotation, 0.0, 0.0)

func _physics_process(delta: float) -> void:
	_update_boost_recharge(delta)
	if _travel_mode:
		velocity = Vector2.ZERO
		visuals.update_motion(_travel_visual_intensity, _travel_visual_intensity, _facing_rotation, 0.0, delta)
		ship_camera.set_motion_velocity(Vector2.ZERO)
		return
	if not _controls_enabled:
		velocity = Vector2.ZERO
		visuals.update_motion(0.0, 0.0, _facing_rotation, 0.0, delta)
		ship_camera.set_motion_velocity(Vector2.ZERO)
		return
	_bump_feedback_cooldown = maxf(_bump_feedback_cooldown - delta, 0.0)

	var navigation_intent := _input_service.get_navigation_vector()
	var raw_intent := navigation_intent

	if navigation_intent.length_squared() <= 0.001 and _input_service.uses_pointer_steering():
		raw_intent = ShipSteering.pointer_intent(
			get_global_transform_with_canvas().origin,
			_input_service.get_primary_pointer_position(),
			tuning.pointer_deadzone,
			tuning.pointer_full_thrust_distance
		)

	if navigation_intent.length_squared() > 0.001:
		_smoothed_intent = navigation_intent.limit_length(1.0)
	else:
		var steering_weight := 1.0 - exp(-tuning.pointer_steering_response * delta)
		_smoothed_intent = _smoothed_intent.lerp(raw_intent, steering_weight)

	var intent := _attenuate_outward_intent(_smoothed_intent)
	if _boost_remaining > 0.0:
		_boost_remaining = maxf(_boost_remaining - delta, 0.0)
		if _boost_remaining <= 0.0:
			boost_ended.emit()
	var boosting := _boost_remaining > 0.0
	var environment_max_speed := tuning.max_speed * _environment_speed_multiplier
	var desired_velocity := ShipSteering.target_velocity(intent, environment_max_speed)

	var response := tuning.deceleration
	if boosting:
		_update_boost_direction(intent, delta)
		var boost_throttle := 1.0
		if intent.length_squared() > 0.001:
			boost_throttle = lerpf(0.55, 1.0, intent.length())
		desired_velocity = _boost_direction * environment_max_speed * tuning.boost_speed_multiplier * boost_throttle
		response = tuning.acceleration * tuning.boost_acceleration_multiplier
	elif intent.length_squared() > 0.001:
		response = tuning.acceleration * lerpf(0.46, 1.0, intent.length())

	velocity = velocity.move_toward(desired_velocity, response * delta)
	velocity += _environment_force * delta
	var velocity_cap := tuning.max_speed * 1.22
	if boosting:
		velocity_cap = tuning.max_speed * tuning.boost_speed_multiplier * _environment_speed_multiplier
	velocity = velocity.limit_length(velocity_cap)
	_apply_soft_world_bounds(delta)

	var turn_amount := _update_facing(intent, delta)
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_apply_bump(collision)

	_enforce_hard_world_bounds()

	var speed_ratio := clampf(velocity.length() / tuning.max_speed, 0.0, 1.0)
	visuals.update_motion(speed_ratio, intent.length(), _facing_rotation, turn_amount, delta, 1.0 if boosting else 0.0)
	ship_camera.set_motion_velocity(velocity)

	if not _has_started_moving and speed_ratio > 0.08:
		_has_started_moving = true
		movement_started.emit()

func _update_facing(intent: Vector2, delta: float) -> float:
	var facing := Vector2.ZERO
	if intent.length_squared() > 0.001:
		facing = intent.normalized()
	elif velocity.length_squared() > 64.0:
		facing = velocity.normalized()

	if facing == Vector2.ZERO:
		return 0.0

	var target_rotation := facing.angle() + PI * 0.5
	var difference := wrapf(target_rotation - _facing_rotation, -PI, PI)
	var weight := 1.0 - exp(-tuning.turn_response * delta)
	_facing_rotation = lerp_angle(_facing_rotation, target_rotation, weight)
	return clampf(difference / (PI * 0.5), -1.0, 1.0)

func _attenuate_outward_intent(intent: Vector2) -> Vector2:
	if _world_bounds.size == Vector2.ZERO:
		return intent

	var adjusted := intent
	var margin := tuning.boundary_soft_margin
	var left := _world_bounds.position.x + tuning.boundary_hard_padding
	var right := _world_bounds.end.x - tuning.boundary_hard_padding
	var top := _world_bounds.position.y + tuning.boundary_hard_padding
	var bottom := _world_bounds.end.y - tuning.boundary_hard_padding

	if adjusted.x < 0.0:
		adjusted.x *= _edge_input_scale(global_position.x - left, margin)
	elif adjusted.x > 0.0:
		adjusted.x *= _edge_input_scale(right - global_position.x, margin)

	if adjusted.y < 0.0:
		adjusted.y *= _edge_input_scale(global_position.y - top, margin)
	elif adjusted.y > 0.0:
		adjusted.y *= _edge_input_scale(bottom - global_position.y, margin)

	return adjusted

func _edge_input_scale(distance_to_edge: float, margin: float) -> float:
	var t := clampf(distance_to_edge / maxf(margin, 1.0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _apply_soft_world_bounds(delta: float) -> void:
	if _world_bounds.size == Vector2.ZERO:
		return

	var margin := tuning.boundary_soft_margin
	var left := _world_bounds.position.x + tuning.boundary_hard_padding
	var right := _world_bounds.end.x - tuning.boundary_hard_padding
	var top := _world_bounds.position.y + tuning.boundary_hard_padding
	var bottom := _world_bounds.end.y - tuning.boundary_hard_padding

	var correction := Vector2.ZERO
	correction.x += _edge_strength(global_position.x - left, margin)
	correction.x -= _edge_strength(right - global_position.x, margin)
	correction.y += _edge_strength(global_position.y - top, margin)
	correction.y -= _edge_strength(bottom - global_position.y, margin)

	velocity += correction * tuning.boundary_push_acceleration * delta

	var damp_step := tuning.max_speed * tuning.boundary_outward_damping * delta
	if correction.x > 0.0 and velocity.x < 0.0:
		velocity.x = move_toward(velocity.x, 0.0, damp_step * absf(correction.x))
	elif correction.x < 0.0 and velocity.x > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, damp_step * absf(correction.x))

	if correction.y > 0.0 and velocity.y < 0.0:
		velocity.y = move_toward(velocity.y, 0.0, damp_step * absf(correction.y))
	elif correction.y < 0.0 and velocity.y > 0.0:
		velocity.y = move_toward(velocity.y, 0.0, damp_step * absf(correction.y))

func _edge_strength(distance_to_edge: float, margin: float) -> float:
	var t := clampf(1.0 - distance_to_edge / maxf(margin, 1.0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _enforce_hard_world_bounds() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return

	var left := _world_bounds.position.x + tuning.boundary_hard_padding
	var right := _world_bounds.end.x - tuning.boundary_hard_padding
	var top := _world_bounds.position.y + tuning.boundary_hard_padding
	var bottom := _world_bounds.end.y - tuning.boundary_hard_padding

	var clamped := Vector2(
		clampf(global_position.x, left, right),
		clampf(global_position.y, top, bottom)
	)

	if not is_equal_approx(clamped.x, global_position.x):
		global_position.x = clamped.x
		velocity.x = 0.0
	if not is_equal_approx(clamped.y, global_position.y):
		global_position.y = clamped.y
		velocity.y = 0.0

func _apply_bump(collision: KinematicCollision2D) -> void:
	_cancel_boost()
	var normal := collision.get_normal()
	var incoming_speed := velocity.length()
	if incoming_speed <= 1.0:
		return

	velocity = velocity.bounce(normal) * tuning.bump_speed_retention
	if incoming_speed >= 48.0 and velocity.length() < tuning.bump_minimum_speed:
		velocity = normal * tuning.bump_minimum_speed

	global_position += normal * 2.0

	if _bump_feedback_cooldown > 0.0:
		return

	_bump_feedback_cooldown = 0.14
	var intensity := clampf(incoming_speed / tuning.max_speed, 0.18, 1.0)
	visuals.play_bump(intensity, normal)
	ship_camera.add_bump_shake(intensity)
	bumped.emit(intensity, normal)

func can_boost() -> bool:
	return _controls_enabled and not _travel_mode and _boost_charges > 0 and _boost_remaining <= 0.001

func is_boosting() -> bool:
	return _boost_remaining > 0.0

func get_boost_charges() -> int:
	return _boost_charges

func get_boost_capacity() -> int:
	return _boost_charge_capacity

func get_boost_recharge_progress() -> float:
	if _boost_charges >= _boost_charge_capacity:
		return 1.0
	return clampf(_boost_recharge_elapsed / maxf(tuning.boost_recharge_seconds, 0.001), 0.0, 1.0)

func _on_boost_requested() -> void:
	if not can_boost():
		return
	var launch_direction := _smoothed_intent
	if launch_direction.length_squared() <= 0.001 and velocity.length_squared() > 64.0:
		launch_direction = velocity.normalized()
	if launch_direction.length_squared() <= 0.001:
		launch_direction = Vector2.UP.rotated(_facing_rotation)
	_boost_direction = launch_direction.normalized()
	_boost_charges -= 1
	_boost_recharge_elapsed = 0.0
	_boost_remaining = tuning.boost_duration + _boost_duration_bonus
	visuals.play_boost()
	ship_camera.add_bump_shake(0.18)
	boost_started.emit()

func _update_boost_direction(intent: Vector2, delta: float) -> void:
	if intent.length_squared() <= 0.001:
		return
	var target_direction := intent.normalized()
	var weight := 1.0 - exp(-tuning.turn_response * tuning.boost_turn_authority * delta)
	var blended := _boost_direction.lerp(target_direction, weight)
	if blended.length_squared() > 0.001:
		_boost_direction = blended.normalized()

func _update_boost_recharge(delta: float) -> void:
	if _boost_charges >= _boost_charge_capacity:
		_boost_recharge_elapsed = 0.0
		return
	if _boost_remaining > 0.0:
		return
	_boost_recharge_elapsed += delta * _boost_recharge_rate
	while _boost_recharge_elapsed >= tuning.boost_recharge_seconds and _boost_charges < _boost_charge_capacity:
		_boost_recharge_elapsed -= tuning.boost_recharge_seconds
		_boost_charges += 1
	if _boost_charges >= _boost_charge_capacity:
		_boost_recharge_elapsed = 0.0

func _cancel_boost() -> void:
	if _boost_remaining <= 0.0:
		return
	_boost_remaining = 0.0
	boost_ended.emit()

func _on_cargo_changed(used_units: int, capacity: int) -> void:
	cargo_changed.emit(used_units, capacity)

func _on_tractor_target_changed(definition) -> void:
	tractor_target_changed.emit(definition)

func _on_tractor_progress_changed(progress: float) -> void:
	tractor_progress_changed.emit(progress)

func _on_salvage_collected(definition, used_units: int, capacity: int) -> void:
	salvage_collected.emit(definition, used_units, capacity)

func _on_cargo_collection_blocked() -> void:
	cargo_collection_blocked.emit()
