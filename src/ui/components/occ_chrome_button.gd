extends Button
class_name OccChromeButton

@export var base_tint := Color(0.30, 0.82, 0.98, 0.92)
@export var hover_tint := Color(0.47, 0.92, 1.00, 1.00)
@export var pressed_tint := Color(0.34, 0.93, 0.74, 1.00)

@onready var chrome: NinePatchRect = %Chrome

func _ready() -> void:
	assert(chrome != null, "OccChromeButton requires Chrome.")
	custom_minimum_size.y = maxf(custom_minimum_size.y, 48.0)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	mouse_entered.connect(_refresh_visual)
	mouse_exited.connect(_refresh_visual)
	focus_entered.connect(_refresh_visual)
	focus_exited.connect(_refresh_visual)
	button_down.connect(_refresh_visual)
	button_up.connect(_refresh_visual)

	_refresh_visual()

func _refresh_visual() -> void:
	if not is_node_ready():
		return
	if button_pressed:
		chrome.modulate = pressed_tint
	elif is_hovered() or has_focus():
		chrome.modulate = hover_tint
	else:
		chrome.modulate = base_tint
