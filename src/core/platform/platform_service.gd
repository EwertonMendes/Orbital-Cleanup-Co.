extends Node
class_name PlatformService

var provider_name := "debug-native"
var _platform = null

func initialize() -> void:
	if not OS.has_feature("web"):
		return

	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		push_warning("PlatformService could not access the browser window.")
		return

	_platform = window.OCCPlatform
	if _platform == null:
		push_warning("OCCPlatform is missing; platform features remain unavailable.")
		return

	_platform.initialize()
	provider_name = str(_platform.getProviderName())

func is_feature_available(feature: String) -> bool:
	if _platform == null:
		return false
	return bool(_platform.isFeatureAvailable(feature))

func gameplay_started() -> void:
	if _platform != null:
		_platform.gameplayStarted()

func gameplay_stopped() -> void:
	if _platform != null:
		_platform.gameplayStopped()

func track_event(event_name: String, payload: Dictionary = {}) -> void:
	if _platform != null:
		_platform.trackEvent(event_name, payload)

func show_interstitial(placement: String) -> void:
	if _platform != null:
		_platform.showInterstitial(placement)

func show_rewarded(placement: String) -> void:
	if _platform != null:
		_platform.showRewarded(placement)

func pause_external_audio() -> void:
	if _platform != null:
		_platform.pauseExternalAudio()

func resume_external_audio() -> void:
	if _platform != null:
		_platform.resumeExternalAudio()


func is_debug_provider() -> bool:
	return provider_name.begins_with("debug")

func get_query_parameter(name: String) -> String:
	if name.is_empty():
		return ""
	return String(get_query_parameters().get(name, ""))

func get_query_parameters() -> Dictionary:
	var output: Dictionary = {}
	if not OS.has_feature("web"):
		return output

	var window := JavaScriptBridge.get_interface("window")
	if window == null or window.location == null:
		return output

	var search := str(window.location.search)
	if search.begins_with("?"):
		search = search.substr(1)
	if search.is_empty():
		return output

	for pair in search.split("&", false):
		var parts := pair.split("=", false, 1)
		var key := String(parts[0])
		if key.is_empty():
			continue
		var value := String(parts[1]) if parts.size() > 1 else ""
		output[key] = value
	return output
