extends Node2D
class_name EnvironmentalVfxLayer

const PARTICLE_GLOW := preload("res://assets/original/vfx/particle_glow.svg")
const PARTICLE_STREAK := preload("res://assets/original/vfx/particle_streak.svg")
const PARTICLE_SHARD := preload("res://assets/original/vfx/particle_shard.svg")

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _accent := Color("#55e6ff")
var _nebula := Color("#183b72")
var _profile := "clean"
var _profile_strength := 0.0
var _focal_anchor := Vector2(0.5, 0.5)
var _field_particles: CPUParticles2D
var _foreground_particles: CPUParticles2D
var _energy_particles: CPUParticles2D
var _hazard_label := "ENV_STABLE_ORBIT"
var _hazard_intensity := 0.0
var _hazard_color := Color("#183b72")
var _hazard_distortion := 0.0
var _hazard_phase := 0.0
var _redraw_accumulator := 0.0
var _last_viewport_size := Vector2.ZERO
var _configured := false

func configure(
	play_bounds: Rect2,
	palette: Dictionary,
	visual_profile: Dictionary
) -> void:
	_play_bounds = play_bounds
	_accent = Color.from_string(String(palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	_nebula = Color.from_string(String(palette.get("nebula", "#183b72")), Color("#183b72"))
	_profile = WorldVisualLanguage.environment_effect_profile(visual_profile)
	_profile_strength = WorldVisualLanguage.environment_effect_intensity(visual_profile)
	var anchor_value := visual_profile.get("primary_anchor", [0.5, 0.5])
	if anchor_value is Array and (anchor_value as Array).size() >= 2:
		var anchor := anchor_value as Array
		_focal_anchor = Vector2(float(anchor[0]), float(anchor[1]))
	else:
		_focal_anchor = Vector2(0.5, 0.5)
	_configured = true
	if is_node_ready():
		_ensure_emitters()
		_apply_profile_particles()
		_update_camera_state(true)

func set_environment_state(
	label_key: String,
	intensity: float,
	color: Color,
	distortion: float
) -> void:
	var changed := (
		label_key != _hazard_label
		or absf(intensity - _hazard_intensity) >= 0.025
		or absf(distortion - _hazard_distortion) >= 0.025
		or not color.is_equal_approx(_hazard_color)
	)
	if not changed:
		return

	_hazard_label = label_key
	_hazard_intensity = clampf(intensity, 0.0, 1.0)
	_hazard_color = color
	_hazard_distortion = clampf(distortion, 0.0, 1.0)

	var hazard_speed := 1.0 + _hazard_intensity * 0.55 + _hazard_distortion * 0.25
	for emitter in [_field_particles, _foreground_particles, _energy_particles]:
		if emitter != null:
			emitter.speed_scale = hazard_speed
	queue_redraw()

func _ready() -> void:
	_ensure_emitters()
	_apply_profile_particles()
	_update_camera_state(true)

func _process(delta: float) -> void:
	_hazard_phase = fmod(_hazard_phase + delta, 10000.0)
	_update_camera_state(false)
	_redraw_accumulator += delta
	if _redraw_accumulator >= RuntimeQuality.environmental_vfx_redraw_interval():
		_redraw_accumulator = 0.0
		if _hazard_intensity > 0.015:
			queue_redraw()

func _ensure_emitters() -> void:
	if _field_particles == null:
		_field_particles = CPUParticles2D.new()
		_field_particles.name = "FarParticles"
		_field_particles.z_index = 0
		add_child(_field_particles)

	if _foreground_particles == null:
		_foreground_particles = CPUParticles2D.new()
		_foreground_particles.name = "ForegroundParticles"
		_foreground_particles.z_as_relative = false
		_foreground_particles.z_index = 24
		add_child(_foreground_particles)

	if _energy_particles == null:
		_energy_particles = CPUParticles2D.new()
		_energy_particles.name = "EnergyParticles"
		_energy_particles.z_as_relative = false
		_energy_particles.z_index = 26
		add_child(_energy_particles)

	for emitter in [_field_particles, _foreground_particles, _energy_particles]:
		emitter.local_coords = false
		emitter.gravity = Vector2.ZERO
		emitter.one_shot = false
		emitter.emitting = true
		emitter.use_fixed_seed = true
		emitter.randomness = 0.42

func _apply_profile_particles() -> void:
	if not _configured or _field_particles == null:
		return

	var total_budget := RuntimeQuality.environmental_vfx_particle_cap()
	var far_count := maxi(1, int(round(total_budget * 0.42)))
	var near_count := maxi(1, int(round(total_budget * 0.34)))
	var energy_count := maxi(1, total_budget - far_count - near_count)
	var seed_base := 9400 + absi(int(hash(_profile))) % 1000

	_reset_emitter(_field_particles, far_count, seed_base + 1)
	_reset_emitter(_foreground_particles, near_count, seed_base + 2)
	_reset_emitter(_energy_particles, energy_count, seed_base + 3)

	match _profile:
		"dust":
			_configure_dust_particles()
		"nebula":
			_configure_nebula_particles()
		"solar":
			_configure_solar_particles()
		"anomaly":
			_configure_anomaly_particles()
		_:
			_configure_clean_particles()

	for emitter in [_field_particles, _foreground_particles, _energy_particles]:
		emitter.preprocess = minf(emitter.lifetime, 4.0)
		emitter.restart()

func _reset_emitter(emitter: CPUParticles2D, amount: int, seed_value: int) -> void:
	emitter.amount = amount
	emitter.seed = seed_value
	emitter.speed_scale = 1.0
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_ring_inner_radius = 0.0
	emitter.emission_ring_radius = 0.0
	emitter.direction = Vector2.RIGHT
	emitter.spread = 45.0
	emitter.initial_velocity_min = 0.0
	emitter.initial_velocity_max = 0.0
	emitter.angular_velocity_min = 0.0
	emitter.angular_velocity_max = 0.0
	emitter.orbit_velocity_min = 0.0
	emitter.orbit_velocity_max = 0.0
	emitter.linear_accel_min = 0.0
	emitter.linear_accel_max = 0.0
	emitter.radial_accel_min = 0.0
	emitter.radial_accel_max = 0.0
	emitter.tangential_accel_min = 0.0
	emitter.tangential_accel_max = 0.0
	emitter.damping_min = 0.0
	emitter.damping_max = 0.0
	emitter.angle_min = 0.0
	emitter.angle_max = 0.0
	emitter.particle_flag_align_y = false
	emitter.modulate = Color.WHITE
	emitter.position = Vector2.ZERO

func _configure_clean_particles() -> void:
	_configure_emitter(
		_field_particles,
		PARTICLE_GLOW,
		8.5,
		0.055,
		0.18,
		6.0,
		20.0,
		Vector2(0.82, -0.18),
		155.0,
		_make_lifetime_gradient(_accent, Color.WHITE, 0.46 * _profile_strength),
		_make_initial_gradient(_nebula.lightened(0.20), _accent)
	)
	_field_particles.orbit_velocity_min = -0.015
	_field_particles.orbit_velocity_max = 0.015

	_configure_emitter(
		_foreground_particles,
		PARTICLE_GLOW,
		4.6,
		0.09,
		0.30,
		12.0,
		34.0,
		Vector2(0.78, -0.24),
		110.0,
		_make_lifetime_gradient(_accent, Color.WHITE, 0.30 * _profile_strength),
		_make_initial_gradient(_accent, Color.WHITE)
	)

	_configure_emitter(
		_energy_particles,
		PARTICLE_STREAK,
		2.2,
		0.12,
		0.30,
		65.0,
		120.0,
		Vector2(1.0, 0.12).normalized(),
		14.0,
		_make_lifetime_gradient(_accent, Color.WHITE, 0.22 * _profile_strength),
		_make_initial_gradient(_accent, Color.WHITE)
	)
	_energy_particles.particle_flag_align_y = true

func _configure_dust_particles() -> void:
	var pale := _accent.darkened(0.08)
	var shadow := _nebula.lightened(0.20)

	_configure_emitter(
		_field_particles,
		PARTICLE_SHARD,
		8.0,
		0.045,
		0.14,
		18.0,
		46.0,
		Vector2(1.0, 0.20).normalized(),
		34.0,
		_make_lifetime_gradient(shadow, pale, 0.40 * _profile_strength),
		_make_initial_gradient(shadow, pale)
	)
	_field_particles.angular_velocity_min = -34.0
	_field_particles.angular_velocity_max = 34.0

	_configure_emitter(
		_foreground_particles,
		PARTICLE_SHARD,
		5.2,
		0.12,
		0.34,
		28.0,
		72.0,
		Vector2(1.0, 0.18).normalized(),
		26.0,
		_make_lifetime_gradient(pale, Color.WHITE, 0.50 * _profile_strength),
		_make_initial_gradient(shadow, pale)
	)
	_foreground_particles.angular_velocity_min = -62.0
	_foreground_particles.angular_velocity_max = 62.0

	_configure_emitter(
		_energy_particles,
		PARTICLE_STREAK,
		2.4,
		0.16,
		0.42,
		90.0,
		160.0,
		Vector2(1.0, 0.16).normalized(),
		11.0,
		_make_lifetime_gradient(pale, Color.WHITE, 0.25 * _profile_strength),
		_make_initial_gradient(shadow, pale)
	)
	_energy_particles.particle_flag_align_y = true

func _configure_nebula_particles() -> void:
	var violet := _nebula.lightened(0.30)
	var cyan := _accent

	_configure_emitter(
		_field_particles,
		PARTICLE_GLOW,
		8.8,
		0.07,
		0.28,
		5.0,
		24.0,
		Vector2(0.35, -0.16).normalized(),
		180.0,
		_make_lifetime_gradient(violet, cyan, 0.64 * _profile_strength),
		_make_initial_gradient(violet, cyan)
	)
	_field_particles.orbit_velocity_min = -0.028
	_field_particles.orbit_velocity_max = 0.028

	_configure_emitter(
		_foreground_particles,
		PARTICLE_GLOW,
		6.2,
		0.18,
		0.62,
		8.0,
		30.0,
		Vector2(0.24, -0.12).normalized(),
		180.0,
		_make_lifetime_gradient(cyan, violet, 0.42 * _profile_strength),
		_make_initial_gradient(cyan, Color("#b99cff"))
	)
	_foreground_particles.orbit_velocity_min = -0.045
	_foreground_particles.orbit_velocity_max = 0.045

	_configure_emitter(
		_energy_particles,
		PARTICLE_STREAK,
		2.8,
		0.13,
		0.34,
		52.0,
		105.0,
		Vector2(0.92, -0.38).normalized(),
		34.0,
		_make_lifetime_gradient(cyan, Color("#b99cff"), 0.38 * _profile_strength),
		_make_initial_gradient(cyan, Color("#b99cff"))
	)
	_energy_particles.particle_flag_align_y = true

func _configure_solar_particles() -> void:
	var hot := _accent
	var orange := _nebula.lightened(0.10)

	_configure_emitter(
		_field_particles,
		PARTICLE_GLOW,
		4.2,
		0.08,
		0.30,
		24.0,
		72.0,
		Vector2.RIGHT,
		180.0,
		_make_lifetime_gradient(orange, hot, 0.58 * _profile_strength),
		_make_initial_gradient(orange, hot)
	)
	_field_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_field_particles.emission_sphere_radius = 360.0
	_field_particles.radial_accel_min = 26.0
	_field_particles.radial_accel_max = 72.0

	_configure_emitter(
		_foreground_particles,
		PARTICLE_GLOW,
		3.3,
		0.14,
		0.48,
		36.0,
		95.0,
		Vector2.RIGHT,
		180.0,
		_make_lifetime_gradient(hot, Color.WHITE, 0.50 * _profile_strength),
		_make_initial_gradient(orange, hot)
	)
	_foreground_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_foreground_particles.emission_sphere_radius = 460.0
	_foreground_particles.radial_accel_min = 42.0
	_foreground_particles.radial_accel_max = 96.0

	_configure_emitter(
		_energy_particles,
		PARTICLE_STREAK,
		2.0,
		0.20,
		0.58,
		120.0,
		245.0,
		Vector2.RIGHT,
		180.0,
		_make_lifetime_gradient(hot, Color.WHITE, 0.58 * _profile_strength),
		_make_initial_gradient(orange, hot)
	)
	_energy_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_energy_particles.emission_sphere_radius = 330.0
	_energy_particles.radial_accel_min = 65.0
	_energy_particles.radial_accel_max = 145.0
	_energy_particles.particle_flag_align_y = true

func _configure_anomaly_particles() -> void:
	var gold := _accent
	var violet := _nebula.lightened(0.32)

	_configure_emitter(
		_field_particles,
		PARTICLE_GLOW,
		7.8,
		0.07,
		0.24,
		10.0,
		34.0,
		Vector2.RIGHT,
		180.0,
		_make_lifetime_gradient(violet, gold, 0.54 * _profile_strength),
		_make_initial_gradient(violet, gold)
	)
	_field_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_field_particles.emission_ring_inner_radius = 190.0
	_field_particles.emission_ring_radius = 560.0
	_field_particles.orbit_velocity_min = 0.055
	_field_particles.orbit_velocity_max = 0.11
	_field_particles.radial_accel_min = -18.0
	_field_particles.radial_accel_max = -6.0

	_configure_emitter(
		_foreground_particles,
		PARTICLE_GLOW,
		5.6,
		0.16,
		0.48,
		18.0,
		48.0,
		Vector2.RIGHT,
		180.0,
		_make_lifetime_gradient(gold, Color.WHITE, 0.46 * _profile_strength),
		_make_initial_gradient(violet, gold)
	)
	_foreground_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_foreground_particles.emission_ring_inner_radius = 320.0
	_foreground_particles.emission_ring_radius = 820.0
	_foreground_particles.orbit_velocity_min = -0.085
	_foreground_particles.orbit_velocity_max = -0.035
	_foreground_particles.radial_accel_min = -12.0
	_foreground_particles.radial_accel_max = -3.0

	_configure_emitter(
		_energy_particles,
		PARTICLE_STREAK,
		2.7,
		0.14,
		0.38,
		55.0,
		105.0,
		Vector2.RIGHT,
		180.0,
		_make_lifetime_gradient(gold, Color.WHITE, 0.40 * _profile_strength),
		_make_initial_gradient(violet, gold)
	)
	_energy_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_energy_particles.emission_ring_inner_radius = 250.0
	_energy_particles.emission_ring_radius = 700.0
	_energy_particles.orbit_velocity_min = 0.07
	_energy_particles.orbit_velocity_max = 0.14
	_energy_particles.particle_flag_align_y = true

func _configure_emitter(
	emitter: CPUParticles2D,
	texture: Texture2D,
	lifetime: float,
	scale_min: float,
	scale_max: float,
	velocity_min: float,
	velocity_max: float,
	direction: Vector2,
	spread: float,
	lifetime_gradient: Gradient,
	initial_gradient: Gradient
) -> void:
	emitter.texture = texture
	emitter.lifetime = lifetime
	emitter.lifetime_randomness = 0.34
	emitter.scale_amount_min = scale_min
	emitter.scale_amount_max = scale_max
	emitter.initial_velocity_min = velocity_min
	emitter.initial_velocity_max = velocity_max
	emitter.direction = direction
	emitter.spread = spread
	emitter.color = Color.WHITE
	emitter.color_ramp = lifetime_gradient
	emitter.color_initial_ramp = initial_gradient

func _make_lifetime_gradient(
	start_color: Color,
	end_color: Color,
	peak_alpha: float
) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(start_color, 0.0),
		Color(start_color, peak_alpha),
		Color(end_color, peak_alpha * 0.62),
		Color(end_color, 0.0),
	])
	return gradient

func _make_initial_gradient(first: Color, second: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([first, second])
	return gradient

func _update_camera_state(force_geometry: bool) -> void:
	if _field_particles == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	global_position = camera.global_position
	var viewport_size := get_viewport_rect().size
	var zoom := Vector2(
		maxf(absf(camera.zoom.x), 0.01),
		maxf(absf(camera.zoom.y), 0.01)
	)
	var visible_world_size := Vector2(
		viewport_size.x / zoom.x,
		viewport_size.y / zoom.y
	)

	if force_geometry or not viewport_size.is_equal_approx(_last_viewport_size):
		_last_viewport_size = viewport_size
		var extents := visible_world_size * 0.62
		_field_particles.emission_rect_extents = extents
		_foreground_particles.emission_rect_extents = extents
		_energy_particles.emission_rect_extents = extents

	var focal_offset := (_focal_anchor - Vector2(0.5, 0.5)) * visible_world_size
	if _profile in ["solar", "anomaly"]:
		_field_particles.position = focal_offset
		_foreground_particles.position = focal_offset
		_energy_particles.position = focal_offset
	else:
		_field_particles.position = Vector2.ZERO
		_foreground_particles.position = Vector2.ZERO
		_energy_particles.position = Vector2.ZERO

func _draw() -> void:
	if _hazard_intensity <= 0.015:
		return

	var intensity := _hazard_intensity * RuntimeQuality.visual_effects_factor()
	match _hazard_label:
		"ENV_GRAVITY_WELL":
			for index in range(4):
				var radius := 130.0 + float(index) * 82.0 + fposmod(_hazard_phase * 26.0, 64.0)
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(_hazard_color, 0.055 * intensity), 1.8, true)
		"ENV_LOW_VISIBILITY":
			for index in range(5):
				var angle := float(index) / 5.0 * TAU + _hazard_phase * 0.05
				var offset := Vector2.from_angle(angle) * (130.0 + index * 58.0)
				draw_circle(offset, 190.0 + index * 35.0, Color(_hazard_color, 0.018 * intensity))
		"ENV_SCANNER_INTERFERENCE":
			for index in range(9):
				var y := -330.0 + float(index) * 82.0 + fposmod(_hazard_phase * 34.0, 66.0)
				draw_line(
					Vector2(-620.0, y),
					Vector2(620.0, y + 24.0),
					Color(_hazard_color, 0.035 * intensity),
					1.2,
					true
				)
		"ENV_TRACTOR_DISTORTION":
			for index in range(5):
				var radius := 95.0 + float(index) * 66.0
				var start := _hazard_phase * 0.16 + index * 1.15
				draw_arc(Vector2.ZERO, radius, start, start + 1.25, 30, Color(_hazard_color, 0.055 * intensity), 1.5, true)
		"ENV_MAGNETIC_ZONE":
			for index in range(8):
				var angle := float(index) / 8.0 * TAU + _hazard_phase * 0.15
				var a := Vector2.from_angle(angle) * 160.0
				var b := Vector2.from_angle(angle + 0.28) * 340.0
				draw_line(a, b, Color(_hazard_color, 0.055 * intensity), 1.4, true)
		_:
			if _hazard_distortion > 0.08:
				draw_arc(Vector2.ZERO, 260.0, 0.0, TAU, 56, Color(_hazard_color, 0.04 * intensity), 1.2, true)
