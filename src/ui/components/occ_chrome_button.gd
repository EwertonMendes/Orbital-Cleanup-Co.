extends Button
class_name OccChromeButton

@export_enum("auto", "tab", "utility") var role: String = "auto":
	set(value):
		role = value
		_apply_type_variation()

@export var emphasis := false:
	set(value):
		emphasis = value
		_apply_type_variation()

func _ready() -> void:
	var profile := ResponsiveUiProfile.current()
	custom_minimum_size.y = maxf(
		custom_minimum_size.y,
		ResponsiveUiProfile.touch_target_height(profile)
	)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(_pressed_visual)
	button_up.connect(_released_visual)
	focus_exited.connect(_released_visual)
	_apply_type_variation()

func _apply_type_variation() -> void:
	if not is_inside_tree():
		return
	match role:
		"tab":
			theme_type_variation = &"TabButton"
		"utility":
			theme_type_variation = &"UtilityButton"
		_:
			theme_type_variation = &"PrimaryButton" if emphasis else &"SecondaryButton"

func _pressed_visual() -> void:
	OccCursorSkin.set_pressed()

func _released_visual() -> void:
	OccCursorSkin.set_pointing()
