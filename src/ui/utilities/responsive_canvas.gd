extends RefCounted
class_name ResponsiveCanvas

const LANDSCAPE_REFERENCE := Vector2i(1280, 720)
const PORTRAIT_REFERENCE := Vector2i(720, 1280)

static func apply_reference(root_window: Window) -> bool:
	assert(root_window != null, "ResponsiveCanvas requires a root Window.")
	var window_size := DisplayServer.window_get_size()
	var portrait := window_size.y > window_size.x
	var desired := PORTRAIT_REFERENCE if portrait else LANDSCAPE_REFERENCE
	if root_window.content_scale_size != desired:
		root_window.content_scale_size = desired
	return portrait
