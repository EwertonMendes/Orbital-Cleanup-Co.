extends Control

enum Tab {
	CONTRACTS,
	UPGRADES,
	CAREER,
	SHIP,
	DISCOVERY,
}

const COMPACT_WIDTH := 700.0
const FLIGHT_SCREEN_PATH := "res://src/ui/screens/flight/flight_screen.tscn"
const DEFAULT_SECTOR_ID := "earth_training_01"
const UPGRADE_CARD_SCENE := preload("res://src/ui/components/hq_upgrade_card.tscn")
const RANK_ROW_SCENE := preload("res://src/ui/components/hq_rank_row.tscn")
const CHROME_BUTTON_SCENE := preload("res://src/ui/components/occ_chrome_button.tscn")
const DISCOVERY_CARD_SCENE := preload("res://src/ui/components/hq_discovery_card.tscn")

@onready var safe_area: MarginContainer = %SafeArea
@onready var header: BoxContainer = %Header
@onready var tab_grid: GridContainer = %TabGrid
@onready var content_scroll: ScrollContainer = %ContentScroll
@onready var content_shell: Control = %ContentShell
@onready var contracts_panel: VBoxContainer = %ContractsPanel
@onready var upgrades_panel: VBoxContainer = %UpgradesPanel
@onready var career_panel: VBoxContainer = %CareerPanel
@onready var ship_panel: VBoxContainer = %ShipPanel
@onready var discovery_panel: VBoxContainer = %DiscoveryPanel
@onready var contract_hero: BoxContainer = %ContractHero
@onready var ship_body: BoxContainer = %ShipBody
@onready var primary_action: Button = %PrimaryAction
@onready var footer: Control = %Footer
@onready var upgrade_grid: GridContainer = %UpgradeGrid
@onready var career_list: VBoxContainer = %CareerList
@onready var credits_label: Label = %CreditsLabel
@onready var rank_label: Label = %RankLabel
@onready var xp_label: Label = %XpLabel
@onready var career_rank_value: Label = %CareerRankValue
@onready var career_xp_label: Label = %CareerXpLabel
@onready var career_xp_bar: ProgressBar = %CareerXpBar
@onready var contract_state: Label = %ContractState
@onready var contract_selector: GridContainer = %ContractSelector
@onready var contract_position: Label = %ContractPosition
@onready var previous_contract: Button = %PreviousContract
@onready var endless_contract: Button = %EndlessContract
@onready var next_contract: Button = %NextContract
@onready var contract_title: Label = %ContractTitle
@onready var contract_description: Label = %ContractDescription
@onready var contract_target: Label = %ContractTarget
@onready var contract_risk: Label = %ContractRisk
@onready var contract_payout: Label = %ContractPayout
@onready var last_result: Label = %LastResult
@onready var ship_stats: Label = %ShipStats
@onready var ship_preview: TextureRect = %ShipPreview
@onready var contract_ship_art: TextureRect = %ShipArt
@onready var hull_options: GridContainer = %HullOptions
@onready var paint_options: GridContainer = %PaintOptions
@onready var trail_options: GridContainer = %TrailOptions
@onready var beam_options: GridContainer = %BeamOptions
@onready var discovery_count: Label = %DiscoveryCount
@onready var completed_contracts: Label = %CompletedContracts
@onready var discovery_empty_card: PanelContainer = %DiscoveryEmptyCard
@onready var discovery_list: VBoxContainer = %DiscoveryList
@onready var english_button: Button = %EnglishButton
@onready var portuguese_button: Button = %PortugueseButton
@onready var spanish_button: Button = %SpanishButton
@onready var contracts_tab: Button = %ContractsTab
@onready var upgrades_tab: Button = %UpgradesTab
@onready var career_tab: Button = %CareerTab
@onready var ship_tab: Button = %ShipTab
@onready var discovery_tab: Button = %DiscoveryTab

var _context: Dictionary = {}
var _settings: SettingsService
var _platform: PlatformService
var _router: SceneRouter
var _progression: ProgressionService
var _registry := ContentRegistry.new()
var _generator := SectorGenerator.new()
var _endless_generator := EndlessContractGenerator.new()
var _sector_ids := PackedStringArray()
var _selected_sector_index := 0
var _viewing_endless := false
var _endless_number := 1
var _active_sector_definition: Dictionary = {}
var _sector_plan: Dictionary = {}
var _active_tab := Tab.CONTRACTS
var _tab_group := ButtonGroup.new()

func configure(context: Dictionary) -> void:
	_context = context
	_settings = context.get("settings") as SettingsService
	_platform = context.get("platform") as PlatformService
	_router = context.get("router") as SceneRouter
	_progression = context.get("progression") as ProgressionService
	assert(_progression != null, "OperationsScreen requires ProgressionService.")
	assert(_router != null, "OperationsScreen requires SceneRouter.")

	var scaler := DifficultyScaler.new()
	scaler.configure(_registry)
	_generator.configure(_registry, scaler)
	_endless_generator.configure(_registry)
	_sector_ids = _registry.list_sector_ids()
	assert(not _sector_ids.is_empty(), "Headquarters requires at least one authored sector.")
	var preferred_index := _sector_ids.find(DEFAULT_SECTOR_ID)
	_selected_sector_index = preferred_index if preferred_index >= 0 else 0
	_load_selected_sector()

func _ready() -> void:
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	primary_action.pressed.connect(_deploy_training)
	previous_contract.pressed.connect(_select_relative_contract.bind(-1))
	endless_contract.pressed.connect(_toggle_endless_mode)
	next_contract.pressed.connect(_select_relative_contract.bind(1))

	_setup_tabs()
	english_button.pressed.connect(_change_locale.bind("en"))
	portuguese_button.pressed.connect(_change_locale.bind("pt_BR"))
	spanish_button.pressed.connect(_change_locale.bind("es_ES"))

	if _settings != null and not _settings.locale_changed.is_connected(_on_locale_changed):
		_settings.locale_changed.connect(_on_locale_changed)
	if not _progression.state_changed.is_connected(_on_progression_changed):
		_progression.state_changed.connect(_on_progression_changed)

	_apply_responsive_layout()
	_refresh_all()
	_show_tab(Tab.CONTRACTS)
	print("[HQ] READY tab=contracts")

func _validate_contracts() -> void:
	assert(safe_area != null, "Headquarters requires SafeArea.")
	assert(header != null, "Headquarters requires responsive Header.")
	assert(tab_grid != null, "Headquarters requires TabGrid.")
	assert(content_scroll != null, "Headquarters requires ContentScroll.")
	assert(content_shell != null, "Headquarters requires ContentShell.")
	assert(primary_action != null, "Headquarters requires PrimaryAction.")
	assert(contract_selector != null, "Headquarters requires responsive ContractSelector.")
	assert(previous_contract != null and endless_contract != null and next_contract != null and contract_position != null, "Headquarters requires contract navigation.")
	assert(upgrade_grid != null, "Headquarters requires UpgradeGrid.")
	assert(career_list != null, "Headquarters requires CareerList.")
	assert(ship_preview != null and contract_ship_art != null, "Headquarters requires cosmetic ship previews.")
	assert(hull_options != null and paint_options != null and trail_options != null and beam_options != null, "Headquarters requires cosmetic option grids.")
	assert(contracts_panel != null and upgrades_panel != null and career_panel != null, "Headquarters core panels are required.")
	assert(ship_panel != null and discovery_panel != null, "Headquarters future-facing panels are required.")
	assert(discovery_empty_card != null and discovery_list != null, "Headquarters discovery catalog containers are required.")
	assert(not _sector_plan.is_empty(), "Headquarters requires sector data.")

func _setup_tabs() -> void:
	var tabs := [
		{"button": contracts_tab, "tab": Tab.CONTRACTS},
		{"button": upgrades_tab, "tab": Tab.UPGRADES},
		{"button": career_tab, "tab": Tab.CAREER},
		{"button": ship_tab, "tab": Tab.SHIP},
		{"button": discovery_tab, "tab": Tab.DISCOVERY},
	]
	for entry_variant in tabs:
		var entry := entry_variant as Dictionary
		var button := entry["button"] as Button
		var tab := int(entry["tab"])
		button.toggle_mode = true
		button.button_group = _tab_group
		button.pressed.connect(_show_tab.bind(tab))
	contracts_tab.button_pressed = true

func _show_tab(tab: int) -> void:
	_active_tab = tab
	contracts_panel.visible = tab == Tab.CONTRACTS
	upgrades_panel.visible = tab == Tab.UPGRADES
	career_panel.visible = tab == Tab.CAREER
	ship_panel.visible = tab == Tab.SHIP
	discovery_panel.visible = tab == Tab.DISCOVERY
	footer.visible = tab == Tab.CONTRACTS
	content_scroll.scroll_vertical = 0

	match tab:
		Tab.UPGRADES:
			_refresh_upgrades()
		Tab.CAREER:
			_refresh_career()
		Tab.SHIP:
			_refresh_ship()
		Tab.DISCOVERY:
			_refresh_discovery()

func _apply_responsive_layout() -> void:
	var portrait := ResponsiveCanvas.apply_reference(get_tree().root)
	var compact := portrait or size.x < COMPACT_WIDTH
	header.vertical = compact
	contract_hero.vertical = compact
	ship_body.vertical = compact
	tab_grid.columns = 3 if compact else 5
	contract_selector.columns = 2 if compact else 4
	upgrade_grid.columns = 1 if compact else 3
	content_shell.custom_minimum_size.y = 150.0 if size.y < 500.0 else 260.0

	var horizontal_margin := 14 if compact else 28
	var vertical_margin := 12 if compact else 20
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

func _deploy_training() -> void:
	var scene := load(FLIGHT_SCREEN_PATH) as PackedScene
	assert(scene != null, "Training flight screen must be loadable.")
	var flight_context := _context.duplicate(true)
	if _viewing_endless:
		flight_context["sector_id"] = String(_active_sector_definition["id"])
		flight_context["sector_definition"] = _active_sector_definition.duplicate(true)
		flight_context["endless_number"] = _endless_number
	else:
		flight_context["sector_id"] = String(_sector_ids[_selected_sector_index])
	_router.show_screen(scene, flight_context)

func _select_relative_contract(delta: int) -> void:
	if _viewing_endless:
		_endless_number = maxi(1, _endless_number + delta)
		_load_endless_contract()
		_refresh_contracts()
		return

	if _sector_ids.size() <= 1:
		return
	_selected_sector_index = (_selected_sector_index + delta) % _sector_ids.size()
	if _selected_sector_index < 0:
		_selected_sector_index += _sector_ids.size()
	_load_selected_sector()
	_refresh_contracts()

func _toggle_endless_mode() -> void:
	if _viewing_endless:
		_load_selected_sector()
	else:
		_viewing_endless = true
		_endless_number = maxi(1, _completed_contract_total() + 1)
		_load_endless_contract()
	_refresh_contracts()

func _load_selected_sector() -> void:
	assert(_selected_sector_index >= 0 and _selected_sector_index < _sector_ids.size(), "Selected sector index is out of bounds.")
	_viewing_endless = false
	_active_sector_definition = {}
	_sector_plan = _generator.generate(String(_sector_ids[_selected_sector_index]))

func _load_endless_contract() -> void:
	_viewing_endless = true
	_active_sector_definition = _endless_generator.create_sector_definition(_endless_number)
	_sector_plan = _generator.generate_definition(_active_sector_definition)

func _completed_contract_total() -> int:
	var snapshot := _progression.get_snapshot()
	var completed := snapshot.get("completed_contracts", {}) as Dictionary
	var total := 0
	for value in completed.values():
		total += int(value)
	return total

func _risk_key(difficulty: int) -> String:
	if difficulty <= 3:
		return "HQ_RISK_LOW"
	if difficulty <= 6:
		return "HQ_RISK_MODERATE"
	if difficulty <= 9:
		return "HQ_RISK_ELEVATED"
	return "HQ_RISK_HIGH"

func _change_locale(locale: String) -> void:
	if _settings != null:
		_settings.set_locale(locale)
	else:
		TranslationServer.set_locale(locale)
		_refresh_all()

func _on_locale_changed(_locale: String) -> void:
	_refresh_all()

func _on_progression_changed(_snapshot: Dictionary) -> void:
	_refresh_all()

func _refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_header()
	_refresh_tabs()
	_refresh_contracts()
	_refresh_upgrades()
	_refresh_career()
	_refresh_ship()
	_refresh_discovery()

func _refresh_header() -> void:
	%CompanyLabel.text = tr("HQ_COMPANY")
	%DeskLabel.text = tr("HQ_DESK")
	credits_label.text = tr("HQ_CREDITS_FMT") % _progression.get_credits()
	rank_label.text = tr("HQ_RANK_FMT") % tr(_progression.get_rank_display_name_key())

	var progress := _progression.get_rank_progress()
	if bool(progress["is_max_rank"]):
		xp_label.text = tr("HQ_XP_MAX_FMT") % int(progress["current_xp"])
	else:
		xp_label.text = tr("HQ_XP_FMT") % [int(progress["current_xp"]), int(progress["next_min_xp"])]
	%LanguageLabel.text = tr("HQ_LANGUAGE")

func _refresh_tabs() -> void:
	contracts_tab.text = tr("HQ_TAB_CONTRACTS")
	upgrades_tab.text = tr("HQ_TAB_UPGRADES")
	career_tab.text = tr("HQ_TAB_CAREER")
	ship_tab.text = tr("HQ_TAB_SHIP")
	discovery_tab.text = tr("HQ_TAB_DISCOVERY")

func _refresh_contracts() -> void:
	var sector := _sector_plan["sector"] as Dictionary
	var contract_ref := sector["contract"] as Dictionary
	var contract := _registry.get_contract(String(contract_ref["type"]))
	var params := _sector_plan["parameters"] as Dictionary
	var multiplier := float(params.get("reward_multiplier", 1.0))
	var base_pay := int(round(float(contract["base_pay"]) * multiplier))
	var perfect_bonus := int(round(float(contract["perfect_bonus"]) * multiplier))

	%ContractsTitle.text = tr("HQ_CONTRACTS_TITLE")
	%ContractsSubtitle.text = tr("HQ_CONTRACTS_SUBTITLE")
	previous_contract.text = tr("HQ_CONTRACT_PREVIOUS")
	next_contract.text = tr("HQ_CONTRACT_NEXT")
	if _viewing_endless:
		contract_state.text = tr("HQ_ENDLESS_AVAILABLE")
		contract_position.text = tr("HQ_ENDLESS_INDEX_FMT") % [_endless_number, int(sector["seed"])]
		endless_contract.text = tr("HQ_AUTHORED_CONTRACTS")
		previous_contract.disabled = _endless_number <= 1
		next_contract.disabled = false
		contract_title.text = tr("SECTOR_ENDLESS_CONTRACT_FMT") % [
			_endless_number,
			tr(String((_sector_plan["biome"] as Dictionary)["display_name_key"])),
		]
	else:
		contract_state.text = tr("HQ_CONTRACT_AVAILABLE")
		contract_position.text = tr("HQ_CONTRACT_INDEX_FMT") % [_selected_sector_index + 1, _sector_ids.size()]
		endless_contract.text = tr("HQ_ENDLESS_CONTRACTS")
		previous_contract.disabled = _sector_ids.size() <= 1
		next_contract.disabled = _sector_ids.size() <= 1
		contract_title.text = tr(String(sector["display_name_key"]))
	contract_description.text = tr("HQ_CONTRACT_DESCRIPTION")
	contract_target.text = tr("HQ_CONTRACT_TARGET_FMT") % int(round(float(contract_ref["target_percent"])))
	contract_risk.text = tr(_risk_key(int(sector["difficulty"])))
	contract_payout.text = tr("HQ_CONTRACT_PAY_FMT") % [base_pay, perfect_bonus]
	%ContractShipName.text = tr("OPS_SHIP_NAME")
	%ContractShipStatus.text = tr("HQ_SHIP_READY")
	primary_action.text = tr("HQ_DEPLOY")

	var result := _progression.get_last_contract_result()
	last_result.visible = not result.is_empty()
	if not result.is_empty():
		if bool(result.get("perfect_cleanup", false)):
			last_result.text = tr("OPS_LAST_RESULT_PERFECT_FMT") % [
				int(result.get("credits_awarded", 0)),
				int(result.get("xp_awarded", 0)),
			]
		else:
			last_result.text = tr("OPS_LAST_RESULT_FMT") % [
				int(result.get("credits_awarded", 0)),
				int(result.get("xp_awarded", 0)),
			]

func _refresh_upgrades() -> void:
	%UpgradesTitle.text = tr("HQ_UPGRADES_TITLE")
	%UpgradesSubtitle.text = tr("HQ_UPGRADES_SUBTITLE")

	for child in upgrade_grid.get_children():
		child.queue_free()

	for definition_variant in _progression.get_upgrade_definitions():
		var definition := definition_variant as Dictionary
		var card := UPGRADE_CARD_SCENE.instantiate() as HqUpgradeCard
		assert(card != null, "Upgrade card scene must instantiate.")
		upgrade_grid.add_child(card)

		var id := String(definition["id"])
		var level := _progression.get_upgrade_level(id)
		var max_level := int(definition["max_level"])
		var cost := _progression.get_upgrade_cost(id)
		card.configure(
			id,
			tr(String(definition["display_name_key"])),
			tr(String(definition["description_key"])),
			level,
			max_level,
			cost,
			_upgrade_effect_text(definition, level),
			_progression.can_purchase_upgrade(id)
		)
		card.purchase_requested.connect(_purchase_upgrade)

func _purchase_upgrade(upgrade_id: String) -> void:
	if not _progression.purchase_upgrade(upgrade_id):
		return
	if _platform != null:
		_platform.track_event("upgrade_purchased", {
			"upgrade_id": upgrade_id,
			"level": _progression.get_upgrade_level(upgrade_id),
		})

func _upgrade_effect_text(definition: Dictionary, level: int) -> String:
	var id := String(definition["id"])
	var effects := definition.get("effects", {}) as Dictionary
	match id:
		"tractor_range":
			var value := float(effects.get("scan_range_add", 0.0))
			return tr("HQ_UPGRADE_EFFECT_RANGE_FMT") % int(round(value * float(level)))
		"collection_speed":
			var value := float(effects.get("collection_speed_multiplier_add", 0.0))
			return tr("HQ_UPGRADE_EFFECT_SPEED_FMT") % int(round(value * 100.0 * float(level)))
		"cargo_capacity":
			var value := float(effects.get("cargo_capacity_add", 0.0))
			return tr("HQ_UPGRADE_EFFECT_CARGO_FMT") % int(round(value * float(level)))
	return ""

func _refresh_career() -> void:
	%CareerTitle.text = tr("HQ_CAREER_TITLE")
	%CareerSubtitle.text = tr("HQ_CAREER_SUBTITLE")
	career_rank_value.text = tr(_progression.get_rank_display_name_key())

	var progress := _progression.get_rank_progress()
	var current_xp := int(progress["current_xp"])
	if bool(progress["is_max_rank"]):
		career_xp_label.text = tr("HQ_XP_MAX_FMT") % current_xp
		career_xp_bar.value = 100.0
	else:
		var current_min := int(progress["current_min_xp"])
		var next_min := int(progress["next_min_xp"])
		var span := maxi(next_min - current_min, 1)
		career_xp_bar.value = clampf(float(current_xp - current_min) / float(span) * 100.0, 0.0, 100.0)
		career_xp_label.text = tr("HQ_CAREER_PROGRESS_FMT") % [current_xp, next_min]

	for child in career_list.get_children():
		child.queue_free()

	var ranks := _registry.get_progression("career_ranks").get("ranks", []) as Array
	var current_rank := _progression.get_rank_id()
	for value in ranks:
		var rank := value as Dictionary
		var row := RANK_ROW_SCENE.instantiate() as HqRankRow
		assert(row != null, "Rank row scene must instantiate.")
		career_list.add_child(row)
		var min_xp := int(rank["min_xp"])
		row.configure(
			tr(String(rank["display_name_key"])),
			min_xp,
			current_xp >= min_xp,
			String(rank["id"]) == current_rank
		)

func _refresh_ship() -> void:
	%ShipTitle.text = tr("HQ_SHIP_TITLE")
	%ShipSubtitle.text = tr("HQ_SHIP_SUBTITLE")
	%LoadoutTitle.text = tr("HQ_SHIP_LOADOUT")
	%HullHeading.text = tr("HQ_CUSTOMIZE_HULL")
	%PaintHeading.text = tr("HQ_CUSTOMIZE_PAINT")
	%TrailHeading.text = tr("HQ_CUSTOMIZE_TRAIL")
	%BeamHeading.text = tr("HQ_CUSTOMIZE_BEAM")
	%WorkshopStatus.text = tr("HQ_SHIP_WORKSHOP_STATUS")

	var loadout := _progression.get_ship_cosmetics()
	var hull := loadout["hull"] as Dictionary
	var paint := loadout["paint"] as Dictionary
	var trail := loadout["trail"] as Dictionary
	var beam := loadout["beam"] as Dictionary

	%ShipName.text = tr(String(hull["display_name_key"]))
	%ContractShipName.text = tr(String(hull["display_name_key"]))
	%HullValue.text = tr("HQ_SHIP_HULL_FMT") % tr(String(hull["display_name_key"]))
	%PaintValue.text = tr("HQ_SHIP_PAINT_FMT") % tr(String(paint["display_name_key"]))
	%TrailValue.text = tr("HQ_SHIP_TRAIL_FMT") % tr(String(trail["display_name_key"]))
	%BeamStyleValue.text = tr("HQ_SHIP_BEAM_FMT") % tr(String(beam["display_name_key"]))

	var texture := load(String(hull["texture"])) as Texture2D
	assert(texture != null, "HQ hull preview texture must load.")
	ship_preview.texture = texture
	contract_ship_art.texture = texture
	var preview_material := ship_preview.material as ShaderMaterial
	assert(preview_material != null, "HQ ship preview requires paint ShaderMaterial.")
	preview_material.set_shader_parameter(
		"paint_color",
		Color.from_string(String(paint["color"]), Color(0.224, 0.714, 0.91, 1.0))
	)
	preview_material.set_shader_parameter("paint_strength", float(paint["strength"]))

	var ship := _progression.get_ship_modifiers()
	var recovery_percent := int(round((float(ship["collection_speed_multiplier"]) - 1.0) * 100.0))
	ship_stats.text = tr("HQ_SHIP_STATS_FMT") % [
		int(round(float(ship["scan_range"]))),
		int(round(float(ship["cargo_capacity"]))),
		recovery_percent,
	]

	_populate_cosmetic_options(hull_options, "hull")
	_populate_cosmetic_options(paint_options, "paint")
	_populate_cosmetic_options(trail_options, "trail")
	_populate_cosmetic_options(beam_options, "beam")

func _populate_cosmetic_options(container: GridContainer, category: String) -> void:
	for child in container.get_children():
		child.queue_free()

	var equipped := _progression.get_equipped_cosmetic_id(category)
	for option in _progression.get_cosmetic_options(category):
		var cosmetic_id := String(option["id"])
		var unlocked := _progression.is_cosmetic_unlocked(category, cosmetic_id)
		var selected := cosmetic_id == equipped
		var button := CHROME_BUTTON_SCENE.instantiate() as OccChromeButton
		assert(button != null, "Cosmetic option must use OccChromeButton.")
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.base_tint = OccPalette.MINT if selected else OccPalette.CYAN
		button.disabled = not unlocked
		button.modulate.a = 1.0 if unlocked else 0.48

		var name := tr(String(option["display_name_key"]))
		if selected:
			button.text = tr("HQ_COSMETIC_EQUIPPED_FMT") % name
		elif unlocked:
			button.text = name
		else:
			button.text = tr("HQ_COSMETIC_LOCKED_FMT") % name
			var rank_id := String(option["unlock_rank"])
			button.tooltip_text = tr("HQ_COSMETIC_UNLOCK_RANK_FMT") % tr(_rank_display_key(rank_id))

		button.pressed.connect(_equip_cosmetic.bind(category, cosmetic_id))
		container.add_child(button)

func _equip_cosmetic(category: String, cosmetic_id: String) -> void:
	if not _progression.equip_cosmetic(category, cosmetic_id):
		return
	if _platform != null:
		_platform.track_event("cosmetic_equipped", {
			"category": category,
			"cosmetic_id": cosmetic_id,
		})

func _rank_display_key(rank_id: String) -> String:
	for value in _registry.get_progression("career_ranks").get("ranks", []) as Array:
		var rank := value as Dictionary
		if String(rank["id"]) == rank_id:
			return String(rank["display_name_key"])
	return "RANK_TRAINEE"

func _refresh_discovery() -> void:
	%DiscoveryTitle.text = tr("HQ_DISCOVERY_TITLE")
	%DiscoverySubtitle.text = tr("HQ_DISCOVERY_SUBTITLE")
	%DiscoveryEmptyTitle.text = tr("HQ_DISCOVERY_EMPTY_TITLE")
	%DiscoveryEmptyBody.text = tr("HQ_DISCOVERY_EMPTY_BODY")

	var discoveries := _progression.get_discovery_ids()
	var snapshot := _progression.get_snapshot()
	var completed := snapshot.get("completed_contracts", {}) as Dictionary
	var completed_total := 0
	for value in completed.values():
		completed_total += int(value)
	discovery_count.text = tr("HQ_DISCOVERY_COUNT_FMT") % discoveries.size()
	completed_contracts.text = tr("HQ_COMPLETED_CONTRACTS_FMT") % completed_total

	discovery_empty_card.visible = discoveries.is_empty()
	discovery_list.visible = not discoveries.is_empty()
	for child in discovery_list.get_children():
		child.queue_free()

	for salvage_id in discoveries:
		if not _registry.has_salvage(salvage_id):
			continue
		var definition := _registry.get_salvage_definition(salvage_id)
		var card := DISCOVERY_CARD_SCENE.instantiate() as HqDiscoveryCard
		assert(card != null, "Discovery card scene must instantiate.")
		discovery_list.add_child(card)
		var rarity_key := _rarity_key(String(definition.rarity))
		var category_key := _category_key(String(definition.category))
		card.configure(
			definition.sprite,
			tr(String(definition.display_name_key)),
			tr("HQ_DISCOVERY_META_FMT") % [tr(category_key), tr(rarity_key)],
			tr("HQ_DISCOVERY_VALUE_FMT") % definition.base_value,
			tr(rarity_key),
			WorldVisualLanguage.salvage_rarity_color(definition.rarity)
		)

func _rarity_key(rarity: String) -> String:
	match rarity:
		"uncommon":
			return "RARITY_UNCOMMON"
		"rare":
			return "RARITY_RARE"
		"epic":
			return "RARITY_EPIC"
		_:
			return "RARITY_COMMON"

func _category_key(category: String) -> String:
	match category:
		"electronics":
			return "CATEGORY_ELECTRONICS"
		"cargo":
			return "CATEGORY_CARGO"
		"research":
			return "CATEGORY_RESEARCH"
		"power":
			return "CATEGORY_POWER"
		"mining":
			return "CATEGORY_MINING"
		"industrial":
			return "CATEGORY_INDUSTRIAL"
		"propulsion":
			return "CATEGORY_PROPULSION"
		_:
			return "CATEGORY_SCRAP"
