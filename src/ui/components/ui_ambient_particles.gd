extends Control
class_name UiAmbientParticles

var _particles: Array[Dictionary] = []
var _phase := 0.0
var _redraw_clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 9152026
	for index in range(22):
		_particles.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"speed": rng.randf_range(0.014, 0.042),
			"radius": rng.randf_range(0.7, 1.8),
			"alpha": rng.randf_range(0.08, 0.28),
			"phase": rng.randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	_redraw_clock += delta
	if _redraw_clock >= 0.05:
		_redraw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	for particle in _particles:
		var uv := particle["uv"] as Vector2
		var drift := fposmod(uv.y - _phase * float(particle["speed"]), 1.0)
		var x := uv.x * viewport_size.x + sin(_phase * 0.22 + float(particle["phase"])) * 10.0
		var y := drift * viewport_size.y
		var edge_weight: float = absf(uv.x - 0.5) * 2.0
		var alpha: float = float(particle["alpha"]) * lerpf(0.34, 1.0, edge_weight)
		var tint := OccPalette.MINT if int(float(particle["phase"]) * 10.0) % 5 == 0 else OccPalette.CYAN
		draw_circle(Vector2(x, y), float(particle["radius"]), Color(tint, alpha))
