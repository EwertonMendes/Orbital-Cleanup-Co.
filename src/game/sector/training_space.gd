extends Node2D
class_name TrainingSpace

const BACKGROUND_EXTENT := 6200.0
const STAR_EXTENT := 3200.0
const STAR_COUNT := 920

var _stars: Array[Dictionary] = []

func _ready() -> void:
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

	# Large translucent volumes create depth without expensive full-screen shaders.
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
