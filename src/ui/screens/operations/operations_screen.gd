extends Control

const COMPACT_WIDTH := 820.0
const FLIGHT_SCREEN_PATH := "res://src/ui/screens/flight/flight_screen.tscn"
const DEFAULT_SECTOR_ID := "earth_training_01"

@onready var body: BoxContainer = %Body
@onready var header: BoxContainer = %Header
@onready var safe_area: MarginContainer = %SafeArea
@onready var primary_action: Button = %PrimaryAction
@onready var contract_state: Label = %ContractState
@onready var contract_title: Label = %ContractTitle
@onready var contract_description: Label = %ContractDescription
@onready var cleanup_label: Label = %CleanupLabel
@onready var cleanup_progress: ProgressBar = %CleanupProgress
@onready var hazard_label: Label = %HazardLabel
@onready var payout_label: Label = %PayoutLabel
@onready var last_result_label: Label = %LastResultLabel
@onready var ship_heading: Label = %ShipHeading
@onready var ship_name: Label = %ShipName
@onready var ship_visual: Control = %ShipVisual
@onready var beam_label: Label = %BeamLabel
@onready var cargo_label: Label = %CargoLabel
@onready var scanner_label: Label = %ScannerLabel
@onready var upgrades_label: Label = %UpgradesLabel
@onready var tractor_upgrade: Button = %TractorUpgrade
@onready var collection_upgrade: Button = %CollectionUpgrade
@onready var cargo_upgrade: Button = %CargoUpgrade
@onready var credits_label: Label = %CreditsLabel
@onready var rank_label: Label = %RankLabel
@onready var xp_label: Label = %XpLabel
@onready var desk_label: Label = %DeskLabel
@onready var language_label: Label = %LanguageLabel
@onready var english_button: Button = %EnglishButton
@onready var portuguese_button: Button = %PortugueseButton
@onready var spanish_button: Button = %SpanishButton

var _context: Dictionary = {}
var _settings: SettingsService
var _platform: PlatformService
var _router: SceneRouter
var _progression: ProgressionService
var _registry := ContentRegistry.new()
var _sector_plan: Dictionary = {}

func configure(context: Dictionary) -> void:
	_context = context
	_settings = context.get("settings") as SettingsService
	_platform = context.get("platform") as PlatformService
	_router = context.get("router") as SceneRouter
	_progression = context.get("progression") as ProgressionService
	assert(_progression != null, "OperationsScreen requires ProgressionService.")

	var scaler := DifficultyScaler.new()
	scaler.configure(_registry)
	var generator := SectorGenerator.new()
	generator.configure(_registry, scaler)
	_sector_plan = generator.generate(DEFAULT_SECTOR_ID)

func _ready() -> void:
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	primary_action.pressed.connect(_deploy_training)
	tractor_upgrade.pressed.connect(_purchase_upgrade.bind("tractor_range"))
	collection_upgrade.pressed.connect(_purchase_upgrade.bind("collection_speed"))
	cargo_upgrade.pressed.connect(_purchase_upgrade.bind("cargo_capacity"))
	english_button.pressed.connect(_change_locale.bind("en"))
	portuguese_button.pressed.connect(_change_locale.bind("pt_BR"))
	spanish_button.pressed.connect(_change_locale.bind("es_ES"))

	if _settings != null and not _settings.locale_changed.is_connected(_on_locale_changed):
		_settings.locale_changed.connect(_on_locale_changed)
	if not _progression.state_changed.is_connected(_on_progression_changed):
		_progression.state_changed.connect(_on_progression_changed)

	_apply_responsive_layout()
	_refresh_copy()

func _validate_contracts() -> void:
	assert(body != null, "Operations UI requires responsive Body.")
	assert(header != null, "Operations UI requires responsive Header.")
	assert(safe_area != null, "Operations UI requires SafeArea.")
	assert(primary_action != null, "Operations UI requires PrimaryAction.")
	assert(%ShipArt is TextureRect, "Operations UI requires ShipArt.")
	assert(credits_label != null and rank_label != null and xp_label != null, "Career summary is required.")
	assert(tractor_upgrade != null and collection_upgrade != null and cargo_upgrade != null, "Upgrade controls are required.")
	assert(english_button != null and portuguese_button != null and spanish_button != null, "Locale controls are required.")
	assert(not _sector_plan.is_empty(), "Operations UI requires sector data.")

func _apply_responsive_layout() -> void:
	var portrait := ResponsiveCanvas.apply_reference(get_tree().root)
	var compact := portrait or size.x < COMPACT_WIDTH
	body.vertical = compact
	header.vertical = compact
	ship_visual.visible = not compact
	var horizontal_margin := 22 if compact else 32
	var vertical_margin := 18 if compact else 24
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

func _deploy_training() -> void:
	assert(_router != null, "OperationsScreen requires SceneRouter to deploy.")
	var scene := load(FLIGHT_SCREEN_PATH) as PackedScene
	assert(scene != null, "Training flight screen must be loadable.")
	var flight_context := _context.duplicate()
	flight_context["sector_id"] = DEFAULT_SECTOR_ID
	_router.show_screen(scene, flight_context)

func _purchase_upgrade(upgrade_id: String) -> void:
	if _progression.purchase_upgrade(upgrade_id) and _platform != null:
		_platform.track_event("upgrade_purchased", {
			"upgrade_id": upgrade_id,
			"level": _progression.get_upgrade_level(upgrade_id),
		})

func _change_locale(locale: String) -> void:
	if _settings != null:
		_settings.set_locale(locale)
	else:
		TranslationServer.set_locale(locale)
		_refresh_copy()

func _on_locale_changed(_locale: String) -> void:
	_refresh_copy()

func _on_progression_changed(_snapshot: Dictionary) -> void:
	_refresh_progression()

func _refresh_copy() -> void:
	if not is_node_ready():
		return

	var sector := _sector_plan["sector"] as Dictionary
	var contract_ref := sector["contract"] as Dictionary
	var contract := _registry.get_contract(String(contract_ref["type"]))
	var params := _sector_plan["parameters"] as Dictionary
	var reward_multiplier := float(params.get("reward_multiplier", 1.0))
	var base_pay := int(round(float(contract["base_pay"]) * reward_multiplier))
	var perfect_bonus := int(round(float(contract["perfect_bonus"]) * reward_multiplier))

	desk_label.text = tr("OPS_DESK")
	contract_state.text = tr("OPS_TRAINING")
	contract_title.text = tr(String(sector["display_name_key"]))
	contract_description.text = tr("OPS_CONTRACT_DESCRIPTION")
	cleanup_label.text = tr("OPS_CLEANUP_TARGET_FMT") % int(round(float(contract_ref["target_percent"])))
	cleanup_progress.value = float(contract_ref["target_percent"])
	hazard_label.text = tr("OPS_HAZARD")
	payout_label.text = tr("OPS_PAYOUT_FMT") % [base_pay, perfect_bonus]
	ship_heading.text = tr("OPS_SHIP_HEADING")
	ship_name.text = tr("OPS_SHIP_NAME")
	scanner_label.text = tr("OPS_SCANNER")
	language_label.text = tr("OPS_LANGUAGE")
	upgrades_label.text = tr("OPS_UPGRADES")
	primary_action.text = tr("OPS_DEPLOY")
	_refresh_progression()

func _refresh_progression() -> void:
	if not is_node_ready():
		return

	credits_label.text = tr("OPS_CREDITS_FMT") % _progression.get_credits()
	rank_label.text = tr("OPS_RANK_FMT") % tr(_progression.get_rank_display_name_key())

	var rank_progress := _progression.get_rank_progress()
	if bool(rank_progress["is_max_rank"]):
		xp_label.text = tr("OPS_XP_MAX_FMT") % int(rank_progress["current_xp"])
	else:
		xp_label.text = tr("OPS_XP_FMT") % [
			int(rank_progress["current_xp"]),
			int(rank_progress["next_min_xp"]),
		]

	var ship := _progression.get_ship_modifiers()
	beam_label.text = tr("OPS_BEAM_FMT") % int(round(float(ship["scan_range"])))
	cargo_label.text = tr("OPS_CARGO_FMT") % int(round(float(ship["cargo_capacity"])))
	scanner_label.text = tr("OPS_SCANNER")

	_refresh_upgrade_button(tractor_upgrade, "tractor_range")
	_refresh_upgrade_button(collection_upgrade, "collection_speed")
	_refresh_upgrade_button(cargo_upgrade, "cargo_capacity")
	_refresh_last_result()

func _refresh_upgrade_button(button: Button, upgrade_id: String) -> void:
	var definition := _find_upgrade(upgrade_id)
	var level := _progression.get_upgrade_level(upgrade_id)
	var max_level := int(definition["max_level"])
	var name := tr(String(definition["display_name_key"]))

	if level >= max_level:
		button.text = tr("OPS_UPGRADE_MAX_FMT") % [name, level]
		button.disabled = true
		return

	var cost := _progression.get_upgrade_cost(upgrade_id)
	button.text = tr("OPS_UPGRADE_BUTTON_FMT") % [name, level, level + 1, cost]
	button.disabled = not _progression.can_purchase_upgrade(upgrade_id)
	button.tooltip_text = tr(String(definition["description_key"]))

func _refresh_last_result() -> void:
	var result := _progression.get_last_contract_result()
	last_result_label.visible = not result.is_empty()
	if result.is_empty():
		return

	if bool(result.get("perfect_cleanup", false)):
		last_result_label.text = tr("OPS_LAST_RESULT_PERFECT_FMT") % [
			int(result.get("credits_awarded", 0)),
			int(result.get("xp_awarded", 0)),
		]
	else:
		last_result_label.text = tr("OPS_LAST_RESULT_FMT") % [
			int(result.get("credits_awarded", 0)),
			int(result.get("xp_awarded", 0)),
		]

func _find_upgrade(upgrade_id: String) -> Dictionary:
	for value in _progression.get_upgrade_definitions():
		var definition := value as Dictionary
		if String(definition["id"]) == upgrade_id:
			return definition
	assert(false, "Unknown upgrade: %s" % upgrade_id)
	return {}
