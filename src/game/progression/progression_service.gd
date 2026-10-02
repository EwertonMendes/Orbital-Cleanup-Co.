extends Node
class_name ProgressionService

signal state_changed(snapshot: Dictionary)
signal upgrade_purchased(upgrade_id: String, level: int, cost: int)
signal rank_changed(rank_id: String)
signal cosmetic_equipped(category: String, cosmetic_id: String)
signal cosmetic_purchased(category: String, cosmetic_id: String, cost: int)
signal discovery_registered(salvage_id: String, rarity: String)
signal ship_purchased(ship_id: String, cost: int)
signal active_ship_changed(ship_id: String)
signal module_purchased(module_id: String, cost: int)
signal module_equipped(slot: String, module_id: String)
signal ship_mastery_changed(ship_id: String, mastery_xp: int)

var _save_service: SaveService
var _registry := ContentRegistry.new()
var _state: Dictionary = {}
var _rank_config: Dictionary = {}
var _legacy_upgrade_config: Dictionary = {}
var _fleet_rules: Dictionary = {}
var _cosmetic_config: Dictionary = {}

func initialize(save_service: SaveService) -> void:
	assert(save_service != null, "ProgressionService requires SaveService.")
	_save_service = save_service
	_rank_config = _registry.get_progression("career_ranks")
	_legacy_upgrade_config = _registry.get_progression("upgrades")
	_fleet_rules = _registry.get_progression("fleet_rules")
	_cosmetic_config = _registry.get_cosmetic("ship_customization")

	var persisted := _save_service.read_state()
	_state = _normalize_state(persisted, _save_service.get_last_read_schema_version())
	_refresh_rank(false)
	_sanitize_fleet()
	_persist()
	print("[Progression] READY rank=%s credits=%d xp=%d ship=%s schema=%d" % [
		String(_state["rank"]),
		int(_state["credits"]),
		int(_state["company_xp"]),
		get_active_ship_id(),
		SaveService.SCHEMA_VERSION,
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

func get_ship_definitions() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for ship_id in _registry.list_ship_ids():
		output.append(_registry.get_ship(ship_id))
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a := _rank_index(String((a["unlock"] as Dictionary)["rank"]))
		var rank_b := _rank_index(String((b["unlock"] as Dictionary)["rank"]))
		if rank_a == rank_b:
			var price_a := int((a["unlock"] as Dictionary)["price"])
			var price_b := int((b["unlock"] as Dictionary)["price"])
			if price_a == price_b:
				return String(a["id"]) < String(b["id"])
			return price_a < price_b
		return rank_a < rank_b
	)
	return output

func get_active_ship_id() -> String:
	var fleet := _state.get("fleet", {}) as Dictionary
	return String(fleet.get("active_ship_id", String(_fleet_rules.get("default_ship_id", "pioneer_01"))))

func get_active_ship_definition() -> Dictionary:
	var ship_id := get_active_ship_id()
	assert(_registry.has_ship(ship_id), "Active ship definition is missing: %s" % ship_id)
	return _registry.get_ship(ship_id)

func is_ship_owned(ship_id: String) -> bool:
	var fleet := _state.get("fleet", {}) as Dictionary
	var ships := fleet.get("ships", {}) as Dictionary
	return ships.has(ship_id)

func get_ship_access(ship_id: String) -> Dictionary:
	if not _registry.has_ship(ship_id):
		return {}
	var definition := _registry.get_ship(ship_id)
	var unlock := definition.get("unlock", {}) as Dictionary
	var requirement := get_rank_requirement(String(unlock.get("rank", "trainee")))
	requirement["type"] = "ship"
	requirement["ship_id"] = ship_id
	requirement["content_display_name_key"] = String(definition["display_name_key"])
	requirement["price"] = maxi(int(unlock.get("price", 0)), 0)
	requirement["owned"] = is_ship_owned(ship_id)
	requirement["affordable"] = get_credits() >= int(requirement["price"])
	return requirement

func can_purchase_ship(ship_id: String) -> bool:
	var access := get_ship_access(ship_id)
	if access.is_empty() or bool(access["owned"]) or not bool(access["unlocked"]):
		return false
	return bool(access["affordable"])

func purchase_ship(ship_id: String) -> bool:
	if not can_purchase_ship(ship_id):
		return false
	var access := get_ship_access(ship_id)
	var cost := int(access["price"])
	var fleet := (_state["fleet"] as Dictionary).duplicate(true)
	var ships := fleet.get("ships", {}) as Dictionary
	ships[ship_id] = _default_ship_state(ship_id)
	fleet["ships"] = ships
	_state["fleet"] = fleet
	_state["credits"] = get_credits() - cost
	_ensure_default_assets_owned(ship_id)
	_persist()
	ship_purchased.emit(ship_id, cost)
	state_changed.emit(get_snapshot())
	print("[Fleet] PURCHASE ship=%s cost=%d" % [ship_id, cost])
	return true

func select_ship(ship_id: String) -> bool:
	if not is_ship_owned(ship_id):
		return false
	if get_active_ship_id() == ship_id:
		return true
	var fleet := (_state["fleet"] as Dictionary).duplicate(true)
	fleet["active_ship_id"] = ship_id
	_state["fleet"] = fleet
	_persist()
	active_ship_changed.emit(ship_id)
	state_changed.emit(get_snapshot())
	print("[Fleet] ACTIVE ship=%s" % ship_id)
	return true

func get_active_ship_mastery() -> Dictionary:
	var ship_state := _get_ship_state(get_active_ship_id())
	var xp := maxi(int(ship_state.get("mastery_xp", 0)), 0)
	var thresholds := (_fleet_rules.get("mastery", {}) as Dictionary).get("levels", []) as Array
	assert(not thresholds.is_empty(), "Fleet mastery thresholds are required.")
	var level := 1
	for index in range(thresholds.size()):
		if xp >= int(thresholds[index]):
			level = index + 1
		else:
			break
	var current_min := int(thresholds[level - 1])
	var is_max := level >= thresholds.size()
	var next_min := xp if is_max else int(thresholds[level])
	return {
		"ship_id": get_active_ship_id(),
		"xp": xp,
		"level": level,
		"max_level": thresholds.size(),
		"current_min_xp": current_min,
		"next_min_xp": next_min,
		"is_max_level": is_max,
	}

func get_upgrade_definitions() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value in _fleet_rules.get("upgrade_tracks", []) as Array:
		output.append((value as Dictionary).duplicate(true))
	return output

func get_upgrade_level(upgrade_id: String) -> int:
	var ship_state := _get_ship_state(get_active_ship_id())
	var upgrades := ship_state.get("upgrades", {}) as Dictionary
	return int(upgrades.get(upgrade_id, 0))

func get_upgrade_cost(upgrade_id: String) -> int:
	var definition := _find_upgrade(upgrade_id)
	assert(not definition.is_empty(), "Unknown fleet upgrade: %s" % upgrade_id)
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
	var ship_id := get_active_ship_id()
	var ship_state := _get_ship_state(ship_id).duplicate(true)
	var upgrades := ship_state.get("upgrades", {}) as Dictionary
	var next_level := get_upgrade_level(upgrade_id) + 1
	upgrades[upgrade_id] = next_level
	ship_state["upgrades"] = upgrades
	_store_ship_state(ship_id, ship_state)
	_state["credits"] = get_credits() - cost
	_persist()
	upgrade_purchased.emit(upgrade_id, next_level, cost)
	state_changed.emit(get_snapshot())
	print("[Fleet] UPGRADE ship=%s id=%s level=%d cost=%d" % [ship_id, upgrade_id, next_level, cost])
	return true

func get_module_definitions(slot: String = "") -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value in _fleet_rules.get("modules", []) as Array:
		var definition := value as Dictionary
		if not slot.is_empty() and String(definition.get("slot", "")) != slot:
			continue
		output.append(definition.duplicate(true))
	return output

func is_module_unlocked(module_id: String) -> bool:
	var definition := _find_module(module_id)
	if definition.is_empty():
		return false
	return meets_rank_requirement(String(definition.get("unlock_rank", "trainee")))

func is_module_owned(module_id: String) -> bool:
	var fleet := _state.get("fleet", {}) as Dictionary
	return (fleet.get("owned_modules", []) as Array).has(module_id)

func get_module_cost(module_id: String) -> int:
	var definition := _find_module(module_id)
	assert(not definition.is_empty(), "Unknown module: %s" % module_id)
	return maxi(int(definition.get("price", 0)), 0)

func can_purchase_module(module_id: String) -> bool:
	return (
		is_module_unlocked(module_id)
		and not is_module_owned(module_id)
		and get_credits() >= get_module_cost(module_id)
	)

func purchase_module(module_id: String) -> bool:
	if not can_purchase_module(module_id):
		return false
	var cost := get_module_cost(module_id)
	var fleet := (_state["fleet"] as Dictionary).duplicate(true)
	var owned := fleet.get("owned_modules", []) as Array
	owned.append(module_id)
	owned.sort()
	fleet["owned_modules"] = owned
	_state["fleet"] = fleet
	_state["credits"] = get_credits() - cost
	_persist()
	module_purchased.emit(module_id, cost)
	state_changed.emit(get_snapshot())
	print("[Fleet] MODULE_PURCHASE id=%s cost=%d" % [module_id, cost])
	return true

func equip_module(slot: String, module_id: String, slot_index: int = 0) -> bool:
	var definition := _find_module(module_id)
	if definition.is_empty() or String(definition.get("slot", "")) != slot:
		return false
	if not is_module_owned(module_id):
		return false
	var ship_id := get_active_ship_id()
	var ship_definition := _registry.get_ship(ship_id)
	var slots := ship_definition.get("module_slots", {}) as Dictionary
	var capacity := int(slots.get(slot, 0))
	if capacity <= 0 or slot_index < 0 or slot_index >= capacity:
		return false
	var ship_state := _get_ship_state(ship_id).duplicate(true)
	var modules := ship_state.get("modules", {}) as Dictionary
	var equipped := (modules.get(slot, []) as Array).duplicate()
	while equipped.size() < capacity:
		equipped.append("")
	equipped[slot_index] = module_id
	modules[slot] = equipped
	ship_state["modules"] = modules
	_store_ship_state(ship_id, ship_state)
	_persist()
	module_equipped.emit(slot, module_id)
	state_changed.emit(get_snapshot())
	return true

func get_equipped_modules() -> Dictionary:
	return (_get_ship_state(get_active_ship_id()).get("modules", {}) as Dictionary).duplicate(true)

func get_active_ship_build() -> Dictionary:
	var ship_id := get_active_ship_id()
	var definition := _registry.get_ship(ship_id)
	var ship_state := _get_ship_state(ship_id)
	return ShipBuildResolver.resolve(definition, ship_state, _fleet_rules, get_ship_cosmetics())

func get_ship_modifiers() -> Dictionary:
	return (get_active_ship_build().get("stats", {}) as Dictionary).duplicate(true)

func get_cosmetic_options(category: String) -> Array[Dictionary]:
	if category == "hull":
		var ships: Array[Dictionary] = []
		for definition in get_ship_definitions():
			var unlock := definition.get("unlock", {}) as Dictionary
			var visual := definition.get("visual", {}) as Dictionary
			ships.append({
				"id": String(definition["id"]),
				"display_name_key": String(definition["display_name_key"]),
				"unlock_rank": String(unlock.get("rank", "trainee")),
				"price": int(unlock.get("price", 0)),
				"texture": String(visual.get("base_texture", "")),
			})
		return ships

	var categories := _cosmetic_config.get("categories", {}) as Dictionary
	assert(categories.has(category), "Unknown cosmetic category: %s" % category)
	var output: Array[Dictionary] = []
	for value in categories[category] as Array:
		output.append((value as Dictionary).duplicate(true))
	return output

func get_equipped_cosmetic_ids() -> Dictionary:
	var ship_state := _get_ship_state(get_active_ship_id())
	var equipped := (ship_state.get("cosmetics", {}) as Dictionary).duplicate(true)
	equipped["hull"] = get_active_ship_id()
	return equipped

func get_equipped_cosmetic_id(category: String) -> String:
	if category == "hull":
		return get_active_ship_id()
	var defaults := _cosmetic_config.get("default_loadout", {}) as Dictionary
	var ship_state := _get_ship_state(get_active_ship_id())
	var equipped := ship_state.get("cosmetics", {}) as Dictionary
	return String(equipped.get(category, defaults.get(category, "")))

func get_cosmetic_definition(category: String, cosmetic_id: String) -> Dictionary:
	if category == "hull":
		if not _registry.has_ship(cosmetic_id):
			return {}
		var definition := _registry.get_ship(cosmetic_id)
		var unlock := definition.get("unlock", {}) as Dictionary
		var visual := definition.get("visual", {}) as Dictionary
		return {
			"id": cosmetic_id,
			"display_name_key": String(definition["display_name_key"]),
			"unlock_rank": String(unlock.get("rank", "trainee")),
			"price": int(unlock.get("price", 0)),
			"texture": String(visual.get("base_texture", "")),
		}
	return _find_cosmetic_option(category, cosmetic_id).duplicate(true)

func get_ship_cosmetics() -> Dictionary:
	var output: Dictionary = {}
	output["hull"] = get_cosmetic_definition("hull", get_active_ship_id())
	var categories := _cosmetic_config.get("categories", {}) as Dictionary
	for category_variant in categories.keys():
		var category := String(category_variant)
		var cosmetic_id := get_equipped_cosmetic_id(category)
		var definition := _find_cosmetic_option(category, cosmetic_id)
		assert(not definition.is_empty(), "Equipped cosmetic must exist: %s/%s" % [category, cosmetic_id])
		output[category] = definition.duplicate(true)
	return output

func is_cosmetic_unlocked(category: String, cosmetic_id: String) -> bool:
	if category == "hull":
		var access := get_ship_access(cosmetic_id)
		return not access.is_empty() and bool(access["unlocked"])
	var definition := _find_cosmetic_option(category, cosmetic_id)
	if definition.is_empty():
		return false
	return meets_rank_requirement(String(definition.get("unlock_rank", "trainee")))

func is_cosmetic_owned(category: String, cosmetic_id: String) -> bool:
	if category == "hull":
		return is_ship_owned(cosmetic_id)
	var fleet := _state.get("fleet", {}) as Dictionary
	var owned_by_category := fleet.get("owned_cosmetics", {}) as Dictionary
	var owned := owned_by_category.get(category, []) as Array
	return owned.has(cosmetic_id)

func get_cosmetic_cost(category: String, cosmetic_id: String) -> int:
	if category == "hull":
		var access := get_ship_access(cosmetic_id)
		return int(access.get("price", 0))
	var definition := _find_cosmetic_option(category, cosmetic_id)
	assert(not definition.is_empty(), "Unknown cosmetic: %s/%s" % [category, cosmetic_id])
	return maxi(int(definition.get("price", 0)), 0)

func can_purchase_cosmetic(category: String, cosmetic_id: String) -> bool:
	if category == "hull":
		return can_purchase_ship(cosmetic_id)
	return (
		is_cosmetic_unlocked(category, cosmetic_id)
		and not is_cosmetic_owned(category, cosmetic_id)
		and get_credits() >= get_cosmetic_cost(category, cosmetic_id)
	)

func purchase_cosmetic(category: String, cosmetic_id: String) -> bool:
	if category == "hull":
		return purchase_ship(cosmetic_id)
	if not can_purchase_cosmetic(category, cosmetic_id):
		return false
	var cost := get_cosmetic_cost(category, cosmetic_id)
	var fleet := (_state["fleet"] as Dictionary).duplicate(true)
	var owned_by_category := fleet.get("owned_cosmetics", {}) as Dictionary
	var owned := owned_by_category.get(category, []) as Array
	owned.append(cosmetic_id)
	owned.sort()
	owned_by_category[category] = owned
	fleet["owned_cosmetics"] = owned_by_category
	_state["fleet"] = fleet
	_state["credits"] = get_credits() - cost
	_persist()
	cosmetic_purchased.emit(category, cosmetic_id, cost)
	state_changed.emit(get_snapshot())
	print("[Customization] PURCHASE category=%s id=%s cost=%d" % [category, cosmetic_id, cost])
	return true

func equip_cosmetic(category: String, cosmetic_id: String) -> bool:
	if category == "hull":
		return select_ship(cosmetic_id)
	if not is_cosmetic_unlocked(category, cosmetic_id) or not is_cosmetic_owned(category, cosmetic_id):
		return false

	var ship_id := get_active_ship_id()
	var ship_state := _get_ship_state(ship_id).duplicate(true)
	var cosmetics := ship_state.get("cosmetics", {}) as Dictionary
	if String(cosmetics.get(category, "")) == cosmetic_id:
		return true

	cosmetics[category] = cosmetic_id
	ship_state["cosmetics"] = cosmetics
	_store_ship_state(ship_id, ship_state)
	_persist()
	cosmetic_equipped.emit(category, cosmetic_id)
	state_changed.emit(get_snapshot())
	print("[Customization] EQUIP ship=%s category=%s id=%s" % [ship_id, category, cosmetic_id])
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
	var mastery_before := get_active_ship_mastery()

	_state["credits"] = credits_before + credits_awarded
	_state["company_xp"] = xp_before + xp_awarded

	var completed := _state.get("completed_contracts", {}) as Dictionary
	var sector_id := String(result.get("sector_id", "unknown"))
	completed[sector_id] = int(completed.get(sector_id, 0)) + 1
	_state["completed_contracts"] = completed
	_state["last_contract_result"] = result.duplicate(true)

	var mastery_rules := _fleet_rules.get("mastery", {}) as Dictionary
	var mastery_awarded := int(mastery_rules.get("contract_xp", 0))
	if bool(result.get("perfect_cleanup", false)):
		mastery_awarded += int(mastery_rules.get("perfect_cleanup_bonus", 0))
	var active_ship_id := get_active_ship_id()
	var active_ship_state := _get_ship_state(active_ship_id).duplicate(true)
	active_ship_state["mastery_xp"] = maxi(int(active_ship_state.get("mastery_xp", 0)) + mastery_awarded, 0)
	_store_ship_state(active_ship_id, active_ship_state)

	_refresh_rank(true)

	var rank_after := get_rank_id()
	var mastery_after := get_active_ship_mastery()
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
		"ship_id": active_ship_id,
		"mastery_xp_awarded": mastery_awarded,
		"mastery_before": mastery_before,
		"mastery_after": mastery_after,
	}

	_persist()
	ship_mastery_changed.emit(active_ship_id, int(mastery_after["xp"]))
	state_changed.emit(get_snapshot())
	print("[Economy] PAYOUT sector=%s credits=%d xp=%d mastery=%d total_credits=%d promoted=%s" % [
		sector_id,
		credits_awarded,
		xp_awarded,
		mastery_awarded,
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

func _normalize_state(persisted: Dictionary, source_schema: int) -> Dictionary:
	if persisted.is_empty():
		return _default_state()
	if source_schema == SaveService.LEGACY_SCHEMA_VERSION or not persisted.has("fleet"):
		return _migrate_legacy_state(persisted)

	var defaults := _default_state()
	defaults["credits"] = maxi(int(persisted.get("credits", defaults["credits"])), 0)
	defaults["company_xp"] = maxi(int(persisted.get("company_xp", defaults["company_xp"])), 0)
	defaults["rank"] = String(persisted.get("rank", defaults["rank"]))

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

	var saved_fleet = persisted.get("fleet", {})
	if saved_fleet is Dictionary:
		var fleet := defaults["fleet"] as Dictionary
		var saved_ships := (saved_fleet as Dictionary).get("ships", {})
		var ships: Dictionary = {}
		if saved_ships is Dictionary:
			for ship_id_variant in (saved_ships as Dictionary).keys():
				var ship_id := String(ship_id_variant)
				if _registry.has_ship(ship_id):
					var saved_ship_state = (saved_ships as Dictionary)[ship_id_variant]
					if saved_ship_state is Dictionary:
						ships[ship_id] = _normalize_ship_state(ship_id, saved_ship_state as Dictionary)
		var default_ship_id := String(_fleet_rules.get("default_ship_id", "pioneer_01"))
		if not ships.has(default_ship_id):
			ships[default_ship_id] = _default_ship_state(default_ship_id)
		fleet["ships"] = ships

		var active_ship_id := String((saved_fleet as Dictionary).get("active_ship_id", default_ship_id))
		fleet["active_ship_id"] = active_ship_id if ships.has(active_ship_id) else default_ship_id

		var owned_modules: Array[String] = []
		for value in (saved_fleet as Dictionary).get("owned_modules", []) as Array:
			var module_id := String(value)
			if not _find_module(module_id).is_empty() and not owned_modules.has(module_id):
				owned_modules.append(module_id)
		owned_modules.sort()
		fleet["owned_modules"] = owned_modules

		var owned_cosmetics := _empty_owned_cosmetics()
		var saved_owned = (saved_fleet as Dictionary).get("owned_cosmetics", {})
		if saved_owned is Dictionary:
			for category_variant in owned_cosmetics.keys():
				var category := String(category_variant)
				var values := (saved_owned as Dictionary).get(category, [])
				if not values is Array:
					continue
				var ids := owned_cosmetics[category] as Array
				for value in values as Array:
					var cosmetic_id := String(value)
					if not _find_cosmetic_option(category, cosmetic_id).is_empty() and not ids.has(cosmetic_id):
						ids.append(cosmetic_id)
				ids.sort()
				owned_cosmetics[category] = ids
		fleet["owned_cosmetics"] = owned_cosmetics
		defaults["fleet"] = fleet
	return defaults

func _migrate_legacy_state(persisted: Dictionary) -> Dictionary:
	var migrated := _default_state()
	migrated["credits"] = maxi(int(persisted.get("credits", 0)), 0)
	migrated["company_xp"] = maxi(int(persisted.get("company_xp", 0)), 0)
	migrated["rank"] = String(persisted.get("rank", "trainee"))

	if persisted.get("completed_contracts", {}) is Dictionary:
		migrated["completed_contracts"] = (persisted["completed_contracts"] as Dictionary).duplicate(true)
	if persisted.get("last_contract_result", {}) is Dictionary:
		migrated["last_contract_result"] = (persisted["last_contract_result"] as Dictionary).duplicate(true)

	var discoveries: Array[String] = []
	for value in persisted.get("discoveries", []) as Array:
		var salvage_id := String(value)
		if _registry.has_salvage(salvage_id) and not discoveries.has(salvage_id):
			discoveries.append(salvage_id)
	discoveries.sort()
	migrated["discoveries"] = discoveries

	var fleet := migrated["fleet"] as Dictionary
	var default_ship_id := String(_fleet_rules.get("default_ship_id", "pioneer_01"))
	var ships := fleet["ships"] as Dictionary
	var ship_state := (ships[default_ship_id] as Dictionary).duplicate(true)

	var legacy_effects: Dictionary = {}
	var saved_upgrades := persisted.get("upgrades", {}) as Dictionary
	for value in _legacy_upgrade_config.get("upgrades", []) as Array:
		var definition := value as Dictionary
		var upgrade_id := String(definition["id"])
		var level := clampi(int(saved_upgrades.get(upgrade_id, 0)), 0, int(definition["max_level"]))
		if level <= 0:
			continue
		for effect_key_variant in (definition.get("effects", {}) as Dictionary).keys():
			var effect_key := String(effect_key_variant)
			legacy_effects[effect_key] = float(legacy_effects.get(effect_key, 0.0)) + float((definition["effects"] as Dictionary)[effect_key]) * float(level)
	ship_state["legacy_effects"] = legacy_effects

	var legacy_cosmetics = persisted.get("cosmetics", {})
	if legacy_cosmetics is Dictionary:
		var cosmetics := ship_state["cosmetics"] as Dictionary
		for category_variant in cosmetics.keys():
			var category := String(category_variant)
			var candidate := String((legacy_cosmetics as Dictionary).get(category, cosmetics[category]))
			if not _find_cosmetic_option(category, candidate).is_empty():
				cosmetics[category] = candidate
		ship_state["cosmetics"] = cosmetics

	ships[default_ship_id] = ship_state
	fleet["ships"] = ships
	fleet["active_ship_id"] = default_ship_id

	var owned_cosmetics := fleet["owned_cosmetics"] as Dictionary
	for category_variant in owned_cosmetics.keys():
		var category := String(category_variant)
		var ids := owned_cosmetics[category] as Array
		for value in (_cosmetic_config.get("categories", {}) as Dictionary)[category] as Array:
			var option := value as Dictionary
			if _rank_index(String(option.get("unlock_rank", "trainee"))) <= _rank_index(String(migrated["rank"])):
				var cosmetic_id := String(option["id"])
				if not ids.has(cosmetic_id):
					ids.append(cosmetic_id)
		ids.sort()
		owned_cosmetics[category] = ids
	fleet["owned_cosmetics"] = owned_cosmetics
	migrated["fleet"] = fleet
	print("[Save] MIGRATED v1_to_v2 ship=%s legacy_effects=%d" % [default_ship_id, legacy_effects.size()])
	return migrated

func _default_state() -> Dictionary:
	var default_ship_id := String(_fleet_rules.get("default_ship_id", "pioneer_01"))
	assert(_registry.has_ship(default_ship_id), "Fleet default ship definition is missing: %s" % default_ship_id)
	var ships: Dictionary = {}
	ships[default_ship_id] = _default_ship_state(default_ship_id)
	return {
		"credits": 0,
		"company_xp": 0,
		"rank": "trainee",
		"discoveries": [],
		"completed_contracts": {},
		"last_contract_result": {},
		"fleet": {
			"active_ship_id": default_ship_id,
			"ships": ships,
			"owned_modules": _default_owned_modules(default_ship_id),
			"owned_cosmetics": _default_owned_cosmetics(),
		},
	}

func _default_ship_state(ship_id: String) -> Dictionary:
	var definition := _registry.get_ship(ship_id)
	var upgrades: Dictionary = {}
	for value in _fleet_rules.get("upgrade_tracks", []) as Array:
		var track := value as Dictionary
		upgrades[String(track["id"])] = 0
	return {
		"mastery_xp": 0,
		"upgrades": upgrades,
		"modules": _default_module_loadout(definition),
		"cosmetics": (_cosmetic_config.get("default_loadout", {}) as Dictionary).duplicate(true),
		"legacy_effects": {},
	}

func _normalize_ship_state(ship_id: String, saved: Dictionary) -> Dictionary:
	var normalized := _default_ship_state(ship_id)
	normalized["mastery_xp"] = maxi(int(saved.get("mastery_xp", 0)), 0)

	var saved_upgrades := saved.get("upgrades", {}) as Dictionary
	var upgrades := normalized["upgrades"] as Dictionary
	for value in _fleet_rules.get("upgrade_tracks", []) as Array:
		var track := value as Dictionary
		var track_id := String(track["id"])
		upgrades[track_id] = clampi(int(saved_upgrades.get(track_id, 0)), 0, int(track["max_level"]))
	normalized["upgrades"] = upgrades

	var saved_modules = saved.get("modules", {})
	if saved_modules is Dictionary:
		var definition := _registry.get_ship(ship_id)
		normalized["modules"] = _normalize_module_loadout(definition, saved_modules as Dictionary)

	var saved_cosmetics = saved.get("cosmetics", {})
	if saved_cosmetics is Dictionary:
		var cosmetics := normalized["cosmetics"] as Dictionary
		for category_variant in cosmetics.keys():
			var category := String(category_variant)
			var candidate := String((saved_cosmetics as Dictionary).get(category, cosmetics[category]))
			if not _find_cosmetic_option(category, candidate).is_empty():
				cosmetics[category] = candidate
		normalized["cosmetics"] = cosmetics

	var saved_legacy = saved.get("legacy_effects", {})
	if saved_legacy is Dictionary:
		var legacy: Dictionary = {}
		for key_variant in (saved_legacy as Dictionary).keys():
			var key := String(key_variant)
			if key.ends_with("_add"):
				legacy[key] = float((saved_legacy as Dictionary)[key_variant])
		normalized["legacy_effects"] = legacy
	return normalized

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

	for ship in get_ship_definitions():
		var unlock := ship.get("unlock", {}) as Dictionary
		var unlock_rank := String(unlock.get("rank", "trainee"))
		var unlock_index := _rank_index(unlock_rank)
		if unlock_index > previous_index and unlock_index <= next_index:
			output.append({
				"type": "ship",
				"id": String(ship["id"]),
				"display_name_key": String(ship["display_name_key"]),
				"unlock_rank": unlock_rank,
			})

	for module in _fleet_rules.get("modules", []) as Array:
		var definition := module as Dictionary
		var unlock_rank := String(definition.get("unlock_rank", "trainee"))
		var unlock_index := _rank_index(unlock_rank)
		if unlock_index > previous_index and unlock_index <= next_index:
			output.append({
				"type": "module",
				"id": String(definition["id"]),
				"display_name_key": String(definition["display_name_key"]),
				"unlock_rank": unlock_rank,
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

func _sanitize_fleet() -> void:
	var fleet := (_state.get("fleet", {}) as Dictionary).duplicate(true)
	var ships := fleet.get("ships", {}) as Dictionary
	var default_ship_id := String(_fleet_rules.get("default_ship_id", "pioneer_01"))
	if not ships.has(default_ship_id):
		ships[default_ship_id] = _default_ship_state(default_ship_id)

	var active_ship_id := String(fleet.get("active_ship_id", default_ship_id))
	if not ships.has(active_ship_id):
		active_ship_id = default_ship_id
	fleet["active_ship_id"] = active_ship_id
	fleet["ships"] = ships

	var owned_modules := fleet.get("owned_modules", []) as Array
	for ship_id_variant in ships.keys():
		var ship_id := String(ship_id_variant)
		var definition := _registry.get_ship(ship_id)
		for module_id_variant in (definition.get("default_modules", {}) as Dictionary).values():
			var module_id := String(module_id_variant)
			if not module_id.is_empty() and not owned_modules.has(module_id):
				owned_modules.append(module_id)
	owned_modules.sort()
	fleet["owned_modules"] = owned_modules

	var owned_cosmetics := fleet.get("owned_cosmetics", {}) as Dictionary
	var defaults := _cosmetic_config.get("default_loadout", {}) as Dictionary
	for category_variant in defaults.keys():
		var category := String(category_variant)
		var ids := owned_cosmetics.get(category, []) as Array
		var default_id := String(defaults[category])
		if not ids.has(default_id):
			ids.append(default_id)
		ids.sort()
		owned_cosmetics[category] = ids
	fleet["owned_cosmetics"] = owned_cosmetics
	_state["fleet"] = fleet

	for ship_id_variant in ships.keys():
		var ship_id := String(ship_id_variant)
		var ship_state := _get_ship_state(ship_id).duplicate(true)
		var cosmetics := ship_state.get("cosmetics", {}) as Dictionary
		for category_variant in defaults.keys():
			var category := String(category_variant)
			var cosmetic_id := String(cosmetics.get(category, defaults[category]))
			var allowed := (
				not _find_cosmetic_option(category, cosmetic_id).is_empty()
				and (owned_cosmetics.get(category, []) as Array).has(cosmetic_id)
			)
			if not allowed:
				cosmetics[category] = String(defaults[category])
		ship_state["cosmetics"] = cosmetics

		var ship_definition := _registry.get_ship(ship_id)
		var modules := _normalize_module_loadout(ship_definition, ship_state.get("modules", {}) as Dictionary)
		var defaults := _default_module_loadout(ship_definition)
		for slot_variant in modules.keys():
			var slot := String(slot_variant)
			var equipped := modules[slot] as Array
			var fallback := defaults[slot] as Array
			for index in range(equipped.size()):
				var module_id := String(equipped[index])
				var module := _find_module(module_id)
				if module.is_empty() or String(module.get("slot", "")) != slot or not owned_modules.has(module_id):
					equipped[index] = String(fallback[index]) if index < fallback.size() else ""
			modules[slot] = equipped
		ship_state["modules"] = modules
		_store_ship_state(ship_id, ship_state)

func _ensure_default_assets_owned(ship_id: String) -> void:
	var definition := _registry.get_ship(ship_id)
	var fleet := (_state["fleet"] as Dictionary).duplicate(true)
	var owned_modules := fleet.get("owned_modules", []) as Array
	for value in (definition.get("default_modules", {}) as Dictionary).values():
		var module_id := String(value)
		if not module_id.is_empty() and not owned_modules.has(module_id):
			owned_modules.append(module_id)
	owned_modules.sort()
	fleet["owned_modules"] = owned_modules

	var owned_cosmetics := fleet.get("owned_cosmetics", {}) as Dictionary
	var defaults := _cosmetic_config.get("default_loadout", {}) as Dictionary
	for category_variant in defaults.keys():
		var category := String(category_variant)
		var ids := owned_cosmetics.get(category, []) as Array
		var cosmetic_id := String(defaults[category])
		if not ids.has(cosmetic_id):
			ids.append(cosmetic_id)
		owned_cosmetics[category] = ids
	fleet["owned_cosmetics"] = owned_cosmetics
	_state["fleet"] = fleet

func _default_module_loadout(definition: Dictionary) -> Dictionary:
	var slots := definition.get("module_slots", {}) as Dictionary
	var authored_defaults := definition.get("default_modules", {}) as Dictionary
	var output: Dictionary = {}
	for slot_variant in slots.keys():
		var slot := String(slot_variant)
		var capacity := maxi(int(slots[slot_variant]), 0)
		var values_variant = authored_defaults.get(slot, [])
		var values: Array = values_variant as Array if values_variant is Array else [values_variant]
		var equipped: Array[String] = []
		for index in range(capacity):
			equipped.append(String(values[index]) if index < values.size() else "")
		output[slot] = equipped
	return output

func _normalize_module_loadout(definition: Dictionary, saved: Dictionary) -> Dictionary:
	var output := _default_module_loadout(definition)
	var slots := definition.get("module_slots", {}) as Dictionary
	for slot_variant in slots.keys():
		var slot := String(slot_variant)
		var capacity := maxi(int(slots[slot_variant]), 0)
		var saved_variant = saved.get(slot, [])
		var saved_values: Array = saved_variant as Array if saved_variant is Array else [saved_variant]
		var normalized := output.get(slot, []) as Array
		for index in range(mini(capacity, saved_values.size())):
			var module_id := String(saved_values[index])
			var module := _find_module(module_id)
			if not module.is_empty() and String(module.get("slot", "")) == slot:
				normalized[index] = module_id
		output[slot] = normalized
	return output

func _default_owned_modules(ship_id: String) -> Array[String]:
	var output: Array[String] = []
	var definition := _registry.get_ship(ship_id)
	for slot_modules_variant in (definition.get("default_modules", {}) as Dictionary).values():
		var slot_modules: Array = slot_modules_variant as Array if slot_modules_variant is Array else [slot_modules_variant]
		for value in slot_modules:
			var module_id := String(value)
			if not module_id.is_empty() and not output.has(module_id):
				output.append(module_id)
	output.sort()
	return output

func _default_owned_cosmetics() -> Dictionary:
	var output := _empty_owned_cosmetics()
	var defaults := _cosmetic_config.get("default_loadout", {}) as Dictionary
	for category_variant in defaults.keys():
		var category := String(category_variant)
		var ids := output[category] as Array
		ids.append(String(defaults[category]))
		output[category] = ids
	return output

func _empty_owned_cosmetics() -> Dictionary:
	var output: Dictionary = {}
	for category_variant in (_cosmetic_config.get("categories", {}) as Dictionary).keys():
		output[String(category_variant)] = []
	return output

func _get_ship_state(ship_id: String) -> Dictionary:
	var fleet := _state.get("fleet", {}) as Dictionary
	var ships := fleet.get("ships", {}) as Dictionary
	assert(ships.has(ship_id), "Player does not own ship state: %s" % ship_id)
	return ships[ship_id] as Dictionary

func _store_ship_state(ship_id: String, ship_state: Dictionary) -> void:
	var fleet := (_state["fleet"] as Dictionary).duplicate(true)
	var ships := fleet.get("ships", {}) as Dictionary
	ships[ship_id] = ship_state.duplicate(true)
	fleet["ships"] = ships
	_state["fleet"] = fleet

func _find_rank(rank_id: String) -> Dictionary:
	for value in _rank_config.get("ranks", []) as Array:
		var rank := value as Dictionary
		if String(rank["id"]) == rank_id:
			return rank
	return {}

func _find_upgrade(upgrade_id: String) -> Dictionary:
	for value in _fleet_rules.get("upgrade_tracks", []) as Array:
		var upgrade := value as Dictionary
		if String(upgrade["id"]) == upgrade_id:
			return upgrade
	return {}

func _find_module(module_id: String) -> Dictionary:
	for value in _fleet_rules.get("modules", []) as Array:
		var module := value as Dictionary
		if String(module["id"]) == module_id:
			return module
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

func _persist() -> void:
	assert(_save_service != null, "ProgressionService is not initialized.")
	var error := _save_service.write_state(_state)
	assert(error == OK, "Progression save failed: %s" % error)
