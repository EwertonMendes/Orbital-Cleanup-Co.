extends RefCounted
class_name RuntimeQuality

const EFFECTS_LOW := 0
const EFFECTS_MEDIUM := 1
const EFFECTS_HIGH := 2

static func is_constrained_render_target() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")

static func is_mobile_render_target() -> bool:
	return OS.has_feature("mobile")

static func visual_effects_level() -> int:
	if is_mobile_render_target():
		return EFFECTS_LOW
	if OS.has_feature("web"):
		return EFFECTS_MEDIUM
	return EFFECTS_HIGH

static func visual_effects_level_name() -> String:
	match visual_effects_level():
		EFFECTS_LOW:
			return "low"
		EFFECTS_MEDIUM:
			return "medium"
		_:
			return "high"

static func visual_effects_factor() -> float:
	match visual_effects_level():
		EFFECTS_LOW:
			return 0.55
		EFFECTS_MEDIUM:
			return 0.78
		_:
			return 1.0

static func star_count() -> int:
	return 760 if is_constrained_render_target() else 1450

static func soft_cloud_layers() -> int:
	return 3 if is_constrained_render_target() else 6

static func ambient_mote_cap() -> int:
	return 24 if is_constrained_render_target() else 38

static func environmental_vfx_particle_cap() -> int:
	match visual_effects_level():
		EFFECTS_LOW:
			return 24
		EFFECTS_MEDIUM:
			return 42
		_:
			return 64

static func ambient_redraw_interval() -> float:
	return 1.0 / 20.0 if is_constrained_render_target() else 1.0 / 30.0

static func environmental_vfx_redraw_interval() -> float:
	match visual_effects_level():
		EFFECTS_LOW:
			return 1.0 / 18.0
		EFFECTS_MEDIUM:
			return 1.0 / 24.0
		_:
			return 1.0 / 30.0

static func environmental_field_redraw_interval() -> float:
	return 0.10 if is_constrained_render_target() else 1.0 / 15.0

static func use_screen_texture_post_process() -> bool:
	# Desktop Web keeps the single-fetch compositor. Mobile uses the lightweight fallback.
	return not is_mobile_render_target()
