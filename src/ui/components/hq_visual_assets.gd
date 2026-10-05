extends RefCounted
class_name HqVisualAssets

const NAV_CONTRACTS: Texture2D = preload("res://assets/original/ui/hq/generated/nav_contracts.webp")
const NAV_UPGRADES: Texture2D = preload("res://assets/original/ui/hq/generated/nav_upgrades.webp")
const NAV_CAREER: Texture2D = preload("res://assets/original/ui/hq/generated/nav_career.webp")
const NAV_FLEET: Texture2D = preload("res://assets/original/ui/hq/generated/nav_fleet.webp")
const NAV_DISCOVERIES: Texture2D = preload("res://assets/original/ui/hq/generated/nav_discoveries.webp")

const META_CLEANUP: Texture2D = preload("res://assets/original/ui/hq/generated/meta_cleanup.webp")
const META_RISK: Texture2D = preload("res://assets/original/ui/hq/generated/meta_risk.webp")
const META_REWARD: Texture2D = preload("res://assets/original/ui/hq/generated/meta_reward.webp")
const META_LOCATION: Texture2D = preload("res://assets/original/ui/hq/generated/meta_location.webp")
const META_COMPLETE: Texture2D = preload("res://assets/original/ui/hq/generated/meta_complete.webp")

const FLEET_BAY: Texture2D = preload("res://assets/original/ui/hq/generated/fleet_hangar_hq.svg")
const ORBIT_DIVIDER: Texture2D = preload("res://assets/original/ui/hq/orbit_divider.svg")
const TECHNICAL_PATTERN: Texture2D = preload("res://assets/original/ui/hq/technical_pattern.svg")

const EARTH_PREVIEW: Texture2D = preload("res://assets/original/ui/hq/generated/contract_earth.webp")
const LUNAR_PREVIEW: Texture2D = preload("res://assets/original/ui/hq/generated/contract_lunar_fixed.svg")
const MARS_PREVIEW: Texture2D = preload("res://assets/original/ui/hq/generated/contract_mars.webp")
const NEBULA_PREVIEW: Texture2D = preload("res://assets/original/ui/hq/generated/contract_nebula.webp")

static func nav_icon(index: int) -> Texture2D:
	var icons: Array[Texture2D] = [NAV_CONTRACTS, NAV_UPGRADES, NAV_CAREER, NAV_FLEET, NAV_DISCOVERIES]
	return icons[clampi(index, 0, icons.size() - 1)]

static func upgrade_art(upgrade_id: String) -> Texture2D:
	match upgrade_id:
		"propulsion_core":
			return preload("res://assets/original/ui/hq/generated/upgrade_propulsion.png")
		"maneuvering_thrusters":
			return preload("res://assets/original/ui/hq/generated/upgrade_maneuver.png")
		"recovery_array":
			return preload("res://assets/original/ui/hq/generated/upgrade_recovery.png")
		"cargo_frame":
			return preload("res://assets/original/ui/hq/generated/upgrade_cargo.png")
		"pulse_system":
			return preload("res://assets/original/ui/hq/generated/upgrade_energy.png")
	return preload("res://assets/original/ui/hq/upgrade_recovery.svg")

static func rank_badge(rank_id: String) -> Texture2D:
	match rank_id:
		"trainee":
			return preload("res://assets/original/ui/hq/generated/rank_trainee.png")
		"junior_cleaner":
			return preload("res://assets/original/ui/hq/generated/rank_junior_cleaner.png")
		"orbital_cleaner":
			return preload("res://assets/original/ui/hq/generated/rank_orbital_cleaner.png")
		"senior_cleaner":
			return preload("res://assets/original/ui/hq/generated/rank_senior_cleaner.png")
		"sector_specialist":
			return preload("res://assets/original/ui/hq/generated/rank_sector_specialist.png")
		_:
			return preload("res://assets/original/ui/hq/generated/rank_deep_space_operator.png")

static func contract_preview(sector_id: String) -> Texture2D:
	if sector_id.begins_with("earth_"):
		return EARTH_PREVIEW
	if sector_id.begins_with("lunar_belt"):
		return LUNAR_PREVIEW
	if sector_id.begins_with("mars_freight"):
		return MARS_PREVIEW
	if sector_id.begins_with("blue_nebula"):
		return NEBULA_PREVIEW
	var base_id := sector_id
	var parts := sector_id.rsplit("_", false, 1)
	if parts.size() == 2 and String(parts[1]).is_valid_int():
		base_id = String(parts[0])
	var path := "res://assets/original/destinations/%s_hd.webp" % base_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return EARTH_PREVIEW
