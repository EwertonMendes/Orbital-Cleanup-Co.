extends Node2D
class_name SalvageMarker

var _definition: SalvageDefinition
var _priority_target := false
var _targeted := false
var _progress := 0.0
var _phase := 0.0
var _redraw_clock := 0.0

func configure(definition: SalvageDefinition, priority_target: bool = false) -> void:
	_definition = definition
	_priority_target = priority_target
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
	_redraw_clock += delta
	if _redraw_clock >= 1.0 / 30.0:
		_redraw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	if _definition == null:
		return

	var recovery := WorldVisualLanguage.salvage_recovery_color()
	var progress_color := WorldVisualLanguage.salvage_progress_color()
	var category := WorldVisualLanguage.salvage_category_color(_definition.category)
	var rarity := WorldVisualLanguage.salvage_rarity_color(_definition.rarity)
	var radius := _definition.collision_radius + 12.0
	var breathe := (sin(_phase) + 1.0) * 0.5
	var rarity_name := String(_definition.rarity)

	var idle_alpha := 0.10 + breathe * 0.035
	if rarity_name == "uncommon":
		idle_alpha += 0.035
	elif rarity_name == "rare":
		idle_alpha += 0.08
	elif rarity_name == "epic":
		idle_alpha += 0.12

	draw_circle(Vector2.ZERO, radius + 7.0, Color(recovery, 0.012 + breathe * 0.008))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(recovery, idle_alpha), 1.15, true)
	_draw_brackets(radius, recovery, 0.82 if _targeted else 0.38)
	_draw_category_signature(radius, category)
	_draw_rarity_signature(radius, rarity, rarity_name)

	if _priority_target:
		var priority_radius := radius + 18.0
		for index in range(4):
			var center_angle := float(index) * PI * 0.5 + _phase * 0.16
			draw_arc(Vector2.ZERO, priority_radius, center_angle - 0.16, center_angle + 0.16, 8, Color.WHITE, 0.72, true)

	if not _targeted:
		return

	draw_circle(Vector2.ZERO, radius + 4.0, Color(recovery, 0.045))
	_draw_target_arcs(radius + 3.0, recovery)
	if _progress > 0.0:
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * _progress, 48, Color(progress_color, 0.98), 3.0, true)

func _draw_rarity_signature(radius: float, color: Color, rarity_name: String) -> void:
	var pip := Vector2(0.0, -radius - 8.0)
	var diamond := PackedVector2Array([
		pip + Vector2(0.0, -4.5),
		pip + Vector2(4.5, 0.0),
		pip + Vector2(0.0, 4.5),
		pip + Vector2(-4.5, 0.0),
	])
	draw_colored_polygon(diamond, Color(color, 0.94))

	if rarity_name == "uncommon":
		draw_arc(Vector2.ZERO, radius + 5.0, -0.45, 0.45, 12, Color(color, 0.32), 1.2, true)
	elif rarity_name == "rare":
		var mote_position := Vector2.from_angle(_phase * 0.72) * (radius + 16.0)
		draw_circle(mote_position, 2.1, Color(color, 0.72))
		for index in range(2):
			var start := _phase * 0.18 + index * PI
			draw_arc(Vector2.ZERO, radius + 6.0, start, start + 0.52, 12, Color(color, 0.42), 1.5, true)
	elif rarity_name == "epic":
		for index in range(3):
			var angle := _phase * (0.72 + float(index) * 0.12) + float(index) * TAU / 3.0
			draw_circle(Vector2.from_angle(angle) * (radius + 17.0), 2.5, Color(color, 0.78))
		for index in range(3):
			var start := -_phase * 0.15 + float(index) * TAU / 3.0
			draw_arc(Vector2.ZERO, radius + 8.0, start, start + 0.48, 12, Color(color, 0.48), 1.7, true)

func _draw_target_arcs(radius: float, color: Color) -> void:
	for index in range(4):
		var center_angle := float(index) * PI * 0.5
		draw_arc(Vector2.ZERO, radius, center_angle - 0.34, center_angle + 0.34, 10, Color(color, 0.92), 2.2, true)

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
			var chevron := PackedVector2Array([anchor + Vector2(-5.0, -3.0), anchor, anchor + Vector2(-5.0, 3.0)])
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
