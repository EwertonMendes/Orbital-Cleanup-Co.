extends Node2D
class_name EnvironmentRuntime

signal environment_state_changed(label_key: String, intensity: float)
signal environment_visual_state_changed(
	visibility: float,
	environment_color: Color,
	distortion: float,
	label_key: String,
	intensity: float
)

var _fields: Array[EnvironmentalField] = []
var _play_bounds := Rect2()
var _palette: Dictionary = {}
var _biome_id := ""
var _ship: PlayerShip
var _sector_runtime: SectorRuntime
var _last_label := ""
var _last_intensity := -1.0
const SALVAGE_SAMPLE_INTERVAL := 0.10

var _fog_color := Color("#183b72")
var _salvage_sample_accumulator := 0.0
var _salvage_nodes: Array[SalvageObject] = []

func configure(
	field_definitions: Array,
	play_bounds: Rect2,
	palette: Dictionary,
	biome_id: String
) -> void:
	_play_bounds = play_bounds
	_palette = palette.duplicate(true)
	_biome_id = biome_id
	_fog_color = Color.from_string(String(palette.get("nebula", "#183b72")), Color("#183b72"))

	for child in get_children():
		child.queue_free()
	_fields.clear()

	for value in field_definitions:
		var field := EnvironmentalField.new()
		field.configure(value as Dictionary, _palette)
		add_child(field)
		_fields.append(field)

func bind(
	ship: PlayerShip,
	sector_runtime: SectorRuntime
) -> void:
	assert(ship != null, "EnvironmentRuntime requires PlayerShip.")
	assert(sector_runtime != null, "EnvironmentRuntime requires SectorRuntime.")
	_ship = ship
	_sector_runtime = sector_runtime
	_salvage_nodes = sector_runtime.get_salvage_nodes()
	_apply_ship_state(_neutral_state())
	_update_salvage_forces()

func get_field_count() -> int:
	return _fields.size()

func get_field_kinds() -> PackedStringArray:
	var kinds := PackedStringArray()
	for field in _fields:
		if not kinds.has(field.get_kind()):
			kinds.append(field.get_kind())
	kinds.sort()
	return kinds

func _physics_process(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return

	# Ship forces are sampled on every fixed physics tick. Inertial flight makes
	# stale gravity/current samples visible immediately, so gameplay physics must
	# not share the lower-frequency cadence used for loose salvage.
	var ship_state := _sample(_ship.global_position)
	_apply_ship_state(ship_state)
	_report_state(ship_state)

	_salvage_sample_accumulator += delta
	if _salvage_sample_accumulator >= SALVAGE_SAMPLE_INTERVAL:
		_salvage_sample_accumulator = fmod(_salvage_sample_accumulator, SALVAGE_SAMPLE_INTERVAL)
		_update_salvage_forces()

func _sample(world_position: Vector2) -> EnvironmentSample:
	var output := _neutral_state()
	for field in _fields:
		output.combine(field.sample(world_position))
	output.finalize_limits()
	return output

func _neutral_state() -> EnvironmentSample:
	return EnvironmentSample.new()

func _apply_ship_state(state: EnvironmentSample) -> void:
	if _ship == null:
		return
	_ship.set_environment_physics(
		state.linear_acceleration,
		state.external_force,
		state.linear_drag,
		state.thrust_multiplier
	)
	if _ship.tractor_beam != null:
		_ship.tractor_beam.set_environment_modifiers(
			state.scanner_multiplier,
			state.tractor_multiplier
		)

	var distortion := maxf(
		1.0 - state.scanner_multiplier,
		1.0 - state.tractor_multiplier
	)
	environment_visual_state_changed.emit(
		state.visibility,
		_fog_color,
		distortion,
		state.label_key,
		state.dominant_intensity
	)

func _update_salvage_forces() -> void:
	for salvage in _salvage_nodes:
		if not is_instance_valid(salvage) or salvage.is_queued_for_deletion():
			continue
		var state := _sample(salvage.global_position)
		salvage.set_environment_force(
			state.salvage_force,
			_play_bounds
		)

func _report_state(state: EnvironmentSample) -> void:
	var label := state.label_key
	var intensity := state.dominant_intensity
	if label == _last_label and absf(intensity - _last_intensity) < 0.08:
		return
	_last_label = label
	_last_intensity = intensity
	environment_state_changed.emit(label, intensity)
