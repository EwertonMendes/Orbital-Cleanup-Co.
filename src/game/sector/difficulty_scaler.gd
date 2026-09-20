extends RefCounted
class_name DifficultyScaler

var _registry: ContentRegistry
var _curves: Dictionary = {}

func configure(registry: ContentRegistry) -> void:
	assert(registry != null, "DifficultyScaler requires ContentRegistry.")
	_registry = registry
	var data := _registry.get_progression("difficulty_scaling")
	_curves = (data.get("curves", {}) as Dictionary).duplicate(true)
	assert(not _curves.is_empty(), "Difficulty scaling curves are required.")

func evaluate(difficulty: int) -> Dictionary:
	assert(difficulty >= 1, "Difficulty must be at least 1.")
	assert(not _curves.is_empty(), "DifficultyScaler must be configured before use.")

	return {
		"salvage_count": _curve("salvage_count", difficulty),
		"obstacle_count": _curve("obstacle_count", difficulty),
		"rare_weight_multiplier": _curve("rare_weight_multiplier", difficulty),
		"mass_multiplier": _curve("mass_multiplier", difficulty),
		"reward_multiplier": _curve("reward_multiplier", difficulty),
	}

func _curve(id: String, difficulty: int) -> float:
	var curve := _curves.get(id, {}) as Dictionary
	assert(not curve.is_empty(), "Missing difficulty curve: %s" % id)

	var base := float(curve.get("base", 0.0))
	var per_level := float(curve.get("per_level", 0.0))
	var maximum := float(curve.get("max", base))
	return minf(base + per_level * float(difficulty - 1), maximum)
