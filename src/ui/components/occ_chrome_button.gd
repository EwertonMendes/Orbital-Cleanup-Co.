extends Button
class_name OccChromeButton

@export var base_tint := Color(0.27, 0.72, 0.86, 0.58)
@export var hover_tint := Color(0.43, 0.88, 0.98, 0.92)
@export var pressed_tint := Color(0.56, 0.95, 0.81, 0.92)
@export var emphasis := false

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 48.0)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_visual_system()

func _apply_visual_system() -> void:
	add_theme_stylebox_override(
		"normal",
		_make_style(
			Color(0.025, 0.075, 0.105, 0.97) if not emphasis else Color(0.025, 0.115, 0.145, 0.99),
			base_tint,
			1 if not emphasis else 2
		)
	)
	add_theme_stylebox_override(
		"hover",
		_make_style(Color(0.035, 0.14, 0.18, 0.99), hover_tint, 1 if not emphasis else 2)
	)
	add_theme_stylebox_override(
		"pressed",
		_make_style(Color(0.04, 0.18, 0.17, 1.0), pressed_tint, 2)
	)
	add_theme_stylebox_override(
		"disabled",
		_make_style(Color(0.02, 0.055, 0.072, 0.78), Color(base_tint, 0.22), 1)
	)
	add_theme_stylebox_override("focus", _make_focus_style())

	add_theme_color_override("font_color", Color(0.91, 0.97, 1.0, 1.0))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color(0.78, 1.0, 0.91, 1.0))
	add_theme_color_override("font_disabled_color", Color(0.48, 0.61, 0.67, 0.78))
	add_theme_font_size_override("font_size", 14 if not emphasis else 15)

func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = 1
	style.border_width_right = border_width
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style.shadow_size = 5 if emphasis else 3
	return style

func _make_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(1.0, 0.82, 0.40, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_right = 11
	style.corner_radius_bottom_left = 11
	return style
