extends RefCounted
class_name OccCursorSkin

const ARROW := preload("res://assets/third_party/kenney_ui_sci_fi/ui/Extra/cursor_h.png")
const POINT := preload("res://assets/third_party/kenney_ui_sci_fi/ui/Extra/cursor_c.png")
const PRESSED := preload("res://assets/third_party/kenney_ui_sci_fi/ui/Extra/cursor_d.png")

static func apply() -> void:
	Input.set_custom_mouse_cursor(ARROW, Input.CURSOR_ARROW, Vector2(2, 2))
	Input.set_custom_mouse_cursor(POINT, Input.CURSOR_POINTING_HAND, Vector2(7, 4))

static func set_pressed() -> void:
	Input.set_custom_mouse_cursor(PRESSED, Input.CURSOR_POINTING_HAND, Vector2(7, 4))

static func set_pointing() -> void:
	Input.set_custom_mouse_cursor(POINT, Input.CURSOR_POINTING_HAND, Vector2(7, 4))
