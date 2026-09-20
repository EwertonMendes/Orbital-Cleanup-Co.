extends CharacterBody2D
class_name PlayerShip

signal movement_started
signal bumped(intensity: float, normal: Vector2)

@export var tuning: ShipMovementTuning

@onready var visuals: ShipVisuals = %FeedbackRoot
@onready var ship_camera: ShipCamera = %ShipCamera

var _input_service: InputService
var _has_started_moving := false
var _bump_feedback_cooldown := 0.0

func configure(input_service: InputService) -> void:
	assert(input_service != null, "PlayerShip requires InputService.")
	_input_service = input_service

func _ready() -> void:
	assert(tuning != null, "PlayerShip requires ShipMovementTuning.")
	tuning.validate()
	assert(_input_service != null, "PlayerShip must be configured with InputService before entering the tree.")
	ship_camera.configure(tuning)
	print("[Ship] READY")
	
func _physics_process(delta: float) -> void:
	_bump_feedback_cooldown = maxf(_bump_feedback_cooldown - delta, 0.0)

	var keyboard_intent := _input_service.get_navigation_vector()
	var pointer_intent := Vector2.ZERO
	if keyboard_intent.length_squared() <= 0.001 and _input_service.is_primary_pointer_active():
		pointer_intent = ShipSteering.pointer_intent(
			get_global_transform_with_canvas().origin,
			_input_service.get_primary_pointer_position(),
			tuning.pointer_deadzone,
			tuning.pointer_full_thrust_distance
		)

	var intent := ShipSteering.combine_intent(keyboard_intent, pointer_intent)
	var desired_velocity := ShipSteering.target_velocity(intent, tuning.max_speed)
	var response := tuning.deceleration
	if intent.length_squared() > 0.001:
		response = tuning.acceleration * lerpf(0.42, 1.0, intent.length())

	velocity = velocity.move_toward(desired_velocity, response * delta)

	var turn_amount := _update_facing(intent, delta)
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_apply_bump(collision)

	var speed_ratio := clampf(velocity.length() / tuning.max_speed, 0.0, 1.0)
	visuals.update_motion(speed_ratio, intent.length(), turn_amount, delta)
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
	var difference := wrapf(target_rotation - rotation, -PI, PI)
	var weight := 1.0 - exp(-tuning.turn_response * delta)
	rotation = lerp_angle(rotation, target_rotation, weight)
	return clampf(difference / (PI * 0.5), -1.0, 1.0)

func _apply_bump(collision: KinematicCollision2D) -> void:
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
