extends RefCounted
class_name ContentRegistry

const CONTENT_ROOT := "res://content"

var _json_cache: Dictionary = {}
var _salvage_cache: Dictionary = {}

func get_sector(id: String) -> Dictionary:
	return _load_named("sectors", id)

func get_biome(id: String) -> Dictionary:
	return _load_named("biomes", id)

func get_salvage_data(id: String) -> Dictionary:
	return _load_named("salvage", id)

func get_salvage_table(id: String) -> Dictionary:
	return _load_named("salvage_tables", id)

func get_landmark(id: String) -> Dictionary:
	return _load_named("landmarks", id)

func get_contract(id: String) -> Dictionary:
	return _load_named("contracts", id)

func get_modifier(id: String) -> Dictionary:
	return _load_named("modifiers", id)

func get_progression(id: String) -> Dictionary:
	return _load_named("progression", id)

func get_cosmetic(id: String) -> Dictionary:
	return _load_named("cosmetics", id)

func list_sector_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open("%s/sectors" % CONTENT_ROOT)
	assert(dir != null, "Unable to enumerate sector content.")

	dir.list_dir_begin()
	var filename := dir.get_next()
	while not filename.is_empty():
		if not dir.current_is_dir() and filename.ends_with(".json"):
			ids.append(filename.left(filename.length() - 5))
		filename = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids

func get_salvage_definition(id: String) -> SalvageDefinition:
	if _salvage_cache.has(id):
		return _salvage_cache[id] as SalvageDefinition

	var data := get_salvage_data(id)
	var definition := SalvageDefinition.new()
	definition.id = StringName(data["id"])
	definition.display_name_key = StringName(data["display_name_key"])
	definition.sprite = load(String(data["sprite"])) as Texture2D
	definition.category = StringName(data["category"])
	definition.rarity = StringName(data["rarity"])
	definition.base_value = int(data["base_value"])
	definition.mass = float(data["mass"])
	definition.collect_duration = float(data["collect_duration"])
	definition.cleanliness_value = float(data["cleanliness_value"])
	definition.cargo_units = int(data["cargo_units"])
	definition.visual_scale = float(data["visual_scale"])
	definition.collision_radius = float(data["collision_radius"])
	definition.tags = PackedStringArray(data.get("tags", []))
	definition.validate()

	_salvage_cache[id] = definition
	return definition

func _load_named(category: String, id: String) -> Dictionary:
	assert(not id.is_empty(), "Content id cannot be empty.")
	var cache_key := "%s/%s" % [category, id]
	if _json_cache.has(cache_key):
		return (_json_cache[cache_key] as Dictionary).duplicate(true)

	var path := "%s/%s/%s.json" % [CONTENT_ROOT, category, id]
	assert(FileAccess.file_exists(path), "Missing content definition: %s" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Unable to open content definition: %s" % path)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "Content definition must be a JSON object: %s" % path)

	var data := parsed as Dictionary
	assert(String(data.get("id", "")) == id, "Content id must match filename: %s" % path)
	_json_cache[cache_key] = data.duplicate(true)
	return data.duplicate(true)
