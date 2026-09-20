extends Control
class_name SectorPreviewCanvas

var _plan: Dictionary = {}

func _ready() -> void:
	resized.connect(queue_redraw)

func set_plan(plan: Dictionary) -> void:
	_plan = plan.duplicate(true)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#06111d"))
	if _plan.is_empty():
		return

	var bounds := _plan["play_bounds"] as Rect2
	var padding := 28.0
	var target := Rect2(Vector2(padding, padding), size - Vector2(padding * 2.0, padding * 2.0))
	if target.size.x <= 1.0 or target.size.y <= 1.0:
		return

	var scale := minf(target.size.x / bounds.size.x, target.size.y / bounds.size.y)
	var world_size := bounds.size * scale
	var origin := target.position + (target.size - world_size) * 0.5
	var preview_bounds := Rect2(origin, world_size)
	draw_rect(preview_bounds, Color("#143247"), true)
	draw_rect(preview_bounds, Color("#51e7ff"), false, 2.0)

	for value in _plan.get("obstacle_spawns", []) as Array:
		var entry := value as Dictionary
		draw_circle(_map_position(entry["position"] as Vector2, bounds, preview_bounds), 3.0, Color("#7b8994"))

	for value in _plan.get("salvage_spawns", []) as Array:
		var entry := value as Dictionary
		draw_circle(_map_position(entry["position"] as Vector2, bounds, preview_bounds), 2.4, Color("#9af8d7"))

	for value in _plan.get("landmark_spawns", []) as Array:
		var entry := value as Dictionary
		draw_circle(_map_position(entry["position"] as Vector2, bounds, preview_bounds), 7.0, Color("#ffd166"))
		draw_circle(_map_position(entry["position"] as Vector2, bounds, preview_bounds), 10.0, Color(1.0, 0.82, 0.4, 0.22), false, 2.0)

	var depot := _plan["depot_position"] as Vector2
	draw_circle(_map_position(depot, bounds, preview_bounds), 6.0, Color("#53d7f1"))
	draw_circle(_map_position(Vector2.ZERO, bounds, preview_bounds), 4.0, Color.WHITE)

func _map_position(world: Vector2, world_bounds: Rect2, preview_bounds: Rect2) -> Vector2:
	var normalized := Vector2(
		(world.x - world_bounds.position.x) / world_bounds.size.x,
		(world.y - world_bounds.position.y) / world_bounds.size.y
	)
	return preview_bounds.position + normalized * preview_bounds.size
