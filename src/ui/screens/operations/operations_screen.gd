extends Control

signal deployment_requested(context: Dictionary)
signal close_requested

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
const STATUS_GREEN := preload("res://assets/third_party/kenney_ui_sci_fi/ui/squareGreen.png")
const STATUS_YELLOW := preload("res://assets/third_party/kenney_ui_sci_fi/ui/squareYellow.png")
const STATUS_RED := preload("res://assets/third_party/kenney_ui_sci_fi/ui/squareRed.png")

@onready var safe_area: MarginContainer = %SafeArea
@onready var header: BoxContainer = %Header
@onready var main_row: BoxContainer = %MainRow
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
@onready var risk_icon: TextureRect = %RiskIcon
@onready var contract_payout: Label = %ContractPayout
@onready var contract_requirement: Label = %ContractRequirement
@onready var next_unlock_panel: VBoxContainer = %NextUnlockPanel
@onready var next_unlock_title: Label = %NextUnlockTitle
@onready var next_unlock_label: Label = %NextUnlockLabel
@onready var next_unlock_progress: ProgressBar = %NextUnlockProgress
@onready var next_unlock_progress_label: Label = %NextUnlockProgressLabel
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
@onready var discovery_list: GridContainer = %DiscoveryList
@onready var english_button: Button = %EnglishButton
@onready var portuguese_button: Button = %PortugueseButton
@onready var spanish_button: Button = %SpanishButton
@onready var contracts_tab: Button = %ContractsTab
@onready var upgrades_tab: Button = %UpgradesTab
@onready var career_tab: Button = %CareerTab
@onready var ship_tab: Button = %ShipTab
@onready var discovery_tab: Button = %DiscoveryTab
@onready var close_overlay: Button = %CloseOverlay
@onready var overlay_scrim: ColorRect = %OverlayScrim
@onready var floating_surface: PanelContainer = %FloatingSurface
@onready var settings_button: Button = %SettingsButton
@onready var settings_layer: Control = %SettingsLayer
@onready var settings_modal: PanelContainer = %SettingsModal
@onready var settings_close: Button = %SettingsClose
@onready var volume_down: Button = %VolumeDown
@onready var volume_up: Button = %VolumeUp
@onready var volume_value: Label = %VolumeValue

var _context: Dictionary = {}
var _settings: SettingsService
var _audio: AudioService
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
var _active_tab := -1
var _tab_group := ButtonGroup.new()
var _overlay_mode := false
var _tab_reveal_tween: Tween
var _tab_transitioning := false
var _tab_pulse_tween: Tween
var _base_theme: Theme
var _ui_profile := -1

func configure(context: Dictionary) -> void:
	_context = context
	_overlay_mode = bool(context.get("operations_overlay", false))
	_settings = context.get("settings") as SettingsService
	_audio = context.get("audio") as AudioService
	_platform = context.get("platform") as PlatformService
	_router = context.get("router") as SceneRouter
	_progression = context.get("progression") as ProgressionService
	assert(_progression != null, "OperationsScreen requires ProgressionService.")
	assert(_router != null, "OperationsScreen requires SceneRouter.")

	var scaler := DifficultyScaler.new()
	scaler.configure(_registry)
	_generator.configure(_registry, scaler)
	_endless_generator.configure(_registry)
	var authored_sector_ids := _registry.list_sector_ids()
	_sector_ids = PackedStringArray()
	for sector_id in authored_sector_ids:
		if _progression.is_sector_unlocked(String(sector_id)):
			_sector_ids.append(String(sector_id))
	assert(not _sector_ids.is_empty(), "Operations requires at least one unlocked authored sector.")
	var requested_sector := String(context.get("debug_hq_sector_id", DEFAULT_SECTOR_ID))
	var preferred_index := _sector_ids.find(requested_sector)
	_selected_sector_index = preferred_index if preferred_index >= 0 else 0
	_load_selected_sector()

func _ready() -> void:
	_base_theme = theme
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	primary_action.pressed.connect(_deploy_training)
	close_overlay.pressed.connect(_request_close)
	settings_button.pressed.connect(_open_settings)
	settings_close.pressed.connect(_close_settings)
	volume_down.pressed.connect(_adjust_volume.bind(-0.1))
	volume_up.pressed.connect(_adjust_volume.bind(0.1))
	previous_contract.pressed.connect(_select_relative_contract.bind(-1))
	endless_contract.pressed.connect(_toggle_endless_mode)
	next_contract.pressed.connect(_select_relative_contract.bind(1))

	_setup_tabs()
	english_button.pressed.connect(_change_locale.bind("en"))
	portuguese_button.pressed.connect(_change_locale.bind("pt_BR"))
	spanish_button.pressed.connect(_change_locale.bind("es_ES"))

	if _settings != null and not _settings.locale_changed.is_connected(_on_locale_changed):
		_settings.locale_changed.connect(_on_locale_changed)
	if _settings != null and not _settings.audio_changed.is_connected(_on_audio_changed):
		_settings.audio_changed.connect(_on_audio_changed)
	if not _progression.state_changed.is_connected(_on_progression_changed):
		_progression.state_changed.connect(_on_progression_changed)

	_apply_overlay_presentation()
	_apply_responsive_layout()
	_refresh_all()
	_wire_button_feedback(self)
	_show_tab(Tab.CONTRACTS, true)
	print("[HQ] READY tab=contracts mode=%s" % ("overlay" if _overlay_mode else "screen"))

func _validate_contracts() -> void:
	assert(safe_area != null, "Headquarters requires SafeArea.")
	assert(header != null, "Headquarters requires responsive Header.")
	assert(tab_grid != null, "Headquarters requires TabGrid.")
	assert(content_scroll != null, "Headquarters requires ContentScroll.")
	assert(content_shell != null, "Headquarters requires ContentShell.")
	assert(primary_action != null, "Headquarters requires PrimaryAction.")
	assert(contract_selector != null, "Headquarters requires responsive ContractSelector.")
	assert(previous_contract != null and endless_contract != null and next_contract != null and contract_position != null, "Headquarters requires contract navigation.")
	assert(contract_requirement != null, "Headquarters requires active-contract access feedback.")
	assert(next_unlock_panel != null and next_unlock_label != null and next_unlock_progress != null, "Headquarters requires next career unlock feedback.")
	assert(upgrade_grid != null, "Headquarters requires UpgradeGrid.")
	assert(career_list != null, "Headquarters requires CareerList.")
	assert(ship_preview != null and contract_ship_art != null, "Headquarters requires cosmetic ship previews.")
	assert(hull_options != null and paint_options != null and trail_options != null and beam_options != null, "Headquarters requires cosmetic option grids.")
	assert(contracts_panel != null and upgrades_panel != null and career_panel != null, "Headquarters core panels are required.")
	assert(ship_panel != null and discovery_panel != null, "Headquarters future-facing panels are required.")
	assert(discovery_empty_card != null and discovery_list != null, "Headquarters discovery catalog containers are required.")
	assert(close_overlay != null and overlay_scrim != null and floating_surface != null, "Operations overlay chrome is required.")
	assert(settings_button != null and settings_layer != null and settings_modal != null and settings_close != null, "Operations requires a dedicated settings panel.")
	assert(volume_down != null and volume_up != null and volume_value != null, "Operations settings controls are required.")
	assert(not _sector_plan.is_empty(), "Operations requires sector data.")

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

func _show_tab(tab: int, instant: bool = false) -> void:
	if _tab_transitioning:
		_sync_tab_selection()
		return
	if tab == _active_tab and not instant:
		return

	var previous_tab := _active_tab
	var previous_panel := _panel_for_tab(previous_tab) if previous_tab >= 0 else null
	var active_panel := _panel_for_tab(tab)

	if instant or previous_panel == null:
		_active_tab = tab
		_refresh_tab_content(tab)
		_apply_panel_visibility(active_panel)
		_sync_tab_selection()
		_update_tab_visuals()
		content_scroll.scroll_vertical = 0
		return

	_tab_transitioning = true
	var direction := 1.0 if tab > previous_tab else -1.0

	if _tab_reveal_tween != null and _tab_reveal_tween.is_valid():
		_tab_reveal_tween.kill()

	var previous_origin := previous_panel.position
	_tab_reveal_tween = create_tween()
	_tab_reveal_tween.set_parallel(true)
	_tab_reveal_tween.tween_property(
		previous_panel,
		"position:x",
		previous_origin.x - direction * 84.0,
		0.18
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tab_reveal_tween.tween_property(
		previous_panel,
		"modulate:a",
		0.0,
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tab_reveal_tween.finished
	previous_panel.position = previous_origin

	_active_tab = tab
	_refresh_tab_content(tab)
	_apply_panel_visibility(active_panel)
	content_scroll.scroll_vertical = 0
	_sync_tab_selection()
	_update_tab_visuals()

	await get_tree().process_frame
	var active_origin := active_panel.position
	active_panel.position = active_origin + Vector2(direction * 96.0, 0.0)
	active_panel.modulate = Color(0.72, 0.90, 1.0, 0.0)

	_tab_reveal_tween = create_tween()
	_tab_reveal_tween.set_parallel(true)
	_tab_reveal_tween.tween_property(
		active_panel,
		"position",
		active_origin,
		0.24
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tab_reveal_tween.tween_property(
		active_panel,
		"modulate",
		Color.WHITE,
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _tab_reveal_tween.finished
	active_panel.position = active_origin
	active_panel.modulate = Color.WHITE
	_tab_transitioning = false

func _sync_tab_selection() -> void:
	var tabs: Array[Button] = [
		contracts_tab,
		upgrades_tab,
		career_tab,
		ship_tab,
		discovery_tab,
	]
	for index in range(tabs.size()):
		tabs[index].button_pressed = index == _active_tab

func _refresh_tab_content(tab: int) -> void:
	footer.visible = tab == Tab.CONTRACTS
	match tab:
		Tab.UPGRADES:
			_refresh_upgrades()
		Tab.CAREER:
			_refresh_career()
		Tab.SHIP:
			_refresh_ship()
		Tab.DISCOVERY:
			_refresh_discovery()

func _apply_panel_visibility(active_panel: Control) -> void:
	var panels: Array[Control] = [contracts_panel, upgrades_panel, career_panel, ship_panel, discovery_panel]
	for panel in panels:
		panel.visible = panel == active_panel
		panel.modulate.a = 1.0

func _panel_for_tab(tab: int) -> Control:
	match tab:
		Tab.UPGRADES:
			return upgrades_panel
		Tab.CAREER:
			return career_panel
		Tab.SHIP:
			return ship_panel
		Tab.DISCOVERY:
			return discovery_panel
		_:
			return contracts_panel

func _update_tab_visuals() -> void:
	if _tab_pulse_tween != null and _tab_pulse_tween.is_valid():
		_tab_pulse_tween.kill()

	var tabs: Array[Button] = [
		contracts_tab,
		upgrades_tab,
		career_tab,
		ship_tab,
		discovery_tab,
	]
	for button in tabs:
		button.self_modulate = Color.WHITE
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_hover_color")
		button.remove_theme_color_override("font_pressed_color")
		button.remove_theme_color_override("font_hover_pressed_color")
		button.remove_theme_color_override("font_outline_color")
		button.remove_theme_constant_override("outline_size")

	var active_button := tabs[_active_tab] if _active_tab >= 0 and _active_tab < tabs.size() else null
	if active_button == null:
		return

	# The pressed TabButton state owns the yellow Kenney surface. This slow
	# modulation adds a restrained glow without changing geometry or layout.
	active_button.self_modulate = Color(1.0, 0.98, 0.88, 1.0)
	_tab_pulse_tween = create_tween().set_loops()
	_tab_pulse_tween.tween_property(
		active_button,
		"self_modulate",
		Color(1.0, 0.90, 0.64, 1.0),
		1.70
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tab_pulse_tween.tween_property(
		active_button,
		"self_modulate",
		Color(1.0, 0.98, 0.88, 1.0),
		1.70
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_responsive_layout() -> void:
	var portrait := ResponsiveCanvas.apply_reference(get_tree().root)
	var window_size := DisplayServer.window_get_size()
	var profile := ResponsiveUiProfile.current()
	var phone := ResponsiveUiProfile.is_phone(profile)
	var compact := ResponsiveUiProfile.is_compact(profile)
	var narrow := portrait or phone or window_size.x < int(COMPACT_WIDTH)

	if _ui_profile != int(profile):
		theme = ResponsiveUiProfile.build_theme(_base_theme, profile)
		_ui_profile = int(profile)
	ResponsiveUiProfile.apply_minimum_touch_targets(self, profile)

	# On phones the console reflows instead of shrinking desktop geometry.
	header.vertical = profile == ResponsiveUiProfile.Profile.PHONE_PORTRAIT
	main_row.vertical = narrow
	contract_hero.vertical = narrow
	ship_body.vertical = narrow
	tab_grid.columns = (
		2 if portrait or window_size.x < 560
		else (3 if compact else 1)
	)
	contract_selector.columns = 2 if portrait else (3 if narrow else 4)
	upgrade_grid.columns = 1 if narrow else 3
	discovery_list.columns = 1 if narrow else 2

	# ContentScroll owns overflow. Larger phone typography must scroll rather
	# than be compressed to fit the old desktop density.
	content_shell.custom_minimum_size.y = 0.0

	var horizontal_margin := 12 if phone else (14 if compact else 22)
	var vertical_margin := 10 if phone else (12 if compact else 20)
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

	var available_width := maxf(size.x - (16.0 if compact else 80.0), 320.0)
	var available_height := maxf(size.y - (16.0 if compact else 56.0), 300.0)
	var console_height := 1180.0 if portrait else 650.0
	floating_surface.custom_minimum_size = Vector2(
		minf(1120.0, available_width),
		minf(console_height, available_height)
	)

	var settings_width := 620.0 if portrait else (720.0 if phone else 500.0)
	var settings_height := 460.0 if phone else (390.0 if portrait else 330.0)
	settings_modal.custom_minimum_size = Vector2(
		minf(settings_width, maxf(size.x - 32.0, 300.0)),
		minf(settings_height, maxf(size.y - 32.0, 260.0))
	)

	var footer_spacer := footer.get_node_or_null("FooterSpacer") as Control
	if footer_spacer != null:
		footer_spacer.visible = not portrait and not phone
	primary_action.custom_minimum_size.x = 0.0 if portrait or phone else 260.0
	primary_action.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL if portrait or phone else Control.SIZE_SHRINK_BEGIN
	)

func _deploy_training() -> void:
	var access := _active_contract_access()
	if not bool(access.get("unlocked", false)):
		if _platform != null:
			_platform.track_event("locked_contract_attempted", {
				"type": String(access.get("type", "")),
				"required_rank": String(access.get("rank_id", "")),
			})
		return

	var scene := load(FLIGHT_SCREEN_PATH) as PackedScene
	assert(scene != null, "Training flight screen must be loadable.")
	var flight_context := _context.duplicate(true)
	flight_context.erase("free_roam")
	flight_context.erase("open_operations")
	flight_context["arrival_warp"] = true
	flight_context["travel_direction"] = 1
	flight_context["return_screen_path"] = FLIGHT_SCREEN_PATH
	if _viewing_endless:
		flight_context["sector_id"] = String(_active_sector_definition["id"])
		flight_context["sector_definition"] = _active_sector_definition.duplicate(true)
		flight_context["endless_number"] = _endless_number
	else:
		flight_context["sector_id"] = String(_sector_ids[_selected_sector_index])

	if _overlay_mode:
		deployment_requested.emit(flight_context)
		return
	_router.show_screen(scene, flight_context)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_layer.visible:
		_close_settings()
	elif _overlay_mode:
		_request_close()
	else:
		return
	get_viewport().set_input_as_handled()

func _request_close() -> void:
	if not _overlay_mode:
		return
	if _audio != null:
		_audio.play_ui_back()
	close_requested.emit()

func _apply_overlay_presentation() -> void:
	overlay_scrim.visible = _overlay_mode
	floating_surface.visible = true
	close_overlay.visible = _overlay_mode
	var backdrop := get_node_or_null("Backdrop") as CanvasItem
	if backdrop != null:
		backdrop.visible = not _overlay_mode

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

func _active_contract_access() -> Dictionary:
	if _viewing_endless:
		return _progression.get_endless_access()
	return _progression.get_sector_access(String(_sector_ids[_selected_sector_index]))

func _refresh_next_unlock() -> void:
	var unlock := _progression.get_next_content_unlock()
	next_unlock_panel.visible = not unlock.is_empty()
	if unlock.is_empty():
		return

	var current_xp := int(unlock["current_xp"])
	var required_xp := int(unlock["min_xp"])
	var remaining := int(unlock["xp_remaining"])
	var rank_requirement := _progression.get_rank_requirement(String(unlock["rank_id"]))

	next_unlock_title.text = tr("HQ_NEXT_UNLOCK")
	next_unlock_label.text = tr("HQ_NEXT_UNLOCK_FMT") % [
		tr(String(unlock["content_display_name_key"])),
		tr(String(rank_requirement["display_name_key"])),
	]
	next_unlock_progress.value = 100.0 if required_xp <= 0 else clampf(
		float(current_xp) / float(required_xp) * 100.0,
		0.0,
		100.0
	)
	next_unlock_progress_label.text = tr("HQ_NEXT_UNLOCK_XP_FMT") % [
		current_xp,
		required_xp,
		remaining,
	]

func _completed_contract_total() -> int:
	var snapshot := _progression.get_snapshot()
	var completed := snapshot.get("completed_contracts", {}) as Dictionary
	var total := 0
	for value in completed.values():
		total += int(value)
	return total

func _contract_target_text(contract_ref: Dictionary, contract: Dictionary, reward_multiplier: float) -> String:
	match String(contract["kind"]):
		"cleanup":
			return tr("HQ_CONTRACT_TARGET_FMT") % int(round(float(contract_ref["target_percent"])))
		"full_cleanup":
			return tr("HQ_CONTRACT_TARGET_FULL")
		"recovery":
			return tr("HQ_CONTRACT_TARGET_RECOVERY_FMT") % int(contract_ref["target_count"])
		"valuable_recovery":
			var scaled_target := int(round(float(contract_ref["target_value"]) * reward_multiplier))
			return tr("HQ_CONTRACT_TARGET_VALUE_FMT") % scaled_target
		"priority_object":
			var definition := _registry.get_salvage_definition(String(contract_ref["target_salvage_id"]))
			return tr("HQ_CONTRACT_TARGET_PRIORITY_FMT") % [
				int(contract_ref["target_count"]),
				tr(String(definition.display_name_key)),
			]
	return tr("HQ_CONTRACT_TARGET_FULL")

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

func _on_audio_changed(_master_linear: float) -> void:
	_update_volume_value()

func _on_progression_changed(_snapshot: Dictionary) -> void:
	_refresh_all()

func _refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_header()
	_refresh_tabs()
	_refresh_contracts()
	_refresh_next_unlock()
	_refresh_upgrades()
	_refresh_career()
	_refresh_ship()
	_refresh_discovery()

func _refresh_header() -> void:
	%CompanyLabel.text = tr("HQ_COMPANY")
	close_overlay.text = tr("HQ_CLOSE")
	%DeskLabel.text = tr("HQ_DESK")
	%SettingsButton.text = tr("HQ_SETTINGS")
	%SettingsTitle.text = tr("HQ_SETTINGS")
	%AudioLabel.text = tr("HQ_SETTINGS_AUDIO")
	%SettingsClose.text = tr("HQ_SETTINGS_DONE")
	credits_label.text = tr("HQ_CREDITS_FMT") % _progression.get_credits()
	%LanguageLabel.text = tr("HQ_LANGUAGE")
	_update_volume_value()

func _refresh_tabs() -> void:
	contracts_tab.text = tr("HQ_TAB_CONTRACTS")
	upgrades_tab.text = tr("HQ_TAB_UPGRADES")
	career_tab.text = tr("HQ_TAB_CAREER")
	ship_tab.text = tr("HQ_TAB_SHIP")
	discovery_tab.text = tr("HQ_TAB_DISCOVERY")
	discovery_tab.visible = _progression.get_discovery_count() > 0

func _refresh_contracts() -> void:
	var sector := _sector_plan["sector"] as Dictionary
	var access := _active_contract_access()
	var unlocked := bool(access["unlocked"])
	var contract_ref := sector["contract"] as Dictionary
	var contract := _registry.get_contract(String(contract_ref["type"]))
	var params := _sector_plan["parameters"] as Dictionary
	var multiplier := float(params.get("reward_multiplier", 1.0))
	var base_pay := int(round(float(contract["base_pay"]) * multiplier))
	var perfect_bonus := int(round(float(contract["perfect_bonus"]) * multiplier))

	%ContractsTitle.text = tr("HQ_CONTRACTS_TITLE")
	%ContractsSubtitle.text = tr("HQ_CONTRACTS_SUBTITLE")
	previous_contract.text = "<  %s" % tr("HQ_CONTRACT_PREVIOUS")
	next_contract.text = "%s  >" % tr("HQ_CONTRACT_NEXT")
	endless_contract.visible = _progression.is_endless_unlocked()
	if _viewing_endless:
		contract_state.text = tr("HQ_ENDLESS_AVAILABLE") if unlocked else tr("HQ_CONTRACT_LOCKED")
		contract_position.text = tr("HQ_ENDLESS_INDEX_FMT") % [_endless_number, int(sector["seed"])]
		endless_contract.text = tr("HQ_AUTHORED_CONTRACTS")
		previous_contract.disabled = not unlocked or _endless_number <= 1
		next_contract.disabled = not unlocked
		contract_title.text = tr("SECTOR_ENDLESS_CONTRACT_FMT") % [
			_endless_number,
			tr(String((_sector_plan["biome"] as Dictionary)["display_name_key"])),
		]
	else:
		contract_state.text = tr("HQ_CONTRACT_AVAILABLE") if unlocked else tr("HQ_CONTRACT_LOCKED")
		contract_position.text = tr("HQ_CONTRACT_INDEX_FMT") % [_selected_sector_index + 1, _sector_ids.size()]
		endless_contract.text = tr("HQ_ENDLESS_CONTRACTS")
		previous_contract.disabled = _sector_ids.size() <= 1
		next_contract.disabled = _sector_ids.size() <= 1
		contract_title.text = tr(String(sector["display_name_key"]))
	contract_description.text = "%s · %s" % [
		tr(String(contract["display_name_key"])),
		tr(String(contract["description_key"])),
	]
	contract_target.text = _contract_target_text(contract_ref, contract, multiplier)
	var difficulty := int(sector["difficulty"])
	contract_risk.text = tr(_risk_key(difficulty))
	if difficulty <= 3:
		risk_icon.texture = STATUS_GREEN
	elif difficulty <= 7:
		risk_icon.texture = STATUS_YELLOW
	else:
		risk_icon.texture = STATUS_RED
	contract_payout.text = tr("HQ_CONTRACT_PAY_FMT") % [base_pay, perfect_bonus]
	%ContractShipName.text = tr("OPS_SHIP_NAME")
	%ContractShipStatus.text = tr("HQ_SHIP_READY")
	var requirement := _progression.get_rank_requirement(String(access["rank_id"]))
	primary_action.disabled = not unlocked
	primary_action.text = tr("HQ_DEPLOY") if unlocked else tr("HQ_LOCKED_RANK_FMT") % tr(String(requirement["display_name_key"]))
	contract_requirement.visible = not unlocked
	contract_requirement.text = tr("HQ_CONTRACT_LOCK_REQUIREMENT_FMT") % [
		tr(String(requirement["display_name_key"])),
		int(access["min_xp"]),
	]
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
		_wire_button_feedback(card)

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
		"pulse_boost":
			var recharge := float(effects.get("boost_recharge_rate_add", 0.0)) * float(level)
			var duration := float(effects.get("boost_duration_bonus_add", 0.0)) * float(level)
			return tr("HQ_UPGRADE_EFFECT_BOOST_FMT") % [
				int(round(recharge * 100.0)),
				int(round(duration * 1000.0)),
			]
		"boost_capacitor":
			return tr("HQ_UPGRADE_EFFECT_BOOST_CAPACITY_FMT") % (1 + level)
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
	var current_index := 0
	for index in range(ranks.size()):
		if String((ranks[index] as Dictionary)["id"]) == current_rank:
			current_index = index
			break
	for index in range(ranks.size()):
		if index != current_index and index != current_index + 1:
			continue
		var rank := ranks[index] as Dictionary
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
		if not unlocked:
			continue
		var selected := cosmetic_id == equipped
		var button := CHROME_BUTTON_SCENE.instantiate() as OccChromeButton
		assert(button != null, "Cosmetic option must use OccChromeButton.")
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.emphasis = selected

		var name := tr(String(option["display_name_key"]))
		button.text = tr("HQ_COSMETIC_EQUIPPED_FMT") % name if selected else name
		button.pressed.connect(_equip_cosmetic.bind(category, cosmetic_id))
		container.add_child(button)
		_wire_button_feedback(button)

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

	var discovery_index := 0
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
		card.call_deferred("reveal", minf(float(discovery_index) * 0.035, 0.24))
		discovery_index += 1

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


func _open_settings() -> void:
	settings_layer.visible = true
	settings_layer.modulate.a = 0.0
	_update_volume_value()
	settings_close.grab_focus()
	var tween := create_tween()
	tween.tween_property(settings_layer, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _close_settings() -> void:
	if _audio != null:
		_audio.play_ui_back()
	var tween := create_tween()
	tween.tween_property(settings_layer, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		settings_layer.visible = false
		settings_layer.modulate.a = 1.0
		settings_button.grab_focus()
	)

func _adjust_volume(delta: float) -> void:
	if _settings == null:
		return
	_settings.set_master_audio_linear(clampf(_settings.master_audio_linear + delta, 0.0, 1.0))
	_update_volume_value()

func _update_volume_value() -> void:
	if volume_value == null:
		return
	var linear := _settings.master_audio_linear if _settings != null else 1.0
	volume_value.text = "%d%%" % int(round(linear * 100.0))

func _wire_button_feedback(root: Node) -> void:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root as Button)
	for node in root.find_children("*", "Button", true, false):
		if node is Button:
			buttons.append(node as Button)
	for button in buttons:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if button.has_meta("occ_feedback_wired"):
			continue
		button.set_meta("occ_feedback_wired", true)
		button.mouse_entered.connect(_play_ui_hover)
		if button != close_overlay and button != settings_close:
			button.pressed.connect(_play_ui_click)
		button.button_down.connect(_on_ui_button_down.bind(button))
		button.button_up.connect(_on_ui_button_up.bind(button))
		button.mouse_exited.connect(_on_ui_button_up.bind(button))

func _play_ui_hover() -> void:
	if _audio != null:
		_audio.play_ui_hover()

func _play_ui_click() -> void:
	if _audio != null:
		_audio.play_ui_click()

func _on_ui_button_down(_button: Button) -> void:
	OccCursorSkin.set_pressed()

func _on_ui_button_up(_button: Button) -> void:
	OccCursorSkin.set_pointing()
