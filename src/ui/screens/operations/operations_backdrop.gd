extends Control

var _stars: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920
	for index in range(125):
		_stars.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.45, 1.9),
			"alpha": rng.randf_range(0.10, 0.60),
			"warm": rng.randf() > 0.91,
		})
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var viewport_size: Vector2 = get_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), OccPalette.SPACE_950)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.02, 0.075, 0.12, 0.48))

	var glow_center := Vector2(viewport_size.x * 0.77, viewport_size.y * 0.47)
	var glow_base := minf(viewport_size.x, viewport_size.y)
	for index in range(7, 0, -1):
		var radius := glow_base * (0.12 + float(index) * 0.075)
		var alpha := 0.008 + float(8 - index) * 0.004
		draw_circle(glow_center, radius, Color(0.16, 0.62, 0.78, alpha))

	for star in _stars:
		var pos: Vector2 = star["uv"] * viewport_size
		var color := Color(1.0, 0.82, 0.54, float(star["alpha"])) if bool(star["warm"]) else Color(0.66, 0.9, 1.0, float(star["alpha"]))
		draw_circle(pos, float(star["radius"]), color)

	var orbit_center := Vector2(viewport_size.x * 0.73, viewport_size.y * 0.50)
	var radius: float = min(viewport_size.x, viewport_size.y) * 0.38
	draw_arc(orbit_center, radius, deg_to_rad(188.0), deg_to_rad(350.0), 110, Color(0.24, 0.69, 0.82, 0.22), 2.2, true)
	draw_arc(orbit_center, radius * 0.74, deg_to_rad(8.0), deg_to_rad(170.0), 96, Color(0.56, 0.95, 0.81, 0.13), 1.2, true)
	draw_arc(orbit_center, radius * 1.18, deg_to_rad(218.0), deg_to_rad(314.0), 72, Color(1.0, 0.82, 0.4, 0.08), 1.0, true)

	var horizon_y := viewport_size.y * 0.82
	draw_line(Vector2(viewport_size.x * 0.06, horizon_y), Vector2(viewport_size.x * 0.94, horizon_y), Color(0.26, 0.72, 0.86, 0.07), 1.0, true)
