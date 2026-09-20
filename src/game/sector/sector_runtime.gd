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
	landmark.configure(entry["definition"] as Dictionary)
	landmark.position = entry["position"] as Vector2
	landmark.rotation = float(entry["rotation"])
	landmark_root.add_child(landmark)

func _spawn_obstacle(entry: Dictionary) -> void:
	var obstacle := OBSTACLE_SCENE.instantiate() as SectorObstacle
	assert(obstacle != null, "Generic obstacle scene must instantiate.")
	obstacle.configure(entry["definition"] as Dictionary, float(entry["scale"]))
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
	salvage.position = entry["position"] as Vector2
	salvage.spin_speed = float(entry["spin_speed"])
	salvage_root.add_child(salvage)
