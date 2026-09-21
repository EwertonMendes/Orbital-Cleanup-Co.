extends Control
class_name DepotNavigationGuide

const UPDATE_INTERVAL := 1.0 / 30.0
const EDGE_PADDING := 42.0
const NEAR_DISTANCE := 430.0
const LABEL_SIZE := Vector2(176.0, 28.0)

@onready var distance_label: Label = %DepotNavLabel

var _ship: PlayerShip
var _depot: Node2D
var _cargo_used := 0
var _cargo_capacity := 1
var _update_accumulator := 0.0
var _target_alpha := 0.0
var _marker_position := Vector2.ZERO
var _direction := Vector2.RIGHT
var _configured := false

func configure(ship: PlayerShip, depot: Node2D) -> void:
	assert(ship != null, "DepotNavigationGuide requires PlayerShip.")
	assert(depot != null, "DepotNavigationGuide requires depot target.")
	_ship = ship
	_depot = depot
	_configured = true
	_update_navigation()

func set_cargo_state(used_units: int, capacity: int) -> void:
	_cargo_used = maxi(used_units, 0)
	_cargo_capacity = maxi(capacity, 1)
	if _configured:
		_update_navigation()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label.custom_minimum_size = LABEL_SIZE
	modulate.a = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var previous_alpha := modulate.a
	modulate.a = move_toward(modulate.a, _target_alpha, delta * 5.5)
	if not is_equal_approx(previous_alpha, modulate.a):
		queue_redraw()

	if not _configured or _ship == null or _depot == null:
		return

	_update_accumulator += delta
	if _update_accumulator < UPDATE_INTERVAL:
		return
	_update_accumulator = fmod(_update_accumulator, UPDATE_INTERVAL)
	_update_navigation()

func _update_navigation() -> void:
	if not is_inside_tree() or _ship == null or _depot == null:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var portrait := viewport_size.y > viewport_size.x
	var top_inset := minf(viewport_size.y * (0.34 if portrait else 0.22), 292.0 if portrait else 158.0)
	var bottom_inset := 52.0
	var side_inset := 46.0
	var navigation_rect := Rect2(
		Vector2(side_inset, top_inset),
		Vector2(
			maxf(viewport_size.x - side_inset * 2.0, 120.0),
			maxf(viewport_size.y - top_inset - bottom_inset, 100.0)
		)
	)

	var depot_screen := get_viewport().get_canvas_transform() * _depot.global_position
	var world_distance := _ship.global_position.distance_to(_depot.global_position)
	var depot_visible := navigation_rect.grow(-26.0).has_point(depot_screen)

	if depot_visible or world_distance <= NEAR_DISTANCE:
		_target_alpha = 0.0
		distance_label.visible = false
		return

	var center := navigation_rect.get_center()
	var ray := depot_screen - center
	if ray.length_squared() <= 0.01:
		_target_alpha = 0.0
		distance_label.visible = false
		return

	_direction = ray.normalized()
	var half := navigation_rect.size * 0.5
	var tx := INF if absf(ray.x) < 0.001 else half.x / absf(ray.x)
	var ty := INF if absf(ray.y) < 0.001 else half.y / absf(ray.y)
	var edge_t := minf(tx, ty)
	_marker_position = center + ray * edge_t - _direction * 12.0
	_marker_position.x = clampf(_marker_position.x, navigation_rect.position.x, navigation_rect.end.x)
	_marker_position.y = clampf(_marker_position.y, navigation_rect.position.y, navigation_rect.end.y)

	var full := _cargo_used >= _cargo_capacity
	var distance_text := _format_distance(world_distance)
	distance_label.text = tr("FLIGHT_DEPOT_NAV_FULL_FMT") % distance_text if full else tr("FLIGHT_DEPOT_NAV_FMT") % distance_text
	distance_label.add_theme_color_override(
		"font_color",
		Color("#ffc857") if full else Color("#9fe9ff")
	)
	distance_label.visible = true

	var inward := -_direction * 72.0
	var label_center := _marker_position + inward
	var label_position := label_center - LABEL_SIZE * 0.5
	label_position.x = clampf(label_position.x, navigation_rect.position.x, navigation_rect.end.x - LABEL_SIZE.x)
	label_position.y = clampf(label_position.y, navigation_rect.position.y, navigation_rect.end.y - LABEL_SIZE.y)
	distance_label.position = label_position
	distance_label.size = LABEL_SIZE

	_target_alpha = 1.0 if full else 0.78
	queue_redraw()

func _format_distance(distance: float) -> String:
	if distance >= 1000.0:
		return tr("FLIGHT_DISTANCE_KM_FMT") % (distance / 1000.0)
	var rounded_meters := int(round(distance / 10.0)) * 10
	return tr("FLIGHT_DISTANCE_M_FMT") % rounded_meters

func _draw() -> void:
	if not distance_label.visible or modulate.a <= 0.01:
		return

	var full := _cargo_used >= _cargo_capacity
	var accent := Color("#ffc857") if full else Color("#77dff6")
	var backdrop := Color(0.015, 0.050, 0.070, 0.76)

	draw_circle(_marker_position, 18.0, backdrop)
	draw_arc(
		_marker_position,
		18.0,
		_direction.angle() - 1.05,
		_direction.angle() + 1.05,
		18,
		Color(accent, 0.78),
		2.0,
		true
	)

	var perpendicular := Vector2(-_direction.y, _direction.x)
	var tip := _marker_position + _direction * 11.0
	var tail := _marker_position - _direction * 5.5
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			tail + perpendicular * 5.5,
			tail - perpendicular * 5.5,
		]),
		accent
	)
	draw_circle(_marker_position, 2.2, Color(accent, 0.92))
