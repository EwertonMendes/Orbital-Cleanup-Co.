extends RefCounted
class_name ResponsiveCanvas

const LANDSCAPE_REFERENCE := Vector2i(1280, 720)
const PORTRAIT_REFERENCE := Vector2i(720, 1280)

static func viewport_size() -> Vector2i:
	if OS.has_feature("web"):
		var browser_window := JavaScriptBridge.get_interface("window")
		if browser_window != null:
			var visual_viewport = browser_window.visualViewport
			if visual_viewport != null:
				var visual_width := int(round(float(visual_viewport.width)))
				var visual_height := int(round(float(visual_viewport.height)))
				if visual_width > 0 and visual_height > 0:
					return Vector2i(visual_width, visual_height)

			var width := int(round(float(browser_window.innerWidth)))
			var height := int(round(float(browser_window.innerHeight)))
			if width > 0 and height > 0:
				return Vector2i(width, height)
	return DisplayServer.window_get_size()

static func prefers_touch_layout() -> bool:
	if OS.has_feature("mobile"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		var browser_navigator := JavaScriptBridge.get_interface("navigator")
		if browser_navigator != null:
			var max_touch_points := int(browser_navigator.maxTouchPoints)
			if max_touch_points > 0:
				return true
	return false

static func apply_reference(root_window: Window) -> bool:
	assert(root_window != null, "ResponsiveCanvas requires a root Window.")
	var window_size := viewport_size()
	var portrait := window_size.y > window_size.x
	var desired := PORTRAIT_REFERENCE if portrait else LANDSCAPE_REFERENCE
	if root_window.content_scale_size != desired:
		root_window.content_scale_size = desired
	return portrait
