extends Node
class_name AudioService

var _settings: SettingsService

func initialize(settings: SettingsService) -> void:
	assert(settings != null, "AudioService requires SettingsService.")
	_settings = settings
	_settings.audio_changed.connect(_apply_master_volume)
	_apply_master_volume(_settings.master_audio_linear)

func set_master_linear(value: float) -> void:
	assert(_settings != null, "AudioService must be initialized before use.")
	_settings.set_master_audio_linear(value)

func _apply_master_volume(linear: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	assert(bus_index >= 0, "Godot Master audio bus is required.")
	var db := -80.0 if linear <= 0.0001 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(bus_index, db)
	AudioServer.set_bus_mute(bus_index, linear <= 0.0001)
