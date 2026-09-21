extends Node2D
class_name SalvageMarker

var _definition: SalvageDefinition
var _targeted := false
var _progress := 0.0
var _phase := 0.0

func configure(definition: SalvageDefinition) -> void:
	_definition = definition
	queue_redraw()

func set_targeted(value: bool) -> void:
	_targeted = value
	if not value:
		_progress = 0.0
	queue_redraw()

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 2.1, TAU)
	queue_redraw()

func _draw() -> void:
	if _definition == null:
		return

	var recovery := WorldVisualLanguage.salvage_recovery_color()
	var progress_color := WorldVisualLanguage.salvage_progress_color()
	var category := WorldVisualLanguage.salvage_category_color(_definition.category)
	var rarity := WorldVisualLanguage.salvage_rarity_color(_definition.rarity)
	var radius := _definition.collision_radius + 13.0
	var breathe := (sin(_phase) + 1.0) * 0.5
	var idle_alpha := 0.22 + breathe * 0.06

	draw_circle(Vector2.ZERO, radius + 8.0, Color(recovery, 0.024 + breathe * 0.010))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(recovery, idle_alpha), 1.35, true)
	_draw_brackets(radius, recovery, 0.78 if _targeted else 0.48)
	_draw_category_signature(radius, category)

	var pip := Vector2(0.0, -radius - 8.0)
	var diamond := PackedVector2Array([
		pip + Vector2(0.0, -4.5),
		pip + Vector2(4.5, 0.0),
		pip + Vector2(0.0, 4.5),
		pip + Vector2(-4.5, 0.0),
	])
	draw_colored_polygon(diamond, Color(rarity, 0.94))

	var rarity_name := String(_definition.rarity)
	if rarity_name in ["rare", "epic"]:
		var mote_count := 2 if rarity_name == "epic" else 1
		for index in range(mote_count):
			var angle := _phase * (0.72 + float(index) * 0.18) + float(index) * PI
			var mote_position := Vector2.from_angle(angle) * (radius + 16.0)
			draw_circle(mote_position, 2.5 if rarity_name == "epic" else 2.0, Color(rarity, 0.72))

	if not _targeted:
		return

	draw_circle(Vector2.ZERO, radius + 4.0, Color(recovery, 0.055))
	_draw_target_arcs(radius + 3.0, recovery)
	if _progress > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius + 8.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * _progress,
			48,
			Color(progress_color, 0.98),
			3.0,
			true
		)

func _draw_target_arcs(radius: float, color: Color) -> void:
	for index in range(4):
		var center_angle := float(index) * PI * 0.5
		draw_arc(
			Vector2.ZERO,
			radius,
			center_angle - 0.34,
			center_angle + 0.34,
			10,
			Color(color, 0.92),
			2.2,
			true
		)

func _draw_brackets(radius: float, color: Color, alpha: float) -> void:
	var c := Color(color, alpha)
	var arm := 8.0
	var offset := radius + 3.0
	var directions: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for direction in directions:
		var tangent: Vector2 = Vector2(-direction.y, direction.x)
		var center: Vector2 = direction * offset
		draw_line(center - tangent * arm, center + tangent * arm, c, 2.0, true)
		draw_line(center, center - direction * 6.0, c, 2.0, true)

func _draw_category_signature(radius: float, color: Color) -> void:
	var c := Color(color, 0.82)
	var anchor := Vector2(radius + 12.0, radius + 4.0)
	match String(_definition.category):
		"electronics":
			for offset in [-5.0, 0.0, 5.0]:
				draw_circle(anchor + Vector2(offset, 0.0), 1.8, c)
		"cargo":
			draw_rect(Rect2(anchor - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), c, false, 1.6)
		"research":
			draw_arc(anchor, 5.0, 0.0, TAU, 16, c, 1.5, true)
			draw_circle(anchor, 1.6, c)
		"power":
			draw_line(anchor - Vector2(5.0, 0.0), anchor + Vector2(5.0, 0.0), c, 1.8, true)
			draw_line(anchor - Vector2(0.0, 5.0), anchor + Vector2(0.0, 5.0), c, 1.8, true)
		"mining":
			var chevron := PackedVector2Array([
				anchor + Vector2(-5.0, -3.0),
				anchor,
				anchor + Vector2(-5.0, 3.0),
			])
			draw_polyline(chevron, c, 1.8, true)
		"industrial":
			draw_line(anchor + Vector2(-5.0, -3.0), anchor + Vector2(5.0, -3.0), c, 1.6, true)
			draw_line(anchor + Vector2(-5.0, 3.0), anchor + Vector2(5.0, 3.0), c, 1.6, true)
		"propulsion":
			draw_line(anchor + Vector2(-5.0, 0.0), anchor + Vector2(4.0, 0.0), c, 1.8, true)
			draw_line(anchor + Vector2(1.0, -4.0), anchor + Vector2(5.0, 0.0), c, 1.8, true)
			draw_line(anchor + Vector2(1.0, 4.0), anchor + Vector2(5.0, 0.0), c, 1.8, true)
		_:
			draw_circle(anchor, 2.2, c)
