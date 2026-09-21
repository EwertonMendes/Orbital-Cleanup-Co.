extends RefCounted
class_name EndlessContractGenerator

const BIOME_IDS := [
	"earth_orbit",
	"lunar_belt",
	"mars_freight",
	"blue_nebula",
]
const CONTRACT_ROTATION := [
	"standard_cleanup",
	"recovery_run",
	"standard_cleanup",
	"valuable_recovery",
	"full_cleanup",
	"priority_recovery",
]
const DISPLAY_NAME_KEY := "SECTOR_ENDLESS_CONTRACT"

var _registry: ContentRegistry

func configure(registry: ContentRegistry) -> void:
	assert(registry != null, "EndlessContractGenerator requires ContentRegistry.")
	_registry = registry

func create_sector_definition(contract_number: int, seed_override: int = -1, biome_override: String = "") -> Dictionary:
	assert(_registry != null, "EndlessContractGenerator must be configured.")
	assert(contract_number >= 1, "Endless contract number must be >= 1.")

	var seed := seed_override if seed_override >= 0 else _seed_for_contract(contract_number)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var biome_id := biome_override
	if biome_id.is_empty():
		biome_id = String(BIOME_IDS[(contract_number - 1) % BIOME_IDS.size()])
	assert(BIOME_IDS.has(biome_id), "Unsupported endless biome override: %s" % biome_id)
	var biome := _registry.get_biome(biome_id)

	var table_ids := biome.get("salvage_tables", []) as Array
	assert(not table_ids.is_empty(), "Endless biome requires salvage tables.")
	var table_id := String(table_ids[rng.randi_range(0, table_ids.size() - 1)])

	var landmark_ids := _pick_unique(
		biome.get("landmarks", []) as Array,
		2 if contract_number >= 6 and rng.randf() > 0.42 else 1,
		rng
	)
	var modifier_ids := _pick_unique(
		biome.get("modifiers", []) as Array,
		2 if contract_number >= 10 and rng.randf() > 0.50 else 1,
		rng
	)

	var contract_id := String(CONTRACT_ROTATION[(contract_number - 1) % CONTRACT_ROTATION.size()])
	var contract_ref := _build_contract_ref(contract_id, table_id, contract_number, rng)

	var scale_step := mini(contract_number - 1, 40)
	var half_width := 4800.0 + float(scale_step) * 45.0
	var half_height := 3000.0 + float(scale_step) * 30.0
	var density := clampf(0.78 + float(scale_step) * 0.012 + rng.randf_range(-0.05, 0.06), 0.72, 1.32)
	var clusters := mini(4 + int((contract_number - 1) / 3), 10)
	var depot := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(620.0, 1180.0)

	return {
		"id": "endless_%06d" % contract_number,
		"display_name_key": DISPLAY_NAME_KEY,
		"biome": biome_id,
		"seed": seed,
		"difficulty": contract_number,
		"map": {
			"half_extents": [half_width, half_height],
			"debris_density": density,
			"cluster_count": clusters,
		},
		"salvage_tables": [
			{"id": table_id, "weight": 100.0},
		],
		"landmarks": landmark_ids,
		"contract": contract_ref,
		"modifiers": modifier_ids,
		"depot": {
			"position": [depot.x, depot.y],
		},
	}

func _build_contract_ref(
	contract_id: String,
	table_id: String,
	contract_number: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var contract := _registry.get_contract(contract_id)
	var kind := String(contract["kind"])
	var progress := clampf(float(contract_number - 1) / 28.0, 0.0, 1.0)
	var output := {"type": contract_id}

	match kind:
		"cleanup", "full_cleanup":
			var range := contract["target_percent_range"] as Array
			var target := int(round(lerpf(float(range[0]), float(range[1]), progress)))
			target = clampi(target + rng.randi_range(-2, 2), int(range[0]), int(range[1]))
			output["target_percent"] = target
		"recovery":
			var range := contract["target_count_range"] as Array
			var target := int(round(lerpf(float(range[0]), float(range[1]), progress)))
			output["target_count"] = clampi(target + rng.randi_range(-1, 1), int(range[0]), int(range[1]))
		"valuable_recovery":
			var range := contract["target_value_range"] as Array
			var target := int(round(lerpf(float(range[0]), float(range[1]), progress)))
			target += rng.randi_range(-40, 40)
			output["target_value"] = clampi(target, int(range[0]), int(range[1]))
		"priority_object":
			var range := contract["target_count_range"] as Array
			output["target_count"] = clampi(
				int(round(lerpf(float(range[0]), float(range[1]), progress))),
				int(range[0]),
				int(range[1])
			)
			output["target_salvage_id"] = _pick_priority_salvage(table_id, rng)
		_:
			assert(false, "Unsupported endless contract kind: %s" % kind)

	return output

func _pick_priority_salvage(table_id: String, rng: RandomNumberGenerator) -> String:
	var table := _registry.get_salvage_table(table_id)
	var preferred: Array[String] = []
	var fallback: Array[String] = []

	for value in table["entries"] as Array:
		var entry := value as Dictionary
		var salvage_id := String(entry["salvage"])
		fallback.append(salvage_id)
		var salvage := _registry.get_salvage_data(salvage_id)
		if String(salvage.get("rarity", "common")) in ["rare", "epic"]:
			preferred.append(salvage_id)

	var candidates := preferred if not preferred.is_empty() else fallback
	assert(not candidates.is_empty(), "Priority contract requires at least one salvage candidate.")
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _seed_for_contract(contract_number: int) -> int:
	var value := (contract_number * 7919 + 104729) % 2147483647
	return maxi(value, 1)

func _pick_unique(source: Array, requested: int, rng: RandomNumberGenerator) -> Array:
	var candidates := source.duplicate()
	var output: Array = []
	var count := mini(requested, candidates.size())
	for _index in range(count):
		var pick := rng.randi_range(0, candidates.size() - 1)
		output.append(candidates[pick])
		candidates.remove_at(pick)
	return output
