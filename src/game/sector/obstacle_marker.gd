extends Node2D
class_name SectorObstacleMarker

var _radius := 32.0
var _phase := 0.0

func configure(radius: float) -> void:
	_radius = maxf(radius, 12.0)
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.9, TAU)
	queue_redraw()

func _draw() -> void:
	var hazard := WorldVisualLanguage.hazard_color()
	var breathe := (sin(_phase) + 1.0) * 0.5
	var ring_radius := _radius + 9.0

	draw_circle(Vector2.ZERO, _radius + 4.0, Color(0.0, 0.0, 0.0, 0.13))
	for index in range(8):
		var start := TAU * float(index) / 8.0 + 0.06
		var end := start + 0.28
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			start,
			end,
			8,
			Color(hazard, 0.35 + breathe * 0.08),
			2.2,
			true
		)

	var directions: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for direction in directions:
		var start: Vector2 = direction * (ring_radius + 1.0)
		draw_line(start, direction * (ring_radius + 7.0), Color(hazard, 0.34), 1.5, true)
