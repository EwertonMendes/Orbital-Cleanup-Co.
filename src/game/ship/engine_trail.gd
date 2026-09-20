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

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	global_rotation = 0.0
	_source = get_node_or_null(source_path) as Node2D
	assert(_source != null, "EngineTrail requires a valid source Node2D.")
	_rebuild_line()

func set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
	_display_intensity = move_toward(_display_intensity, _target_intensity, delta * 5.5)

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

	for position in _positions:
		add_point(position)

	# The live head is not stored as history. It stays attached to the exhaust
	# every render frame, which makes the trail continuous at low speed.
	if _source != null and _display_intensity > 0.02:
		var head := _source.global_position
		if get_point_count() == 0 or get_point_position(get_point_count() - 1).distance_to(head) > 0.05:
			add_point(head)

	var history_alpha := 0.0
	if not _ages.is_empty():
		history_alpha = clampf(1.0 - (_ages[0] / sample_lifetime), 0.0, 1.0)

	modulate.a = clampf(maxf(_display_intensity, history_alpha * 0.62), 0.0, 1.0)
	visible = get_point_count() >= 2 and (_display_intensity > 0.02 or history_alpha > 0.02)
