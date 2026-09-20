extends RefCounted
class_name ShipSteering

static func pointer_intent(
	ship_viewport_position: Vector2,
	pointer_viewport_position: Vector2,
	deadzone: float,
	full_thrust_distance: float
) -> Vector2:
	var offset := pointer_viewport_position - ship_viewport_position
	var distance := offset.length()
	if distance <= deadzone or distance <= 0.001:
		return Vector2.ZERO

	var usable_range := maxf(full_thrust_distance - deadzone, 1.0)
	var linear_strength := clampf((distance - deadzone) / usable_range, 0.0, 1.0)
	var eased_strength := linear_strength * linear_strength * (3.0 - 2.0 * linear_strength)
	return offset.normalized() * eased_strength

static func combine_intent(keyboard: Vector2, pointer: Vector2) -> Vector2:
	if keyboard.length_squared() > 0.001:
		return keyboard.limit_length(1.0)
	return pointer.limit_length(1.0)

static func target_velocity(intent: Vector2, max_speed: float) -> Vector2:
	return intent.limit_length(1.0) * maxf(max_speed, 0.0)
