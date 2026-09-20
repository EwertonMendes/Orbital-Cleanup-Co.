extends Control

var _stars: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920
	for index in range(90):
		_stars.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.55, 1.8),
			"alpha": rng.randf_range(0.14, 0.62),
		})
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), OccPalette.SPACE_950)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.075, 0.12, 0.62))

	for star in _stars:
		var pos: Vector2 = star["uv"] * size
		draw_circle(pos, float(star["radius"]), Color(0.66, 0.9, 1.0, float(star["alpha"])))

	var orbit_center := Vector2(size.x * 0.72, size.y * 0.48)
	var radius: float = min(size.x, size.y) * 0.35
	draw_arc(orbit_center, radius, deg_to_rad(193.0), deg_to_rad(350.0), 96, Color(0.24, 0.69, 0.82, 0.18), 2.0, true)
	draw_arc(orbit_center, radius * 0.72, deg_to_rad(8.0), deg_to_rad(168.0), 96, Color(0.56, 0.95, 0.81, 0.10), 1.0, true)
