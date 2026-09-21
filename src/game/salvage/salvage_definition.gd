extends Resource
class_name SalvageDefinition

const MOTION_PROFILES := [&"tumble", &"drift", &"heavy", &"stable", &"pulse", &"spin"]
const EFFECT_PROFILES := [&"none", &"spark", &"scan", &"pulse", &"orbit"]

@export var id: StringName
@export var display_name_key: StringName
@export var sprite: Texture2D
@export var category: StringName = &"scrap"
@export var rarity: StringName = &"common"
@export_range(0, 100000, 1) var base_value := 10
@export_range(0.1, 20.0, 0.1) var mass := 1.0
@export_range(0.1, 10.0, 0.05) var collect_duration := 0.8
@export_range(0.0, 100.0, 0.1) var cleanliness_value := 1.0
@export_range(1, 12, 1) var cargo_units := 1
@export_range(0.2, 4.0, 0.05) var visual_scale := 1.0
@export_range(6.0, 120.0, 1.0) var collision_radius := 22.0
@export var motion_profile: StringName = &"tumble"
@export var effect_profile: StringName = &"none"
@export_range(0.0, 2.5, 0.05) var spin_multiplier := 1.0
@export_range(0.0, 8.0, 0.1) var float_amplitude := 3.0
@export var tags := PackedStringArray()

func validate() -> void:
	assert(not id.is_empty(), "SalvageDefinition.id is required.")
	assert(not display_name_key.is_empty(), "SalvageDefinition.display_name_key is required.")
	assert(sprite != null, "SalvageDefinition.sprite is required.")
	assert(base_value >= 0, "SalvageDefinition.base_value cannot be negative.")
	assert(mass > 0.0, "SalvageDefinition.mass must be positive.")
	assert(collect_duration > 0.0, "SalvageDefinition.collect_duration must be positive.")
	assert(cargo_units > 0, "SalvageDefinition.cargo_units must be positive.")
	assert(collision_radius > 0.0, "SalvageDefinition.collision_radius must be positive.")
	assert(motion_profile in MOTION_PROFILES, "SalvageDefinition.motion_profile is invalid.")
	assert(effect_profile in EFFECT_PROFILES, "SalvageDefinition.effect_profile is invalid.")
	assert(spin_multiplier >= 0.0 and spin_multiplier <= 2.5, "SalvageDefinition.spin_multiplier is out of range.")
	assert(float_amplitude >= 0.0 and float_amplitude <= 8.0, "SalvageDefinition.float_amplitude is out of range.")
