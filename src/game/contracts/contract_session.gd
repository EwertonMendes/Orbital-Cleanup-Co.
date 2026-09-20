extends RefCounted
class_name ContractSession

signal cleanliness_changed(percent: float, cleaned: float, total: float)
signal target_reached
signal perfect_cleanup_reached

var _sector_id := ""
var _contract: Dictionary = {}
var _target_percent := 100.0
var _total_cleanliness := 1.0
var _cleaned := 0.0
var _salvage_credits := 0
var _reward_multiplier := 1.0
var _target_announced := false
var _perfect_announced := false

func configure(context: Dictionary) -> void:
	_sector_id = String(context.get("sector_id", ""))
	_contract = (context.get("contract", {}) as Dictionary).duplicate(true)
	_target_percent = float(context.get("target_percent", 100.0))
	_total_cleanliness = maxf(float(context.get("total_cleanliness", 0.0)), 0.001)
	_reward_multiplier = maxf(float(context.get("reward_multiplier", 1.0)), 0.0)

	assert(not _sector_id.is_empty(), "ContractSession requires sector_id.")
	assert(not _contract.is_empty(), "ContractSession requires contract definition.")
	assert(_target_percent > 0.0 and _target_percent <= 100.0, "Contract target must be in (0, 100].")

func start() -> void:
	print("[Contract] START sector=%s target=%.0f" % [_sector_id, _target_percent])

func record_salvage(definition: SalvageDefinition) -> void:
	assert(definition != null, "ContractSession requires collected salvage definition.")
	_cleaned = minf(_cleaned + definition.cleanliness_value, _total_cleanliness)
	_salvage_credits += maxi(definition.base_value, 0)
	cleanliness_changed.emit(get_cleanup_percent(), _cleaned, _total_cleanliness)
	_refresh_milestones()

func get_cleanup_percent() -> float:
	return clampf((_cleaned / _total_cleanliness) * 100.0, 0.0, 100.0)

func get_target_percent() -> float:
	return _target_percent

func is_target_reached() -> bool:
	return get_cleanup_percent() + 0.001 >= _target_percent

func is_perfect_cleanup() -> bool:
	return get_cleanup_percent() >= 99.999

func get_salvage_credits() -> int:
	return _salvage_credits

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
	assert(is_target_reached(), "Cannot complete a contract before its cleanup target.")
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
		"cleanup_percent": get_cleanup_percent(),
		"perfect_cleanup": perfect,
		"base_pay": base_pay,
		"salvage_credits": _salvage_credits,
		"perfect_bonus": perfect_bonus,
		"credits_awarded": base_pay + _salvage_credits + perfect_bonus,
		"xp_awarded": xp,
	}

func _refresh_milestones() -> void:
	if not _target_announced and is_target_reached():
		_target_announced = true
		print("[Contract] COMPLETE sector=%s cleanliness=%.1f" % [_sector_id, get_cleanup_percent()])
		target_reached.emit()

	if not _perfect_announced and is_perfect_cleanup():
		_perfect_announced = true
		print("[Contract] PERFECT sector=%s" % _sector_id)
		perfect_cleanup_reached.emit()
