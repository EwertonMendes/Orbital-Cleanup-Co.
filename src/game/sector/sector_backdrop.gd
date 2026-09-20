extends Node2D
class_name SectorBackdrop

const BACKGROUND_EXTENT := 18000.0
const STAR_EXTENT := 11500.0
const STAR_COUNT := 1650

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _background_color := Color("#040b13")
var _nebula_color := Color("#0b3d4d")
var _accent_color := Color("#53d7f1")
var _stars: Array[Dictionary] = []

func configure(play_bounds: Rect2, palette: Dictionary) -> void:
	assert(play_bounds.size.x > 0.0 and play_bounds.size.y > 0.0, "SectorBackdrop requires valid bounds.")
	_play_bounds = play_bounds
	_background_color = Color(String(palette.get("background", "#040b13")))
	_nebula_color = Color(String(palette.get("nebula", "#0b3d4d")))
	_accent_color = Color(String(palette.get("accent", "#53d7f1")))
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

	var nebula_soft := Color(_nebula_color, 0.16)
	var nebula_faint := Color(_nebula_color, 0.085)
	draw_circle(Vector2(0, 80), 2300.0, nebula_soft)
	draw_circle(Vector2(3000, -1900), 1700.0, nebula_faint)
	draw_circle(Vector2(-3400, 2100), 1900.0, nebula_faint)

	for star in _stars:
		var star_color := Color(1.0, 0.86, 0.55, float(star["alpha"])) if bool(star["warm"]) else Color(0.66, 0.90, 1.0, float(star["alpha"]))
		draw_circle(star["position"], float(star["radius"]), star_color)

	draw_arc(Vector2(1150, -650), 1100.0, deg_to_rad(192.0), deg_to_rad(342.0), 96, Color(_accent_color, 0.13), 2.0, true)
	draw_arc(Vector2(-1800, 1300), 920.0, deg_to_rad(8.0), deg_to_rad(176.0), 84, Color(_accent_color, 0.07), 1.5, true)
	_draw_perimeter()

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
