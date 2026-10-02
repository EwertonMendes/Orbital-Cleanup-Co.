extends Node2D
class_name EngineFxRig

@onready var engine_core: Sprite2D = %EngineCore
@onready var primary_particles: CPUParticles2D = %EngineParticles
@onready var secondary_particles: CPUParticles2D = %SecondaryParticles
@onready var primary_trail: EngineTrail = %PrimaryTrail
@onready var secondary_trail: EngineTrail = %SecondaryTrail

var _style: Dictionary = {}
var _palette: Dictionary = {}
var _target_intensity := 0.0
var _display_intensity := 0.0
var _boost_ratio := 0.0
var _preview_mode := false
var _preview_clock := 0.0
var _core_base_scale := Vector2(0.065, 0.095)
var _core_base_alpha := 0.90
var _core_pulse := 0.04
var _core_stretch := 0.22
var _core_anchor_offset := -1.5
var _boost_core_scale_bonus := 0.22
var _boost_core_alpha_bonus := 0.08
var _boost_particle_speed_bonus := 0.75
var _configured := false

func configure(
	style: Dictionary,
	palette: Dictionary,
	socket_scale: float = 1.0,
	particle_budget: int = 84
) -> void:
	assert(not style.is_empty(), "EngineFxRig requires an engine effect style.")
	assert(not palette.is_empty(), "EngineFxRig requires a trail palette.")
	_style = style.duplicate(true)
	_palette = palette.duplicate(true)
	var safe_socket_scale := clampf(socket_scale, 0.25, 2.5)

	var core_profile := _style.get("core", {}) as Dictionary
	var core_texture_path := String(core_profile.get("texture", ""))
	assert(not core_texture_path.is_empty(), "Engine effect core texture is required.")
	var core_texture := load(core_texture_path) as Texture2D
	assert(core_texture != null, "Engine effect core texture must load: %s" % core_texture_path)
	engine_core.texture = core_texture
	_core_base_scale = Vector2(
		clampf(float(core_profile.get("scale_x", 0.065)), 0.01, 0.30),
		clampf(float(core_profile.get("scale_y", 0.095)), 0.01, 0.30)
	) * safe_socket_scale
	_core_base_alpha = clampf(float(core_profile.get("alpha", 0.90)), 0.05, 1.0)
	_core_pulse = clampf(float(core_profile.get("pulse", 0.04)), 0.0, 0.35)
	_core_stretch = clampf(float(core_profile.get("stretch", 0.22)), 0.0, 0.80)
	_core_anchor_offset = float(core_profile.get("anchor_offset", -1.5))

	var boost_profile := _style.get("boost", {}) as Dictionary
	_boost_core_scale_bonus = clampf(float(boost_profile.get("core_scale_bonus", 0.22)), 0.0, 1.0)
	_boost_core_alpha_bonus = clampf(float(boost_profile.get("core_alpha_bonus", 0.08)), 0.0, 0.5)
	_boost_particle_speed_bonus = clampf(float(boost_profile.get("particle_speed_bonus", 0.75)), 0.0, 2.0)

	var trail_profile := _style.get("trail", {}) as Dictionary
	assert(not trail_profile.is_empty(), "Engine effect trail profile is required.")
	primary_trail.apply_style(trail_profile, _palette, 0.0, 1.0)
	var use_secondary_trail := bool(trail_profile.get("secondary_trail", false))
	secondary_trail.set_enabled(use_secondary_trail)
	if use_secondary_trail:
		secondary_trail.apply_style(
			trail_profile,
			_palette,
			float(trail_profile.get("secondary_phase", PI)),
			clampf(float(trail_profile.get("secondary_alpha_scale", 0.82)), 0.05, 1.0)
		)

	var primary_profile := _style.get("primary_particles", {}) as Dictionary
	var secondary_profile := _style.get("secondary_particles", {}) as Dictionary
	var primary_requested := maxi(int(primary_profile.get("amount", 0)), 0)
	var secondary_requested := maxi(int(secondary_profile.get("amount", 0)), 0)
	var requested_total := maxi(primary_requested + secondary_requested, 1)
	var safe_budget := clampi(particle_budget, 8, 96)
	var budget_scale := minf(1.0, float(safe_budget) / float(requested_total))
	var primary_amount := int(round(float(primary_requested) * budget_scale)) if primary_requested > 0 else 0
	var secondary_amount := int(round(float(secondary_requested) * budget_scale)) if secondary_requested > 0 else 0
	if primary_requested > 0:
		primary_amount = maxi(primary_amount, 1)
	if secondary_requested > 0:
		secondary_amount = maxi(secondary_amount, 1)

	_apply_particle_profile(primary_particles, primary_profile, primary_amount, "primary")
	_apply_particle_profile(secondary_particles, secondary_profile, secondary_amount, "secondary")
	_configured = true
	set_preview_mode(_preview_mode)
	set_motion(_target_intensity, _boost_ratio)
	_update_visual_state()

func set_preview_mode(value: bool) -> void:
	_preview_mode = value
	_preview_clock = 0.0
	primary_trail.set_preview_mode(value)
	secondary_trail.set_preview_mode(value)
	if _preview_mode:
		set_motion(0.78, 0.10)

func set_motion(intensity: float, boost: float = 0.0) -> void:
	_target_intensity = clampf(intensity, 0.0, 1.0)
	_boost_ratio = clampf(boost, 0.0, 1.0)
	primary_trail.set_intensity(maxf(_target_intensity, _boost_ratio))
	primary_trail.set_boost(_boost_ratio)
	secondary_trail.set_intensity(maxf(_target_intensity, _boost_ratio))
	secondary_trail.set_boost(_boost_ratio)

func play_boost() -> void:
	primary_trail.set_intensity(1.0)
	secondary_trail.set_intensity(1.0)
	if primary_particles.visible:
		primary_particles.restart()
	if secondary_particles.visible:
		secondary_particles.restart()

func _process(delta: float) -> void:
	if not _configured:
		return
	_display_intensity = move_toward(_display_intensity, _target_intensity, delta * 6.0)
	_preview_clock += delta
	_update_visual_state()

func _update_visual_state() -> void:
	var display_boost := _boost_ratio
	if _preview_mode:
		display_boost = clampf(_boost_ratio + 0.06 + sin(_preview_clock * 2.2) * 0.04, 0.0, 1.0)

	var active := _display_intensity > 0.035 or display_boost > 0.035
	var core_color := _palette_color("core", "#E9FDFF")
	var primary_color := _palette_color("primary", "#55DFFF")
	var secondary_color := _palette_color("secondary", "#199FDF")

	var pulse := 1.0
	if _core_pulse > 0.0 and active:
		pulse += sin(_preview_clock * 10.0) * _core_pulse * (0.35 + _display_intensity * 0.65)
	var intensity_scale := 0.76 + _display_intensity * _core_stretch
	var boost_scale := 1.0 + display_boost * _boost_core_scale_bonus
	engine_core.scale = Vector2(
		_core_base_scale.x * pulse * (0.92 + _display_intensity * 0.12),
		_core_base_scale.y * intensity_scale * boost_scale
	)
	_update_core_anchor()
	var core_alpha := clampf(
		_core_base_alpha * (0.14 + _display_intensity * 0.86) + display_boost * _boost_core_alpha_bonus,
		0.0,
		1.0
	)
	engine_core.modulate = Color(core_color.r, core_color.g, core_color.b, core_alpha)
	engine_core.visible = active

	_update_particle_runtime(primary_particles, primary_color, active, display_boost)
	_update_particle_runtime(secondary_particles, secondary_color, active, display_boost)

func _update_core_anchor() -> void:
	if engine_core.texture == null:
		return
	var half_height := engine_core.texture.get_size().y * engine_core.scale.y * 0.5
	engine_core.position = Vector2(0.0, half_height + _core_anchor_offset)

func _update_particle_runtime(
	particles: CPUParticles2D,
	color: Color,
	active: bool,
	display_boost: float
) -> void:
	if not particles.visible:
		particles.emitting = false
		return
	particles.emitting = active
	particles.speed_scale = 0.72 + _display_intensity * 0.86 + display_boost * _boost_particle_speed_bonus
	var base_alpha := float(particles.get_meta(&"occ_base_alpha", 0.72))
	particles.color = Color(color.r, color.g, color.b, clampf(base_alpha * (0.35 + _display_intensity * 0.65), 0.0, 1.0))

func _apply_particle_profile(
	particles: CPUParticles2D,
	profile: Dictionary,
	resolved_amount: int,
	layer_name: String
) -> void:
	if profile.is_empty() or resolved_amount <= 0:
		particles.emitting = false
		particles.visible = false
		return

	var texture_path := String(profile.get("texture", ""))
	assert(not texture_path.is_empty(), "Engine %s particle texture is required." % layer_name)
	var texture := load(texture_path) as Texture2D
	assert(texture != null, "Engine particle texture must load: %s" % texture_path)

	particles.visible = true
	particles.emitting = false
	particles.amount = clampi(resolved_amount, 1, 64)
	particles.texture = texture
	particles.lifetime = clampf(float(profile.get("lifetime", 0.34)), 0.05, 2.0)
	particles.randomness = clampf(float(profile.get("randomness", 0.35)), 0.0, 1.0)
	particles.local_coords = false
	particles.direction = Vector2(0.0, 1.0)
	particles.spread = clampf(float(profile.get("spread", 16.0)), 0.0, 180.0)
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = maxf(float(profile.get("velocity_min", 58.0)), 0.0)
	particles.initial_velocity_max = maxf(float(profile.get("velocity_max", 128.0)), particles.initial_velocity_min)
	particles.damping_min = maxf(float(profile.get("damping_min", 35.0)), 0.0)
	particles.damping_max = maxf(float(profile.get("damping_max", 72.0)), particles.damping_min)
	particles.scale_amount_min = maxf(float(profile.get("scale_min", 0.045)), 0.001)
	particles.scale_amount_max = maxf(float(profile.get("scale_max", 0.10)), particles.scale_amount_min)
	var base_alpha := clampf(float(profile.get("alpha", 0.72)), 0.0, 1.0)
	particles.set_meta(&"occ_base_alpha", base_alpha)

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.72, 1.0])
	fade.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	particles.color_ramp = fade

	var scale_end := clampf(float(profile.get("scale_end", 1.0)), 0.1, 4.0)
	if not is_equal_approx(scale_end, 1.0):
		var scale_curve := Curve.new()
		scale_curve.add_point(Vector2(0.0, 1.0))
		scale_curve.add_point(Vector2(1.0, scale_end))
		particles.scale_amount_curve = scale_curve
	else:
		particles.scale_amount_curve = null

func _palette_color(key: String, fallback: String) -> Color:
	var palette_values := _palette.get("palette", {}) as Dictionary
	return Color.from_string(String(palette_values.get(key, fallback)), Color.from_string(fallback, Color.WHITE))
