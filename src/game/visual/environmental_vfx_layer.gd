extends Node2D
class_name EnvironmentalVfxLayer

const BASE_PARTICLE_COUNT := 48

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _accent := Color("#55e6ff")
var _nebula := Color("#183b72")
var _profile := "clean"
var _profile_strength := 0.0
var _dust_density := 1.0
var _phase := 0.0
var _redraw_accumulator := 0.0
var _particles: Array[Dictionary] = []
var _hazard_label := "ENV_STABLE_ORBIT"
var _hazard_intensity := 0.0
var _hazard_color := Color("#183b72")
var _hazard_distortion := 0.0

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
	_dust_density = clampf(float(visual_profile.get("dust_density", 1.0)), 0.2, 2.0)
	_rebuild_particles()
	queue_redraw()

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
	queue_redraw()

func _ready() -> void:
	_rebuild_particles()
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, 10000.0)
	_redraw_accumulator += delta
	if _redraw_accumulator >= RuntimeQuality.environmental_vfx_redraw_interval():
		_redraw_accumulator = 0.0
		queue_redraw()

func _rebuild_particles() -> void:
	_particles.clear()
	var requested := int(round(float(BASE_PARTICLE_COUNT) * _dust_density))
	var count := clampi(requested, 12, RuntimeQuality.environmental_vfx_particle_cap())
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929 + absi(int(hash(_profile)))
	for index in range(count):
		_particles.append({
			"u": rng.randf(),
			"v": rng.randf(),
			"phase": rng.randf(),
			"speed": rng.randf_range(12.0, 42.0),
			"size": rng.randf_range(0.8, 2.6),
			"length": rng.randf_range(14.0, 56.0),
			"alpha": rng.randf_range(0.035, 0.16),
			"angle": rng.randf_range(-0.35, 0.35),
		})

func _draw() -> void:
	if _profile_strength <= 0.001:
		return

	match _profile:
		"dust":
			_draw_dust_profile()
		"nebula":
			_draw_nebula_profile()
		"solar":
			_draw_solar_profile()
		"anomaly":
			_draw_anomaly_profile()
		_:
			_draw_clean_profile()

	_draw_active_hazard()

func _particle_position(item: Dictionary, direction: Vector2, multiplier: float = 1.0) -> Vector2:
	var extent := _play_bounds.size
	var travel := float(item["speed"]) * _phase * multiplier
	var start := Vector2(
		_play_bounds.position.x + float(item["u"]) * extent.x,
		_play_bounds.position.y + float(item["v"]) * extent.y
	)
	var local := start - _play_bounds.position + direction * travel
	local.x = fposmod(local.x, maxf(extent.x, 1.0))
	local.y = fposmod(local.y, maxf(extent.y, 1.0))
	return _play_bounds.position + local

func _draw_clean_profile() -> void:
	var strength := _profile_strength * RuntimeQuality.visual_effects_factor()
	for index in range(mini(_particles.size(), 18)):
		var item := _particles[index]
		var position := _particle_position(item, Vector2(0.15, -0.08), 0.20)
		var alpha := float(item["alpha"]) * 0.34 * strength
		draw_circle(position, float(item["size"]) * 0.72, Color(_accent, alpha))

func _draw_dust_profile() -> void:
	var strength := _profile_strength * RuntimeQuality.visual_effects_factor()
	var direction := Vector2(1.0, 0.18).normalized()
	for item in _particles:
		var position := _particle_position(item, direction, 0.72)
		var length := float(item["length"]) * (0.35 + strength * 0.55)
		var alpha := float(item["alpha"]) * (0.45 + strength * 0.55)
		draw_line(
			position - direction * length,
			position + direction * length * 0.2,
			Color(_accent, alpha),
			maxf(float(item["size"]) * 0.55, 0.7),
			true
		)

func _draw_nebula_profile() -> void:
	var strength := _profile_strength * RuntimeQuality.visual_effects_factor()
	var direction := Vector2(0.18, -0.10)
	for index in range(_particles.size()):
		var item := _particles[index]
		var position := _particle_position(item, direction, 0.34)
		var pulse := 0.62 + absf(fposmod(_phase * 0.18 + float(item["phase"]), 1.0) - 0.5) * 0.76
		var radius := float(item["size"]) * (1.5 + float(index % 4) * 0.55)
		var color := _accent if index % 3 != 0 else _nebula
		draw_circle(position, radius, Color(color, float(item["alpha"]) * pulse * strength))
		if index % 7 == 0:
			draw_arc(
				position,
				radius * 5.0,
				float(item["angle"]),
				float(item["angle"]) + 1.15,
				14,
				Color(_accent, 0.022 * strength),
				1.0,
				true
			)

func _draw_solar_profile() -> void:
	var strength := _profile_strength * RuntimeQuality.visual_effects_factor()
	var direction := Vector2(1.0, -0.10).normalized()
	for index in range(_particles.size()):
		var item := _particles[index]
		var position := _particle_position(item, direction, 1.15)
		var length := float(item["length"]) * (0.75 + strength)
		var alpha := float(item["alpha"]) * (0.60 + strength * 0.65)
		draw_line(
			position - direction * length,
			position + direction * length * 0.12,
			Color(_accent, alpha),
			maxf(float(item["size"]) * 0.70, 0.8),
			true
		)
		if index % 8 == 0:
			draw_circle(position, 4.0 + float(item["size"]) * 2.0, Color(_nebula, 0.045 * strength))

func _draw_anomaly_profile() -> void:
	var strength := _profile_strength * RuntimeQuality.visual_effects_factor()
	var camera := get_viewport().get_camera_2d()
	var center := camera.global_position if camera != null else _play_bounds.get_center()
	for index in range(5):
		var radius := 280.0 + float(index) * 210.0
		var phase := _phase * (0.07 + float(index) * 0.012)
		draw_arc(
			center,
			radius,
			phase + float(index) * 0.9,
			phase + float(index) * 0.9 + 1.35,
			38,
			Color(_accent, (0.018 + float(index) * 0.005) * strength),
			1.2 + float(index) * 0.15,
			true
		)
	for index in range(mini(_particles.size(), 30)):
		var item := _particles[index]
		var radius := 340.0 + float(index % 7) * 110.0
		var angle := float(item["phase"]) * TAU + _phase * (0.035 + float(index % 3) * 0.012)
		var position := center + Vector2.from_angle(angle) * radius
		draw_circle(position, float(item["size"]) * 1.2, Color(_accent, float(item["alpha"]) * 0.55 * strength))

func _draw_active_hazard() -> void:
	if _hazard_intensity <= 0.015:
		return
	var camera := get_viewport().get_camera_2d()
	var center := camera.global_position if camera != null else _play_bounds.get_center()
	var intensity := _hazard_intensity * RuntimeQuality.visual_effects_factor()

	match _hazard_label:
		"ENV_GRAVITY_WELL":
			for index in range(3):
				var radius := 150.0 + float(index) * 95.0 + fposmod(_phase * 22.0, 70.0)
				draw_arc(center, radius, 0.0, TAU, 52, Color(_hazard_color, 0.035 * intensity), 1.4, true)
		"ENV_LOW_VISIBILITY":
			for index in range(4):
				var offset := Vector2.from_angle(float(index) / 4.0 * TAU) * (140.0 + index * 75.0)
				draw_circle(center + offset, 180.0 + index * 32.0, Color(_hazard_color, 0.012 * intensity))
		"ENV_SCANNER_INTERFERENCE":
			for index in range(7):
				var y := center.y - 280.0 + float(index) * 92.0 + fposmod(_phase * 26.0, 72.0)
				draw_line(
					Vector2(center.x - 540.0, y),
					Vector2(center.x + 540.0, y + 20.0),
					Color(_hazard_color, 0.025 * intensity),
					1.0,
					true
				)
		"ENV_TRACTOR_DISTORTION":
			for index in range(4):
				var radius := 110.0 + float(index) * 75.0
				var start := _phase * 0.10 + index * 1.3
				draw_arc(center, radius, start, start + 0.95, 24, Color(_hazard_color, 0.04 * intensity), 1.2, true)
		"ENV_MAGNETIC_ZONE":
			for index in range(6):
				var angle := float(index) / 6.0 * TAU + _phase * 0.12
				var a := center + Vector2.from_angle(angle) * 180.0
				var b := center + Vector2.from_angle(angle + 0.32) * 300.0
				draw_line(a, b, Color(_hazard_color, 0.045 * intensity), 1.1, true)
		"ENV_SOLAR_CURRENT":
			var direction := Vector2(1.0, 0.18).normalized()
			for index in range(8):
				var offset := Vector2(-420.0 + index * 115.0, -250.0 + fposmod(index * 137.0, 500.0))
				var p := center + offset
				draw_line(p - direction * 80.0, p + direction * 130.0, Color(_hazard_color, 0.04 * intensity), 1.4, true)
		_:
			if _hazard_distortion > 0.08:
				draw_arc(center, 240.0, 0.0, TAU, 48, Color(_hazard_color, 0.025 * intensity), 1.0, true)
