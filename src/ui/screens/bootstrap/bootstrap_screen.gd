extends Control

@onready var eyebrow_label: Label = %EyebrowLabel
@onready var slogan_label: Label = %SloganLabel
@onready var foundation_label: Label = %FoundationLabel
@onready var status_label: Label = %StatusLabel
@onready var message_label: Label = %MessageLabel
@onready var language_label: Label = %LanguageLabel
@onready var build_label: Label = %BuildLabel
@onready var provider_label: Label = %ProviderLabel
@onready var english_button: Button = %EnglishButton
@onready var portuguese_button: Button = %PortugueseButton
@onready var spanish_button: Button = %SpanishButton

var _provider_name := "debug"
var _build_version := "0.0.0-dev"
var _commit := "local"

func _ready() -> void:
	print("[OCC] BOOT")
	english_button.pressed.connect(_set_locale.bind("en"))
	portuguese_button.pressed.connect(_set_locale.bind("pt_BR"))
	spanish_button.pressed.connect(_set_locale.bind("es_ES"))
	_apply_initial_locale()
	await get_tree().process_frame
	_read_web_runtime()
	_refresh_copy()
	print("[OCC] READY")

func _apply_initial_locale() -> void:
	var current := TranslationServer.get_locale()
	if current.begins_with("pt"):
		TranslationServer.set_locale("pt_BR")
	elif current.begins_with("es"):
		TranslationServer.set_locale("es_ES")
	else:
		TranslationServer.set_locale("en")
	_refresh_copy()

func _set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_refresh_copy()

func _read_web_runtime() -> void:
	if not OS.has_feature("web"):
		_provider_name = "debug-native"
		return

	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return

	var platform = window.OCCPlatform
	if platform != null:
		platform.initialize()
		_provider_name = str(platform.getProviderName())

	var build = window.OCC_BUILD
	if build != null:
		_build_version = str(build.version)
		_commit = str(build.commit)

func _refresh_copy() -> void:
	if not is_node_ready():
		return
	eyebrow_label.text = tr("BOOTSTRAP_EYEBROW")
	slogan_label.text = tr("BOOTSTRAP_SLOGAN")
	foundation_label.text = tr("BOOTSTRAP_FOUNDATION")
	status_label.text = tr("BOOTSTRAP_STATUS") % [_provider_name, _short_commit()]
	message_label.text = tr("BOOTSTRAP_MESSAGE")
	language_label.text = tr("BOOTSTRAP_LANGUAGE")
	provider_label.text = "%s: %s" % [tr("BOOTSTRAP_PROVIDER"), _provider_name]
	build_label.text = "%s: %s" % [tr("BOOTSTRAP_BUILD"), _build_version]

func _short_commit() -> String:
	if _commit.length() <= 8:
		return _commit
	return _commit.substr(0, 8)
