extends Button
class_name OccActionButton

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 46.0)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
