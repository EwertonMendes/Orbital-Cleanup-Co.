extends Node
class_name AdService

signal ad_active_changed(active: bool)

const REAL_PROVIDER_INITIAL_GRACE_MS := 90000
const REAL_PROVIDER_INTERSTITIAL_COOLDOWN_MS := 90000

var _platform: PlatformService
var _audio: AudioService
var _busy := false
var _ad_active := false
var _active_request_id := ""
var _tree_was_paused := false
var _session_started_ms := 0
var _last_interstitial_ms := -1
var _results: Dictionary = {}

func initialize(platform: PlatformService, audio: AudioService) -> void:
	assert(platform != null, "AdService requires PlatformService.")
	assert(audio != null, "AdService requires AudioService.")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_platform = platform
	_audio = audio
	_session_started_ms = Time.get_ticks_msec()
	_platform.ad_started.connect(_on_ad_started)
	_platform.ad_result.connect(_on_ad_result)

func is_busy() -> bool:
	return _busy

func show_contract_break() -> Dictionary:
	if not _platform.is_feature_available("interstitial"):
		return _skipped("interstitial", "contract_complete", "unsupported")

	var now := Time.get_ticks_msec()
	if not _platform.is_debug_provider():
		if now - _session_started_ms < REAL_PROVIDER_INITIAL_GRACE_MS:
			return _skipped("interstitial", "contract_complete", "initial_grace")
		if _last_interstitial_ms >= 0 and now - _last_interstitial_ms < REAL_PROVIDER_INTERSTITIAL_COOLDOWN_MS:
			return _skipped("interstitial", "contract_complete", "cooldown")

	var result := await show_interstitial("contract_complete")
	if bool(result.get("completed", false)):
		_last_interstitial_ms = Time.get_ticks_msec()
	return result

func show_interstitial(placement: String) -> Dictionary:
	return await _request_ad("interstitial", placement)

func show_rewarded(placement: String) -> Dictionary:
	return await _request_ad("rewarded", placement)

func _request_ad(kind: String, placement: String) -> Dictionary:
	if _busy:
		return _skipped(kind, placement, "busy")
	if not _platform.is_feature_available(kind):
		return _skipped(kind, placement, "unsupported")

	_busy = true
	var request_id := (
		_platform.show_rewarded(placement)
		if kind == "rewarded"
		else _platform.show_interstitial(placement)
	)
	if request_id.is_empty():
		_busy = false
		return _skipped(kind, placement, "request_failed")

	while not _results.has(request_id):
		await _platform.ad_result

	var result := (_results[request_id] as Dictionary).duplicate(true)
	_results.erase(request_id)
	_busy = false
	return result

func _on_ad_started(details: Dictionary) -> void:
	var request_id := String(details.get("requestId", ""))
	if request_id.is_empty() or _ad_active:
		return
	_ad_active = true
	_active_request_id = request_id
	_tree_was_paused = get_tree().paused
	_audio.pause_for_external()
	get_tree().paused = true
	ad_active_changed.emit(true)
	print("[Ads] START kind=%s placement=%s provider=%s" % [
		String(details.get("kind", "")),
		String(details.get("placement", "")),
		String(details.get("provider", "")),
	])

func _on_ad_result(result: Dictionary) -> void:
	var request_id := String(result.get("requestId", ""))
	if not request_id.is_empty():
		_results[request_id] = result.duplicate(true)

	if _ad_active and request_id == _active_request_id:
		_audio.resume_from_external()
		get_tree().paused = _tree_was_paused
		_ad_active = false
		_active_request_id = ""
		ad_active_changed.emit(false)

	print("[Ads] RESULT kind=%s placement=%s completed=%s rewarded=%s reason=%s" % [
		String(result.get("kind", "")),
		String(result.get("placement", "")),
		str(bool(result.get("completed", false))),
		str(bool(result.get("rewarded", false))),
		String(result.get("reason", "")),
	])

func _skipped(kind: String, placement: String, reason: String) -> Dictionary:
	return {
		"provider": _platform.provider_name if _platform != null else "none",
		"kind": kind,
		"placement": placement,
		"completed": false,
		"rewarded": false,
		"reason": reason,
		"skipped": true,
	}
