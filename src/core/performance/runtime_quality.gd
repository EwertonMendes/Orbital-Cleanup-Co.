extends RefCounted
class_name RuntimeQuality

static func is_constrained_render_target() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")

static func star_count() -> int:
	return 760 if is_constrained_render_target() else 1450

static func soft_cloud_layers() -> int:
	return 3 if is_constrained_render_target() else 6

static func ambient_mote_cap() -> int:
	return 24 if is_constrained_render_target() else 38

static func ambient_redraw_interval() -> float:
	return 1.0 / 20.0 if is_constrained_render_target() else 1.0 / 30.0

static func environmental_field_redraw_interval() -> float:
	return 0.10 if is_constrained_render_target() else 1.0 / 15.0

static func use_screen_texture_post_process() -> bool:
	return not is_constrained_render_target()
