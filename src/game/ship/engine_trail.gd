extends Line2D
class_name EngineTrail

@export var source_path: NodePath
@export_range(0.10, 2.0, 0.01) var sample_lifetime := 0.52
@export_range(0.005, 0.20, 0.005) var sample_interval := 0.025
@export_range(0.1, 20.0, 0.1) var minimum_sample_distance := 1.5
@export_range(8, 96, 1) var max_samples := 48

var _source: Node2D
var _target_intensity := 0.0
var _display_intensity := 0.0
var _sample_clock := 0.0
var _positions: Array[Vector2] = []
var _ages: Array[float] = []
var _enabled := true
var _preview_mode := false
var _base_width := 11.0
var _base_lifetime := 0.52
var _mode := "ribbon"
var _wave_amplitude := 0.0
var _wave_frequency := 0.0
var _phase := 0.0
var _opacity := 1.0
var _alpha_scale := 1.0
var _preview_length := 72.0
var _preview_points := 20
var _boost_width_bonus := 0.20
var _boost_lifetime_bonus := 0.12
var _boost_ratio := 0.0

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	global_rotation = 0.0
	_source = get_node_or_null(source_path) as Node2D
	assert(_source != null, "EngineTrail requires a valid source Node2D.")
	_base_width = width
	_base_lifetime = sample_lifetime
	_rebuild_line()

func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled:
		_positions.clear()
		_ages.clear()
		clear_points()
		visible = false

func set_preview_mode(value: bool) -> void:
	_preview_mode = value
	_positions.clear()
	_ages.clear()
	_sample_clock = 0.0
	_rebuild_line()

func set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.0, 1.0)

func set_boost(value: float) -> void:
	_boost_ratio = clampf(value, 0.0, 1.0)
	width = _base_width * (1.0 + _boost_width_bonus * _boost_ratio)
	sample_lifetime = _base_lifetime * (1.0 + _boost_lifetime_bonus * _boost_ratio)

func apply_style(
	style: Dictionary,
	palette: Dictionary = {},
	phase: float = 0.0,
	alpha_scale: float = 1.0,
	visual_scale: float = 1.0
) -> void:
	assert(not style.is_empty(), "EngineTrail style cannot be empty.")
	_mode = String(style.get("mode", "ribbon"))
	var safe_visual_scale := clampf(visual_scale, 0.25, 4.0)
	_base_width = clampf(float(style.get("width", width)) * safe_visual_scale, 1.0, 64.0)
	_base_lifetime = clampf(float(style.get("lifetime", sample_lifetime)), 0.10, 2.0)
	sample_interval = clampf(float(style.get("sample_interval", sample_interval)), 0.005, 0.20)
	minimum_sample_distance = clampf(float(style.get("minimum_sample_distance", minimum_sample_distance)), 0.1, 20.0)
	max_samples = clampi(int(style.get("max_samples", max_samples)), 8, 96)
	_wave_amplitude = clampf(float(style.get("wave_amplitude", 0.0)) * safe_visual_scale, 0.0, 48.0)
	_wave_frequency = clampf(float(style.get("wave_frequency", 0.0)), 0.0, 8.0)
	_phase = phase
	_opacity = clampf(float(style.get("opacity", 1.0)), 0.05, 1.0)
	_alpha_scale = clampf(alpha_scale, 0.05, 1.0)
	_preview_length = clampf(float(style.get("preview_length", 72.0)) * safe_visual_scale, 12.0, 480.0)
	_preview_points = clampi(int(style.get("preview_points", 20)), 8, 48)
	_boost_width_bonus = clampf(float(style.get("boost_width_bonus", 0.20)), 0.0, 1.0)
	_boost_lifetime_bonus = clampf(float(style.get("boost_lifetime_bonus", 0.12)), 0.0, 1.0)
	width = _base_width
	sample_lifetime = _base_lifetime

	var palette_values := palette.get("palette", palette) as Dictionary
	var tail_hex := String(palette_values.get("trail_tail", style.get("tail_color", "#199FDF")))
	var head_hex := String(palette_values.get("trail_head", style.get("head_color", "#B0F8FF")))
	var tail := Color.from_string(tail_hex, Color(0.10, 0.62, 0.87, 1.0))
	var head := Color.from_string(head_hex, Color(0.69, 0.97, 1.0, 1.0))
	var next_gradient := Gradient.new()
	next_gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.76, 1.0])
	next_gradient.colors = PackedColorArray([
		Color(tail.r, tail.g, tail.b, 0.0),
		Color(tail.r, tail.g, tail.b, 0.30 * _opacity * _alpha_scale),
		Color(head.r, head.g, head.b, 0.76 * _opacity * _alpha_scale),
		Color(head.r, head.g, head.b, 0.98 * _opacity * _alpha_scale),
	])
	gradient = next_gradient
	set_boost(_boost_ratio)
	_rebuild_line()

func _process(delta: float) -> void:
	if not _enabled:
		visible = false
		return

	_display_intensity = move_toward(_display_intensity, _target_intensity, delta * 5.5)

	if _preview_mode:
		_rebuild_line()
		return

	for index in range(_ages.size()):
		_ages[index] += delta

	while not _ages.is_empty() and (_ages[0] >= sample_lifetime or _ages.size() > max_samples):
		_ages.remove_at(0)
		_positions.remove_at(0)

	if _source != null and _display_intensity > 0.035:
		_sample_clock += delta
		var source_position := _source.global_position

		if _positions.is_empty():
			_positions.append(source_position)
			_ages.append(0.0)
			_sample_clock = 0.0
		elif _sample_clock >= sample_interval:
			if _positions.back().distance_to(source_position) >= minimum_sample_distance:
				_positions.append(source_position)
				_ages.append(0.0)
			_sample_clock = 0.0
	else:
		_sample_clock = 0.0

	_rebuild_line()

func _rebuild_line() -> void:
	clear_points()
	if not _enabled or _source == null:
		visible = false
		return

	if _preview_mode:
		_rebuild_preview_line()
		modulate.a = clampf(_display_intensity * _opacity, 0.0, 1.0)
		visible = _display_intensity > 0.02 and get_point_count() >= 2
		return

	for index in range(_positions.size()):
		add_point(_styled_history_position(index))

	# The live head is not stored as history. It stays attached to the exhaust
	# every render frame, which makes the trail continuous at low speed.
	if _display_intensity > 0.02:
		var head := _source.global_position
		if get_point_count() == 0 or get_point_position(get_point_count() - 1).distance_to(head) > 0.05:
			add_point(head)

	var history_alpha := 0.0
	if not _ages.is_empty():
		history_alpha = clampf(1.0 - (_ages[0] / maxf(sample_lifetime, 0.001)), 0.0, 1.0)

	modulate.a = clampf(maxf(_display_intensity, history_alpha * 0.62) * _opacity, 0.0, 1.0)
	visible = get_point_count() >= 2 and (_display_intensity > 0.02 or history_alpha > 0.02)

func _rebuild_preview_line() -> void:
	var origin := _source.global_position
	var direction := Vector2.DOWN.rotated(_source.global_rotation)
	var perpendicular := direction.orthogonal()
	var length := _preview_length * (0.72 + _display_intensity * 0.38 + _boost_ratio * 0.28)

	for index in range(_preview_points):
		var progress := float(index) / float(maxi(_preview_points - 1, 1))
		var distance_from_head := (1.0 - progress) * length
		var point := origin + direction * distance_from_head
		if _mode == "dual_helix" and _wave_amplitude > 0.0:
			var wave := sin(progress * TAU * _wave_frequency + _phase)
			point += perpendicular * wave * _wave_amplitude
		add_point(point)

func _styled_history_position(index: int) -> Vector2:
	var point := _positions[index]
	if _mode != "dual_helix" or _wave_amplitude <= 0.0 or _positions.size() < 2:
		return point

	var previous := _positions[maxi(index - 1, 0)]
	var next := _positions[mini(index + 1, _positions.size() - 1)]
	var tangent := (next - previous).normalized()
	if tangent == Vector2.ZERO:
		tangent = Vector2.DOWN
	var progress := float(index) / float(maxi(_positions.size() - 1, 1))
	var wave := sin(progress * TAU * _wave_frequency + _phase)
	return point + tangent.orthogonal() * wave * _wave_amplitude
