extends ColorRect
class_name WorldPostProcess

var _pulse_tween: Tween
var _configured := false
var _last_environment_visibility := -1.0
var _last_environment_distortion := -1.0
var _last_environment_color := Color.TRANSPARENT
var _lightweight_mode := false
var _environment_overlay := Color.TRANSPARENT
var _profile_overlay := Color.TRANSPARENT
var _palette: Dictionary = {}
var _visual_profile: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightweight_mode = not RuntimeQuality.use_screen_texture_post_process()
	if _lightweight_mode:
		material = null
		color = Color.TRANSPARENT
	if not get_viewport().size_changed.is_connected(_apply_quality):
		get_viewport().size_changed.connect(_apply_quality)
	_apply_configuration()
	_apply_quality()

func configure(palette: Dictionary, visual_profile: Dictionary = {}) -> void:
	_configured = true
	_palette = palette.duplicate(true)
	if not visual_profile.is_empty():
		_visual_profile = visual_profile.duplicate(true)
	if is_node_ready():
		_apply_configuration()
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
		_refresh_lightweight_overlay()
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
		_pulse_tween.tween_method(
			func(value: float) -> void:
				self.color = Color(
					_profile_overlay.r + _environment_overlay.r,
					_profile_overlay.g + _environment_overlay.g,
					_profile_overlay.b + _environment_overlay.b,
					clampf(value, 0.0, 0.12)
				),
			self.color.a,
			maxf(_profile_overlay.a, _environment_overlay.a),
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

func _apply_configuration() -> void:
	if not _configured or _palette.is_empty():
		return

	var accent := Color.from_string(String(_palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	var atmosphere := Color.from_string(
		String(_visual_profile.get("atmosphere_color", _palette.get("nebula", "#183b72"))),
		accent
	)
	var profile_strength := WorldVisualLanguage.environment_effect_intensity(_visual_profile)
	var shimmer := clampf(float(_visual_profile.get("shimmer_strength", 0.0)), 0.0, 0.5)

	if _lightweight_mode:
		_profile_overlay = Color(
			atmosphere,
			clampf(profile_strength * 0.022 * RuntimeQuality.visual_effects_factor(), 0.0, 0.025)
		)
		_refresh_lightweight_overlay()
		return

	var shader_material := material as ShaderMaterial
	assert(shader_material != null, "WorldPostProcess requires ShaderMaterial.")
	shader_material.set_shader_parameter("grade_tint", accent)
	shader_material.set_shader_parameter("profile_color", atmosphere)
	shader_material.set_shader_parameter(
		"profile_mode",
		WorldVisualLanguage.environment_effect_mode(_visual_profile)
	)
	shader_material.set_shader_parameter("profile_strength", profile_strength)
	shader_material.set_shader_parameter("shimmer_strength", shimmer)
	shader_material.set_shader_parameter("quality_factor", RuntimeQuality.visual_effects_factor())

func _refresh_lightweight_overlay() -> void:
	if not _lightweight_mode:
		return
	var alpha := maxf(_profile_overlay.a, _environment_overlay.a)
	if alpha <= 0.0:
		color = Color.TRANSPARENT
		return
	var profile_weight := _profile_overlay.a / maxf(_profile_overlay.a + _environment_overlay.a, 0.0001)
	var mixed := _environment_overlay.lerp(_profile_overlay, profile_weight)
	color = Color(mixed.r, mixed.g, mixed.b, alpha)

func _apply_quality() -> void:
	if _lightweight_mode:
		return
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 700.0 or viewport_size.y < 430.0
	var quality := RuntimeQuality.visual_effects_factor()
	shader_material.set_shader_parameter("effect_strength", (0.40 if compact else 0.62) * quality)
	shader_material.set_shader_parameter("glow_strength", (0.025 if compact else 0.050) * quality)
	shader_material.set_shader_parameter("grain_strength", 0.0)
	shader_material.set_shader_parameter("quality_factor", quality)
