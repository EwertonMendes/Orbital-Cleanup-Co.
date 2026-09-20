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
