extends Node2D
class_name AmbientOrbitLayer

const MOTE_COUNT := 34

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _accent := Color("#55e6ff")
var _nebula := Color("#183b72")
var _phase := 0.0
var _motes: Array[Dictionary] = []

func configure(play_bounds: Rect2, palette: Dictionary) -> void:
	_play_bounds = play_bounds
	_accent = Color.from_string(String(palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	_nebula = Color.from_string(String(palette.get("nebula", "#183b72")), Color("#183b72"))
	queue_redraw()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771904
	for index in range(MOTE_COUNT):
		var center := Vector2(
			rng.randf_range(_play_bounds.position.x, _play_bounds.end.x),
			rng.randf_range(_play_bounds.position.y, _play_bounds.end.y)
		)
		_motes.append({
			"center": center,
			"radius": rng.randf_range(90.0, 520.0),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.025, 0.095) * (-1.0 if index % 3 == 0 else 1.0),
			"size": rng.randf_range(0.7, 2.0),
			"alpha": rng.randf_range(0.10, 0.34),
		})
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	queue_redraw()

func _draw() -> void:
	var center := _play_bounds.get_center()
	for index in range(3):
		var radius := 760.0 + float(index) * 640.0
		var phase := _phase * (0.035 + float(index) * 0.013)
		var span := 0.72 + float(index) * 0.16
		draw_arc(
			center,
			radius,
			phase + float(index) * 1.7,
			phase + float(index) * 1.7 + span,
			54,
			Color(_accent, 0.055 - float(index) * 0.010),
			1.15,
			true
		)

	for mote in _motes:
		var angle := float(mote["phase"]) + _phase * float(mote["speed"])
		var orbit := Vector2.from_angle(angle) * float(mote["radius"])
		var position := (mote["center"] as Vector2) + orbit
		var alpha := float(mote["alpha"]) * (0.72 + sin(angle * 2.7) * 0.28)
		draw_circle(position, float(mote["size"]), Color(_accent, maxf(alpha, 0.02)))

	var drift_center := center + Vector2(cos(_phase * 0.028), sin(_phase * 0.022)) * 520.0
	draw_circle(drift_center, 360.0, Color(_nebula, 0.012))
