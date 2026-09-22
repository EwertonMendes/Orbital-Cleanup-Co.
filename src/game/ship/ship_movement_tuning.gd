extends Resource
class_name ShipMovementTuning

@export_range(80.0, 900.0, 1.0) var max_speed := 300.0
@export_range(80.0, 1800.0, 1.0) var acceleration := 560.0
@export_range(80.0, 1800.0, 1.0) var deceleration := 720.0
@export_range(1.0, 30.0, 0.1) var turn_response := 6.2
@export_range(1.0, 30.0, 0.1) var pointer_steering_response := 5.4
@export_range(0.0, 180.0, 1.0) var pointer_deadzone := 82.0
@export_range(120.0, 720.0, 1.0) var pointer_full_thrust_distance := 420.0
@export_range(1.05, 1.8, 0.01) var boost_speed_multiplier := 1.38
@export_range(1.0, 3.0, 0.05) var boost_acceleration_multiplier := 1.8
@export_range(0.2, 1.5, 0.01) var boost_duration := 0.62
@export_range(0.8, 8.0, 0.05) var boost_recharge_seconds := 3.2
@export_range(0.2, 1.0, 0.01) var boost_turn_authority := 0.78
@export_range(0.1, 1.0, 0.01) var bump_speed_retention := 0.52
@export_range(20.0, 220.0, 1.0) var bump_minimum_speed := 78.0
@export_range(0.0, 160.0, 1.0) var camera_lead_distance := 46.0
@export_range(1.0, 20.0, 0.1) var camera_lead_response := 7.0
@export_range(0.0, 18.0, 0.1) var camera_shake_strength := 3.6
@export_range(80.0, 600.0, 1.0) var boundary_soft_margin := 320.0
@export_range(100.0, 1800.0, 1.0) var boundary_push_acceleration := 760.0
@export_range(0.5, 20.0, 0.1) var boundary_outward_damping := 8.0
@export_range(8.0, 120.0, 1.0) var boundary_hard_padding := 42.0

func validate() -> void:
	assert(max_speed > 0.0, "Ship max_speed must be positive.")
	assert(acceleration > 0.0, "Ship acceleration must be positive.")
	assert(deceleration > 0.0, "Ship deceleration must be positive.")
	assert(turn_response > 0.0, "Ship turn_response must be positive.")
	assert(pointer_steering_response > 0.0, "Pointer steering response must be positive.")
	assert(pointer_deadzone >= 0.0, "Ship pointer_deadzone cannot be negative.")
	assert(pointer_full_thrust_distance > pointer_deadzone, "Full-thrust distance must be greater than deadzone.")
	assert(boost_speed_multiplier > 1.0, "Boost speed must exceed normal top speed.")
	assert(boost_acceleration_multiplier >= 1.0, "Boost acceleration cannot be weaker than normal thrust.")
	assert(boost_duration > 0.0 and boost_recharge_seconds > boost_duration, "Boost requires a short pulse and a longer recharge.")
	assert(boost_turn_authority > 0.0 and boost_turn_authority <= 1.0, "Boost turn authority must be in (0, 1].")
	assert(bump_speed_retention > 0.0 and bump_speed_retention <= 1.0, "Bump retention must be in (0, 1].")
	assert(boundary_soft_margin > boundary_hard_padding, "Boundary soft margin must exceed hard padding.")
