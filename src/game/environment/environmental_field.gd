extends Node2D
class_name EnvironmentalField

var _definition: Dictionary = {}
var _kind := ""
var _shape := "circle"
var _radius := 420.0
var _size := Vector2(900.0, 360.0)
var _strength := 0.5
var _field_color := Color("#72d7ff")
var _secondary_color := Color("#9effe6")
var _phase := 0.0
var _redraw_accumulator := 0.0

func configure(definition: Dictionary, palette: Dictionary) -> void:
	assert(not definition.is_empty(), "EnvironmentalField requires generated definition.")
	_definition = definition.duplicate(true)
	_kind = String(definition["kind"])
	_shape = String(definition.get("shape", "circle"))
	_radius = maxf(float(definition.get("radius", 420.0)), 40.0)
	_size = definition.get("size", Vector2(900.0, 360.0)) as Vector2
	_strength = clampf(float(definition.get("strength", 0.5)), 0.05, 1.0)
	_field_color = Color.from_string(
		String(definition.get("color", palette.get("accent", "#72d7ff"))),
		Color("#72d7ff")
	)
	_secondary_color = Color.from_string(
		String(definition.get("secondary_color", palette.get("nebula", "#183b72"))),
		Color("#183b72")
	)
	position = definition["position"] as Vector2
	rotation = float(definition.get("rotation", 0.0))
	z_index = -8
	queue_redraw()

func get_kind() -> String:
	return _kind

func sample(world_position: Vector2) -> Dictionary:
	var local := to_local(world_position)
	var influence := _influence_at_local(local)
	var output := {
		"kind": _kind,
		"intensity": influence * _strength,
		"ship_force": Vector2.ZERO,
		"salvage_force": Vector2.ZERO,
		"speed_multiplier": 1.0,
		"scanner_multiplier": 1.0,
		"tractor_multiplier": 1.0,
		"visibility": 1.0,
		"label_key": _label_key(),
	}
	if influence <= 0.0:
		return output

	var intensity := float(output["intensity"])
	match _kind:
		"gravity_well":
			var toward_center := (global_position - world_position).normalized()
			output["ship_force"] = toward_center * 190.0 * intensity
			output["salvage_force"] = toward_center * 105.0 * intensity
		"safe_corridor":
			output["speed_multiplier"] = lerpf(1.0, 1.06, intensity)
		"drift_current":
			var direction := Vector2.RIGHT.rotated(global_rotation)
			output["ship_force"] = direction * 165.0 * intensity
			output["salvage_force"] = direction * 92.0 * intensity
		"visibility_pocket":
			output["visibility"] = lerpf(1.0, 0.48, intensity)
		"scanner_interference":
			output["scanner_multiplier"] = lerpf(1.0, 0.52, intensity)
		"tractor_distortion":
			output["tractor_multiplier"] = lerpf(1.0, 0.58, intensity)
		"magnetic_zone":
			var toward_center := (global_position - world_position).normalized()
			output["ship_force"] = toward_center * 32.0 * intensity
			output["salvage_force"] = toward_center * 135.0 * intensity
			output["tractor_multiplier"] = lerpf(1.0, 0.78, intensity)
	return output

func contains_world_position(world_position: Vector2, padding: float = 0.0) -> bool:
	var local := to_local(world_position)
	if _shape == "box":
		var half := _size * 0.5 + Vector2.ONE * padding
		return absf(local.x) <= half.x and absf(local.y) <= half.y
	return local.length() <= _radius + padding

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	_redraw_accumulator += delta
	if _redraw_accumulator >= RuntimeQuality.environmental_field_redraw_interval():
		_redraw_accumulator = 0.0
		queue_redraw()

func _influence_at_local(local: Vector2) -> float:
	var normalized := 0.0
	if _shape == "box":
		var half := Vector2(maxf(_size.x * 0.5, 1.0), maxf(_size.y * 0.5, 1.0))
		normalized = maxf(absf(local.x) / half.x, absf(local.y) / half.y)
	else:
		normalized = local.length() / maxf(_radius, 1.0)

	if normalized >= 1.0:
		return 0.0
	var t := clampf(1.0 - normalized, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _label_key() -> String:
	match _kind:
		"gravity_well":
			return "ENV_GRAVITY_WELL"
		"safe_corridor":
			return "ENV_SAFE_CORRIDOR"
		"drift_current":
			return "ENV_SOLAR_CURRENT"
		"visibility_pocket":
			return "ENV_LOW_VISIBILITY"
		"scanner_interference":
			return "ENV_SCANNER_INTERFERENCE"
		"tractor_distortion":
			return "ENV_TRACTOR_DISTORTION"
		"magnetic_zone":
			return "ENV_MAGNETIC_ZONE"
	return "ENV_STABLE_ORBIT"

func _draw() -> void:
	match _kind:
		"gravity_well":
			_draw_gravity_well()
		"safe_corridor":
			_draw_corridor()
		"drift_current":
			_draw_current()
		"visibility_pocket":
			_draw_visibility_pocket()
		"scanner_interference":
			_draw_interference()
		"tractor_distortion":
			_draw_tractor_distortion()
		"magnetic_zone":
			_draw_magnetic_zone()

func _draw_gravity_well() -> void:
	for index in range(4):
		var radius := _radius * (0.34 + float(index) * 0.18) + sin(_phase * 0.7 + index) * 5.0
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(_field_color, 0.045 + index * 0.018), 1.4, true)
	for index in range(8):
		var angle := float(index) / 8.0 * TAU + _phase * 0.11
		var outer := Vector2.from_angle(angle) * _radius * 0.78
		var inner := Vector2.from_angle(angle) * _radius * 0.58
		draw_line(outer, inner, Color(_field_color, 0.17), 1.5, true)

func _draw_corridor() -> void:
	var half := _size * 0.5
	var color := Color(_field_color, 0.13)
	draw_rect(Rect2(-half, _size), color, false, 2.0, true)
	var lane_offset := sin(_phase * 0.55) * 7.0
	draw_line(Vector2(-half.x, -half.y * 0.55 + lane_offset), Vector2(half.x, -half.y * 0.55 + lane_offset), Color(_field_color, 0.08), 1.0, true)
	draw_line(Vector2(-half.x, half.y * 0.55 + lane_offset), Vector2(half.x, half.y * 0.55 + lane_offset), Color(_field_color, 0.08), 1.0, true)
	for index in range(12):
		var t := fposmod(float(index) / 12.0 + _phase * 0.025, 1.0)
		var x := lerpf(-half.x, half.x, t)
		draw_line(Vector2(x - 18.0, 0.0), Vector2(x + 18.0, 0.0), Color(_field_color, 0.13), 1.4, true)

func _draw_current() -> void:
	var half := _size * 0.5
	for row in range(3):
		var y := lerpf(-half.y * 0.72, half.y * 0.72, float(row) / 2.0)
		for column in range(4):
			var t := fposmod(float(column) / 4.0 + _phase * 0.06 + row * 0.07, 1.0)
			var x := lerpf(-half.x, half.x, t)
			var alpha := 0.07 + _strength * 0.08
			draw_line(Vector2(x - 38.0, y), Vector2(x + 22.0, y), Color(_field_color, alpha), 2.0, true)
			draw_line(Vector2(x + 22.0, y), Vector2(x + 8.0, y - 8.0), Color(_field_color, alpha), 1.4, true)
			draw_line(Vector2(x + 22.0, y), Vector2(x + 8.0, y + 8.0), Color(_field_color, alpha), 1.4, true)
	draw_rect(Rect2(-half, _size), Color(_secondary_color, 0.025), true)

func _draw_visibility_pocket() -> void:
	for index in range(3, 0, -1):
		var ratio := float(index) / 3.0
		var radius := _radius * ratio
		var alpha := 0.020 + (1.0 - ratio) * 0.022
		draw_circle(Vector2.ZERO, radius, Color(_secondary_color, alpha))
	draw_arc(Vector2.ZERO, _radius, _phase * 0.06, _phase * 0.06 + 2.3, 24, Color(_field_color, 0.07), 1.2, true)

func _draw_interference() -> void:
	for index in range(4):
		var radius := _radius * (0.35 + index * 0.17)
		var start := _phase * (0.17 + index * 0.03) + index
		draw_arc(Vector2.ZERO, radius, start, start + 1.3, 24, Color(_field_color, 0.12), 1.6, true)
	for index in range(7):
		var angle := float(index) * 0.9 + sin(_phase * 0.4 + index) * 0.25
		var p := Vector2.from_angle(angle) * _radius * 0.72
		draw_circle(p, 2.0, Color(_field_color, 0.20))

func _draw_tractor_distortion() -> void:
	for index in range(3):
		var radius := _radius * (0.38 + index * 0.20)
		var offset := sin(_phase * (0.7 + index * 0.12)) * 0.18
		draw_arc(Vector2.ZERO, radius, offset + index, offset + index + 3.9, 32, Color(_field_color, 0.10), 2.0, true)
	draw_circle(Vector2.ZERO, _radius * 0.18, Color(_secondary_color, 0.035))

func _draw_magnetic_zone() -> void:
	for index in range(6):
		var angle := float(index) / 6.0 * TAU + _phase * 0.14
		var p1 := Vector2.from_angle(angle) * _radius * 0.32
		var p2 := Vector2.from_angle(angle + 0.34) * _radius * 0.78
		draw_arc(Vector2.ZERO, p2.length(), angle - 0.22, angle + 0.22, 12, Color(_field_color, 0.09), 1.6, true)
		draw_circle(p1, 2.4, Color(_field_color, 0.20))
