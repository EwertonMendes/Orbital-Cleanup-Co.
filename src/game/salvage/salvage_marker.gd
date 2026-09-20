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

	var category := WorldVisualLanguage.salvage_category_color(_definition.category)
	var rarity := WorldVisualLanguage.salvage_rarity_color(_definition.rarity)
	var radius := _definition.collision_radius + 13.0
	var breathe := (sin(_phase) + 1.0) * 0.5
	var idle_alpha := 0.20 + breathe * 0.07

	draw_circle(Vector2.ZERO, radius + 8.0, Color(category, 0.025 + breathe * 0.012))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(category, idle_alpha), 1.4, true)
	_draw_brackets(radius, category, 0.68 if _targeted else 0.42)

	var pip := Vector2(0.0, -radius - 8.0)
	var diamond := PackedVector2Array([
		pip + Vector2(0.0, -4.5),
		pip + Vector2(4.5, 0.0),
		pip + Vector2(0.0, 4.5),
		pip + Vector2(-4.5, 0.0),
	])
	draw_colored_polygon(diamond, Color(rarity, 0.92))

	if not _targeted:
		return

	draw_circle(Vector2.ZERO, radius + 4.0, Color(category, 0.06))
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 64, Color(category, 0.88), 2.2, true)
	if _progress > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius + 8.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * _progress,
			48,
			Color(rarity, 0.98),
			3.0,
			true
		)

func _draw_brackets(radius: float, color: Color, alpha: float) -> void:
	var c := Color(color, alpha)
	var arm := 8.0
	var offset := radius + 3.0
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var tangent := Vector2(-direction.y, direction.x)
		var center := direction * offset
		draw_line(center - tangent * arm, center + tangent * arm, c, 2.0, true)
		draw_line(center, center - direction * 6.0, c, 2.0, true)
