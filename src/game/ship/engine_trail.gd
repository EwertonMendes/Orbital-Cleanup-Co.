extends Line2D
class_name EngineTrail

@export var source_path: NodePath
@export_range(0.05, 2.0, 0.01) var sample_lifetime := 0.42
@export_range(1.0, 40.0, 0.5) var sample_distance := 8.0
@export_range(4, 64, 1) var max_samples := 28

var _source: Node2D
var _intensity := 0.0
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
	_intensity = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
	for index in range(_ages.size()):
		_ages[index] += delta

	while not _ages.is_empty() and (_ages[0] >= sample_lifetime or _ages.size() > max_samples):
		_ages.remove_at(0)
		_positions.remove_at(0)

	if _source != null and _intensity > 0.06:
		var position := _source.global_position
		if _positions.is_empty() or _positions.back().distance_to(position) >= sample_distance:
			_positions.append(position)
			_ages.append(0.0)

	_rebuild_line()

func _rebuild_line() -> void:
	clear_points()
	for position in _positions:
		add_point(position)

	var life_alpha := 0.0
	if not _ages.is_empty():
		life_alpha = clampf(1.0 - (_ages[0] / sample_lifetime), 0.0, 1.0)
	modulate.a = maxf(_intensity, life_alpha * 0.55)
