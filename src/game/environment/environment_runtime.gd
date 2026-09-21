extends Node2D
class_name EnvironmentRuntime

signal environment_state_changed(label_key: String, intensity: float)

var _fields: Array[EnvironmentalField] = []
var _play_bounds := Rect2()
var _palette: Dictionary = {}
var _biome_id := ""
var _ship: PlayerShip
var _sector_runtime: SectorRuntime
var _post_process: WorldPostProcess
var _last_label := ""
var _last_intensity := -1.0
var _fog_color := Color("#183b72")

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
	sector_runtime: SectorRuntime,
	post_process: WorldPostProcess
) -> void:
	assert(ship != null, "EnvironmentRuntime requires PlayerShip.")
	assert(sector_runtime != null, "EnvironmentRuntime requires SectorRuntime.")
	assert(post_process != null, "EnvironmentRuntime requires WorldPostProcess.")
	_ship = ship
	_sector_runtime = sector_runtime
	_post_process = post_process
	_apply_ship_state(_neutral_state())

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

	var ship_state := _sample(_ship.global_position)
	_apply_ship_state(ship_state)
	_apply_salvage_motion(delta)
	_report_state(ship_state)

func _sample(world_position: Vector2) -> Dictionary:
	var output := _neutral_state()
	var dominant_intensity := 0.0
	var dominant_label := "ENV_STABLE_ORBIT"

	for field in _fields:
		var sample := field.sample(world_position)
		var intensity := float(sample["intensity"])
		if intensity <= 0.0:
			continue

		output["ship_force"] = (output["ship_force"] as Vector2) + (sample["ship_force"] as Vector2)
		output["salvage_force"] = (output["salvage_force"] as Vector2) + (sample["salvage_force"] as Vector2)
		output["speed_multiplier"] = float(output["speed_multiplier"]) * float(sample["speed_multiplier"])
		output["scanner_multiplier"] = float(output["scanner_multiplier"]) * float(sample["scanner_multiplier"])
		output["tractor_multiplier"] = float(output["tractor_multiplier"]) * float(sample["tractor_multiplier"])
		output["visibility"] = minf(float(output["visibility"]), float(sample["visibility"]))
		if intensity > dominant_intensity:
			dominant_intensity = intensity
			dominant_label = String(sample["label_key"])

	output["ship_force"] = (output["ship_force"] as Vector2).limit_length(210.0)
	output["salvage_force"] = (output["salvage_force"] as Vector2).limit_length(150.0)
	output["speed_multiplier"] = clampf(float(output["speed_multiplier"]), 0.82, 1.08)
	output["scanner_multiplier"] = clampf(float(output["scanner_multiplier"]), 0.46, 1.0)
	output["tractor_multiplier"] = clampf(float(output["tractor_multiplier"]), 0.52, 1.0)
	output["visibility"] = clampf(float(output["visibility"]), 0.46, 1.0)
	output["dominant_intensity"] = dominant_intensity
	output["label_key"] = dominant_label
	return output

func _neutral_state() -> Dictionary:
	return {
		"ship_force": Vector2.ZERO,
		"salvage_force": Vector2.ZERO,
		"speed_multiplier": 1.0,
		"scanner_multiplier": 1.0,
		"tractor_multiplier": 1.0,
		"visibility": 1.0,
		"dominant_intensity": 0.0,
		"label_key": "ENV_STABLE_ORBIT",
	}

func _apply_ship_state(state: Dictionary) -> void:
	if _ship == null:
		return
	_ship.set_environment_motion(
		state["ship_force"] as Vector2,
		float(state["speed_multiplier"])
	)
	_ship.tractor_beam.set_environment_modifiers(
		float(state["scanner_multiplier"]),
		float(state["tractor_multiplier"])
	)
	if _post_process != null:
		_post_process.set_environment_state(
			float(state["visibility"]),
			_fog_color,
			maxf(
				1.0 - float(state["scanner_multiplier"]),
				1.0 - float(state["tractor_multiplier"])
			)
		)

func _apply_salvage_motion(delta: float) -> void:
	if _sector_runtime == null:
		return
	for salvage in _sector_runtime.get_salvage_nodes():
		if not is_instance_valid(salvage):
			continue
		var state := _sample(salvage.global_position)
		salvage.apply_environment_force(
			state["salvage_force"] as Vector2,
			delta,
			_play_bounds
		)

func _report_state(state: Dictionary) -> void:
	var label := String(state["label_key"])
	var intensity := float(state["dominant_intensity"])
	if label == _last_label and absf(intensity - _last_intensity) < 0.08:
		return
	_last_label = label
	_last_intensity = intensity
	environment_state_changed.emit(label, intensity)
