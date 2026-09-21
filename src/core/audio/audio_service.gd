extends Node
class_name AudioService

const UI_HOVER := preload("res://assets/third_party/kenney_interface_sounds/audio/select_003.ogg")
const UI_CLICK := preload("res://assets/third_party/kenney_interface_sounds/audio/click_001.ogg")
const UI_BACK := preload("res://assets/third_party/kenney_interface_sounds/audio/back_001.ogg")

var _settings: SettingsService
var _external_pause_depth := 0
var _ui_player: AudioStreamPlayer
var _last_hover_msec := -1000

func initialize(settings: SettingsService) -> void:
	assert(settings != null, "AudioService requires SettingsService.")
	_settings = settings
	_settings.audio_changed.connect(_apply_master_volume)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiPlayer"
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_player)
	_apply_master_volume(_settings.master_audio_linear)

func set_master_linear(value: float) -> void:
	assert(_settings != null, "AudioService must be initialized before use.")
	_settings.set_master_audio_linear(value)

func play_ui_hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < 70:
		return
	_last_hover_msec = now
	_play_ui(UI_HOVER, -13.0)

func play_ui_click() -> void:
	_play_ui(UI_CLICK, -9.0)

func play_ui_back() -> void:
	_play_ui(UI_BACK, -10.0)

func pause_for_external() -> void:
	_external_pause_depth += 1
	_apply_master_volume(_settings.master_audio_linear if _settings != null else 1.0)

func resume_from_external() -> void:
	_external_pause_depth = maxi(0, _external_pause_depth - 1)
	_apply_master_volume(_settings.master_audio_linear if _settings != null else 1.0)

func is_externally_paused() -> bool:
	return _external_pause_depth > 0

func _play_ui(stream: AudioStream, volume_db: float) -> void:
	if _ui_player == null or _external_pause_depth > 0:
		return
	_ui_player.stop()
	_ui_player.stream = stream
	_ui_player.volume_db = volume_db
	_ui_player.play()

func _apply_master_volume(linear: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	assert(bus_index >= 0, "Godot Master audio bus is required.")
	var db := -80.0 if linear <= 0.0001 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(bus_index, db)
	AudioServer.set_bus_mute(bus_index, linear <= 0.0001 or _external_pause_depth > 0)
