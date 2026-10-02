extends RefCounted
class_name ShipBuildResolver

const MIN_CARGO_INERTIA := 0.05

static func resolve(
	ship_definition: Dictionary,
	ship_state: Dictionary,
	fleet_rules: Dictionary,
	cosmetic_loadout: Dictionary
) -> Dictionary:
	assert(not ship_definition.is_empty(), "ShipBuildResolver requires a ship definition.")
	assert(not fleet_rules.is_empty(), "ShipBuildResolver requires fleet rules.")

	var stats := (ship_definition.get("base_stats", {}) as Dictionary).duplicate(true)
	assert(not stats.is_empty(), "Ship definition requires base_stats.")

	_apply_effects(stats, ship_state.get("legacy_effects", {}) as Dictionary, 1)

	var upgrade_levels := ship_state.get("upgrades", {}) as Dictionary
	for value in fleet_rules.get("upgrade_tracks", []) as Array:
		var track := value as Dictionary
		var track_id := String(track.get("id", ""))
		var level := clampi(
			int(upgrade_levels.get(track_id, 0)),
			0,
			int(track.get("max_level", 0))
		)
		if level <= 0:
			continue
		_apply_effects(stats, track.get("effects", {}) as Dictionary, level)
		for milestone_value in track.get("milestones", []) as Array:
			var milestone := milestone_value as Dictionary
			if level >= int(milestone.get("level", 999999)):
				_apply_effects(stats, milestone.get("effects", {}) as Dictionary, 1)

	var equipped_modules := ship_state.get("modules", {}) as Dictionary
	for slot_variant in equipped_modules.keys():
		var slot := String(slot_variant)
		var slot_modules = equipped_modules[slot_variant]
		var module_ids: Array = slot_modules as Array if slot_modules is Array else [slot_modules]
		for module_id_variant in module_ids:
			var module_id := String(module_id_variant)
			if module_id.is_empty():
				continue
			var module := _find_by_id(fleet_rules.get("modules", []) as Array, module_id)
			if module.is_empty():
				continue
			assert(String(module.get("slot", "")) == slot, "Equipped module slot mismatch: %s" % module_id)
			_apply_effects(stats, module.get("effects", {}) as Dictionary, 1)

	_sanitize_stats(stats)

	return {
		"ship_id": String(ship_definition["id"]),
		"display_name_key": String(ship_definition["display_name_key"]),
		"description_key": String(ship_definition["description_key"]),
		"role_key": String(ship_definition["role_key"]),
		"stats": stats,
		"visual": (ship_definition.get("visual", {}) as Dictionary).duplicate(true),
		"module_slots": (ship_definition.get("module_slots", {}) as Dictionary).duplicate(true),
		"modules": equipped_modules.duplicate(true),
		"cosmetics": cosmetic_loadout.duplicate(true),
		"mastery_xp": maxi(int(ship_state.get("mastery_xp", 0)), 0),
	}

static func _apply_effects(stats: Dictionary, effects: Dictionary, stacks: int) -> void:
	if stacks <= 0:
		return
	for effect_key_variant in effects.keys():
		var effect_key := String(effect_key_variant)
		var amount := float(effects[effect_key]) * float(stacks)
		if effect_key.ends_with("_add"):
			var target_key := effect_key.trim_suffix("_add")
			stats[target_key] = float(stats.get(target_key, 0.0)) + amount

static func _sanitize_stats(stats: Dictionary) -> void:
	stats["max_speed"] = maxf(float(stats.get("max_speed", 300.0)), 80.0)
	stats["acceleration"] = maxf(float(stats.get("acceleration", 420.0)), 80.0)
	stats["dry_mass"] = maxf(float(stats.get("dry_mass", 12.0)), 2.0)
	stats["cargo_inertia_factor"] = clampf(float(stats.get("cargo_inertia_factor", 0.35)), MIN_CARGO_INERTIA, 1.0)
	stats["turn_response"] = maxf(float(stats.get("turn_response", 6.0)), 1.0)
	stats["boost_acceleration"] = maxf(float(stats.get("boost_acceleration", 220.0)), 40.0)
	stats["boost_duration"] = clampf(float(stats.get("boost_duration", 0.62)), 0.2, 1.5)
	stats["boost_recharge_seconds"] = maxf(float(stats.get("boost_recharge_seconds", 3.2)), float(stats["boost_duration"]) + 0.2)
	stats["boost_turn_authority"] = clampf(float(stats.get("boost_turn_authority", 0.78)), 0.2, 1.0)
	stats["scan_range"] = maxf(float(stats.get("scan_range", 320.0)), 80.0)
	stats["capture_distance"] = maxf(float(stats.get("capture_distance", 58.0)), 20.0)
	stats["pull_speed"] = maxf(float(stats.get("pull_speed", 520.0)), 80.0)
	stats["collection_speed_multiplier"] = maxf(float(stats.get("collection_speed_multiplier", 1.0)), 0.1)
	stats["cargo_capacity"] = maxf(float(stats.get("cargo_capacity", 12.0)), 1.0)
	stats["boost_recharge_rate"] = maxf(float(stats.get("boost_recharge_rate", 1.0)), 0.5)
	stats["boost_duration_bonus"] = maxf(float(stats.get("boost_duration_bonus", 0.0)), 0.0)
	stats["boost_charge_capacity"] = clampf(float(stats.get("boost_charge_capacity", 1.0)), 1.0, 2.0)
	stats["environment_force_response"] = clampf(float(stats.get("environment_force_response", 1.0)), 0.45, 1.4)
	stats["environment_drag_response"] = clampf(float(stats.get("environment_drag_response", 1.0)), 0.45, 1.4)

static func _find_by_id(values: Array, id: String) -> Dictionary:
	for value in values:
		var definition := value as Dictionary
		if String(definition.get("id", "")) == id:
			return definition
	return {}
