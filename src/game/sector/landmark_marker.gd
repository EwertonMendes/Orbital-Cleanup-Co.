extends Node2D
class_name SectorLandmarkMarker

var _radius := 110.0
var _phase := 0.0

func configure(radius: float) -> void:
	_radius = maxf(radius, 72.0)
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.35, TAU)
	queue_redraw()

func _draw() -> void:
	var accent := WorldVisualLanguage.landmark_color()
	var breathe := (sin(_phase) + 1.0) * 0.5
	draw_circle(Vector2.ZERO, _radius * 0.9, Color(accent, 0.018 + breathe * 0.008))
	draw_arc(Vector2.ZERO, _radius, deg_to_rad(200.0), deg_to_rad(338.0), 44, Color(accent, 0.25), 1.6, true)
	draw_arc(Vector2.ZERO, _radius + 12.0, deg_to_rad(20.0), deg_to_rad(158.0), 44, Color(accent, 0.12), 1.0, true)
