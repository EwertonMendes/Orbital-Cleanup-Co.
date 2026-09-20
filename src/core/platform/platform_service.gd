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
