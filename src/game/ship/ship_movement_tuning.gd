extends Resource
class_name ShipMovementTuning

@export_range(80.0, 900.0, 1.0) var max_speed := 330.0
@export_range(80.0, 1800.0, 1.0) var acceleration := 720.0
@export_range(80.0, 1800.0, 1.0) var deceleration := 860.0
@export_range(1.0, 30.0, 0.1) var turn_response := 8.5
@export_range(0.0, 160.0, 1.0) var pointer_deadzone := 54.0
@export_range(80.0, 600.0, 1.0) var pointer_full_thrust_distance := 285.0
@export_range(0.1, 1.0, 0.01) var bump_speed_retention := 0.58
@export_range(20.0, 220.0, 1.0) var bump_minimum_speed := 92.0
@export_range(0.0, 160.0, 1.0) var camera_lead_distance := 72.0
@export_range(1.0, 20.0, 0.1) var camera_lead_response := 5.5
@export_range(0.0, 18.0, 0.1) var camera_shake_strength := 5.0

func validate() -> void:
	assert(max_speed > 0.0, "Ship max_speed must be positive.")
	assert(acceleration > 0.0, "Ship acceleration must be positive.")
	assert(deceleration > 0.0, "Ship deceleration must be positive.")
	assert(turn_response > 0.0, "Ship turn_response must be positive.")
	assert(pointer_deadzone >= 0.0, "Ship pointer_deadzone cannot be negative.")
	assert(pointer_full_thrust_distance > pointer_deadzone, "Full-thrust distance must be greater than deadzone.")
	assert(bump_speed_retention > 0.0 and bump_speed_retention <= 1.0, "Bump retention must be in (0, 1].")
