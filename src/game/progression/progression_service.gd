extends Node
class_name ProgressionService

signal state_changed(snapshot: Dictionary)
signal upgrade_purchased(upgrade_id: String, level: int, cost: int)
signal rank_changed(rank_id: String)
signal cosmetic_equipped(category: String, cosmetic_id: String)
signal discovery_registered(salvage_id: String, rarity: String)

var _save_service: SaveService
var _registry := ContentRegistry.new()
var _state: Dictionary = {}
var _rank_config: Dictionary = {}
var _upgrade_config: Dictionary = {}
var _cosmetic_config: Dictionary = {}

func initialize(save_service: SaveService) -> void:
	assert(save_service != null, "ProgressionService requires SaveService.")
	_save_service = save_service
	_rank_config = _registry.get_progression("career_ranks")
	_upgrade_config = _registry.get_progression("upgrades")
	_cosmetic_config = _registry.get_cosmetic("ship_customization")

	var persisted := _save_service.read_state()
	_state = _normalize_state(persisted)
	_refresh_rank(false)
	_sanitize_cosmetics()
	_persist()
	print("[Progression] READY rank=%s credits=%d xp=%d" % [
		String(_state["rank"]),
		int(_state["credits"]),
		int(_state["company_xp"]),
	])

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func get_credits() -> int:
	return int(_state.get("credits", 0))

func get_company_xp() -> int:
	return int(_state.get("company_xp", 0))

func get_rank_id() -> String:
	return String(_state.get("rank", "trainee"))

func get_rank_display_name_key() -> String:
	var rank := _find_rank(get_rank_id())
	return String(rank.get("display_name_key", "RANK_TRAINEE"))

func get_rank_progress() -> Dictionary:
	return _rank_progress_for(get_company_xp(), get_rank_id())

func meets_rank_requirement(rank_id: String) -> bool:
	var required_index := _rank_index(rank_id)
	assert(required_index >= 0, "Unknown rank requirement: %s" % rank_id)
	return _rank_index(get_rank_id()) >= required_index

func get_rank_requirement(rank_id: String) -> Dictionary:
	var rank := _find_rank(rank_id)
	assert(not rank.is_empty(), "Unknown rank requirement: %s" % rank_id)
	var min_xp := int(rank["min_xp"])
	var current_xp := get_company_xp()
	return {
		"rank_id": rank_id,
		"display_name_key": String(rank["display_name_key"]),
		"min_xp": min_xp,
		"current_xp": current_xp,
		"xp_remaining": maxi(min_xp - current_xp, 0),
		"unlocked": meets_rank_requirement(rank_id),
	}

func get_sector_access(sector_id: String) -> Dictionary:
	var sector := _registry.get_sector(sector_id)
	var requirement := get_rank_requirement(String(sector["unlock_rank"]))
	requirement["type"] = "sector"
	requirement["sector_id"] = sector_id
	requirement["content_display_name_key"] = String(sector["display_name_key"])
	requirement["career_order"] = int(sector["career_order"])
	return requirement

func is_sector_unlocked(sector_id: String) -> bool:
	return bool(get_sector_access(sector_id)["unlocked"])

func get_endless_unlock_rank() -> String:
	return String(_rank_config.get("endless_unlock_rank", "deep_space_operator"))

func get_endless_access() -> Dictionary:
	var requirement := get_rank_requirement(get_endless_unlock_rank())
	requirement["type"] = "endless"
	requirement["content_display_name_key"] = "UNLOCK_ENDLESS_CONTRACTS"
	requirement["career_order"] = 100000
	return requirement

func is_endless_unlocked() -> bool:
	return bool(get_endless_access()["unlocked"])

func get_next_content_unlock() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for sector_id in _registry.list_sector_ids():
		var access := get_sector_access(sector_id)
		if not bool(access["unlocked"]):
			candidates.append(access)

	var endless_access := get_endless_access()
	if not bool(endless_access["unlocked"]):
		candidates.append(endless_access)

	if candidates.is_empty():
		return {}

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var xp_a := int(a["min_xp"])
		var xp_b := int(b["min_xp"])
		if xp_a == xp_b:
			return int(a["career_order"]) < int(b["career_order"])
		return xp_a < xp_b
	)
	return candidates[0].duplicate(true)

func get_upgrade_definitions() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value in _upgrade_config.get("upgrades", []) as Array:
		output.append((value as Dictionary).duplicate(true))
	return output

func get_upgrade_level(upgrade_id: String) -> int:
	var upgrades := _state.get("upgrades", {}) as Dictionary
	return int(upgrades.get(upgrade_id, 0))

func get_upgrade_cost(upgrade_id: String) -> int:
	var definition := _find_upgrade(upgrade_id)
	assert(not definition.is_empty(), "Unknown upgrade: %s" % upgrade_id)
	var level := get_upgrade_level(upgrade_id)
	var max_level := int(definition["max_level"])
	if level >= max_level:
		return 0
	var base_cost := float(definition["base_cost"])
	var multiplier := float(definition["cost_multiplier"])
	return int(round(base_cost * pow(multiplier, level)))

func can_purchase_upgrade(upgrade_id: String) -> bool:
	var definition := _find_upgrade(upgrade_id)
	if definition.is_empty():
		return false
	var level := get_upgrade_level(upgrade_id)
	if level >= int(definition["max_level"]):
		return false
	return get_credits() >= get_upgrade_cost(upgrade_id)

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false

	var cost := get_upgrade_cost(upgrade_id)
	var upgrades := _state["upgrades"] as Dictionary
	var next_level := get_upgrade_level(upgrade_id) + 1
	_state["credits"] = get_credits() - cost
	upgrades[upgrade_id] = next_level
	_state["upgrades"] = upgrades
	_persist()
	upgrade_purchased.emit(upgrade_id, next_level, cost)
	state_changed.emit(get_snapshot())
	print("[Progression] UPGRADE id=%s level=%d cost=%d" % [upgrade_id, next_level, cost])
	return true

func get_ship_modifiers() -> Dictionary:
	var result := (_upgrade_config.get("base_ship", {}) as Dictionary).duplicate(true)
	for value in _upgrade_config.get("upgrades", []) as Array:
		var definition := value as Dictionary
		var upgrade_id := String(definition["id"])
		var level := get_upgrade_level(upgrade_id)
		if level <= 0:
			continue
		var effects := definition.get("effects", {}) as Dictionary
		for effect_key_variant in effects.keys():
			var effect_key := String(effect_key_variant)
			if not effect_key.ends_with("_add"):
				continue
			var target_key := effect_key.trim_suffix("_add")
			result[target_key] = float(result.get(target_key, 0.0)) + float(effects[effect_key]) * float(level)
	return result

func get_cosmetic_options(category: String) -> Array[Dictionary]:
	var categories := _cosmetic_config.get("categories", {}) as Dictionary
	assert(categories.has(category), "Unknown cosmetic category: %s" % category)
	var output: Array[Dictionary] = []
	for value in categories[category] as Array:
		output.append((value as Dictionary).duplicate(true))
	return output

func get_equipped_cosmetic_ids() -> Dictionary:
	return (_state.get("cosmetics", {}) as Dictionary).duplicate(true)

func get_equipped_cosmetic_id(category: String) -> String:
	var defaults := _cosmetic_config.get("default_loadout", {}) as Dictionary
	var equipped := _state.get("cosmetics", {}) as Dictionary
	return String(equipped.get(category, defaults.get(category, "")))

func get_cosmetic_definition(category: String, cosmetic_id: String) -> Dictionary:
	return _find_cosmetic_option(category, cosmetic_id).duplicate(true)

func get_ship_cosmetics() -> Dictionary:
	var output: Dictionary = {}
	for category in ["hull", "paint", "trail", "beam"]:
		var cosmetic_id := get_equipped_cosmetic_id(category)
		var definition := _find_cosmetic_option(category, cosmetic_id)
		assert(not definition.is_empty(), "Equipped cosmetic must exist: %s/%s" % [category, cosmetic_id])
		output[category] = definition.duplicate(true)
	return output

func is_cosmetic_unlocked(category: String, cosmetic_id: String) -> bool:
	var definition := _find_cosmetic_option(category, cosmetic_id)
	if definition.is_empty():
		return false
	var unlock_rank := String(definition.get("unlock_rank", ""))
	return _rank_index(get_rank_id()) >= _rank_index(unlock_rank)

func equip_cosmetic(category: String, cosmetic_id: String) -> bool:
	if not is_cosmetic_unlocked(category, cosmetic_id):
		return false

	var cosmetics := _state.get("cosmetics", {}) as Dictionary
	if String(cosmetics.get(category, "")) == cosmetic_id:
		return true

	cosmetics[category] = cosmetic_id
	_state["cosmetics"] = cosmetics
	_persist()
	cosmetic_equipped.emit(category, cosmetic_id)
	state_changed.emit(get_snapshot())
	print("[Customization] EQUIP category=%s id=%s" % [category, cosmetic_id])
	return true

func apply_contract_result(result: Dictionary) -> Dictionary:
	assert(bool(result.get("completed", false)), "Only completed contracts can grant progression.")
	var credits_awarded := int(result.get("credits_awarded", 0))
	var xp_awarded := int(result.get("xp_awarded", 0))
	assert(credits_awarded >= 0 and xp_awarded >= 0, "Contract rewards cannot be negative.")

	var credits_before := get_credits()
	var xp_before := get_company_xp()
	var rank_before := get_rank_id()
	var rank_before_key := get_rank_display_name_key()
	var progress_before := _rank_progress_for(xp_before, rank_before)

	_state["credits"] = credits_before + credits_awarded
	_state["company_xp"] = xp_before + xp_awarded

	var completed := _state.get("completed_contracts", {}) as Dictionary
	var sector_id := String(result.get("sector_id", "unknown"))
	completed[sector_id] = int(completed.get(sector_id, 0)) + 1
	_state["completed_contracts"] = completed
	_state["last_contract_result"] = result.duplicate(true)

	_refresh_rank(true)

	var rank_after := get_rank_id()
	var transition := {
		"credits_before": credits_before,
		"credits_after": get_credits(),
		"xp_before": xp_before,
		"xp_after": get_company_xp(),
		"rank_before_id": rank_before,
		"rank_after_id": rank_after,
		"rank_before_key": rank_before_key,
		"rank_after_key": get_rank_display_name_key(),
		"rank_progress_before": progress_before,
		"rank_progress_after": get_rank_progress(),
		"promoted": rank_before != rank_after,
		"unlocks": _collect_unlocks_between_ranks(rank_before, rank_after),
	}

	_persist()
	state_changed.emit(get_snapshot())
	print("[Economy] PAYOUT sector=%s credits=%d xp=%d total_credits=%d promoted=%s" % [
		sector_id,
		credits_awarded,
		xp_awarded,
		get_credits(),
		str(bool(transition["promoted"])),
	])
	return transition

func register_discovery(definition: SalvageDefinition) -> bool:
	if definition == null:
		return false
	var rarity := String(definition.rarity)
	if rarity not in ["rare", "epic"] and not definition.tags.has("discovery"):
		return false

	var salvage_id := String(definition.id)
	var discoveries := _state.get("discoveries", []) as Array
	if discoveries.has(salvage_id):
		return false

	discoveries.append(salvage_id)
	discoveries.sort()
	_state["discoveries"] = discoveries
	_persist()
	discovery_registered.emit(salvage_id, rarity)
	state_changed.emit(get_snapshot())
	print("[Discovery] NEW id=%s rarity=%s total=%d" % [salvage_id, rarity, discoveries.size()])
	return true

func get_discovery_ids() -> PackedStringArray:
	var output := PackedStringArray()
	for value in _state.get("discoveries", []) as Array:
		output.append(String(value))
	return output

func get_discovery_count() -> int:
	return (_state.get("discoveries", []) as Array).size()

func get_last_contract_result() -> Dictionary:
	return (_state.get("last_contract_result", {}) as Dictionary).duplicate(true)

func _normalize_state(persisted: Dictionary) -> Dictionary:
	var defaults := _default_state()
	if persisted.is_empty():
		return defaults

	defaults["credits"] = maxi(int(persisted.get("credits", defaults["credits"])), 0)
	defaults["company_xp"] = maxi(int(persisted.get("company_xp", defaults["company_xp"])), 0)
	defaults["rank"] = String(persisted.get("rank", defaults["rank"]))

	var saved_upgrades := persisted.get("upgrades", {}) as Dictionary
	var upgrades := defaults["upgrades"] as Dictionary
	for definition in _upgrade_config.get("upgrades", []) as Array:
		var upgrade := definition as Dictionary
		var id := String(upgrade["id"])
		upgrades[id] = clampi(int(saved_upgrades.get(id, 0)), 0, int(upgrade["max_level"]))
	defaults["upgrades"] = upgrades

	var saved_cosmetics = persisted.get("cosmetics", {})
	if saved_cosmetics is Dictionary:
		var cosmetics := defaults["cosmetics"] as Dictionary
		for category_variant in cosmetics.keys():
			var category := String(category_variant)
			var candidate := String((saved_cosmetics as Dictionary).get(category, cosmetics[category]))
			if not _find_cosmetic_option(category, candidate).is_empty():
				cosmetics[category] = candidate
		defaults["cosmetics"] = cosmetics

	var saved_discoveries = persisted.get("discoveries", [])
	if saved_discoveries is Array:
		var discoveries: Array[String] = []
		for value in saved_discoveries as Array:
			var salvage_id := String(value)
			if not salvage_id.is_empty() and _registry.has_salvage(salvage_id) and not discoveries.has(salvage_id):
				discoveries.append(salvage_id)
		discoveries.sort()
		defaults["discoveries"] = discoveries

	if persisted.get("completed_contracts", {}) is Dictionary:
		defaults["completed_contracts"] = (persisted["completed_contracts"] as Dictionary).duplicate(true)
	if persisted.get("last_contract_result", {}) is Dictionary:
		defaults["last_contract_result"] = (persisted["last_contract_result"] as Dictionary).duplicate(true)
	return defaults

func _default_state() -> Dictionary:
	var upgrades: Dictionary = {}
	for value in _upgrade_config.get("upgrades", []) as Array:
		var definition := value as Dictionary
		upgrades[String(definition["id"])] = 0
	return {
		"credits": 0,
		"company_xp": 0,
		"rank": "trainee",
		"upgrades": upgrades,
		"discoveries": [],
		"completed_contracts": {},
		"cosmetics": (_cosmetic_config.get("default_loadout", {}) as Dictionary).duplicate(true),
		"last_contract_result": {},
	}

func _refresh_rank(emit_change: bool) -> void:
	var ranks := _rank_config.get("ranks", []) as Array
	assert(not ranks.is_empty(), "Career ranks configuration is required.")
	var next_rank := ranks[0] as Dictionary
	for value in ranks:
		var candidate := value as Dictionary
		if get_company_xp() >= int(candidate["min_xp"]):
			next_rank = candidate
		else:
			break

	var next_id := String(next_rank["id"])
	var previous := String(_state.get("rank", ""))
	_state["rank"] = next_id
	if emit_change and previous != next_id:
		rank_changed.emit(next_id)

func _rank_progress_for(xp: int, rank_id: String) -> Dictionary:
	var ranks := _rank_config.get("ranks", []) as Array
	assert(not ranks.is_empty(), "Career ranks configuration is required.")
	var current_index := _rank_index(rank_id)
	if current_index < 0:
		current_index = 0

	var current := ranks[current_index] as Dictionary
	if current_index >= ranks.size() - 1:
		return {
			"current_xp": xp,
			"current_min_xp": int(current["min_xp"]),
			"next_min_xp": xp,
			"is_max_rank": true,
		}

	var next_rank := ranks[current_index + 1] as Dictionary
	return {
		"current_xp": xp,
		"current_min_xp": int(current["min_xp"]),
		"next_min_xp": int(next_rank["min_xp"]),
		"is_max_rank": false,
	}

func _collect_unlocks_between_ranks(previous_rank: String, next_rank: String) -> Array[Dictionary]:
	var previous_index := _rank_index(previous_rank)
	var next_index := _rank_index(next_rank)
	var output: Array[Dictionary] = []
	if next_index <= previous_index:
		return output

	for sector_id in _registry.list_sector_ids():
		var sector := _registry.get_sector(sector_id)
		var unlock_rank := String(sector["unlock_rank"])
		var unlock_index := _rank_index(unlock_rank)
		if unlock_index > previous_index and unlock_index <= next_index:
			output.append({
				"type": "sector",
				"id": sector_id,
				"display_name_key": String(sector["display_name_key"]),
				"unlock_rank": unlock_rank,
			})

	var endless_rank := get_endless_unlock_rank()
	var endless_index := _rank_index(endless_rank)
	if endless_index > previous_index and endless_index <= next_index:
		output.append({
			"type": "feature",
			"id": "endless_contracts",
			"display_name_key": "UNLOCK_ENDLESS_CONTRACTS",
			"unlock_rank": endless_rank,
		})

	var categories := _cosmetic_config.get("categories", {}) as Dictionary
	for category_variant in categories.keys():
		var category := String(category_variant)
		for value in categories[category] as Array:
			var option := value as Dictionary
			var unlock_rank := String(option.get("unlock_rank", ""))
			var unlock_index := _rank_index(unlock_rank)
			if unlock_index > previous_index and unlock_index <= next_index:
				output.append({
					"type": "cosmetic",
					"category": category,
					"id": String(option.get("id", "")),
					"display_name_key": String(option.get("display_name_key", "")),
					"unlock_rank": unlock_rank,
				})

	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["display_name_key"]) < String(b["display_name_key"])
	)
	return output

func _find_rank(rank_id: String) -> Dictionary:
	for value in _rank_config.get("ranks", []) as Array:
		var rank := value as Dictionary
		if String(rank["id"]) == rank_id:
			return rank
	return {}

func _find_upgrade(upgrade_id: String) -> Dictionary:
	for value in _upgrade_config.get("upgrades", []) as Array:
		var upgrade := value as Dictionary
		if String(upgrade["id"]) == upgrade_id:
			return upgrade
	return {}

func _find_cosmetic_option(category: String, cosmetic_id: String) -> Dictionary:
	var categories := _cosmetic_config.get("categories", {}) as Dictionary
	if not categories.has(category):
		return {}
	for value in categories[category] as Array:
		var option := value as Dictionary
		if String(option.get("id", "")) == cosmetic_id:
			return option
	return {}

func _rank_index(rank_id: String) -> int:
	var ranks := _rank_config.get("ranks", []) as Array
	for index in range(ranks.size()):
		var rank := ranks[index] as Dictionary
		if String(rank["id"]) == rank_id:
			return index
	return -1

func _sanitize_cosmetics() -> void:
	var cosmetics := _state.get("cosmetics", {}) as Dictionary
	var defaults := _cosmetic_config.get("default_loadout", {}) as Dictionary
	for category_variant in defaults.keys():
		var category := String(category_variant)
		var cosmetic_id := String(cosmetics.get(category, defaults[category]))
		if _find_cosmetic_option(category, cosmetic_id).is_empty() or not is_cosmetic_unlocked(category, cosmetic_id):
			cosmetics[category] = String(defaults[category])
	_state["cosmetics"] = cosmetics

func _persist() -> void:
	assert(_save_service != null, "ProgressionService is not initialized.")
	var error := _save_service.write_state(_state)
	assert(error == OK, "Progression save failed: %s" % error)
