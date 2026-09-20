extends Camera2D
class_name ShipCamera

var _tuning: ShipMovementTuning
var _motion_velocity := Vector2.ZERO
var _lead_offset := Vector2.ZERO
var _shake_energy := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20260920
	position_smoothing_enabled = true
	position_smoothing_speed = 5.5

func configure(tuning: ShipMovementTuning) -> void:
	assert(tuning != null, "ShipCamera requires movement tuning.")
	_tuning = tuning
	position_smoothing_speed = tuning.camera_lead_response

func set_motion_velocity(value: Vector2) -> void:
	_motion_velocity = value

func add_bump_shake(intensity: float) -> void:
	_shake_energy = maxf(_shake_energy, clampf(intensity, 0.0, 1.0))

func _process(delta: float) -> void:
	if _tuning == null:
		return

	var speed_ratio := clampf(_motion_velocity.length() / _tuning.max_speed, 0.0, 1.0)
	var desired_lead := Vector2.ZERO
	if _motion_velocity.length_squared() > 0.01:
		desired_lead = _motion_velocity.normalized() * _tuning.camera_lead_distance * speed_ratio

	var lead_weight := 1.0 - exp(-_tuning.camera_lead_response * delta)
	_lead_offset = _lead_offset.lerp(desired_lead, lead_weight)

	_shake_energy = move_toward(_shake_energy, 0.0, delta * 4.8)
	var shake := Vector2.ZERO
	if _shake_energy > 0.001:
		shake = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		shake *= _tuning.camera_shake_strength * _shake_energy

	offset = _lead_offset + shake
