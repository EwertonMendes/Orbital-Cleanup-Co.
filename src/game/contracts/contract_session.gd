extends RefCounted
class_name ContractSession

signal cleanliness_changed(percent: float, cleaned: float, total: float)
signal objective_changed(snapshot: Dictionary)
signal target_reached
signal perfect_cleanup_reached

var _sector_id := ""
var _contract: Dictionary = {}
var _contract_ref: Dictionary = {}
var _kind := "cleanup"
var _target_percent := 100.0
var _target_count := 0
var _target_value := 0
var _priority_salvage_id := ""
var _total_cleanliness := 1.0
var _cleaned := 0.0
var _salvage_credits := 0
var _recovered_count := 0
var _priority_recovered_count := 0
var _reward_multiplier := 1.0
var _target_announced := false
var _perfect_announced := false

func configure(context: Dictionary) -> void:
	_sector_id = String(context.get("sector_id", ""))
	_contract = (context.get("contract", {}) as Dictionary).duplicate(true)
	_contract_ref = (context.get("contract_ref", {}) as Dictionary).duplicate(true)
	_kind = String(_contract.get("kind", "cleanup"))
	_total_cleanliness = maxf(float(context.get("total_cleanliness", 0.0)), 0.001)
	_reward_multiplier = maxf(float(context.get("reward_multiplier", 1.0)), 0.0)

	if _contract_ref.is_empty():
		_contract_ref = {
			"type": String(_contract.get("id", "")),
			"target_percent": context.get("target_percent", 100.0),
			"target_count": context.get("target_count", 0),
			"target_value": context.get("target_value", 0),
			"target_salvage_id": context.get("target_salvage_id", ""),
		}

	_target_percent = float(_contract_ref.get("target_percent", 100.0))
	_target_count = int(_contract_ref.get("target_count", 0))
	_target_value = int(_contract_ref.get("target_value", 0))
	_priority_salvage_id = String(_contract_ref.get("target_salvage_id", ""))

	assert(not _sector_id.is_empty(), "ContractSession requires sector_id.")
	assert(not _contract.is_empty(), "ContractSession requires contract definition.")
	match _kind:
		"cleanup", "full_cleanup":
			assert(_target_percent > 0.0 and _target_percent <= 100.0, "Cleanup target must be in (0, 100].")
		"recovery":
			assert(_target_count > 0, "Recovery contract requires target_count.")
		"valuable_recovery":
			assert(_target_value > 0, "Valuable Recovery requires target_value.")
		"priority_object":
			assert(_target_count > 0, "Priority Object requires target_count.")
			assert(not _priority_salvage_id.is_empty(), "Priority Object requires target_salvage_id.")
		_:
			assert(false, "Unsupported contract kind: %s" % _kind)

func start() -> void:
	var objective := get_objective_snapshot()
	print("[Contract] START sector=%s kind=%s target=%s" % [
		_sector_id,
		_kind,
		str(objective["target"]),
	])
	objective_changed.emit(objective)

func record_salvage(definition: SalvageDefinition) -> void:
	assert(definition != null, "ContractSession requires collected salvage definition.")
	_cleaned = minf(_cleaned + definition.cleanliness_value, _total_cleanliness)
	_salvage_credits += maxi(definition.base_value, 0)
	_recovered_count += 1
	if String(definition.id) == _priority_salvage_id:
		_priority_recovered_count += 1

	cleanliness_changed.emit(get_cleanup_percent(), _cleaned, _total_cleanliness)
	objective_changed.emit(get_objective_snapshot())
	_refresh_milestones()

func get_contract_kind() -> String:
	return _kind

func get_cleanup_percent() -> float:
	return clampf((_cleaned / _total_cleanliness) * 100.0, 0.0, 100.0)

func get_target_percent() -> float:
	return _target_percent

func get_salvage_credits() -> int:
	return _salvage_credits

func get_recovered_count() -> int:
	return _recovered_count

func get_objective_snapshot() -> Dictionary:
	var current := 0.0
	var target := 1.0
	match _kind:
		"cleanup", "full_cleanup":
			current = get_cleanup_percent()
			target = _target_percent
		"recovery":
			current = float(_recovered_count)
			target = float(_target_count)
		"valuable_recovery":
			current = float(_salvage_credits)
			target = float(_target_value)
		"priority_object":
			current = float(_priority_recovered_count)
			target = float(_target_count)

	var progress := clampf(current / maxf(target, 0.001) * 100.0, 0.0, 100.0)
	return {
		"kind": _kind,
		"current": current,
		"target": target,
		"progress_percent": progress,
		"cleanup_percent": get_cleanup_percent(),
		"priority_salvage_id": _priority_salvage_id,
		"complete": current + 0.001 >= target,
	}

func is_target_reached() -> bool:
	return bool(get_objective_snapshot()["complete"])

func is_perfect_cleanup() -> bool:
	return get_cleanup_percent() >= 99.999

func get_reward_preview() -> Dictionary:
	var base_pay := int(round(float(_contract.get("base_pay", 0)) * _reward_multiplier))
	var perfect_bonus := int(round(float(_contract.get("perfect_bonus", 0)) * _reward_multiplier))
	return {
		"base_pay": base_pay,
		"perfect_bonus": perfect_bonus,
		"company_xp": int(_contract.get("company_xp", 0)),
		"perfect_xp_bonus": int(_contract.get("perfect_xp_bonus", 0)),
	}

func build_result() -> Dictionary:
	assert(is_target_reached(), "Cannot complete a contract before its objective target.")
	var reward := get_reward_preview()
	var perfect := is_perfect_cleanup()
	var base_pay := int(reward["base_pay"])
	var perfect_bonus := int(reward["perfect_bonus"]) if perfect else 0
	var xp := int(reward["company_xp"])
	if perfect:
		xp += int(reward["perfect_xp_bonus"])

	return {
		"completed": true,
		"sector_id": _sector_id,
		"contract_id": String(_contract.get("id", "")),
		"contract_kind": _kind,
		"objective": get_objective_snapshot(),
		"cleanup_percent": get_cleanup_percent(),
		"perfect_cleanup": perfect,
		"recovered_count": _recovered_count,
		"base_pay": base_pay,
		"salvage_credits": _salvage_credits,
		"perfect_bonus": perfect_bonus,
		"credits_awarded": base_pay + _salvage_credits + perfect_bonus,
		"xp_awarded": xp,
	}

func _refresh_milestones() -> void:
	if not _target_announced and is_target_reached():
		_target_announced = true
		print("[Contract] COMPLETE sector=%s kind=%s objective=%s" % [
			_sector_id,
			_kind,
			str(get_objective_snapshot()),
		])
		target_reached.emit()

	if not _perfect_announced and is_perfect_cleanup():
		_perfect_announced = true
		print("[Contract] PERFECT sector=%s" % _sector_id)
		perfect_cleanup_reached.emit()
