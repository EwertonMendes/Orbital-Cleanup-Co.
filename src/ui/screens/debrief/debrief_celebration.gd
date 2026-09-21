extends Control
class_name DebriefCelebration

var _perfect := false
var _promoted := false
var _phase := 0.0
var _sparks: Array[Dictionary] = []

func configure(perfect: bool, promoted: bool) -> void:
	_perfect = perfect
	_promoted = promoted
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	for index in range(38):
		_sparks.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.18, 0.55),
			"size": rng.randf_range(1.0, 2.8),
		})

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_rect().size
	var center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.22)
	var accent := Color("#79e6c4")
	var celebration := Color("#ffc857") if _promoted else Color("#72d7ff")

	for index in range(3):
		var radius := 120.0 + float(index) * 64.0 + sin(_phase * (0.55 + index * 0.09)) * 7.0
		var alpha := 0.08 - float(index) * 0.014
		draw_arc(
			center,
			radius,
			_phase * (0.08 + index * 0.025) + index * 0.7,
			_phase * (0.08 + index * 0.025) + index * 0.7 + 2.2,
			64,
			Color(celebration, alpha),
			2.0,
			true
		)

	if not (_perfect or _promoted):
		return

	for spark in _sparks:
		var uv := spark["uv"] as Vector2
		var motion := fmod(uv.y + _phase * float(spark["speed"]) * 0.035, 1.0)
		var position := Vector2(uv.x * viewport_size.x, motion * viewport_size.y)
		var pulse := 0.55 + sin(_phase * 1.7 + float(spark["phase"])) * 0.35
		var color := celebration if int(float(spark["phase"]) * 10.0) % 2 == 0 else accent
		draw_circle(position, float(spark["size"]), Color(color, 0.16 * pulse))
