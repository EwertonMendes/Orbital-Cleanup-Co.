extends Node
class_name ProgressionService

signal state_changed(snapshot: Dictionary)
signal upgrade_purchased(upgrade_id: String, level: int, cost: int)
signal rank_changed(rank_id: String)

var _save_service: SaveService
var _registry := ContentRegistry.new()
var _state: Dictionary = {}
var _rank_config: Dictionary = {}
var _upgrade_config: Dictionary = {}

func initialize(save_service: SaveService) -> void:
	assert(save_service != null, "ProgressionService requires SaveService.")
	_save_service = save_service
	_rank_config = _registry.get_progression("career_ranks")
	_upgrade_config = _registry.get_progression("upgrades")

	var persisted := _save_service.read_state()
	_state = _normalize_state(persisted)
	_refresh_rank(false)
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
	var ranks := _rank_config.get("ranks", []) as Array
	var current_xp := get_company_xp()
	var current_index := 0
	for index in range(ranks.size()):
		var rank := ranks[index] as Dictionary
		if String(rank["id"]) == get_rank_id():
			current_index = index
			break

	var current := ranks[current_index] as Dictionary
	if current_index >= ranks.size() - 1:
		return {
			"current_xp": current_xp,
			"current_min_xp": int(current["min_xp"]),
			"next_min_xp": current_xp,
			"is_max_rank": true,
		}

	var next_rank := ranks[current_index + 1] as Dictionary
	return {
		"current_xp": current_xp,
		"current_min_xp": int(current["min_xp"]),
		"next_min_xp": int(next_rank["min_xp"]),
		"is_max_rank": false,
	}

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

func apply_contract_result(result: Dictionary) -> void:
	assert(bool(result.get("completed", false)), "Only completed contracts can grant progression.")
	var credits_awarded := int(result.get("credits_awarded", 0))
	var xp_awarded := int(result.get("xp_awarded", 0))
	assert(credits_awarded >= 0 and xp_awarded >= 0, "Contract rewards cannot be negative.")

	_state["credits"] = get_credits() + credits_awarded
	_state["company_xp"] = get_company_xp() + xp_awarded

	var completed := _state.get("completed_contracts", {}) as Dictionary
	var sector_id := String(result.get("sector_id", "unknown"))
	completed[sector_id] = int(completed.get(sector_id, 0)) + 1
	_state["completed_contracts"] = completed
	_state["last_contract_result"] = result.duplicate(true)

	_refresh_rank(true)
	_persist()
	state_changed.emit(get_snapshot())
	print("[Economy] PAYOUT sector=%s credits=%d xp=%d total_credits=%d" % [
		sector_id,
		credits_awarded,
		xp_awarded,
		get_credits(),
	])

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
		"cosmetics": {},
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

func _persist() -> void:
	assert(_save_service != null, "ProgressionService is not initialized.")
	var error := _save_service.write_state(_state)
	assert(error == OK, "Progression save failed: %s" % error)
