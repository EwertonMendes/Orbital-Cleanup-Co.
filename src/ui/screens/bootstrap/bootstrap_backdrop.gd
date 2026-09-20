extends Control

var _stars: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 73921
	for index in range(72):
		_stars.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.7, 2.2),
			"alpha": rng.randf_range(0.18, 0.72)
		})
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#071424"))
	for star in _stars:
		var pos: Vector2 = star["uv"] * size
		draw_circle(pos, float(star["radius"]), Color(0.65, 0.91, 1.0, float(star["alpha"])))
	var center: Vector2 = Vector2(size.x * 0.74, size.y * 0.42)
	var radius: float = min(size.x, size.y) * 0.30
	draw_arc(center, radius, deg_to_rad(194.0), deg_to_rad(346.0), 96, Color(0.20, 0.63, 0.78, 0.20), 2.0, true)
	draw_arc(center, radius * 0.72, deg_to_rad(13.0), deg_to_rad(163.0), 96, Color(0.48, 0.94, 0.82, 0.13), 1.0, true)
