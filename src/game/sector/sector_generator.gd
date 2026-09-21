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
	var environment_rng := RandomNumberGenerator.new()
	environment_rng.seed = maxi(absi(int(sector["seed"]) * 31 + 99173), 1)

	var spawn_rules := biome.get("spawn_rules", {}) as Dictionary
	var min_spacing := float(spawn_rules.get("min_spacing", 120.0))
	var edge_margin := float(spawn_rules.get("edge_margin", 260.0))
	var starter_count := mini(int(spawn_rules.get("starter_cluster_count", 0)), salvage_count)
	var starter_radius := float(spawn_rules.get("starter_cluster_radius", 260.0))
	var depot_position := _vector2_from_array((sector["depot"] as Dictionary)["position"])
	var environment_fields := _build_environment_fields(
		biome,
		environment_rng,
		play_bounds,
		depot_position
	)
	var environment_profile := biome.get("environment", {}) as Dictionary
	parameters["mass_multiplier"] = float(parameters["mass_multiplier"]) * float(
		environment_profile.get("salvage_mass_multiplier", 1.0)
	)

	var occupied: Array[Dictionary] = [
		_occupied_zone(Vector2.ZERO, 90.0),
		_occupied_zone(depot_position, 260.0),
	]
	var landmarks := _build_landmarks(sector, rng, play_bounds, occupied)
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
	_apply_contract_spawn_requirements(sector, salvage_spawns)

	var obstacle_spawns := _build_obstacle_spawns(
		biome,
		rng,
		play_bounds,
		obstacle_count,
		min_spacing * 0.8,
		edge_margin,
		occupied,
		environment_fields
	)

	var signature := _build_signature(
		sector_id,
		int(sector["seed"]),
		sector["contract"] as Dictionary,
		environment_fields,
		salvage_spawns,
		obstacle_spawns,
		landmarks
	)
	return {
		"sector": sector,
		"biome": biome,
		"play_bounds": play_bounds,
		"depot_position": depot_position,
		"parameters": parameters,
		"environment_fields": environment_fields,
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

func _build_landmarks(
	sector: Dictionary,
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	occupied: Array[Dictionary]
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value in sector.get("landmarks", []):
		var id := String(value)
		var definition := _registry.get_landmark(id)
		var placement := definition.get("placement_radius", [1000.0, 1800.0]) as Array
		var reserved_radius := float(definition.get("reserved_radius", 0.0))
		var position := _find_landmark_position(rng, play_bounds, placement, reserved_radius, occupied)
		occupied.append(_occupied_zone(position, reserved_radius))
		var spin_range := definition.get("spin_speed_range", [0.0, 0.0]) as Array
		output.append({
			"id": id,
			"definition": definition,
			"position": position,
			"rotation": rng.randf_range(-PI, PI),
			"spin_speed": rng.randf_range(float(spin_range[0]), float(spin_range[1])),
			"motion_phase": rng.randf_range(0.0, TAU),
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
	occupied: Array[Dictionary],
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

		occupied.append(_occupied_zone(position))
		output.append({
			"salvage_id": salvage_id,
			"position": position,
			"spin_speed": rng.randf_range(-0.42, 0.42),
		})
	return output

func _apply_contract_spawn_requirements(sector: Dictionary, salvage_spawns: Array[Dictionary]) -> void:
	var contract_ref := sector["contract"] as Dictionary
	var contract := _registry.get_contract(String(contract_ref["type"]))
	if String(contract.get("kind", "")) != "priority_object":
		return

	var target_salvage_id := String(contract_ref.get("target_salvage_id", ""))
	var target_count := int(contract_ref.get("target_count", 1))
	assert(not target_salvage_id.is_empty(), "Priority contract requires target_salvage_id.")
	assert(target_count > 0, "Priority contract requires positive target_count.")
	assert(salvage_spawns.size() >= target_count, "Priority contract target count exceeds generated salvage count.")

	for offset in range(target_count):
		var index := salvage_spawns.size() - 1 - offset
		var entry := salvage_spawns[index] as Dictionary
		entry["salvage_id"] = target_salvage_id
		entry["priority_target"] = true
		salvage_spawns[index] = entry

func _build_obstacle_spawns(
	biome: Dictionary,
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	count: int,
	min_spacing: float,
	edge_margin: float,
	occupied: Array[Dictionary],
	environment_fields: Array[Dictionary]
) -> Array[Dictionary]:
	var obstacle_definitions := biome.get("obstacles", []) as Array
	var output: Array[Dictionary] = []
	if obstacle_definitions.is_empty():
		return output

	for _index in range(count):
		var definition: Dictionary = _weighted_pick(obstacle_definitions, "weight", rng) as Dictionary
		var position := _find_obstacle_position(
			rng,
			play_bounds,
			edge_margin,
			min_spacing,
			occupied,
			environment_fields
		)
		occupied.append(_occupied_zone(position))
		output.append({
			"definition": definition.duplicate(true),
			"position": position,
			"rotation": rng.randf_range(-PI, PI),
			"scale": rng.randf_range(float(definition.get("scale_min", 1.0)), float(definition.get("scale_max", 1.0))),
			"spin_speed": rng.randf_range(-0.24, 0.24),
			"motion_phase": rng.randf_range(0.0, TAU),
		})
	return output

func _build_environment_fields(
	biome: Dictionary,
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	depot_position: Vector2
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var environment := biome.get("environment", {}) as Dictionary
	for value in environment.get("volumes", []) as Array:
		var template := value as Dictionary
		var count_range := template["count_range"] as Array
		var count := rng.randi_range(int(count_range[0]), int(count_range[1]))
		for _index in range(count):
			var placement := String(template.get("placement", "random"))
			var position := depot_position if placement == "depot" else _random_environment_position(
				rng,
				play_bounds,
				620.0
			)
			var strength_range := template["strength_range"] as Array
			var entry := {
				"kind": String(template["kind"]),
				"shape": String(template["shape"]),
				"position": position,
				"rotation": rng.randf_range(-PI, PI),
				"strength": rng.randf_range(
					float(strength_range[0]),
					float(strength_range[1])
				),
				"color": String(template["color"]),
				"secondary_color": String(template["secondary_color"]),
			}
			if String(template["shape"]) == "circle":
				var radius_range := template["radius_range"] as Array
				entry["radius"] = rng.randf_range(
					float(radius_range[0]),
					float(radius_range[1])
				)
			else:
				var length_range := template["length_range"] as Array
				var width_range := template["width_range"] as Array
				entry["size"] = Vector2(
					rng.randf_range(float(length_range[0]), float(length_range[1])),
					rng.randf_range(float(width_range[0]), float(width_range[1]))
				)
			output.append(entry)
	return output

func _random_environment_position(
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	edge_margin: float
) -> Vector2:
	return Vector2(
		rng.randf_range(play_bounds.position.x + edge_margin, play_bounds.end.x - edge_margin),
		rng.randf_range(play_bounds.position.y + edge_margin, play_bounds.end.y - edge_margin)
	)

func _find_obstacle_position(
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	edge_margin: float,
	min_spacing: float,
	occupied: Array[Dictionary],
	environment_fields: Array[Dictionary]
) -> Vector2:
	var left := play_bounds.position.x + edge_margin
	var right := play_bounds.end.x - edge_margin
	var top := play_bounds.position.y + edge_margin
	var bottom := play_bounds.end.y - edge_margin

	for _attempt in range(48):
		var candidate := Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))
		if not _is_far_enough(candidate, occupied, min_spacing):
			continue
		if _inside_safe_corridor(candidate, environment_fields, 80.0):
			continue
		return candidate
	return _find_position(rng, play_bounds, edge_margin, min_spacing, occupied)

func _inside_safe_corridor(
	point: Vector2,
	environment_fields: Array[Dictionary],
	padding: float
) -> bool:
	for field in environment_fields:
		if String(field.get("kind", "")) != "safe_corridor":
			continue
		var local := (point - (field["position"] as Vector2)).rotated(
			-float(field.get("rotation", 0.0))
		)
		var size := field.get("size", Vector2.ZERO) as Vector2
		var half := size * 0.5 + Vector2.ONE * padding
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
			return true
	return false

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

func _find_landmark_position(
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	placement_radius: Array,
	reserved_radius: float,
	occupied: Array[Dictionary]
) -> Vector2:
	var minimum_radius := float(placement_radius[0])
	var maximum_radius := float(placement_radius[1])
	var edge_padding := reserved_radius + 80.0
	for _attempt in range(64):
		var radius := rng.randf_range(minimum_radius, maximum_radius)
		var candidate := Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius
		if not _point_inside_bounds(candidate, play_bounds, edge_padding):
			continue
		if _is_far_enough(candidate, occupied, 120.0, reserved_radius):
			return candidate
	return _find_position(rng, play_bounds, edge_padding, 120.0, occupied, reserved_radius)

func _point_inside_bounds(point: Vector2, bounds: Rect2, padding: float) -> bool:
	return (
		point.x >= bounds.position.x + padding
		and point.x <= bounds.end.x - padding
		and point.y >= bounds.position.y + padding
		and point.y <= bounds.end.y - padding
	)

func _occupied_zone(position: Vector2, radius: float = 0.0) -> Dictionary:
	return {"position": position, "radius": maxf(radius, 0.0)}

func _find_position(
	rng: RandomNumberGenerator,
	play_bounds: Rect2,
	edge_margin: float,
	min_spacing: float,
	occupied: Array[Dictionary],
	candidate_radius: float = 0.0
) -> Vector2:
	var left := play_bounds.position.x + edge_margin
	var right := play_bounds.end.x - edge_margin
	var top := play_bounds.position.y + edge_margin
	var bottom := play_bounds.end.y - edge_margin
	for _attempt in range(32):
		var candidate := Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))
		if _is_far_enough(candidate, occupied, min_spacing, candidate_radius):
			return candidate
	return Vector2(rng.randf_range(left, right), rng.randf_range(top, bottom))

func _is_far_enough(candidate: Vector2, occupied: Array[Dictionary], min_spacing: float, candidate_radius: float = 0.0) -> bool:
	for zone in occupied:
		var position := zone["position"] as Vector2
		var required_distance := min_spacing + maxf(candidate_radius, 0.0) + float(zone.get("radius", 0.0))
		if candidate.distance_squared_to(position) < required_distance * required_distance:
			return false
	return true

func _vector2_from_array(value: Array) -> Vector2:
	assert(value.size() == 2, "Vector content must contain exactly two values.")
	return Vector2(float(value[0]), float(value[1]))

func _build_signature(
	sector_id: String,
	seed: int,
	contract_ref: Dictionary,
	environment_fields: Array[Dictionary],
	salvage: Array[Dictionary],
	obstacles: Array[Dictionary],
	landmarks: Array[Dictionary]
) -> String:
	var parts := PackedStringArray([
		sector_id,
		str(seed),
		JSON.stringify(contract_ref),
		str(environment_fields.size()),
		str(salvage.size()),
		str(obstacles.size()),
		str(landmarks.size()),
	])
	for index in range(mini(environment_fields.size(), 4)):
		var field := environment_fields[index] as Dictionary
		var field_position := field["position"] as Vector2
		parts.append("%s@%.1f,%.1f" % [
			String(field["kind"]),
			field_position.x,
			field_position.y,
		])
	for index in range(mini(salvage.size(), 5)):
		var entry: Dictionary = salvage[index] as Dictionary
		var position := entry["position"] as Vector2
		parts.append("%s@%.1f,%.1f" % [String(entry["salvage_id"]), position.x, position.y])
	for index in range(mini(landmarks.size(), 4)):
		var landmark := landmarks[index] as Dictionary
		var landmark_position := landmark["position"] as Vector2
		parts.append("landmark:%s@%.1f,%.1f" % [String(landmark["id"]), landmark_position.x, landmark_position.y])
	return "|".join(parts)
