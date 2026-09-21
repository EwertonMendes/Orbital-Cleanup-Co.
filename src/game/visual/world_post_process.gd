extends ColorRect
class_name WorldPostProcess

var _pulse_tween: Tween
var _configured := false
var _last_environment_visibility := -1.0
var _last_environment_distortion := -1.0
var _last_environment_color := Color.TRANSPARENT
var _lightweight_mode := false
var _environment_overlay := Color.TRANSPARENT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightweight_mode = not RuntimeQuality.use_screen_texture_post_process()
	if _lightweight_mode:
		material = null
		color = Color.TRANSPARENT
	if not get_viewport().size_changed.is_connected(_apply_quality):
		get_viewport().size_changed.connect(_apply_quality)
	_apply_quality()

func configure(palette: Dictionary) -> void:
	_configured = true
	if _lightweight_mode:
		return
	var shader_material := material as ShaderMaterial
	assert(shader_material != null, "WorldPostProcess requires ShaderMaterial.")
	var accent := Color.from_string(String(palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	shader_material.set_shader_parameter("grade_tint", accent)
	_apply_quality()

func set_environment_state(
	visibility: float,
	environment_color: Color,
	distortion: float
) -> void:
	var normalized_visibility := clampf(visibility, 0.46, 1.0)
	var normalized_distortion := clampf(distortion, 0.0, 1.0)
	if (
		absf(normalized_visibility - _last_environment_visibility) < 0.015
		and absf(normalized_distortion - _last_environment_distortion) < 0.015
		and environment_color.is_equal_approx(_last_environment_color)
	):
		return
	_last_environment_visibility = normalized_visibility
	_last_environment_distortion = normalized_distortion
	_last_environment_color = environment_color

	if _lightweight_mode:
		var alpha := clampf((1.0 - normalized_visibility) * 0.10 + normalized_distortion * 0.018, 0.0, 0.075)
		_environment_overlay = Color(environment_color, alpha)
		if _pulse_tween == null or not _pulse_tween.is_valid():
			color = _environment_overlay
		return

	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("environment_color", environment_color)
	shader_material.set_shader_parameter(
		"environment_fog_strength",
		clampf((1.0 - normalized_visibility) * 0.42, 0.0, 0.24)
	)
	shader_material.set_shader_parameter(
		"environment_distortion",
		clampf(normalized_distortion * 0.22, 0.0, 0.10)
	)

func pulse(color: Color, strength: float = 0.16, duration: float = 0.34) -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()

	if _lightweight_mode:
		self.color = Color(color, clampf(strength * 0.24, 0.0, 0.10))
		_pulse_tween = create_tween()
		_pulse_tween.tween_property(
			self,
			"color",
			_environment_overlay,
			maxf(duration, 0.08)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return

	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("flash_color", color)
	shader_material.set_shader_parameter("flash_strength", clampf(strength, 0.0, 0.45))
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(
		func(value: float) -> void:
			shader_material.set_shader_parameter("flash_strength", value),
		clampf(strength, 0.0, 0.45),
		0.0,
		maxf(duration, 0.08)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _apply_quality() -> void:
	if _lightweight_mode:
		return
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 700.0 or viewport_size.y < 430.0
	shader_material.set_shader_parameter("effect_strength", 0.40 if compact else 0.62)
	shader_material.set_shader_parameter("glow_strength", 0.025 if compact else 0.050)
	shader_material.set_shader_parameter("grain_strength", 0.0)
