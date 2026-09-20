extends Control

const COMPACT_WIDTH := 820.0
const LANDSCAPE_REFERENCE := Vector2i(1280, 720)
const PORTRAIT_REFERENCE := Vector2i(720, 1280)

@onready var body: BoxContainer = %Body
@onready var safe_area: MarginContainer = %SafeArea
@onready var primary_action: Button = %PrimaryAction
@onready var contract_state: Label = %ContractState
@onready var contract_title: Label = %ContractTitle
@onready var contract_description: Label = %ContractDescription
@onready var cleanup_label: Label = %CleanupLabel
@onready var hazard_label: Label = %HazardLabel
@onready var payout_label: Label = %PayoutLabel
@onready var ship_heading: Label = %ShipHeading
@onready var ship_name: Label = %ShipName
@onready var beam_label: Label = %BeamLabel
@onready var cargo_label: Label = %CargoLabel
@onready var scanner_label: Label = %ScannerLabel
@onready var desk_label: Label = %DeskLabel
@onready var language_label: Label = %LanguageLabel
@onready var english_button: Button = %EnglishButton
@onready var portuguese_button: Button = %PortugueseButton
@onready var spanish_button: Button = %SpanishButton

var _context: Dictionary = {}
var _settings: SettingsService
var _platform: PlatformService
var _selected := false

func configure(context: Dictionary) -> void:
	_context = context
	_settings = context.get("settings") as SettingsService
	_platform = context.get("platform") as PlatformService

func _ready() -> void:
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	primary_action.pressed.connect(_toggle_contract_selection)
	english_button.pressed.connect(_change_locale.bind("en"))
	portuguese_button.pressed.connect(_change_locale.bind("pt_BR"))
	spanish_button.pressed.connect(_change_locale.bind("es_ES"))

	if _settings != null and not _settings.locale_changed.is_connected(_on_locale_changed):
		_settings.locale_changed.connect(_on_locale_changed)

	_apply_responsive_layout()
	_refresh_copy()

func _validate_contracts() -> void:
	assert(body != null, "Operations UI requires responsive Body.")
	assert(safe_area != null, "Operations UI requires SafeArea.")
	assert(primary_action != null, "Operations UI requires PrimaryAction.")
	assert(%ShipArt is TextureRect, "Operations UI requires ShipArt.")
	assert(english_button != null and portuguese_button != null and spanish_button != null, "Locale controls are required.")

func _apply_responsive_layout() -> void:
	var window_size := DisplayServer.window_get_size()
	var portrait := window_size.y > window_size.x
	_apply_reference_size(portrait)

	var compact := portrait or size.x < COMPACT_WIDTH
	body.vertical = compact
	var horizontal_margin := 22 if compact else 32
	var vertical_margin := 18 if compact else 24
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

func _apply_reference_size(portrait: bool) -> void:
	var root_window := get_tree().root
	var desired := PORTRAIT_REFERENCE if portrait else LANDSCAPE_REFERENCE
	if root_window.content_scale_size != desired:
		root_window.content_scale_size = desired

func _toggle_contract_selection() -> void:
	_selected = not _selected
	if _platform != null:
		_platform.track_event("training_contract_selection", {"selected": _selected})
	_refresh_copy()

func _change_locale(locale: String) -> void:
	if _settings != null:
		_settings.set_locale(locale)
	else:
		TranslationServer.set_locale(locale)
		_refresh_copy()

func _on_locale_changed(_locale: String) -> void:
	_refresh_copy()

func _refresh_copy() -> void:
	if not is_node_ready():
		return
	desk_label.text = tr("OPS_DESK")
	contract_state.text = tr("OPS_SELECTED") if _selected else tr("OPS_TRAINING")
	contract_title.text = tr("OPS_CONTRACT_TITLE")
	contract_description.text = tr("OPS_CONTRACT_DESCRIPTION")
	cleanup_label.text = tr("OPS_CLEANUP_TARGET")
	hazard_label.text = tr("OPS_HAZARD")
	payout_label.text = tr("OPS_PAYOUT")
	ship_heading.text = tr("OPS_SHIP_HEADING")
	ship_name.text = tr("OPS_SHIP_NAME")
	beam_label.text = tr("OPS_BEAM")
	cargo_label.text = tr("OPS_CARGO")
	scanner_label.text = tr("OPS_SCANNER")
	language_label.text = tr("OPS_LANGUAGE")
	primary_action.text = tr("OPS_UNSELECT") if _selected else tr("OPS_SELECT")
