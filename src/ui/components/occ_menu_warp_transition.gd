extends Control
class_name OccMenuWarpTransition

var _intensity := 0.0
var _phase := 0.0
var _direction := 1.0
var _active := false
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func play(direction: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_direction = -1.0 if direction < 0.0 else 1.0
	_phase = 0.0
	_active = true
	visible = true
	set_process(true)
	_set_intensity(0.0)

	_tween = create_tween()
	_tween.tween_method(_set_intensity, 0.0, 1.0, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.06)
	_tween.tween_method(_set_intensity, 1.0, 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish)

func _process(delta: float) -> void:
	if not _active:
		return
	_phase = fposmod(_phase + delta * lerpf(1.2, 6.5, _intensity), 1.0)
	queue_redraw()

func _draw() -> void:
	if _intensity <= 0.01:
		return
	var content_rect := Rect2(
		Vector2(size.x * 0.22, size.y * 0.15),
		Vector2(size.x * 0.74, size.y * 0.72)
	)
	if content_rect.size.x <= 4.0 or content_rect.size.y <= 4.0:
		return

	var wash := Color(0.72, 0.86, 0.96, 0.055 * _intensity)
	draw_rect(content_rect, wash, true)

	var axis := Vector2(_direction, 0.0)
	for index in range(34):
		var lane := fposmod(float(index) * 0.61803398875, 1.0)
		var along := fposmod(float(index) * 0.38196601125 + _phase * (0.88 + float(index % 5) * 0.07), 1.0)
		var point := Vector2(
			content_rect.position.x + along * content_rect.size.x,
			content_rect.position.y + lane * content_rect.size.y
		)
		var length := lerpf(10.0, 132.0 + float(index % 4) * 16.0, _intensity)
		var alpha := (0.10 + float(index % 5) * 0.022) * _intensity
		var tint := Color(0.42, 0.76, 0.90, alpha)
		draw_line(point - axis * length * 0.5, point + axis * length * 0.5, tint, 1.4 + _intensity, true)
		if index % 6 == 0:
			draw_circle(point + axis * length * 0.48, 1.2 + _intensity * 1.3, Color(0.78, 0.94, 1.0, alpha * 1.25))

func _set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	queue_redraw()

func _finish() -> void:
	_intensity = 0.0
	_active = false
	visible = false
	set_process(false)
	queue_redraw()
