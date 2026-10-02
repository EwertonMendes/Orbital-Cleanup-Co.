extends Node2D
class_name PropulsionTrailRig

@onready var trail_a: EngineTrail = %TrailA
@onready var trail_b: EngineTrail = %TrailB
@onready var trail_c: EngineTrail = %TrailC

var _trails: Array[EngineTrail] = []
var _configured := false
var _preview_mode := false
var _target_intensity := 0.0
var _boost_ratio := 0.0

func _ready() -> void:
	_trails = [trail_a, trail_b, trail_c]

func configure(style: Dictionary, palette: Dictionary, visual_scale: float = 1.0) -> void:
	assert(not style.is_empty(), "PropulsionTrailRig requires a propulsion style.")
	assert(not palette.is_empty(), "PropulsionTrailRig requires a trail palette.")
	var trail_style := style.get("trail", {}) as Dictionary
	assert(not trail_style.is_empty(), "Propulsion style requires trail data.")
	var strand_count := clampi(int(trail_style.get("strand_count", 1)), 1, _trails.size())
	var spread := float(trail_style.get("strand_spread", 0.0))
	var width_decay := clampf(float(trail_style.get("strand_width_decay", 0.72)), 0.10, 1.0)
	var alpha_decay := clampf(float(trail_style.get("strand_alpha_decay", 0.78)), 0.10, 1.0)
	var mode := String(trail_style.get("mode", "ribbon"))

	for index in range(_trails.size()):
		var trail := _trails[index]
		var enabled := index < strand_count
		trail.set_enabled(enabled)
		if not enabled:
			continue
		var phase := 0.0
		if mode == "dual_helix" and strand_count == 2:
			phase = PI * float(index)
		elif strand_count > 1:
			phase = TAU * float(index) / float(strand_count)
		var centered_index := float(index) - float(strand_count - 1) * 0.5
		var offset := 0.0 if mode == "dual_helix" else centered_index * spread
		trail.apply_style(
			trail_style,
			palette,
			phase,
			pow(alpha_decay, float(index)),
			pow(width_decay, float(index)),
			offset,
			visual_scale
		)

	_configured = true
	set_preview_mode(_preview_mode)
	set_motion(_target_intensity, _boost_ratio)

func set_preview_mode(value: bool) -> void:
	_preview_mode = value
	for trail in _trails:
		trail.set_preview_mode(value)
	if value:
		set_motion(0.82, 0.10)

func set_motion(intensity: float, boost: float = 0.0) -> void:
	_target_intensity = clampf(intensity, 0.0, 1.0)
	_boost_ratio = clampf(boost, 0.0, 1.0)
	if not _configured:
		return
	for trail in _trails:
		trail.set_intensity(maxf(_target_intensity, _boost_ratio))
		trail.set_boost(_boost_ratio)

func play_boost() -> void:
	if not _configured:
		return
	for trail in _trails:
		trail.set_intensity(1.0)
