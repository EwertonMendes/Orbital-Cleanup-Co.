extends Node2D
class_name TrainingSpace

const FIELD_EXTENT := 4800.0
const STAR_COUNT := 240

var _stars: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31051999
	for index in range(STAR_COUNT):
		_stars.append({
			"position": Vector2(
				rng.randf_range(-FIELD_EXTENT, FIELD_EXTENT),
				rng.randf_range(-FIELD_EXTENT, FIELD_EXTENT)
			),
			"radius": rng.randf_range(0.7, 2.2),
			"alpha": rng.randf_range(0.18, 0.74),
		})
	queue_redraw()

func _draw() -> void:
	draw_rect(
		Rect2(-FIELD_EXTENT, -FIELD_EXTENT, FIELD_EXTENT * 2.0, FIELD_EXTENT * 2.0),
		Color("#040b13")
	)

	draw_circle(Vector2(1250, -740), 920.0, Color(0.06, 0.23, 0.32, 0.16))
	draw_circle(Vector2(-1550, 980), 1180.0, Color(0.10, 0.22, 0.28, 0.10))
	draw_circle(Vector2(220, 1850), 780.0, Color(0.08, 0.32, 0.29, 0.08))

	for star in _stars:
		draw_circle(
			star["position"],
			float(star["radius"]),
			Color(0.66, 0.90, 1.0, float(star["alpha"]))
		)

	draw_arc(Vector2(820, -420), 640.0, deg_to_rad(195.0), deg_to_rad(338.0), 80, Color(0.25, 0.73, 0.86, 0.12), 2.0, true)
	draw_arc(Vector2(-980, 540), 460.0, deg_to_rad(12.0), deg_to_rad(178.0), 72, Color(0.56, 0.95, 0.81, 0.08), 1.5, true)
