extends Node2D
class_name AmbientOrbitLayer

const MOTE_COUNT := 34

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _accent := Color("#55e6ff")
var _nebula := Color("#183b72")
var _phase := 0.0
var _motes: Array[Dictionary] = []
var _biome_id := ""
var _visual_profile: Dictionary = {}
var _effect_profile := "clean"
var _effect_intensity := 0.0
var _traffic: Array[Dictionary] = []
var _redraw_accumulator := 0.0

func configure(
	play_bounds: Rect2,
	palette: Dictionary,
	biome_id: String = "",
	visual_profile: Dictionary = {}
) -> void:
	_play_bounds = play_bounds
	_accent = Color.from_string(String(palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	_nebula = Color.from_string(String(palette.get("nebula", "#183b72")), Color("#183b72"))
	_biome_id = biome_id
	_visual_profile = visual_profile.duplicate(true)
	_effect_profile = WorldVisualLanguage.environment_effect_profile(_visual_profile)
	_effect_intensity = WorldVisualLanguage.environment_effect_intensity(_visual_profile)
	_rebuild_dynamic_content()
	queue_redraw()

func _ready() -> void:
	_rebuild_dynamic_content()
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	_redraw_accumulator += delta
	if _redraw_accumulator >= RuntimeQuality.ambient_redraw_interval():
		_redraw_accumulator = 0.0
		queue_redraw()

func _rebuild_dynamic_content() -> void:
	_motes.clear()
	_traffic.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 771904 + absi(int(hash(_effect_profile)))
	var dust_density := clampf(float(_visual_profile.get("dust_density", 1.0)), 0.25, 1.8)
	var mote_count := clampi(
		int(round(float(MOTE_COUNT) * dust_density)),
		12,
		RuntimeQuality.ambient_mote_cap()
	)
	for index in range(mote_count):
		var center := Vector2(
			rng.randf_range(_play_bounds.position.x, _play_bounds.end.x),
			rng.randf_range(_play_bounds.position.y, _play_bounds.end.y)
		)
		_motes.append({
			"center": center,
			"radius": rng.randf_range(90.0, 520.0),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.025, 0.095) * (-1.0 if index % 3 == 0 else 1.0),
			"size": rng.randf_range(0.7, 2.0),
			"alpha": rng.randf_range(0.10, 0.34),
		})

	var traffic_rng := RandomNumberGenerator.new()
	traffic_rng.seed = 884321 + absi(int(hash(_biome_id)))
	var traffic_count := mini(int(_visual_profile.get("traffic_count", 0)), 10)
	for _index in range(traffic_count):
		_traffic.append({
			"origin": Vector2(
				traffic_rng.randf_range(_play_bounds.position.x, _play_bounds.end.x),
				traffic_rng.randf_range(_play_bounds.position.y, _play_bounds.end.y)
			),
			"span": traffic_rng.randf_range(650.0, 1600.0),
			"phase": traffic_rng.randf(),
			"speed": traffic_rng.randf_range(0.004, 0.014),
			"length": traffic_rng.randf_range(12.0, 28.0),
			"alpha": traffic_rng.randf_range(0.08, 0.20),
		})

func _draw() -> void:
	var center := _play_bounds.get_center()
	for index in range(3):
		var radius := 760.0 + float(index) * 640.0
		var phase := _phase * (0.035 + float(index) * 0.013)
		var span := 0.72 + float(index) * 0.16
		draw_arc(
			center,
			radius,
			phase + float(index) * 1.7,
			phase + float(index) * 1.7 + span,
			54,
			Color(_accent, 0.055 - float(index) * 0.010),
			1.15,
			true
		)

	for mote in _motes:
		var angle := float(mote["phase"]) + _phase * float(mote["speed"])
		var orbit := Vector2.from_angle(angle) * float(mote["radius"])
		var position := (mote["center"] as Vector2) + orbit
		var alpha := float(mote["alpha"]) * (0.72 + sin(angle * 2.7) * 0.28)
		draw_circle(position, float(mote["size"]), Color(_accent, maxf(alpha, 0.02)))

	var drift_center := center + Vector2(cos(_phase * 0.028), sin(_phase * 0.022)) * 520.0
	draw_circle(drift_center, 360.0, Color(_nebula, 0.012))
	_draw_traffic()
	_draw_profile_motion(center)

func _draw_profile_motion(center: Vector2) -> void:
	var strength := _effect_intensity * RuntimeQuality.visual_effects_factor()
	match _effect_profile:
		"dust":
			for index in range(12):
				var y := center.y - 1500.0 + index * 270.0
				var x := center.x + fposmod(_phase * (14.0 + index) + index * 410.0, 3800.0) - 1900.0
				draw_line(Vector2(x - 55.0, y), Vector2(x + 75.0, y + 20.0), Color(_accent, 0.05 * strength), 1.6, true)
		"nebula":
			for index in range(7):
				var angle := float(index) / 7.0 * TAU + _phase * 0.016
				var p := center + Vector2.from_angle(angle) * (620.0 + index * 210.0)
				var pulse := 0.5 + sin(_phase * 0.55 + index) * 0.35
				draw_circle(p, 18.0 + index * 3.0, Color(_nebula, (0.008 + pulse * 0.008) * strength))
		"solar":
			for index in range(8):
				var y := center.y - 1300.0 + index * 360.0
				var x := center.x + fposmod(_phase * (34.0 + index * 2.0) + index * 530.0, 4400.0) - 2200.0
				draw_line(Vector2(x - 110.0, y + 18.0), Vector2(x + 130.0, y - 12.0), Color(_accent, 0.055 * strength), 2.0, true)
		"anomaly":
			for index in range(5):
				var radius := 520.0 + index * 330.0
				var phase := _phase * (0.022 + index * 0.006)
				draw_arc(center, radius, phase + index, phase + index + 0.82, 42, Color(_accent, 0.035 * strength), 1.3, true)
		_:
			for index in range(4):
				var angle := _phase * (0.018 + index * 0.004) + index * 1.4
				var p := center + Vector2.from_angle(angle) * (1250.0 + index * 360.0)
				draw_circle(p, 2.0, Color(_accent, 0.12 * strength))

func _draw_traffic() -> void:
	for item in _traffic:
		var t := fposmod(float(item["phase"]) + _phase * float(item["speed"]), 1.0)
		var origin := item["origin"] as Vector2
		var span := float(item["span"])
		var position := origin + Vector2(lerpf(-span, span, t), sin(t * TAU) * 36.0)
		var length := float(item["length"])
		var color := Color(_accent, float(item["alpha"]))
		draw_line(position - Vector2(length, 0.0), position + Vector2(length, 0.0), color, 1.2, true)
		draw_circle(position + Vector2(length, 0.0), 1.6, Color(_accent, color.a * 1.6))
