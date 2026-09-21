extends Node2D
class_name SectorRuntime

signal sector_ready(sector_id: String, seed: int, generation_signature: String)

const SALVAGE_SCENE := preload("res://src/game/salvage/salvage_object.tscn")
const OBSTACLE_SCENE := preload("res://src/game/sector/sector_obstacle.tscn")
const LANDMARK_SCENE := preload("res://src/game/sector/sector_landmark.tscn")

@onready var landmark_root: Node2D = %GeneratedLandmarks
@onready var obstacle_root: Node2D = %GeneratedObstacles
@onready var salvage_root: Node2D = %GeneratedSalvage

var _registry := ContentRegistry.new()
var _scaler := DifficultyScaler.new()
var _generator := SectorGenerator.new()
var _plan: Dictionary = {}
var _sector_id := ""
var _spawned := false

func configure_sector(sector_id: String) -> void:
	assert(not sector_id.is_empty(), "SectorRuntime requires sector id.")
	assert(not _spawned, "SectorRuntime cannot change sector after spawning.")
	_sector_id = sector_id
	_scaler.configure(_registry)
	_generator.configure(_registry, _scaler)
	_plan = _generator.generate(sector_id)

func configure_sector_definition(sector_definition: Dictionary) -> void:
	assert(not sector_definition.is_empty(), "SectorRuntime requires generated sector definition.")
	assert(not _spawned, "SectorRuntime cannot change sector after spawning.")
	_sector_id = String(sector_definition.get("id", ""))
	assert(not _sector_id.is_empty(), "Generated sector requires id.")
	_scaler.configure(_registry)
	_generator.configure(_registry, _scaler)
	_plan = _generator.generate_definition(sector_definition)

func get_biome_display_name_key() -> String:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return String((_plan["biome"] as Dictionary)["display_name_key"])

func get_biome_id() -> String:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return String((_plan["biome"] as Dictionary)["id"])

func _ready() -> void:
	assert(not _plan.is_empty(), "SectorRuntime must be configured before entering the tree.")
	_spawn_generated_content()
	var sector := _plan["sector"] as Dictionary
	var signature := String(_plan["generation_signature"])
	var seed := int(sector["seed"])
	print(
		"[Sector] READY id=%s seed=%d salvage=%d obstacles=%d signature=%s"
		% [_sector_id, seed, get_salvage_count(), get_obstacle_count(), signature]
	)
	sector_ready.emit(_sector_id, seed, signature)

func get_play_bounds() -> Rect2:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return _plan["play_bounds"] as Rect2

func get_depot_position() -> Vector2:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return _plan["depot_position"] as Vector2

func get_biome_palette() -> Dictionary:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	var biome := _plan["biome"] as Dictionary
	return (biome.get("palette", {}) as Dictionary).duplicate(true)

func get_biome_visual_profile() -> Dictionary:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	var biome := _plan["biome"] as Dictionary
	return (biome.get("visual_profile", {}) as Dictionary).duplicate(true)

func get_environment_fields() -> Array:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return (_plan.get("environment_fields", []) as Array).duplicate(true)

func get_salvage_nodes() -> Array[SalvageObject]:
	var output: Array[SalvageObject] = []
	for child in salvage_root.get_children():
		if child is SalvageObject:
			output.append(child as SalvageObject)
	return output

func get_sector_display_name_key() -> String:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return String((_plan["sector"] as Dictionary)["display_name_key"])

func get_sector_id() -> String:
	return _sector_id

func get_generation_signature() -> String:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	return String(_plan["generation_signature"])

func get_salvage_count() -> int:
	if _plan.is_empty():
		return 0
	return (_plan["salvage_spawns"] as Array).size()

func get_obstacle_count() -> int:
	if _plan.is_empty():
		return 0
	return (_plan["obstacle_spawns"] as Array).size()

func get_total_cleanliness() -> float:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	var total := 0.0
	for value in _plan["salvage_spawns"] as Array:
		var entry := value as Dictionary
		var definition := _registry.get_salvage_definition(String(entry["salvage_id"]))
		total += definition.cleanliness_value
	return maxf(total, 0.001)

func get_contract_context() -> Dictionary:
	assert(not _plan.is_empty(), "SectorRuntime is not configured.")
	var sector := _plan["sector"] as Dictionary
	var contract_ref := sector["contract"] as Dictionary
	var contract := _registry.get_contract(String(contract_ref["type"]))
	var parameters := _plan["parameters"] as Dictionary
	return {
		"sector_id": _sector_id,
		"contract": contract,
		"contract_ref": contract_ref.duplicate(true),
		"total_cleanliness": get_total_cleanliness(),
		"reward_multiplier": float(parameters.get("reward_multiplier", 1.0)),
	}

func _spawn_generated_content() -> void:
	assert(not _spawned, "SectorRuntime content can only spawn once.")
	_spawned = true

	for value in _plan["landmark_spawns"] as Array:
		_spawn_landmark(value as Dictionary)

	for value in _plan["obstacle_spawns"] as Array:
		_spawn_obstacle(value as Dictionary)

	for value in _plan["salvage_spawns"] as Array:
		_spawn_salvage(value as Dictionary)

func _spawn_landmark(entry: Dictionary) -> void:
	var landmark := LANDMARK_SCENE.instantiate() as SectorLandmark
	assert(landmark != null, "Generic landmark scene must instantiate.")
	landmark.configure(
		entry["definition"] as Dictionary,
		float(entry.get("spin_speed", 0.0)),
		float(entry.get("motion_phase", 0.0))
	)
	landmark.position = entry["position"] as Vector2
	landmark.rotation = float(entry["rotation"])
	landmark_root.add_child(landmark)

func _spawn_obstacle(entry: Dictionary) -> void:
	var obstacle := OBSTACLE_SCENE.instantiate() as SectorObstacle
	assert(obstacle != null, "Generic obstacle scene must instantiate.")
	obstacle.configure(
		entry["definition"] as Dictionary,
		float(entry["scale"]),
		float(entry.get("spin_speed", 0.0)),
		float(entry.get("motion_phase", 0.0))
	)
	obstacle.position = entry["position"] as Vector2
	obstacle.rotation = float(entry["rotation"])
	obstacle_root.add_child(obstacle)

func _spawn_salvage(entry: Dictionary) -> void:
	var salvage := SALVAGE_SCENE.instantiate() as SalvageObject
	assert(salvage != null, "Generic salvage scene must instantiate.")

	var source := _registry.get_salvage_definition(String(entry["salvage_id"]))
	var definition := source.duplicate(true) as SalvageDefinition
	assert(definition != null, "Salvage definition must duplicate.")

	var parameters := _plan["parameters"] as Dictionary
	definition.mass *= float(parameters.get("mass_multiplier", 1.0))
	definition.base_value = int(round(float(definition.base_value) * float(parameters.get("reward_multiplier", 1.0))))
	definition.validate()

	salvage.definition = definition
	salvage.priority_target = bool(entry.get("priority_target", false))
	salvage.position = entry["position"] as Vector2
	salvage.spin_speed = float(entry["spin_speed"])
	salvage_root.add_child(salvage)
