extends Button
class_name OccChromeButton

@export_enum("auto", "tab", "utility") var role: String = "auto":
	set(value):
		role = value
		_apply_type_variation()

@export var base_tint := Color(0.27, 0.72, 0.86, 0.58):
	set(value):
		base_tint = value
		_apply_tint()

@export var hover_tint := Color(0.43, 0.88, 0.98, 0.92)
@export var pressed_tint := Color(0.56, 0.95, 0.81, 0.92)
@export var emphasis := false:
	set(value):
		emphasis = value
		_apply_type_variation()

var _motion_tween: Tween
var _rest_position := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 48.0)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_update_pivot)
	mouse_entered.connect(_animate_state.bind(true))
	mouse_exited.connect(_animate_state.bind(false))
	focus_entered.connect(_animate_state.bind(true))
	focus_exited.connect(_animate_state.bind(false))
	button_down.connect(_animate_pressed)
	button_up.connect(_animate_state.bind(is_hovered() or has_focus()))
	_apply_type_variation()
	_apply_tint()
	call_deferred("_capture_rest_geometry")

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

func _apply_tint() -> void:
	if not is_inside_tree():
		return
	var weight := 0.07 if emphasis else 0.025
	self_modulate = Color.WHITE.lerp(Color(base_tint.r, base_tint.g, base_tint.b, 1.0), weight)

func _capture_rest_geometry() -> void:
	_rest_position = position
	_update_pivot()

func _update_pivot() -> void:
	pivot_offset = size * 0.5

func _animate_state(active: bool) -> void:
	if disabled:
		return
	_kill_motion()
	_motion_tween = create_tween().set_parallel(true)
	var target_scale := Vector2.ONE * (1.012 if active else 1.0)
	var target_position := _rest_position + Vector2(0.0, -1.5 if active else 0.0)
	_motion_tween.tween_property(self, "scale", target_scale, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "position", target_position, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_pressed() -> void:
	if disabled:
		return
	_kill_motion()
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(self, "scale", Vector2.ONE * 0.985, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "position", _rest_position + Vector2(0.0, 0.5), 0.06)

func _kill_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
