extends Node2D
class_name TrainingSpace

const PLAY_BOUNDS := Rect2(-2100.0, -1300.0, 4200.0, 2600.0)
const BACKGROUND_EXTENT := 9000.0
const STAR_EXTENT := 5200.0
const STAR_COUNT := 1100

var _stars: Array[Dictionary] = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#040b13"))

	var rng := RandomNumberGenerator.new()
	rng.seed = 31051999
	for index in range(STAR_COUNT):
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
		Color("#040b13")
	)

	draw_circle(Vector2(0, 80), 1650.0, Color(0.025, 0.12, 0.18, 0.20))
	draw_circle(Vector2(980, -690), 1050.0, Color(0.03, 0.28, 0.34, 0.12))
	draw_circle(Vector2(-1180, 980), 1220.0, Color(0.08, 0.24, 0.30, 0.10))
	draw_circle(Vector2(260, 1940), 880.0, Color(0.08, 0.34, 0.28, 0.07))

	for star in _stars:
		var star_color := Color(1.0, 0.86, 0.55, float(star["alpha"])) if bool(star["warm"]) else Color(0.66, 0.90, 1.0, float(star["alpha"]))
		draw_circle(star["position"], float(star["radius"]), star_color)

	draw_arc(Vector2(640, -300), 720.0, deg_to_rad(192.0), deg_to_rad(342.0), 96, Color(0.25, 0.73, 0.86, 0.16), 2.0, true)
	draw_arc(Vector2(-760, 520), 510.0, deg_to_rad(8.0), deg_to_rad(176.0), 84, Color(0.56, 0.95, 0.81, 0.10), 1.5, true)
	draw_arc(Vector2(100, 120), 1080.0, deg_to_rad(225.0), deg_to_rad(292.0), 72, Color(0.32, 0.64, 0.78, 0.07), 1.0, true)

	_draw_training_perimeter()

func _draw_training_perimeter() -> void:
	var outer := PLAY_BOUNDS
	var inner := PLAY_BOUNDS.grow(-115.0)

	draw_rect(outer, Color(0.20, 0.74, 0.89, 0.22), false, 4.0, true)
	draw_rect(inner, Color(0.20, 0.74, 0.89, 0.07), false, 1.5, true)

	var corner := 115.0
	var color := Color(1.0, 0.78, 0.28, 0.58)
	var left := outer.position.x
	var right := outer.end.x
	var top := outer.position.y
	var bottom := outer.end.y

	draw_line(Vector2(left, top), Vector2(left + corner, top), color, 5.0, true)
	draw_line(Vector2(left, top), Vector2(left, top + corner), color, 5.0, true)
	draw_line(Vector2(right, top), Vector2(right - corner, top), color, 5.0, true)
	draw_line(Vector2(right, top), Vector2(right, top + corner), color, 5.0, true)
	draw_line(Vector2(left, bottom), Vector2(left + corner, bottom), color, 5.0, true)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - corner), color, 5.0, true)
	draw_line(Vector2(right, bottom), Vector2(right - corner, bottom), color, 5.0, true)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - corner), color, 5.0, true)
