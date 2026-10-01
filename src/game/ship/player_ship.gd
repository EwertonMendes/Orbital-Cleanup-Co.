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
signal operational_boundary_changed(intensity: float, outward_direction: Vector2)
signal operational_boundary_repelled(return_direction: Vector2)

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
var _environment_acceleration := Vector2.ZERO
var _environment_force := Vector2.ZERO
var _environment_linear_drag := 0.0
var _environment_thrust_multiplier := 1.0
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
var _boundary_warning_intensity := 0.0
var _boundary_warning_direction := Vector2.ZERO
var _boundary_repel_cooldown := 0.0

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

func set_environment_physics(
	linear_acceleration: Vector2,
	external_force: Vector2,
	linear_drag: float = 0.0,
	thrust_multiplier: float = 1.0
) -> void:
	_environment_acceleration = linear_acceleration.limit_length(460.0)
	_environment_force = external_force.limit_length(360.0)
	_environment_linear_drag = clampf(linear_drag, 0.0, 1.8)
	_environment_thrust_multiplier = clampf(thrust_multiplier, 0.65, 1.15)

func unload_cargo() -> int:
	return cargo_hold.unload_all()

func get_cargo_used() -> int:
	return cargo_hold.used_units

func get_cargo_capacity() -> int:
	return cargo_hold.capacity

func get_cargo_mass() -> float:
	return cargo_hold.get_total_mass()

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
	_boundary_repel_cooldown = maxf(_boundary_repel_cooldown - delta, 0.0)

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

	var intent := _smoothed_intent.limit_length(1.0)
	if _boost_remaining > 0.0:
		_boost_remaining = maxf(_boost_remaining - delta, 0.0)
		if _boost_remaining <= 0.0:
			boost_ended.emit()
	var boosting := _boost_remaining > 0.0

	var effective_mass := ShipDynamics.effective_mass(
		tuning.dry_mass,
		cargo_hold.get_total_mass(),
		tuning.cargo_inertia_factor
	)
	var total_acceleration := ShipDynamics.propulsion_acceleration(
		intent,
		velocity,
		tuning,
		effective_mass,
		_environment_thrust_multiplier
	)
	total_acceleration += _environment_acceleration
	total_acceleration += _environment_force * ShipDynamics.mass_response(tuning.dry_mass, effective_mass)

	if boosting:
		_update_boost_direction(intent, delta)
		total_acceleration += ShipDynamics.boost_acceleration(
			_boost_direction,
			tuning,
			effective_mass
		)

	velocity = ShipDynamics.integrate_velocity(
		velocity,
		total_acceleration,
		_environment_linear_drag,
		tuning.absolute_speed_limit,
		delta
	)
	var turn_amount := _update_facing(intent, delta)
	_move_with_collisions(delta)
	_update_operational_boundary(delta)
	_enforce_hard_world_bounds()

	var speed_ratio := clampf(velocity.length() / tuning.max_speed, 0.0, 1.0)
	visuals.update_motion(
		speed_ratio,
		intent.length(),
		_facing_rotation,
		turn_amount,
		delta,
		1.0 if boosting else 0.0,
		velocity
	)
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

func _update_operational_boundary(delta: float) -> void:
	if _world_bounds.size == Vector2.ZERO:
		_set_operational_boundary_state(0.0, Vector2.ZERO)
		return

	var left_distance := global_position.x - _world_bounds.position.x
	var right_distance := _world_bounds.end.x - global_position.x
	var top_distance := global_position.y - _world_bounds.position.y
	var bottom_distance := _world_bounds.end.y - global_position.y
	var distances := [left_distance, right_distance, top_distance, bottom_distance]
	var outward_directions := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

	var nearest_index := 0
	var nearest_distance := float(distances[0])
	for index in range(1, distances.size()):
		var distance := float(distances[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	var outward_direction: Vector2 = outward_directions[nearest_index]
	var outward_speed := maxf(velocity.dot(outward_direction), 0.0)
	var warning_range := maxf(tuning.boundary_warning_margin - tuning.boundary_repel_padding, 1.0)
	var warning_t := clampf((tuning.boundary_warning_margin - nearest_distance) / warning_range, 0.0, 1.0)
	var movement_weight := clampf(outward_speed / maxf(tuning.max_speed * 0.18, 1.0), 0.0, 1.0)
	var warning_intensity := 0.0
	if outward_speed > 4.0 or nearest_distance <= tuning.boundary_repel_padding:
		warning_intensity = smoothstep(0.0, 1.0, warning_t) * lerpf(0.45, 1.0, movement_weight)
	_set_operational_boundary_state(warning_intensity, outward_direction if warning_intensity > 0.0 else Vector2.ZERO)

	var return_direction := Vector2.ZERO
	if left_distance <= tuning.boundary_repel_padding and velocity.x < 0.0:
		return_direction.x += 1.0
	if right_distance <= tuning.boundary_repel_padding and velocity.x > 0.0:
		return_direction.x -= 1.0
	if top_distance <= tuning.boundary_repel_padding and velocity.y < 0.0:
		return_direction.y += 1.0
	if bottom_distance <= tuning.boundary_repel_padding and velocity.y > 0.0:
		return_direction.y -= 1.0
	if return_direction == Vector2.ZERO:
		return

	return_direction = return_direction.normalized()
	var penetration := clampf(
		(tuning.boundary_repel_padding - nearest_distance)
		/ maxf(tuning.boundary_repel_padding - tuning.boundary_hard_padding, 1.0),
		0.0,
		1.0
	)
	velocity += return_direction * tuning.boundary_repel_acceleration * lerpf(0.35, 1.0, penetration) * maxf(delta, 0.0)
	if _boundary_repel_cooldown <= 0.0:
		_apply_boundary_repel(return_direction)

func _apply_boundary_repel(return_direction: Vector2) -> void:
	var inward := return_direction.normalized()
	var outward_speed := maxf(-velocity.dot(inward), 0.0)
	var tangential_velocity := velocity + inward * outward_speed
	var return_speed := maxf(tuning.boundary_return_speed, outward_speed * tuning.boundary_return_velocity_scale)
	velocity = (tangential_velocity + inward * return_speed).limit_length(tuning.absolute_speed_limit)
	_boundary_repel_cooldown = tuning.boundary_repel_cooldown
	_cancel_boost()
	ship_camera.add_bump_shake(0.14)
	operational_boundary_repelled.emit(inward)

func _set_operational_boundary_state(intensity: float, outward_direction: Vector2) -> void:
	var safe_intensity := clampf(intensity, 0.0, 1.0)
	var safe_direction := outward_direction.normalized() if outward_direction.length_squared() > 0.001 else Vector2.ZERO
	if absf(_boundary_warning_intensity - safe_intensity) < 0.01 and _boundary_warning_direction.is_equal_approx(safe_direction):
		return
	_boundary_warning_intensity = safe_intensity
	_boundary_warning_direction = safe_direction
	operational_boundary_changed.emit(_boundary_warning_intensity, _boundary_warning_direction)

func _move_with_collisions(delta: float) -> void:
	var time_remaining := delta
	for _iteration in range(tuning.collision_iterations):
		if time_remaining <= 0.0001 or velocity.length_squared() <= 0.001:
			return

		var requested_motion := velocity * time_remaining
		var requested_distance := requested_motion.length()
		var collision := move_and_collide(requested_motion)
		if collision == null:
			return

		var remainder_distance := collision.get_remainder().length()
		_apply_bump(collision)
		if requested_distance <= 0.001:
			return

		time_remaining *= clampf(remainder_distance / requested_distance, 0.0, 1.0)

func _enforce_hard_world_bounds() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return
	var left := _world_bounds.position.x + tuning.boundary_hard_padding
	var right := _world_bounds.end.x - tuning.boundary_hard_padding
	var top := _world_bounds.position.y + tuning.boundary_hard_padding
	var bottom := _world_bounds.end.y - tuning.boundary_hard_padding

	# Numerical fail-safe only. Normal gameplay is contained by the physical return force.
	if global_position.x < left:
		global_position.x = left
		velocity.x = maxf(absf(velocity.x) * 0.35, tuning.boundary_return_speed)
	elif global_position.x > right:
		global_position.x = right
		velocity.x = -maxf(absf(velocity.x) * 0.35, tuning.boundary_return_speed)
	if global_position.y < top:
		global_position.y = top
		velocity.y = maxf(absf(velocity.y) * 0.35, tuning.boundary_return_speed)
	elif global_position.y > bottom:
		global_position.y = bottom
		velocity.y = -maxf(absf(velocity.y) * 0.35, tuning.boundary_return_speed)

func _apply_bump(collision: KinematicCollision2D) -> void:
	_cancel_boost()
	var normal := collision.get_normal()
	var impact_speed := maxf(-velocity.dot(normal), 0.0)
	if impact_speed <= 1.0:
		return

	velocity = ShipDynamics.collision_response(
		velocity,
		normal,
		tuning.collision_restitution,
		tuning.collision_tangent_retention
	)
	global_position += normal * 2.0

	if _bump_feedback_cooldown > 0.0:
		return

	_bump_feedback_cooldown = 0.14
	var intensity := clampf(impact_speed / tuning.max_speed, 0.18, 1.0)
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
