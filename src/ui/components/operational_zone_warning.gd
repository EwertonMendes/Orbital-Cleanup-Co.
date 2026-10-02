extends Control
class_name OperationalZoneWarning

const EDGE_COLOR := Color(1.0, 0.64, 0.22, 1.0)
const PULSE_SPEED := 2.6

@onready var warning_panel: PanelContainer = %WarningPanel
@onready var warning_label: Label = %WarningLabel

var _ship: PlayerShip
var _target_intensity := 0.0
var _display_intensity := 0.0
var _outward_direction := Vector2.ZERO
var _impact_flash := 0.0
var _phase := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_label.text = tr("FLIGHT_OPERATIONAL_LIMIT_WARNING")
	visible = false
	set_process(false)

func refresh_locale() -> void:
	if not is_node_ready():
		return
	warning_label.text = tr("FLIGHT_OPERATIONAL_LIMIT_WARNING")

func bind(ship: PlayerShip) -> void:
	assert(ship != null, "OperationalZoneWarning requires PlayerShip.")
	if _ship != null:
		if _ship.operational_boundary_changed.is_connected(_on_boundary_changed):
			_ship.operational_boundary_changed.disconnect(_on_boundary_changed)
		if _ship.operational_boundary_repelled.is_connected(_on_boundary_repelled):
			_ship.operational_boundary_repelled.disconnect(_on_boundary_repelled)
	_ship = ship
	_ship.operational_boundary_changed.connect(_on_boundary_changed)
	_ship.operational_boundary_repelled.connect(_on_boundary_repelled)

func _process(delta: float) -> void:
	_phase = fmod(_phase + maxf(delta, 0.0) * PULSE_SPEED, TAU)
	var response := 1.0 - exp(-10.0 * maxf(delta, 0.0))
	_display_intensity = lerpf(_display_intensity, _target_intensity, response)
	_impact_flash = move_toward(_impact_flash, 0.0, maxf(delta, 0.0) * 2.8)

	var pulse := 0.5 + 0.5 * sin(_phase * TAU)
	var presentation_strength := maxf(_display_intensity, _impact_flash)
	warning_panel.visible = presentation_strength > 0.05
	warning_panel.modulate.a = clampf(0.55 + pulse * 0.35 + _impact_flash * 0.25, 0.55, 1.0)
	queue_redraw()

	if _target_intensity <= 0.001 and _display_intensity <= 0.01 and _impact_flash <= 0.01:
		visible = false
		set_process(false)

func _on_boundary_changed(intensity: float, outward_direction: Vector2) -> void:
	_target_intensity = clampf(intensity, 0.0, 1.0)
	if outward_direction.length_squared() > 0.001:
		_outward_direction = outward_direction.normalized()
	if _target_intensity > 0.001:
		visible = true
		set_process(true)
	queue_redraw()

func _on_boundary_repelled(return_direction: Vector2) -> void:
	_outward_direction = -return_direction.normalized()
	_impact_flash = 1.0
	# Keep one persistent, readable message throughout the entire boundary
	# interaction. The impact flash still communicates that forced return began.
	warning_label.text = tr("FLIGHT_OPERATIONAL_LIMIT_WARNING")
	visible = true
	set_process(true)
	queue_redraw()

func _draw() -> void:
	var strength := maxf(_display_intensity, _impact_flash * 0.75)
	if strength <= 0.01 or _outward_direction == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(_phase * TAU)
	var alpha := clampf((0.08 + pulse * 0.12) * strength + _impact_flash * 0.08, 0.0, 0.28)
	if absf(_outward_direction.x) > 0.15:
		_draw_vertical_edge(_outward_direction.x > 0.0, alpha)
	if absf(_outward_direction.y) > 0.15:
		_draw_horizontal_edge(_outward_direction.y > 0.0, alpha)

func _draw_vertical_edge(right_side: bool, alpha: float) -> void:
	var widths := [54.0, 28.0, 10.0]
	var weights := [0.24, 0.5, 1.0]
	for index in range(widths.size()):
		var width := float(widths[index])
		var x := size.x - width if right_side else 0.0
		var color := EDGE_COLOR
		color.a = alpha * float(weights[index])
		draw_rect(Rect2(Vector2(x, 0.0), Vector2(width, size.y)), color)

func _draw_horizontal_edge(bottom_side: bool, alpha: float) -> void:
	var heights := [54.0, 28.0, 10.0]
	var weights := [0.24, 0.5, 1.0]
	for index in range(heights.size()):
		var height := float(heights[index])
		var y := size.y - height if bottom_side else 0.0
		var color := EDGE_COLOR
		color.a = alpha * float(weights[index])
		draw_rect(Rect2(Vector2(0.0, y), Vector2(size.x, height)), color)
