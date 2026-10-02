extends Resource
class_name ShipMovementTuning

# max_speed is the nominal cruise reference, not a hard velocity clamp.
@export_range(80.0, 900.0, 1.0) var max_speed := 300.0
@export_range(80.0, 1800.0, 1.0) var acceleration := 420.0
@export_range(2.0, 80.0, 0.5) var dry_mass := 12.0
@export_range(0.0, 1.0, 0.01) var cargo_inertia_factor := 0.35
@export_range(0.05, 1.0, 0.01) var overspeed_thrust_floor := 0.18
@export_range(300.0, 1400.0, 5.0) var absolute_speed_limit := 720.0
@export_range(1.0, 30.0, 0.1) var turn_response := 6.2
@export_range(1.0, 30.0, 0.1) var pointer_steering_response := 5.4
@export_range(0.0, 180.0, 1.0) var pointer_deadzone := 82.0
@export_range(120.0, 720.0, 1.0) var pointer_full_thrust_distance := 420.0
@export_range(40.0, 600.0, 5.0) var boost_acceleration := 220.0
@export_range(0.2, 1.5, 0.01) var boost_duration := 0.62
@export_range(0.8, 8.0, 0.05) var boost_recharge_seconds := 3.2
@export_range(0.2, 1.0, 0.01) var boost_turn_authority := 0.78
@export_range(0.0, 1.0, 0.01) var collision_restitution := 0.28
@export_range(0.0, 1.0, 0.01) var collision_tangent_retention := 0.86
@export_range(1, 4, 1) var collision_iterations := 3
@export_range(0.0, 160.0, 1.0) var camera_lead_distance := 46.0
@export_range(1.0, 20.0, 0.1) var camera_lead_response := 7.0
@export_range(0.0, 18.0, 0.1) var camera_shake_strength := 3.6
@export_range(240.0, 2400.0, 10.0) var boundary_return_trigger_margin := 1500.0
@export_range(300.0, 2200.0, 10.0) var boundary_hard_escape_margin := 900.0
@export_range(420.0, 1400.0, 5.0) var boundary_return_speed := 900.0
@export_range(1800.0, 6400.0, 10.0) var boundary_return_max_speed := 5600.0
@export_range(0.75, 1.4, 0.05) var boundary_return_target_seconds := 1.0
@export_range(6.0, 28.0, 0.1) var boundary_return_velocity_response := 18.0
@export_range(80.0, 320.0, 5.0) var boundary_return_reentry_depth := 180.0
@export_range(180.0, 720.0, 5.0) var boundary_return_exit_speed := 360.0
@export_range(4.0, 24.0, 0.1) var boundary_return_turn_response := 16.0

func validate() -> void:
	assert(max_speed > 0.0, "Ship cruise speed must be positive.")
	assert(acceleration > 0.0, "Ship acceleration must be positive.")
	assert(dry_mass > 0.0, "Ship dry mass must be positive.")
	assert(cargo_inertia_factor >= 0.0, "Cargo inertia factor cannot be negative.")
	assert(overspeed_thrust_floor > 0.0 and overspeed_thrust_floor <= 1.0, "Overspeed thrust floor must be in (0, 1].")
	assert(absolute_speed_limit > max_speed, "Absolute safety speed must exceed nominal cruise speed.")
	assert(turn_response > 0.0, "Ship turn_response must be positive.")
	assert(pointer_steering_response > 0.0, "Pointer steering response must be positive.")
	assert(pointer_deadzone >= 0.0, "Ship pointer_deadzone cannot be negative.")
	assert(pointer_full_thrust_distance > pointer_deadzone, "Full-thrust distance must be greater than deadzone.")
	assert(boost_acceleration > 0.0, "Boost acceleration must be positive.")
	assert(boost_duration > 0.0 and boost_recharge_seconds > boost_duration, "Boost requires a short pulse and a longer recharge.")
	assert(boost_turn_authority > 0.0 and boost_turn_authority <= 1.0, "Boost turn authority must be in (0, 1].")
	assert(collision_restitution >= 0.0 and collision_restitution <= 1.0, "Collision restitution must be in [0, 1].")
	assert(collision_tangent_retention >= 0.0 and collision_tangent_retention <= 1.0, "Collision tangent retention must be in [0, 1].")
	assert(collision_iterations >= 1, "Collision solver requires at least one iteration.")
	assert(boundary_return_trigger_margin > 0.0, "Boundary return trigger margin must leave a spatial recovery band outside play_bounds.")
	assert(boundary_hard_escape_margin > 0.0, "Numerical containment margin must remain beyond the return trigger.")
	assert(boundary_return_speed > absolute_speed_limit, "Boundary return must be visibly faster than normal flight containment speed.")
	assert(boundary_return_max_speed > boundary_return_speed, "Boundary return needs adaptive emergency speed for distant exits.")
	assert(boundary_return_target_seconds >= 0.8 and boundary_return_target_seconds <= 1.2, "Boundary return should complete in about one second.")
	assert(boundary_return_velocity_response > 0.0, "Boundary return velocity response must be positive.")
	assert(boundary_return_reentry_depth > 0.0, "Boundary return must carry the ship a safe distance back inside the map.")
	assert(boundary_return_exit_speed > 0.0 and boundary_return_exit_speed <= absolute_speed_limit, "Boundary return must hand control back at a normal controllable speed.")
	assert(boundary_return_turn_response > turn_response, "Boundary auto-return must rotate the ship more decisively than normal steering.")
