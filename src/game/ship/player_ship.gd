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
var _pending_ship_build: Dictionary = {}
var _environment_acceleration := Vector2.ZERO
var _environment_force := Vector2.ZERO
var _environment_linear_drag := 0.0
var _environment_thrust_multiplier := 1.0
var _environment_force_response := 1.0
var _environment_drag_response := 1.0
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
var _boundary_return_direction := Vector2.ZERO
var _boundary_return_target := Vector2.ZERO
var _boundary_return_elapsed := 0.0
var _boundary_return_active := false

func configure(
	input_service: InputService,
	world_bounds: Rect2 = Rect2(),
	ship_modifiers: Dictionary = {},
	ship_cosmetics: Dictionary = {},
	ship_build: Dictionary = {}
) -> void:
	assert(input_service != null, "PlayerShip requires InputService.")
	_input_service = input_service
	if not _input_service.boost_requested.is_connected(_on_boost_requested):
		_input_service.boost_requested.connect(_on_boost_requested)
	_world_bounds = world_bounds
	_pending_ship_build = ship_build.duplicate(true)
	_pending_cosmetics = ship_cosmetics.duplicate(true)

	var resolved_modifiers := ship_modifiers
	if not _pending_ship_build.is_empty():
		resolved_modifiers = (_pending_ship_build.get("stats", {}) as Dictionary).duplicate(true)
		_pending_cosmetics = (_pending_ship_build.get("cosmetics", {}) as Dictionary).duplicate(true)

	_apply_resolved_build_state(resolved_modifiers, true)
	_apply_tractor_socket_from_build(_pending_ship_build)

func apply_ship_build(ship_build: Dictionary) -> void:
	assert(is_node_ready(), "Live ship builds can only be applied after PlayerShip is ready.")
	assert(not ship_build.is_empty(), "Live ship build cannot be empty.")
	assert(ship_build.has("stats") and ship_build.has("cosmetics") and ship_build.has("visual"), "Live ship build requires stats, cosmetics and visual data.")

	var previous_build := _pending_ship_build
	var previous_stats := previous_build.get("stats", {}) as Dictionary
	var previous_visual := previous_build.get("visual", {}) as Dictionary
	var previous_cosmetics := previous_build.get("cosmetics", {}) as Dictionary

	var next_stats := ship_build.get("stats", {}) as Dictionary
	var next_visual := ship_build.get("visual", {}) as Dictionary
	var next_cosmetics := ship_build.get("cosmetics", {}) as Dictionary
	var stats_changed := previous_stats != next_stats
	var visual_changed := (
		previous_visual != next_visual
		or String(previous_build.get("ship_id", "")) != String(ship_build.get("ship_id", ""))
	)
	var collision_changed := _hull_collision_geometry_changed(previous_visual, next_visual)
	var cosmetic_changes := _changed_cosmetic_categories(previous_cosmetics, next_cosmetics)

	if not stats_changed and not visual_changed and cosmetic_changes.is_empty():
		return

	_pending_ship_build = ship_build.duplicate(true)
	_pending_cosmetics = next_cosmetics.duplicate(true)

	if stats_changed:
		_apply_resolved_build_state(next_stats, false)

	if visual_changed:
		_apply_tractor_socket_from_build(_pending_ship_build)
		visuals.apply_ship_build(_pending_ship_build)
	elif not cosmetic_changes.is_empty():
		for category in cosmetic_changes:
			if category == "hull":
				continue
			visuals.apply_cosmetic_update(category, _pending_cosmetics)

	if cosmetic_changes.has("beam"):
		tractor_beam.apply_style(_pending_cosmetics["beam"] as Dictionary)

	if collision_changed:
		_rebuild_hull_collision()

	if stats_changed:
		ship_camera.configure(tuning)
		tuning.validate()
		velocity = velocity.limit_length(tuning.absolute_speed_limit)
		cargo_changed.emit(cargo_hold.used_units, cargo_hold.capacity)

	if stats_changed or visual_changed or not cosmetic_changes.is_empty():
		print("[Ship] LIVE_BUILD_APPLIED ship=%s stats=%s visual=%s cosmetics=%s collision=%s" % [
			String(_pending_ship_build.get("ship_id", "")),
			str(stats_changed),
			str(visual_changed),
			",".join(PackedStringArray(cosmetic_changes)),
			str(collision_changed),
		])

func _apply_resolved_build_state(resolved_modifiers: Dictionary, initial_configuration: bool) -> void:
	if not resolved_modifiers.is_empty():
		_apply_runtime_tuning(resolved_modifiers)
		var cargo := get_node("CargoHold") as CargoHold
		var beam := get_node("TractorBeam") as TractorBeam
		assert(cargo != null and beam != null, "PlayerShip build targets must exist.")
		var target_capacity := maxi(int(round(float(resolved_modifiers.get("cargo_capacity", cargo.capacity)))), 1)
		if cargo.used_units > target_capacity:
			push_warning("Ship build cargo capacity is below the currently carried load; preserving occupied units until unload.")
			target_capacity = cargo.used_units
		cargo.capacity = target_capacity
		beam.apply_runtime_profile(
			float(resolved_modifiers.get("scan_range", beam.scan_range)),
			float(resolved_modifiers.get("capture_distance", beam.capture_distance)),
			float(resolved_modifiers.get("pull_speed", beam.pull_speed)),
			float(resolved_modifiers.get("collection_speed_multiplier", beam.collection_speed_multiplier))
		)
		_environment_force_response = clampf(float(resolved_modifiers.get("environment_force_response", 1.0)), 0.45, 1.4)
		_environment_drag_response = clampf(float(resolved_modifiers.get("environment_drag_response", 1.0)), 0.45, 1.4)

	_boost_recharge_rate = maxf(float(resolved_modifiers.get("boost_recharge_rate", 1.0)), 0.5)
	_boost_duration_bonus = maxf(float(resolved_modifiers.get("boost_duration_bonus", 0.0)), 0.0)
	var previous_charges := _boost_charges
	_boost_charge_capacity = clampi(int(round(float(resolved_modifiers.get("boost_charge_capacity", 1.0)))), 1, 2)
	_boost_charges = _boost_charge_capacity if initial_configuration else clampi(previous_charges, 0, _boost_charge_capacity)
	if _boost_charges >= _boost_charge_capacity:
		_boost_recharge_elapsed = 0.0
	else:
		_boost_recharge_elapsed = minf(_boost_recharge_elapsed, tuning.boost_recharge_seconds)

func _apply_tractor_socket_from_build(ship_build: Dictionary) -> void:
	if ship_build.is_empty():
		return
	var visual := ship_build.get("visual", {}) as Dictionary
	var socket_values := visual.get("tractor_socket", [0.0, -2.0]) as Array
	assert(socket_values.size() == 2, "Ship tractor socket requires two values.")
	var collect_anchor := get_node("TractorBeam/CollectAnchor") as Marker2D
	collect_anchor.position = Vector2(float(socket_values[0]), float(socket_values[1]))

func _apply_pending_visual_build() -> void:
	if not _pending_ship_build.is_empty():
		visuals.apply_ship_build(_pending_ship_build)
	elif not _pending_cosmetics.is_empty():
		visuals.apply_cosmetics(_pending_cosmetics)

	if not _pending_cosmetics.is_empty():
		tractor_beam.apply_style(_pending_cosmetics["beam"] as Dictionary)

	_rebuild_hull_collision()

func _rebuild_hull_collision() -> void:
	var hull_collision_radius := CollisionGeometry2D.build_dynamic_solid(self, visuals.ship_sprite)
	assert(hull_collision_radius > 0.0, "PlayerShip hull alpha must generate collision geometry.")
	_sync_hull_collision_rotation()

func _hull_collision_geometry_changed(previous_visual: Dictionary, next_visual: Dictionary) -> bool:
	if previous_visual.is_empty():
		return true
	if String(previous_visual.get("base_texture", "")) != String(next_visual.get("base_texture", "")):
		return true
	return not is_equal_approx(
		float(previous_visual.get("render_scale", 1.0)),
		float(next_visual.get("render_scale", 1.0))
	)

func _changed_cosmetic_categories(previous: Dictionary, next: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	for category_variant in next.keys():
		var category := String(category_variant)
		if previous.get(category, {}) != next.get(category, {}):
			changed.append(category)
	return changed

func _apply_runtime_tuning(stats: Dictionary) -> void:
	assert(tuning != null, "PlayerShip requires ShipMovementTuning before build configuration.")
	tuning = tuning.duplicate(true) as ShipMovementTuning
	tuning.max_speed = maxf(float(stats.get("max_speed", tuning.max_speed)), 80.0)
	tuning.acceleration = maxf(float(stats.get("acceleration", tuning.acceleration)), 80.0)
	tuning.dry_mass = maxf(float(stats.get("dry_mass", tuning.dry_mass)), 2.0)
	tuning.cargo_inertia_factor = clampf(float(stats.get("cargo_inertia_factor", tuning.cargo_inertia_factor)), 0.05, 1.0)
	tuning.turn_response = maxf(float(stats.get("turn_response", tuning.turn_response)), 1.0)
	tuning.boost_acceleration = maxf(float(stats.get("boost_acceleration", tuning.boost_acceleration)), 40.0)
	tuning.boost_duration = clampf(float(stats.get("boost_duration", tuning.boost_duration)), 0.2, 1.5)
	tuning.boost_recharge_seconds = maxf(float(stats.get("boost_recharge_seconds", tuning.boost_recharge_seconds)), tuning.boost_duration + 0.2)
	tuning.boost_turn_authority = clampf(float(stats.get("boost_turn_authority", tuning.boost_turn_authority)), 0.2, 1.0)

func _ready() -> void:
	assert(tuning != null, "PlayerShip requires ShipMovementTuning.")
	assert(cargo_hold != null, "PlayerShip requires CargoHold.")
	assert(tractor_beam != null, "PlayerShip requires TractorBeam.")
	tuning.validate()
	assert(_input_service != null, "PlayerShip must be configured with InputService before entering the tree.")
	ship_camera.configure(tuning)

	_apply_pending_visual_build()
	if not _pending_cosmetics.is_empty():
		print("[Ship] BUILD ship=%s paint=%s trail=%s beam=%s" % [
			String(_pending_ship_build.get("ship_id", (_pending_cosmetics.get("hull", {}) as Dictionary).get("id", ""))),
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
	_environment_force = (external_force * _environment_force_response).limit_length(360.0)
	_environment_linear_drag = clampf(linear_drag * _environment_drag_response, 0.0, 1.8)
	_environment_thrust_multiplier = clampf(thrust_multiplier, 0.65, 1.15)

func unload_cargo() -> Array[SalvageDefinition]:
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
		_boundary_return_active = false
		_boundary_return_direction = Vector2.ZERO
		_boundary_return_target = Vector2.ZERO
		_boundary_return_elapsed = 0.0
		_reset_operational_warning()
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
	_sync_hull_collision_rotation()
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

	var intent := _smoothed_intent.limit_length(1.0)
	var motion_intent := intent
	if _boundary_return_active and _boundary_return_direction.length_squared() > 0.001:
		motion_intent = _boundary_return_direction

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
		motion_intent,
		velocity,
		tuning,
		effective_mass,
		_environment_thrust_multiplier
	)
	total_acceleration += _environment_acceleration
	total_acceleration += _environment_force * ShipDynamics.mass_response(tuning.dry_mass, effective_mass)

	if boosting:
		_update_boost_direction(motion_intent, delta)
		total_acceleration += ShipDynamics.boost_acceleration(
			_boost_direction,
			tuning,
			effective_mass
		)

	var active_speed_limit := tuning.absolute_speed_limit
	if _boundary_return_active:
		active_speed_limit = maxf(active_speed_limit, tuning.boundary_return_max_speed)
	velocity = ShipDynamics.integrate_velocity(
		velocity,
		total_acceleration,
		_environment_linear_drag,
		active_speed_limit,
		delta
	)
	if _boundary_return_active:
		_update_boundary_return_velocity(delta)
	var turn_amount := _update_facing(motion_intent, delta)
	_sync_hull_collision_rotation()
	_move_with_collisions(delta)
	_update_operational_boundary(delta)
	_enforce_hard_world_bounds()

	var speed_ratio := clampf(velocity.length() / tuning.max_speed, 0.0, 1.0)
	visuals.update_motion(
		speed_ratio,
		motion_intent.length(),
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

func _sync_hull_collision_rotation() -> void:
	if not is_node_ready():
		return
	CollisionGeometry2D.set_generated_rotation(self, _facing_rotation)

func _update_facing(intent: Vector2, delta: float) -> float:
	var facing := Vector2.ZERO
	var response := tuning.turn_response
	if _boundary_return_active and _boundary_return_direction.length_squared() > 0.001:
		facing = _boundary_return_direction
		response = tuning.boundary_return_turn_response
	elif intent.length_squared() > 0.001:
		facing = intent.normalized()
	elif velocity.length_squared() > 64.0:
		facing = velocity.normalized()

	if facing == Vector2.ZERO:
		return 0.0

	var target_rotation := facing.angle() + PI * 0.5
	var difference := wrapf(target_rotation - _facing_rotation, -PI, PI)
	var weight := 1.0 - exp(-response * delta)
	_facing_rotation = lerp_angle(_facing_rotation, target_rotation, weight)
	return clampf(difference / (PI * 0.5), -1.0, 1.0)

func _update_operational_boundary(_delta: float) -> void:
	if _world_bounds.size == Vector2.ZERO:
		_reset_operational_warning()
		return

	if _boundary_return_active:
		_reset_operational_warning()
		if _has_completed_boundary_return():
			_finish_boundary_return()
		return

	var closest_inside_point := Vector2(
		clampf(global_position.x, _world_bounds.position.x, _world_bounds.end.x),
		clampf(global_position.y, _world_bounds.position.y, _world_bounds.end.y)
	)
	var outside_offset := global_position - closest_inside_point

	# Every point inside play_bounds is normal gameplay. Crossing that authored
	# edge only enters the warning/tolerance band; player control is preserved.
	if outside_offset.length_squared() <= 0.0001:
		_reset_operational_warning()
		return

	var outward_direction := outside_offset.normalized()
	var trigger_margin := maxf(tuning.boundary_return_trigger_margin, 1.0)
	var outside_depth := maxf(absf(outside_offset.x), absf(outside_offset.y))
	var progress := clampf(outside_depth / trigger_margin, 0.0, 1.0)
	var warning_intensity := lerpf(0.62, 1.0, smoothstep(0.0, 1.0, progress))
	_set_operational_boundary_state(warning_intensity, outward_direction)

	# This state is spatial, never timed. The player may remain in the warning
	# band indefinitely and can always fly back manually. Forced return starts
	# only after the ship physically crosses the invisible outer perimeter.
	if not _boundary_return_trigger_rect().has_point(global_position):
		_apply_boundary_repel(-outward_direction)

func _boundary_return_trigger_rect() -> Rect2:
	var margin := maxf(tuning.boundary_return_trigger_margin, 1.0)
	return _world_bounds.grow(margin)

func _apply_boundary_repel(return_direction: Vector2) -> void:
	var fallback_inward := return_direction.normalized()
	if fallback_inward == Vector2.ZERO:
		return

	_boundary_return_target = _boundary_safe_reentry_target(global_position)
	var target_delta := _boundary_return_target - global_position
	var inward := target_delta.normalized() if target_delta.length_squared() > 0.001 else fallback_inward
	var return_speed := clampf(
		target_delta.length() / maxf(tuning.boundary_return_target_seconds, 0.1),
		tuning.boundary_return_speed,
		tuning.boundary_return_max_speed
	)
	_boundary_return_direction = inward
	_boundary_return_elapsed = 0.0
	_boundary_return_active = true
	# Emergency movement may carry the ship across its tethered salvage. Keep
	# the tether physical, but never authorize cargo capture while the player
	# has no control over the ship.
	tractor_beam.set_capture_enabled(false)
	velocity = inward * return_speed
	_reset_operational_warning()
	_cancel_boost()
	ship_camera.add_bump_shake(0.18)
	operational_boundary_repelled.emit(inward)

func _update_boundary_return_velocity(delta: float) -> void:
	if not _boundary_return_active:
		return

	var target_delta := _boundary_return_target - global_position
	var distance := target_delta.length()
	if distance <= 0.001:
		return

	_boundary_return_elapsed += maxf(delta, 0.0)
	_boundary_return_direction = target_delta / distance
	var remaining_time := maxf(
		tuning.boundary_return_target_seconds - _boundary_return_elapsed,
		0.22
	)
	var desired_speed := clampf(
		distance / remaining_time,
		tuning.boundary_return_speed,
		tuning.boundary_return_max_speed
	)
	var desired_velocity := _boundary_return_direction * desired_speed
	var response := 1.0 - exp(-tuning.boundary_return_velocity_response * maxf(delta, 0.0))
	velocity = velocity.lerp(desired_velocity, response)

func _boundary_safe_reentry_rect() -> Rect2:
	var inset := minf(
		tuning.boundary_return_reentry_depth,
		minf(_world_bounds.size.x, _world_bounds.size.y) * 0.22
	)
	return Rect2(
		_world_bounds.position + Vector2(inset, inset),
		_world_bounds.size - Vector2(inset * 2.0, inset * 2.0)
	)

func _boundary_safe_reentry_target(origin: Vector2) -> Vector2:
	var safe_rect := _boundary_safe_reentry_rect()
	return Vector2(
		clampf(origin.x, safe_rect.position.x, safe_rect.end.x),
		clampf(origin.y, safe_rect.position.y, safe_rect.end.y)
	)

func _has_completed_boundary_return() -> bool:
	if not _boundary_return_active:
		return true
	return _boundary_safe_reentry_rect().has_point(global_position)

func _finish_boundary_return() -> void:
	var release_direction := _boundary_return_direction
	_boundary_return_active = false
	_boundary_return_direction = Vector2.ZERO
	_boundary_return_target = Vector2.ZERO
	_boundary_return_elapsed = 0.0
	tractor_beam.set_capture_enabled(true)
	_smoothed_intent = Vector2.ZERO
	if release_direction.length_squared() > 0.001:
		velocity = release_direction.normalized() * minf(
			tuning.boundary_return_exit_speed,
			tuning.absolute_speed_limit
		)
	_reset_operational_warning()

func _reset_operational_warning() -> void:
	_set_operational_boundary_state(0.0, Vector2.ZERO)

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

	# Numerical fail-safe only. The gameplay return trigger is the invisible
	# perimeter at boundary_return_trigger_margin; this clamp sits farther out
	# and exists only for extreme teleports or single-frame escapes.
	var escape_margin := (
		tuning.boundary_return_trigger_margin
		+ tuning.boundary_hard_escape_margin
	)
	var left := _world_bounds.position.x - escape_margin
	var right := _world_bounds.end.x + escape_margin
	var top := _world_bounds.position.y - escape_margin
	var bottom := _world_bounds.end.y + escape_margin
	var return_direction := Vector2.ZERO

	if global_position.x < left:
		global_position.x = left
		return_direction.x += 1.0
	elif global_position.x > right:
		global_position.x = right
		return_direction.x -= 1.0
	if global_position.y < top:
		global_position.y = top
		return_direction.y += 1.0
	elif global_position.y > bottom:
		global_position.y = bottom
		return_direction.y -= 1.0

	if return_direction != Vector2.ZERO:
		_apply_boundary_repel(return_direction.normalized())

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
	return (
		_controls_enabled
		and not _travel_mode
		and not _boundary_return_active
		and _boost_charges > 0
		and _boost_remaining <= 0.001
	)

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
