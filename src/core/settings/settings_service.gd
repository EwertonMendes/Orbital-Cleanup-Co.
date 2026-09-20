extends Node
class_name SettingsService

signal locale_changed(locale: String)
signal audio_changed(master_linear: float)

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := ["en", "pt_BR", "es_ES"]

var locale := "en"
var master_audio_linear := 0.82

func initialize() -> void:
	var config := ConfigFile.new()
	var load_result := config.load(SETTINGS_PATH)
	if load_result == OK:
		locale = str(config.get_value("general", "locale", locale))
		master_audio_linear = float(config.get_value("audio", "master_linear", master_audio_linear))
	else:
		locale = _normalized_system_locale()

	if not SUPPORTED_LOCALES.has(locale):
		locale = "en"

	TranslationServer.set_locale(locale)

func set_locale(next_locale: String) -> void:
	assert(SUPPORTED_LOCALES.has(next_locale), "Unsupported locale: %s" % next_locale)
	if locale == next_locale:
		return
	locale = next_locale
	TranslationServer.set_locale(locale)
	_save()
	locale_changed.emit(locale)

func set_master_audio_linear(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(master_audio_linear, clamped):
		return
	master_audio_linear = clamped
	_save()
	audio_changed.emit(master_audio_linear)

func _normalized_system_locale() -> String:
	var current := TranslationServer.get_locale()
	if current.begins_with("pt"):
		return "pt_BR"
	if current.begins_with("es"):
		return "es_ES"
	return "en"

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("audio", "master_linear", master_audio_linear)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Could not save settings: %s" % error)
