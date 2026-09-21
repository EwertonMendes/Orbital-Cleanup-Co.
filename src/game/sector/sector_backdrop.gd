extends Node2D
class_name SectorBackdrop

const BACKGROUND_EXTENT := 18000.0
const STAR_EXTENT := 11500.0
const STAR_COUNT := 1650

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _background_color := Color("#040b13")
var _nebula_color := Color("#0b3d4d")
var _accent_color := Color("#53d7f1")
var _biome_id := ""
var _stars: Array[Dictionary] = []

func configure(play_bounds: Rect2, palette: Dictionary, biome_id: String = "") -> void:
	assert(play_bounds.size.x > 0.0 and play_bounds.size.y > 0.0, "SectorBackdrop requires valid bounds.")
	_play_bounds = play_bounds
	_background_color = Color(String(palette.get("background", "#040b13")))
	_nebula_color = Color(String(palette.get("nebula", "#0b3d4d")))
	_accent_color = Color(String(palette.get("accent", "#53d7f1")))
	_biome_id = biome_id
	RenderingServer.set_default_clear_color(_background_color)
	queue_redraw()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31051999
	for _index in range(STAR_COUNT):
		var bright := rng.randf() > 0.82
		_stars.append({
			"position": Vector2(
				rng.randf_range(-STAR_EXTENT, STAR_EXTENT),
				rng.randf_range(-STAR_EXTENT, STAR_EXTENT)
			),
			"radius": rng.randf_range(0.55, 1.45) if not bright else rng.randf_range(1.35, 2.35),
			"alpha": rng.randf_range(0.12, 0.42) if not bright else rng.randf_range(0.48, 0.82),
			"warm": bright and rng.randf() > 0.82,
		})
	queue_redraw()

func _draw() -> void:
	draw_rect(
		Rect2(-BACKGROUND_EXTENT, -BACKGROUND_EXTENT, BACKGROUND_EXTENT * 2.0, BACKGROUND_EXTENT * 2.0),
		_background_color
	)

	_draw_soft_cloud(Vector2(0, 80), 2650.0, _nebula_color, 0.16)
	_draw_soft_cloud(Vector2(3000, -1900), 1850.0, _nebula_color, 0.085)
	_draw_soft_cloud(Vector2(-3400, 2100), 2050.0, _nebula_color, 0.075)
	_draw_biome_horizon()

	for star in _stars:
		var star_color := Color(1.0, 0.86, 0.55, float(star["alpha"])) if bool(star["warm"]) else Color(0.66, 0.90, 1.0, float(star["alpha"]))
		draw_circle(star["position"], float(star["radius"]), star_color)

	draw_arc(Vector2(1150, -650), 1100.0, deg_to_rad(192.0), deg_to_rad(342.0), 96, Color(_accent_color, 0.16), 2.0, true)
	draw_arc(Vector2(-1800, 1300), 920.0, deg_to_rad(8.0), deg_to_rad(176.0), 84, Color(_accent_color, 0.09), 1.5, true)
	draw_arc(Vector2(450, 260), 3200.0, deg_to_rad(208.0), deg_to_rad(304.0), 120, Color(_accent_color, 0.045), 1.0, true)
	_draw_glint(Vector2(2200, 980), 10.0, Color(_accent_color, 0.5))
	_draw_glint(Vector2(-2850, -1250), 7.0, Color(1.0, 0.82, 0.5, 0.42))
	_draw_perimeter()

func _draw_biome_horizon() -> void:
	match _biome_id:
		"earth_orbit":
			_draw_planet_horizon(
				Vector2(610.0, 660.0),
				900.0,
				Color("#081d2b"),
				Color("#4cc9ff"),
				0.34
			)
		"lunar_belt":
			_draw_planet_horizon(
				Vector2(-650.0, 690.0),
				920.0,
				Color("#161d26"),
				Color("#a9bed0"),
				0.22
			)
		"mars_freight":
			_draw_planet_horizon(
				Vector2(650.0, 650.0),
				940.0,
				Color("#2b1413"),
				Color("#ff9c63"),
				0.30
			)
		"blue_nebula":
			_draw_soft_cloud(Vector2(520.0, -180.0), 1550.0, _accent_color, 0.23)
			_draw_soft_cloud(Vector2(-820.0, 580.0), 1250.0, Color("#7f65d8"), 0.13)
		_:
			pass

func _draw_planet_horizon(
	center: Vector2,
	radius: float,
	body_color: Color,
	atmosphere: Color,
	body_alpha: float
) -> void:
	for layer in range(7, 0, -1):
		var expansion := float(layer) * 14.0
		var alpha := 0.006 + float(8 - layer) * 0.006
		draw_circle(center, radius + expansion, Color(atmosphere, alpha))
	draw_circle(center, radius, Color(body_color, body_alpha))
	draw_arc(center, radius + 3.0, deg_to_rad(196.0), deg_to_rad(344.0), 120, Color(atmosphere, 0.22), 2.2, true)
	draw_arc(center, radius - 34.0, deg_to_rad(210.0), deg_to_rad(328.0), 100, Color(atmosphere, 0.055), 1.0, true)

func _draw_soft_cloud(center: Vector2, radius: float, color: Color, strength: float) -> void:
	for layer in range(8, 0, -1):
		var ratio := float(layer) / 8.0
		var layer_radius := radius * (0.34 + ratio * 0.66)
		var alpha := strength * (0.018 + (1.0 - ratio) * 0.026)
		draw_circle(center, layer_radius, Color(color, alpha))

func _draw_glint(position: Vector2, size: float, color: Color) -> void:
	draw_line(position - Vector2(size, 0), position + Vector2(size, 0), color, 1.2, true)
	draw_line(position - Vector2(0, size), position + Vector2(0, size), color, 1.2, true)
	draw_circle(position, 2.0, Color(color, minf(color.a + 0.22, 1.0)))

func _draw_perimeter() -> void:
	var outer := _play_bounds
	var inner := _play_bounds.grow(-180.0)

	draw_rect(outer, Color(_accent_color, 0.16), false, 3.0, true)
	draw_rect(inner, Color(_accent_color, 0.05), false, 1.0, true)

	var corner := 180.0
	var color := Color(1.0, 0.78, 0.28, 0.46)
	var left := outer.position.x
	var right := outer.end.x
	var top := outer.position.y
	var bottom := outer.end.y

	draw_line(Vector2(left, top), Vector2(left + corner, top), color, 4.0, true)
	draw_line(Vector2(left, top), Vector2(left, top + corner), color, 4.0, true)
	draw_line(Vector2(right, top), Vector2(right - corner, top), color, 4.0, true)
	draw_line(Vector2(right, top), Vector2(right, top + corner), color, 4.0, true)
	draw_line(Vector2(left, bottom), Vector2(left + corner, bottom), color, 4.0, true)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - corner), color, 4.0, true)
	draw_line(Vector2(right, bottom), Vector2(right - corner, bottom), color, 4.0, true)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - corner), color, 4.0, true)
