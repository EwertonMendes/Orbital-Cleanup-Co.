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
	queue_redraw()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771904
	var dust_density := clampf(float(_visual_profile.get("dust_density", 1.0)), 0.25, 1.8)
	var mote_count := maxi(12, int(round(float(MOTE_COUNT) * dust_density)))
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
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	queue_redraw()

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
	_draw_biome_motion(center)

func _draw_biome_motion(center: Vector2) -> void:
	match _biome_id:
		"earth_orbit":
			for index in range(4):
				var angle := _phase * (0.018 + index * 0.004) + index * 1.4
				var p := center + Vector2.from_angle(angle) * (1250.0 + index * 360.0)
				draw_circle(p, 2.0, Color(_accent, 0.18))
		"lunar_belt":
			for index in range(14):
				var angle := float(index) * 0.73 + _phase * (0.008 if index % 2 == 0 else -0.006)
				var p := center + Vector2.from_angle(angle) * (900.0 + float(index % 5) * 340.0)
				draw_circle(p, 1.8 + float(index % 3), Color(_accent, 0.08 + float(index % 4) * 0.018))
		"mars_freight":
			for index in range(8):
				var y := center.y - 1600.0 + index * 430.0
				var x := center.x + fposmod(_phase * (18.0 + index) + index * 620.0, 4200.0) - 2100.0
				draw_line(Vector2(x - 70.0, y), Vector2(x + 90.0, y + 24.0), Color(_accent, 0.07), 2.0, true)
		"blue_nebula":
			for index in range(7):
				var angle := float(index) / 7.0 * TAU + _phase * 0.016
				var p := center + Vector2.from_angle(angle) * (620.0 + index * 210.0)
				var pulse := 0.5 + sin(_phase * 0.55 + index) * 0.35
				draw_circle(p, 18.0 + index * 3.0, Color(_nebula, 0.008 + pulse * 0.008))
