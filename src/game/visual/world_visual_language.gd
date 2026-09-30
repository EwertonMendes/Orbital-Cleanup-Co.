extends RefCounted
class_name WorldVisualLanguage

static func salvage_recovery_color() -> Color:
	return Color("#55e6ff")

static func salvage_progress_color() -> Color:
	return Color("#8ff1ce")

static func salvage_category_color(category: StringName) -> Color:
	match String(category):
		"electronics":
			return Color("#55d8ff")
		"cargo":
			return Color("#ffd166")
		"research":
			return Color("#b68cff")
		"power":
			return Color("#8ff1ce")
		"mining":
			return Color("#ffb86c")
		"industrial":
			return Color("#72e2c4")
		"propulsion":
			return Color("#76a9ff")
		_:
			return Color("#68e7f5")

static func salvage_rarity_color(rarity: StringName) -> Color:
	match String(rarity):
		"uncommon":
			return Color("#8ff1ce")
		"rare":
			return Color("#ffd166")
		"epic":
			return Color("#d59cff")
		_:
			return Color("#bdefff")

static func hazard_color() -> Color:
	return Color("#ff8f5c")

static func landmark_color() -> Color:
	return Color("#78bde8")

static func environment_effect_profile(visual_profile: Dictionary) -> String:
	var authored := String(visual_profile.get("effect_profile", ""))
	if not authored.is_empty():
		return authored

	match String(visual_profile.get("horizon_style", "clear")):
		"dust", "rings", "industrial":
			return "dust"
		"nebula", "gas":
			return "nebula"
		"solar":
			return "solar"
		"anomaly":
			return "anomaly"
		_:
			return "clean"

static func environment_effect_mode(visual_profile: Dictionary) -> int:
	match environment_effect_profile(visual_profile):
		"dust":
			return 1
		"nebula":
			return 2
		"solar":
			return 3
		"anomaly":
			return 4
		_:
			return 0

static func environment_effect_intensity(visual_profile: Dictionary) -> float:
	if visual_profile.has("effect_intensity"):
		return clampf(float(visual_profile["effect_intensity"]), 0.0, 1.0)
	return clampf(float(visual_profile.get("horizon_intensity", 0.6)) * 0.55, 0.0, 0.65)
