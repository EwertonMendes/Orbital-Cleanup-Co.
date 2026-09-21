extends Node2D
class_name SectorLandmarkMarker

const REDRAW_INTERVAL := 1.0 / 20.0
var _radius := 110.0
var _phase := 0.0
var _redraw_accumulator := 0.0

func configure(radius: float) -> void:
	_radius = clampf(radius, 72.0, 380.0)
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.35, TAU)
	_redraw_accumulator += delta
	if _redraw_accumulator >= REDRAW_INTERVAL:
		_redraw_accumulator = fmod(_redraw_accumulator, REDRAW_INTERVAL)
		queue_redraw()

func _draw() -> void:
	var accent := WorldVisualLanguage.landmark_color()
	var breathe := (sin(_phase) + 1.0) * 0.5
	draw_circle(Vector2.ZERO, _radius * 0.9, Color(accent, 0.018 + breathe * 0.008))
	draw_arc(Vector2.ZERO, _radius, deg_to_rad(200.0), deg_to_rad(338.0), 44, Color(accent, 0.25), 1.6, true)
	draw_arc(Vector2.ZERO, _radius + 12.0, deg_to_rad(20.0) - _phase * 0.18, deg_to_rad(158.0) - _phase * 0.18, 44, Color(accent, 0.12), 1.0, true)
	for index in range(2):
		var angle := _phase * (0.62 + float(index) * 0.21) + float(index) * PI
		var beacon := Vector2.from_angle(angle) * (_radius + 12.0)
		draw_circle(beacon, 2.2 + breathe * 0.8, Color(accent, 0.66))
