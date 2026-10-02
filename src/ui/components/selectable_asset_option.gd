extends TextureButton
class_name SelectableAssetOption

## Reusable asset-first selector for lists such as language/cosmetic choices.
## The artwork itself is the interactive surface; no generic button chrome is
## drawn around it. Focus/hover darken the asset and selection is persistent.

@export var value_id := ""

const NORMAL_TINT := Color(1.0, 1.0, 1.0, 1.0)
const HOVER_TINT := Color(0.64, 0.68, 0.73, 1.0)
const SELECTED_HOVER_TINT := Color(0.78, 0.81, 0.85, 1.0)
const FOCUS_RING := Color(0.43, 0.91, 1.0, 0.95)
const SELECTED_RING := Color(1.0, 0.78, 0.22, 1.0)
const SELECTED_GLOW := Color(0.43, 0.91, 1.0, 0.48)

var _selected := false
var _hovered := false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_refresh_visual)
	focus_exited.connect(_refresh_visual)
	_refresh_visual()

func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_refresh_visual()

func is_selected() -> bool:
	return _selected

func _on_hover_changed(value: bool) -> void:
	_hovered = value
	_refresh_visual()

func _refresh_visual() -> void:
	var emphasized := _hovered or has_focus()
	if _selected:
		self_modulate = SELECTED_HOVER_TINT if emphasized else NORMAL_TINT
	else:
		self_modulate = HOVER_TINT if emphasized else NORMAL_TINT
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43

	if _selected:
		draw_arc(center, radius, 0.0, TAU, 64, SELECTED_RING, 4.0, true)
		draw_arc(center, radius + 5.0, 0.0, TAU, 64, SELECTED_GLOW, 2.0, true)

		var marker_center := Vector2(size.x - 14.0, 14.0)
		draw_circle(marker_center, 10.0, Color(0.025, 0.06, 0.09, 0.98))
		draw_arc(marker_center, 10.0, 0.0, TAU, 24, SELECTED_RING, 2.0, true)
		draw_line(marker_center + Vector2(-4.0, 0.0), marker_center + Vector2(-1.0, 3.5), SELECTED_RING, 2.4, true)
		draw_line(marker_center + Vector2(-1.0, 3.5), marker_center + Vector2(5.0, -4.0), SELECTED_RING, 2.4, true)

	if _hovered or has_focus():
		draw_arc(center, radius + 9.0, 0.0, TAU, 64, FOCUS_RING, 2.2, true)
