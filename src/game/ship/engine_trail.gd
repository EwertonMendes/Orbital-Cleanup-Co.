extends Line2D
class_name EngineTrail

@export var source_path: NodePath
@export_range(0.10, 2.0, 0.01) var sample_lifetime := 0.52
@export_range(0.005, 0.20, 0.005) var sample_interval := 0.025
@export_range(0.1, 20.0, 0.1) var minimum_sample_distance := 1.5
@export_range(8, 120, 1) var max_samples := 48

var _source: Node2D
var _target_intensity := 0.0
var _display_intensity := 0.0
var _sample_clock := 0.0
var _animation_time := 0.0
var _positions: Array[Vector2] = []
var _ages: Array[float] = []
var _enabled := true
var _preview_mode := false
var _base_width := 11.0
var _base_lifetime := 0.52
var _mode := "ribbon"
var _phase := 0.0
var _opacity := 1.0
var _alpha_scale := 1.0
var _strand_offset := 0.0
var _wave_amplitude := 0.0
var _wave_frequency := 0.0
var _animation_speed := 0.0
var _pulse_count := 0
var _jitter_amplitude := 0.0
var _angularity := 0.0
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
	palette: Dictionary,
	phase: float,
	alpha_scale: float,
	width_scale: float,
	strand_offset: float,
	visual_scale: float
) -> void:
	assert(not style.is_empty(), "EngineTrail style cannot be empty.")
	assert(not palette.is_empty(), "EngineTrail palette cannot be empty.")
	var safe_visual_scale := clampf(visual_scale, 0.25, 4.0)
	_mode = String(style.get("mode", "ribbon"))
	_phase = phase
	_opacity = clampf(float(style.get("opacity", 1.0)), 0.05, 1.0)
	_alpha_scale = clampf(alpha_scale, 0.05, 1.0)
	_strand_offset = strand_offset * safe_visual_scale
	_wave_amplitude = clampf(float(style.get("wave_amplitude", 0.0)) * safe_visual_scale, 0.0, 64.0)
	_wave_frequency = clampf(float(style.get("wave_frequency", 0.0)), 0.0, 10.0)
	_animation_speed = clampf(float(style.get("animation_speed", 0.0)), 0.0, 16.0)
	_pulse_count = clampi(int(style.get("pulse_count", 0)), 0, 10)
	_jitter_amplitude = clampf(float(style.get("jitter_amplitude", 0.0)) * safe_visual_scale, 0.0, 24.0)
	_angularity = clampf(float(style.get("angularity", 0.0)), 0.0, 1.0)

	_base_width = clampf(
		float(style.get("width", width)) * safe_visual_scale * clampf(width_scale, 0.10, 1.5),
		0.75,
		72.0
	)
	_base_lifetime = clampf(float(style.get("lifetime", sample_lifetime)), 0.10, 2.0)
	sample_interval = clampf(float(style.get("sample_interval", sample_interval)), 0.005, 0.20)
	minimum_sample_distance = clampf(float(style.get("minimum_sample_distance", minimum_sample_distance)), 0.1, 20.0)
	max_samples = clampi(int(style.get("max_samples", max_samples)), 8, 120)
	_preview_length = clampf(float(style.get("preview_length", 72.0)) * safe_visual_scale, 12.0, 520.0)
	_preview_points = clampi(int(style.get("preview_points", 20)), 8, 64)
	_boost_width_bonus = clampf(float(style.get("boost_width_bonus", 0.20)), 0.0, 1.0)
	_boost_lifetime_bonus = clampf(float(style.get("boost_lifetime_bonus", 0.12)), 0.0, 1.0)
	width = _base_width
	sample_lifetime = _base_lifetime
	width_curve = _build_width_curve()

	var palette_values := palette.get("palette", palette) as Dictionary
	var tail := Color.from_string(String(palette_values.get("trail_tail", "#199FDF")), Color(0.10, 0.62, 0.87, 1.0))
	var mid := Color.from_string(String(palette_values.get("trail_mid", "#55DFFF")), Color(0.33, 0.87, 1.0, 1.0))
	var head := Color.from_string(String(palette_values.get("trail_head", "#B0F8FF")), Color(0.69, 0.97, 1.0, 1.0))
	var accent := Color.from_string(String(palette_values.get("accent", "#E9FDFF")), Color(0.91, 0.99, 1.0, 1.0))
	var next_gradient := Gradient.new()
	next_gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	next_gradient.colors = PackedColorArray([
		Color(tail.r, tail.g, tail.b, 0.0),
		Color(tail.r, tail.g, tail.b, 0.36 * _opacity * _alpha_scale),
		Color(mid.r, mid.g, mid.b, 0.82 * _opacity * _alpha_scale),
		Color(accent.r if _mode in ["pulse", "spark", "shard"] else head.r,
			accent.g if _mode in ["pulse", "spark", "shard"] else head.g,
			accent.b if _mode in ["pulse", "spark", "shard"] else head.b,
			0.98 * _opacity * _alpha_scale),
	])
	gradient = next_gradient
	set_boost(_boost_ratio)
	_rebuild_line()

func _process(delta: float) -> void:
	if not _enabled:
		visible = false
		return

	_animation_time += delta
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

	var total := _positions.size()
	for index in range(total):
		add_point(_styled_history_position(index, total))

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
		point += perpendicular * _style_offset(progress, index)
		add_point(point)

func _styled_history_position(index: int, total: int) -> Vector2:
	var point := _positions[index]
	if total < 2:
		return point
	var previous := _positions[maxi(index - 1, 0)]
	var next := _positions[mini(index + 1, total - 1)]
	var tangent := (next - previous).normalized()
	if tangent == Vector2.ZERO:
		tangent = Vector2.DOWN
	var progress := float(index) / float(maxi(total - 1, 1))
	return point + tangent.orthogonal() * _style_offset(progress, index)

func _style_offset(progress: float, index: int) -> float:
	var wave := progress * TAU * _wave_frequency + _phase + _animation_time * _animation_speed
	match _mode:
		"plasma":
			return _strand_offset + sin(wave) * _wave_amplitude + sin(wave * 0.47 + 1.7) * _wave_amplitude * 0.34
		"pulse":
			return _strand_offset + sin(wave) * _wave_amplitude * 0.22
		"spark":
			var tick: float = floor(_animation_time * maxf(_animation_speed, 1.0) * 2.5)
			var jitter: float = sin(float(index) * 12.9898 + tick * 2.41 + _phase * 5.3)
			return _strand_offset + jitter * _jitter_amplitude
		"comet":
			return _strand_offset + sin(wave) * _wave_amplitude * (0.20 + (1.0 - progress) * 0.80)
		"shard":
			var alternating := -1.0 if index % 2 == 0 else 1.0
			var stepped: float = round(sin(wave) * 2.0) * 0.5
			return _strand_offset + alternating * _jitter_amplitude * (0.45 + _angularity * 0.55) + stepped * _wave_amplitude
		"mist":
			return _strand_offset + sin(wave) * _wave_amplitude + sin(wave * 1.73 + 0.9) * _wave_amplitude * 0.42
		"dual_helix":
			return _strand_offset + sin(wave) * _wave_amplitude
		_:
			return _strand_offset

func _build_width_curve() -> Curve:
	var curve := Curve.new()
	match _mode:
		"plasma":
			_add_curve_points(curve, [[0.0, 0.04], [0.12, 0.70], [0.28, 1.10], [0.46, 0.62], [0.66, 1.0], [0.84, 0.72], [1.0, 0.92]])
		"pulse":
			var pulses := maxi(_pulse_count, 4)
			curve.add_point(Vector2(0.0, 0.0))
			for index in range(pulses):
				var start := float(index) / float(pulses)
				var center := (float(index) + 0.52) / float(pulses)
				var finish := (float(index) + 0.92) / float(pulses)
				curve.add_point(Vector2(clampf(start + 0.02, 0.0, 0.99), 0.06))
				curve.add_point(Vector2(clampf(center, 0.01, 0.995), 1.18))
				curve.add_point(Vector2(clampf(finish, 0.02, 0.999), 0.05))
			curve.add_point(Vector2(1.0, 0.82))
		"spark":
			_add_curve_points(curve, [[0.0, 0.0], [0.12, 0.95], [0.22, 0.10], [0.34, 1.0], [0.46, 0.08], [0.58, 0.90], [0.70, 0.12], [0.84, 1.05], [1.0, 0.62]])
		"comet":
			_add_curve_points(curve, [[0.0, 0.0], [0.16, 0.10], [0.40, 0.26], [0.68, 0.58], [0.88, 0.86], [1.0, 1.08]])
		"shard":
			_add_curve_points(curve, [[0.0, 0.0], [0.10, 0.88], [0.20, 0.18], [0.34, 1.0], [0.48, 0.22], [0.62, 0.92], [0.76, 0.24], [0.90, 1.02], [1.0, 0.58]])
		"mist":
			_add_curve_points(curve, [[0.0, 0.02], [0.18, 0.48], [0.36, 0.82], [0.56, 0.58], [0.76, 0.92], [1.0, 0.64]])
		"dual_helix":
			_add_curve_points(curve, [[0.0, 0.0], [0.18, 0.48], [0.62, 0.88], [1.0, 1.0]])
		_:
			_add_curve_points(curve, [[0.0, 0.0], [0.14, 0.30], [0.52, 0.72], [1.0, 1.0]])
	return curve

func _add_curve_points(curve: Curve, values: Array) -> void:
	for value in values:
		var pair := value as Array
		curve.add_point(Vector2(float(pair[0]), float(pair[1])))
