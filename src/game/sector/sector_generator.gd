extends RefCounted
class_name SectorGenerator

var _registry: ContentRegistry
var _scaler: DifficultyScaler

func configure(registry: ContentRegistry, scaler: DifficultyScaler) -> void:
	assert(registry != null, "SectorGenerator requires ContentRegistry.")
	assert(scaler != null, "SectorGenerator requires DifficultyScaler.")
	_registry = registry
	_scaler = scaler

func generate(sector_id: String) -> Dictionary:
	assert(_registry != null and _scaler != null, "SectorGenerator must be configured.")
	return generate_definition(_registry.get_sector(sector_id))

func generate_definition(source: Dictionary) -> Dictionary:
	assert(_registry != null and _scaler != null, "SectorGenerator must be configured.")
	assert(not source.is_empty(), "SectorGenerator requires a sector definition.")

	var sector := source.duplicate(true)
	var sector_id := String(sector.get("id", ""))
	assert(not sector_id.is_empty(), "Sector definition requires id.")
	assert(sector.has("biome"), "Sector definition requires biome.")
	assert(sector.has("seed"), "Sector definition requires seed.")
	assert(sector.has("difficulty"), "Sector definition requires difficulty.")
	assert(sector.has("map"), "Sector definition requires map.")
	assert(sector.has("salvage_tables"), "Sector definition requires salvage tables.")
	assert(sector.has("contract"), "Sector definition requires contract.")
	assert(sector.has("depot"), "Sector definition requires depot.")

	var biome := _registry.get_biome(String(sector["biome"]))
	var difficulty := int(sector["difficulty"])
	var parameters := _scaler.evaluate(difficulty)
	_apply_modifiers(parameters, sector.get("modifiers", []))

	var map_data := sector["map"] as Dictionary
	var density := float(map_data.get("debris_density", 1.0))
	var salvage_count := maxi(5, int(round(float(parameters["salvage_count"]) * density)))
	var obstacle_count := maxi(0, int(round(float(parameters["obstacle_count"]) * density)))

	var half_extents_data := map_data["half_extents"] as Array
	var half_extents := Vector2(float(half_extents_data[0]), float(half_extents_data[1]))
	var play_bounds := Rect2(-half_extents, half_extents * 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(sector["seed"])

	var spawn_rules := biome.get("spawn_rules", {}) as Dictionary
	var min_spacing := float(spawn_rules.get("min_spacing", 120.0))
	var edge_margin := float(spawn_rules.get("edge_margin", 260.0))
	var starter_count := mini(int(spawn_rules.get("starter_cluster_count", 0)), salvage_count)
	var starter_radius := float(spawn_rules.get("starter_cluster_radius", 260.0))
	var depot_position := _vector2_from_array((sector["depot"] as Dictionary)["position"])

	var occupied: Array[Vector2] = [Vector2.ZERO, depot_position]
	var landmarks := _build_landmarks(sector, rng, occupied)
	var salvage_spawns := _build_salvage_spawns(
		sector,
		biome,
		rng,
		play_bounds,
		salvage_count,
		starter_count,
		starter_radius,
		min_spacing,
		edge_margin,
		occupied,
		float(parameters["rare_weight_multiplier"])
	)
	var obstacle_spawns := _build_obstacle_spawns(
		biome,
		rng,
		play_bounds,
		obstacle_count,
		min_spacing * 0.8,
		edge_margin,
		occupied
	)

	var signature := _build_signature(sector_id, int(sector["seed"]), salvage_spawns, obstacle_spawns, landmarks)
	return {
		"sector": sector,
		"biome": biome,
		"play_bounds": play_bounds,
		"depot_position": depot_position,
		"parameters": parameters,
		"salvage_spawns": salvage_spawns,
		"obstacle_spawns": obstacle_spawns,
		"landmark_spawns": landmarks,
		"generation_signature": signature,
	}

func _apply_modifiers(parameters: Dictionary, modifier_ids: Array) -> void:
	for value in modifier_ids:
		var modifier := _registry.get_modifier(String(value))
		var runtime := modifier.get("runtime", {}) as Dictionary
		parameters["salvage_count"] = float(parameters["salvage_count"]) * float(runtime.get("salvage_count_multiplier", 1.0))
		parameters["obstacle_count"] = float(parameters["obstacle_count"]) * float(runtime.get("obstacle_count_multiplier", 1.0))
		parameters["rare_weight_multiplier"] = float(parameters["rare_weight_multiplier"]) * float(runtime.get("rare_weight_multiplier", 1.0))

func _build_landmarks(sector: Dictionary, rng: RandomNumberGenerator, occupied: Array[Vector2]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value in sector.get("landmarks", []):
		var id := String(value)
		var definition := _registry.get_landmark(id)
		var placement := definition.get("placement_radius", [1000.0, 1800.0]) as Array
		var radius := rng.randf_range(float(placement[0]), float(placement[1]))
		var angle := rng.randf_range(0.0, TAU)
		var position := Vector2.from_angle(angle) * radius
		occupied.append(position)
		output.append({
			"id": id,
			"definition": definition,
			"position": position,
			"rotation": rng.randf_range(-0.3, 0.3),
		})
	return output

func _build_salvage_spawns(
	sector: Dictionary,
	biome: Dictionary,
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	count: int,
	starter_count: int,
	starter_radius: float,
	min_spacing: float,
	edge_margin: float,
	occupied: Array[Vector2],
	rare_weight_multiplier: float
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index in range(count):
		var table_ref: Dictionary = _weighted_pick(sector["salvage_tables"] as Array, "weight", rng) as Dictionary
		var table_id := String(table_ref["id"])
		var table := _registry.get_salvage_table(table_id)
		var salvage_id := _pick_salvage_id(table["entries"] as Array, rng, rare_weight_multiplier)

		var position: Vector2
		if index < starter_count:
			var radius := rng.randf_range(155.0, maxf(starter_radius, 156.0))
			position = Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius
		else:
			position = _find_position(rng, play_bounds, edge_margin, min_spacing, occupied)

		occupied.append(position)
		output.append({
			"salvage_id": salvage_id,
			"position": position,
			"spin_speed": rng.randf_range(-0.42, 0.42),
		})
	return output

func _build_obstacle_spawns(
	biome: Dictionary,
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	count: int,
	min_spacing: float,
	edge_margin: float,
	occupied: Array[Vector2]
) -> Array[Dictionary]:
	var obstacle_definitions := biome.get("obstacles", []) as Array
	var output: Array[Dictionary] = []
	if obstacle_definitions.is_empty():
		return output

	for _index in range(count):
		var definition: Dictionary = _weighted_pick(obstacle_definitions, "weight", rng) as Dictionary
		var position := _find_position(rng, play_bounds, edge_margin, min_spacing, occupied)
		occupied.append(position)
		output.append({
			"definition": definition.duplicate(true),
			"position": position,
			"rotation": rng.randf_range(-PI, PI),
			"scale": rng.randf_range(float(definition.get("scale_min", 1.0)), float(definition.get("scale_max", 1.0))),
		})
	return output

func _pick_salvage_id(entries: Array, rng: RandomNumberGenerator, rare_weight_multiplier: float) -> String:
	var weighted: Array[Dictionary] = []
	for value in entries:
		var entry := (value as Dictionary).duplicate(true)
		var salvage := _registry.get_salvage_data(String(entry["salvage"]))
		var rarity := String(salvage.get("rarity", "common"))
		var rarity_multiplier := rare_weight_multiplier if rarity != "common" else 1.0
		entry["_effective_weight"] = float(entry["weight"]) * rarity_multiplier
		weighted.append(entry)

	var selected: Dictionary = _weighted_pick(weighted, "_effective_weight", rng) as Dictionary
	return String(selected["salvage"])

func _weighted_pick(entries: Array, weight_key: String, rng: RandomNumberGenerator):
	assert(not entries.is_empty(), "Weighted pick requires entries.")
	var total := 0.0
	for value in entries:
		total += float((value as Dictionary).get(weight_key, 0.0))
	assert(total > 0.0, "Weighted pick requires positive total weight.")

	var roll := rng.randf_range(0.0, total)
	var cursor := 0.0
	for value in entries:
		var entry := value as Dictionary
		cursor += float(entry.get(weight_key, 0.0))
		if roll <= cursor:
			return entry
	return entries.back()

func _find_position(
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	edge_margin: float,
	min_spacing: float,
	occupied: Array[Vector2]
) -> Vector2:
	var left := play_bounds.position.x + edge_margin
	var right := play_bounds.end.x - edge_margin
	var top := play_bounds.position.y + edge_margin
	var bottom := play_bounds.end.y - edge_margin

	for _attempt in range(32):
		var candidate := Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))
		if _is_far_enough(candidate, occupied, min_spacing):
			return candidate

	return Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))

func _is_far_enough(candidate: Vector2, occupied: Array[Vector2], min_spacing: float) -> bool:
	var minimum_sq := min_spacing * min_spacing
	for position in occupied:
		if candidate.distance_squared_to(position) < minimum_sq:
			return false
	return true

func _vector2_from_array(value: Array) -> Vector2:
	assert(value.size() == 2, "Vector content must contain exactly two values.")
	return Vector2(float(value[0]), float(value[1]))

func _build_signature(
	sector_id: String,
	seed: int,
	salvage: Array[Dictionary],
	obstacles: Array[Dictionary],
	landmarks: Array[Dictionary]
) -> String:
	var parts := PackedStringArray([sector_id, str(seed), str(salvage.size()), str(obstacles.size()), str(landmarks.size())])
	for index in range(mini(salvage.size(), 5)):
		var entry: Dictionary = salvage[index] as Dictionary
		var position := entry["position"] as Vector2
		parts.append("%s@%.1f,%.1f" % [String(entry["salvage_id"]), position.x, position.y])
	return "|".join(parts)
