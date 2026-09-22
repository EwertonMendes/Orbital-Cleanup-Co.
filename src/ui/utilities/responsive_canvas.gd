extends RefCounted
class_name ResponsiveCanvas

const LANDSCAPE_REFERENCE := Vector2i(1280, 720)
const PORTRAIT_REFERENCE := Vector2i(720, 1280)

static func viewport_size() -> Vector2i:
	if OS.has_feature("web"):
		var browser_window := JavaScriptBridge.get_interface("window")
		if browser_window != null:
			var width := int(round(float(browser_window.innerWidth)))
			var height := int(round(float(browser_window.innerHeight)))
			if width > 0 and height > 0:
				return Vector2i(width, height)
	return DisplayServer.window_get_size()

static func apply_reference(root_window: Window) -> bool:
	assert(root_window != null, "ResponsiveCanvas requires a root Window.")
	var window_size := viewport_size()
	var portrait := window_size.y > window_size.x
	var desired := PORTRAIT_REFERENCE if portrait else LANDSCAPE_REFERENCE
	if root_window.content_scale_size != desired:
		root_window.content_scale_size = desired
	return portrait
