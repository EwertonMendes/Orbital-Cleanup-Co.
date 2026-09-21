extends Control
class_name WarpTravelTransition

signal departure_finished
signal arrival_finished

const MIN_TRAVEL_DISTANCE := 980.0
const DEPARTURE_DIRECTION := Vector2.RIGHT

var _intensity := 0.0
var _direction := DEPARTURE_DIRECTION
var _phase := 0.0
var _active := false
var _ship: PlayerShip

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func play_departure(ship: PlayerShip, direction: Vector2 = DEPARTURE_DIRECTION) -> void:
	assert(ship != null, "WarpTravelTransition requires a PlayerShip.")
	if _active:
		return

	_active = true
	_ship = ship
	_direction = _normalized_direction(direction)
	_phase = 0.0
	visible = true
	set_process(true)

	var origin := ship.global_position
	var distance := _travel_distance()
	ship.begin_travel(_direction)
	_set_intensity(0.10)

	var charge := create_tween()
	charge.set_parallel(true)
	charge.tween_property(ship, "global_position", origin - _direction * 20.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	charge.tween_method(_set_intensity, 0.10, 0.42, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await charge.finished

	var launch := create_tween()
	launch.set_parallel(true)
	launch.tween_property(ship, "global_position", origin + _direction * distance, 0.58).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	launch.tween_method(_set_intensity, 0.42, 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await launch.finished
	await get_tree().create_timer(0.08).timeout

	print("[Travel] DEPARTURE_COMPLETE direction=%s" % str(_direction))
	departure_finished.emit()

func play_arrival(ship: PlayerShip, direction: Vector2 = DEPARTURE_DIRECTION, restore_collection: bool = true) -> void:
	assert(ship != null, "WarpTravelTransition requires a PlayerShip.")
	if _active:
		return

	_active = true
	_ship = ship
	_direction = _normalized_direction(direction)
	_phase = 0.0
	visible = true
	set_process(true)

	var destination := ship.global_position
	var distance := _travel_distance()
	ship.begin_travel(_direction)
	ship.global_position = destination - _direction * distance
	_set_intensity(1.0)

	var arrival := create_tween()
	arrival.set_parallel(true)
	arrival.tween_property(ship, "global_position", destination, 0.72).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	arrival.tween_method(_set_intensity, 1.0, 0.18, 0.68).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await arrival.finished

	var settle := create_tween()
	settle.tween_method(_set_intensity, 0.18, 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await settle.finished

	ship.end_travel(restore_collection)
	_finish()
	print("[Travel] ARRIVAL_COMPLETE direction=%s" % str(_direction))
	arrival_finished.emit()

func _process(delta: float) -> void:
	if not _active:
		return
	_phase = fposmod(_phase + delta * lerpf(0.8, 5.6, _intensity), 1.0)
	queue_redraw()

func _draw() -> void:
	if _intensity <= 0.005:
		return

	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size

	var wash_alpha := 0.035 + _intensity * 0.10
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.05, 0.16, 0.24, wash_alpha), true)

	var travel_axis := _direction.normalized()
	var perpendicular := Vector2(-travel_axis.y, travel_axis.x)
	for index in range(42):
		var lane := fposmod(float(index) * 0.61803398875, 1.0)
		var along := fposmod(float(index) * 0.38196601125 + _phase * (0.72 + float(index % 7) * 0.045), 1.0)
		var center := viewport_size * 0.5
		var cross_extent := maxf(viewport_size.x, viewport_size.y) * 0.72
		var along_extent := maxf(viewport_size.x, viewport_size.y) * 0.92
		var point := center + perpendicular * ((lane - 0.5) * cross_extent) + travel_axis * ((along - 0.5) * along_extent)
		var length := lerpf(4.0, 150.0 + float(index % 5) * 18.0, _intensity)
		var width := lerpf(0.7, 2.3, _intensity)
		var alpha := (0.10 + float(index % 6) * 0.018) * _intensity
		var tint := Color(0.46, 0.90, 1.0, alpha)
		draw_line(point - travel_axis * length * 0.5, point + travel_axis * length * 0.5, tint, width, true)
		if index % 4 == 0:
			draw_circle(point + travel_axis * length * 0.48, 1.2 + _intensity * 1.8, Color(0.72, 0.98, 1.0, alpha * 1.35))

func _set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _ship != null and is_instance_valid(_ship):
		_ship.set_travel_visual_intensity(_intensity)
	queue_redraw()

func _finish() -> void:
	_intensity = 0.0
	_active = false
	_ship = null
	visible = false
	set_process(false)
	queue_redraw()

func _travel_distance() -> float:
	var viewport_size := get_viewport_rect().size
	return maxf(MIN_TRAVEL_DISTANCE, maxf(viewport_size.x, viewport_size.y) * 1.12)

func _normalized_direction(value: Vector2) -> Vector2:
	if value.length_squared() <= 0.001:
		return DEPARTURE_DIRECTION
	return value.normalized()
