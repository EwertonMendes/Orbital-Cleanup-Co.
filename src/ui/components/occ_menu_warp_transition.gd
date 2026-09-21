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
	_tween.tween_method(_set_intensity, 0.0, 1.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.10)
	_tween.tween_method(_set_intensity, 1.0, 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish)

func _process(delta: float) -> void:
	if not _active:
		return
	_phase = fposmod(_phase + delta * lerpf(1.8, 8.0, _intensity), 1.0)
	queue_redraw()

func _draw() -> void:
	if _intensity <= 0.01:
		return

	var content_rect := Rect2(
		Vector2(size.x * 0.20, size.y * 0.13),
		Vector2(size.x * 0.77, size.y * 0.76)
	)
	if content_rect.size.x <= 4.0 or content_rect.size.y <= 4.0:
		return

	draw_rect(
		content_rect,
		Color(0.40, 0.72, 0.90, 0.10 * _intensity),
		true
	)

	var axis := Vector2(_direction, 0.0)
	for index in range(54):
		var lane := fposmod(float(index) * 0.61803398875, 1.0)
		var along := fposmod(
			float(index) * 0.38196601125
			+ _phase * (0.88 + float(index % 7) * 0.08),
			1.0
		)
		var point := Vector2(
			content_rect.position.x + along * content_rect.size.x,
			content_rect.position.y + lane * content_rect.size.y
		)
		var length := lerpf(16.0, 190.0 + float(index % 5) * 22.0, _intensity)
		var alpha := (0.14 + float(index % 6) * 0.026) * _intensity
		var width := lerpf(1.0, 2.6, _intensity)
		var tint := Color(0.42, 0.80, 1.0, alpha)

		draw_line(
			point - axis * length * 0.5,
			point + axis * length * 0.5,
			tint,
			width,
			true
		)

		if index % 5 == 0:
			draw_circle(
				point + axis * length * 0.48,
				1.4 + _intensity * 2.0,
				Color(0.82, 0.96, 1.0, alpha * 1.3)
			)

	var band_y := content_rect.position.y + content_rect.size.y * 0.48
	var band_alpha := 0.12 * _intensity
	draw_line(
		Vector2(content_rect.position.x, band_y),
		Vector2(content_rect.end.x, band_y),
		Color(0.76, 0.94, 1.0, band_alpha),
		1.5 + _intensity * 1.5,
		true
	)

func _set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	queue_redraw()

func _finish() -> void:
	_intensity = 0.0
	_active = false
	visible = false
	set_process(false)
	queue_redraw()
