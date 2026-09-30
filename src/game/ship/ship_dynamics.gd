extends RefCounted
class_name ShipDynamics

static func effective_mass(dry_mass: float, cargo_mass: float, cargo_inertia_factor: float) -> float:
	var safe_dry_mass := maxf(dry_mass, 0.001)
	return safe_dry_mass + maxf(cargo_mass, 0.0) * maxf(cargo_inertia_factor, 0.0)

static func mass_response(dry_mass: float, effective_mass_value: float) -> float:
	return clampf(maxf(dry_mass, 0.001) / maxf(effective_mass_value, 0.001), 0.25, 1.0)

static func propulsion_acceleration(
	intent: Vector2,
	current_velocity: Vector2,
	tuning: ShipMovementTuning,
	effective_mass_value: float,
	thrust_multiplier: float = 1.0
) -> Vector2:
	if intent.length_squared() <= 0.001:
		return Vector2.ZERO

	var direction := intent.normalized()
	var throttle := clampf(intent.length(), 0.0, 1.0)
	var mass_authority := mass_response(tuning.dry_mass, effective_mass_value)
	var cruise_efficiency := _cruise_efficiency(
		direction,
		current_velocity,
		tuning.max_speed,
		tuning.overspeed_thrust_floor
	)
	return (
		direction
		* tuning.acceleration
		* throttle
		* mass_authority
		* clampf(thrust_multiplier, 0.4, 1.4)
		* cruise_efficiency
	)

static func boost_acceleration(
	direction: Vector2,
	tuning: ShipMovementTuning,
	effective_mass_value: float
) -> Vector2:
	if direction.length_squared() <= 0.001:
		return Vector2.ZERO
	return (
		direction.normalized()
		* tuning.boost_acceleration
		* mass_response(tuning.dry_mass, effective_mass_value)
	)

static func integrate_velocity(
	current_velocity: Vector2,
	total_acceleration: Vector2,
	linear_drag: float,
	absolute_speed_limit: float,
	delta: float
) -> Vector2:
	var next_velocity := current_velocity + total_acceleration * maxf(delta, 0.0)
	var drag := maxf(linear_drag, 0.0)
	if drag > 0.0 and delta > 0.0:
		next_velocity *= exp(-drag * delta)
	if absolute_speed_limit > 0.0:
		next_velocity = next_velocity.limit_length(absolute_speed_limit)
	return next_velocity

static func collision_response(
	current_velocity: Vector2,
	normal: Vector2,
	restitution: float,
	tangent_retention: float
) -> Vector2:
	if normal.length_squared() <= 0.001:
		return current_velocity

	var surface_normal := normal.normalized()
	var normal_speed := current_velocity.dot(surface_normal)
	if normal_speed >= 0.0:
		return current_velocity

	var normal_component := surface_normal * normal_speed
	var tangent_component := current_velocity - normal_component
	return (
		tangent_component * clampf(tangent_retention, 0.0, 1.0)
		- normal_component * clampf(restitution, 0.0, 1.0)
	)

static func _cruise_efficiency(
	thrust_direction: Vector2,
	current_velocity: Vector2,
	cruise_speed: float,
	overspeed_floor: float
) -> float:
	var safe_cruise_speed := maxf(cruise_speed, 1.0)
	var speed := current_velocity.length()
	if speed <= safe_cruise_speed or speed <= 0.001:
		return 1.0

	var alignment := maxf(thrust_direction.dot(current_velocity / speed), 0.0)
	if alignment <= 0.0:
		return 1.0

	var overspeed := speed / safe_cruise_speed - 1.0
	var aligned_efficiency := maxf(
		clampf(overspeed_floor, 0.05, 1.0),
		1.0 / (1.0 + overspeed * 4.0)
	)
	return lerpf(1.0, aligned_efficiency, alignment)
