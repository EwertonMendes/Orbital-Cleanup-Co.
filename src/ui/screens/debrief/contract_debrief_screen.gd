extends Control
class_name ContractDebriefScreen

const OPERATIONS_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"

@onready var safe_area: MarginContainer = %SafeArea
@onready var debrief_card: PanelContainer = %DebriefCard
@onready var content_grid: GridContainer = %ContentGrid
@onready var reward_grid: GridContainer = %RewardGrid
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var mission_label: Label = %MissionLabel
@onready var result_badge: Label = %ResultBadge
@onready var objective_value: Label = %ObjectiveValue
@onready var cleanup_value: Label = %CleanupValue
@onready var recovered_value: Label = %RecoveredValue
@onready var base_pay_value: Label = %BasePayValue
@onready var salvage_value: Label = %SalvageValue
@onready var perfect_bonus_value: Label = %PerfectBonusValue
@onready var reward_total_value: Label = %RewardTotalValue
@onready var balance_value: Label = %BalanceValue
@onready var rank_value: Label = %RankValue
@onready var xp_gain_label: Label = %XpGainLabel
@onready var xp_progress: ProgressBar = %XpProgress
@onready var xp_progress_label: Label = %XpProgressLabel
@onready var promotion_panel: PanelContainer = %PromotionPanel
@onready var promotion_rank: Label = %PromotionRank
@onready var unlocks_list: VBoxContainer = %UnlocksList
@onready var discoveries_panel: PanelContainer = %DiscoveriesPanel
@onready var discoveries_list: VBoxContainer = %DiscoveriesList
@onready var continue_button: Button = %ContinueButton
@onready var celebration: DebriefCelebration = %Celebration

var _context: Dictionary = {}
var _result: Dictionary = {}
var _transition: Dictionary = {}
var _router: SceneRouter
var _ads: AdService
var _platform: PlatformService
var _audio: AudioService
var _registry := ContentRegistry.new()
var _animation: Tween
var _promotion_player: AudioStreamPlayer
var _reward_player: AudioStreamPlayer
var _animation_finished := false
var _base_theme: Theme
var _ui_density_key := -1

func configure(context: Dictionary) -> void:
	_context = context
	_result = (context.get("debrief_result", {}) as Dictionary).duplicate(true)
	_transition = (context.get("debrief_transition", {}) as Dictionary).duplicate(true)
	_router = context.get("router") as SceneRouter
	_ads = context.get("ads") as AdService
	_platform = context.get("platform") as PlatformService
	_audio = context.get("audio") as AudioService

	assert(_router != null, "ContractDebriefScreen requires SceneRouter.")
	assert(bool(_result.get("completed", false)), "ContractDebriefScreen requires a completed contract result.")
	assert(not _transition.is_empty(), "ContractDebriefScreen requires a progression transition snapshot.")

func _ready() -> void:
	_base_theme = theme
	_validate_contracts()
	continue_button.pressed.connect(_continue_to_hq)
	continue_button.mouse_entered.connect(_play_ui_hover)
	resized.connect(_apply_responsive_layout)

	_reward_player = _create_player(ProceduralSfx.unload(), -8.0)
	_promotion_player = _create_player(ProceduralSfx.promotion(), -4.0)

	_apply_responsive_layout()
	_refresh_copy()
	_prepare_animation_state()

	await get_tree().process_frame
	_play_sequence()

	if _platform != null:
		_platform.track_event("contract_debrief_viewed", {
			"sector_id": String(_result.get("sector_id", "")),
			"perfect": bool(_result.get("perfect_cleanup", false)),
			"promoted": bool(_transition.get("promoted", false)),
		})
	print("[Debrief] READY sector=%s promoted=%s" % [
		String(_result.get("sector_id", "")),
		str(bool(_transition.get("promoted", false))),
	])

func _validate_contracts() -> void:
	assert(safe_area != null, "Debrief requires responsive SafeArea.")
	assert(content_grid != null and reward_grid != null, "Debrief requires responsive grids.")
	assert(xp_progress != null, "Debrief requires career XP progress.")
	assert(promotion_panel != null and unlocks_list != null, "Debrief requires promotion reveal.")
	assert(discoveries_panel != null and discoveries_list != null, "Debrief requires discovery summary.")
	assert(continue_button != null, "Debrief requires continue action.")
	assert(celebration != null, "Debrief requires celebration layer.")

func _apply_responsive_layout() -> void:
	var portrait := ResponsiveCanvas.apply_reference(get_tree().root)
	var profile := ResponsiveUiProfile.current()
	var phone := ResponsiveUiProfile.is_phone(profile)
	var compact := ResponsiveUiProfile.is_compact(profile) or portrait

	var density_key := ResponsiveUiProfile.density_key(profile)
	if _ui_density_key != density_key:
		theme = ResponsiveUiProfile.build_theme(_base_theme, profile)
		_ui_density_key = density_key
		print("[UI] PROFILE screen=debrief profile=%s viewport=%s font_scale=%.2f touch_target=%.1f" % [
			ResponsiveUiProfile.profile_name(profile),
			str(ResponsiveUiProfile.viewport_size()),
			ResponsiveUiProfile.font_scale(profile),
			ResponsiveUiProfile.touch_target_height(profile),
		])
	ResponsiveUiProfile.apply_minimum_touch_targets(self, profile)

	content_grid.columns = 1 if compact else 3
	reward_grid.columns = 2 if compact else 4
	var horizontal_margin := 12 if phone else (14 if compact else 30)
	var vertical_margin := 10 if compact else 18
	var available_width := maxf(size.x - float(horizontal_margin * 2), 280.0)
	debrief_card.custom_minimum_size.x = available_width if phone else minf(900.0, available_width)
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

func _refresh_copy() -> void:
	var perfect := bool(_result.get("perfect_cleanup", false))
	var promoted := bool(_transition.get("promoted", false))
	celebration.configure(perfect, promoted)

	%EyebrowLabel.text = tr("DEBRIEF_EYEBROW")
	title_label.text = tr("DEBRIEF_TITLE_PERFECT") if perfect else tr("DEBRIEF_TITLE")
	subtitle_label.text = tr("DEBRIEF_SUBTITLE")
	mission_label.text = _mission_title()
	result_badge.text = tr("DEBRIEF_BADGE_PERFECT") if perfect else tr("DEBRIEF_BADGE_COMPLETE")

	%ObjectiveLabel.text = tr("DEBRIEF_OBJECTIVE")
	objective_value.text = tr("DEBRIEF_OBJECTIVE_COMPLETE")
	%CleanupLabel.text = tr("DEBRIEF_CLEANUP")
	cleanup_value.text = tr("DEBRIEF_PERCENT_FMT") % int(round(float(_result.get("cleanup_percent", 0.0))))
	%RecoveredLabel.text = tr("DEBRIEF_RECOVERED")
	recovered_value.text = tr("DEBRIEF_RECOVERED_FMT") % int(_result.get("recovered_count", 0))

	%RewardsTitle.text = tr("DEBRIEF_REWARDS")
	%BasePayLabel.text = tr("DEBRIEF_BASE_PAY")
	%SalvageLabel.text = tr("DEBRIEF_SALVAGE_VALUE")
	%PerfectBonusLabel.text = tr("DEBRIEF_PERFECT_BONUS")
	%TotalLabel.text = tr("DEBRIEF_TOTAL")
	base_pay_value.text = tr("DEBRIEF_CREDITS_FMT") % int(_result.get("base_pay", 0))
	salvage_value.text = tr("DEBRIEF_CREDITS_FMT") % int(_result.get("salvage_credits", 0))
	perfect_bonus_value.text = tr("DEBRIEF_CREDITS_FMT") % int(_result.get("perfect_bonus", 0))
	reward_total_value.text = tr("DEBRIEF_CREDITS_FMT") % int(_result.get("credits_awarded", 0))
	%BalanceLabel.text = tr("DEBRIEF_BALANCE")

	%CareerTitle.text = tr("DEBRIEF_CAREER")
	rank_value.text = tr(String(_transition.get("rank_before_key", "RANK_TRAINEE")))
	xp_gain_label.text = tr("DEBRIEF_XP_GAIN_FMT") % int(_result.get("xp_awarded", 0))
	%PromotionTitle.text = tr("DEBRIEF_PROMOTED")
	promotion_rank.text = tr(String(_transition.get("rank_after_key", "RANK_TRAINEE")))
	%UnlocksTitle.text = tr("DEBRIEF_UNLOCKS")

	%DiscoveriesTitle.text = tr("DEBRIEF_DISCOVERIES")
	_refresh_unlocks()
	_refresh_discoveries()

	continue_button.text = tr("DEBRIEF_CONTINUE")

func _mission_title() -> String:
	var mission := _context.get("debrief_mission", {}) as Dictionary
	if mission.has("endless_number"):
		return tr("SECTOR_ENDLESS_CONTRACT_FMT") % [
			int(mission["endless_number"]),
			tr(String(mission.get("biome_display_name_key", "BIOME_EARTH_ORBIT"))),
		]
	return tr(String(mission.get("sector_display_name_key", "SECTOR_EARTH_TRAINING_01")))

func _refresh_unlocks() -> void:
	for child in unlocks_list.get_children():
		child.queue_free()

	var unlocks := _transition.get("unlocks", []) as Array
	if unlocks.is_empty():
		var empty := Label.new()
		empty.text = tr("DEBRIEF_NO_UNLOCKS")
		empty.theme_type_variation = &"UiBodyMuted"
		unlocks_list.add_child(empty)
		return

	for value in unlocks:
		var unlock := value as Dictionary
		var row := Label.new()
		row.text = "> %s" % tr(String(unlock.get("display_name_key", "")))
		row.theme_type_variation = &"UiBody"
		row.add_theme_color_override("font_color", Color("#6f5200"))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unlocks_list.add_child(row)

func _refresh_discoveries() -> void:
	for child in discoveries_list.get_children():
		child.queue_free()

	var ids := _result.get("new_discoveries", []) as Array
	discoveries_panel.visible = not ids.is_empty()
	for value in ids:
		var salvage_id := String(value)
		if not _registry.has_salvage(salvage_id):
			continue
		var definition := _registry.get_salvage_definition(salvage_id)
		var row := Label.new()
		row.text = "> %s · %s" % [
			tr(String(definition.display_name_key)),
			tr(_rarity_key(String(definition.rarity))),
		]
		row.theme_type_variation = &"UiBody"
		row.add_theme_color_override("font_color", _discovery_text_color(String(definition.rarity)))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		discoveries_list.add_child(row)

func _discovery_text_color(rarity: String) -> Color:
	match rarity:
		"epic":
			return Color("#60328a")
		"rare":
			return Color("#7a5700")
		"uncommon":
			return Color("#1f6547")
		_:
			return Color("#293640")

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

func _prepare_animation_state() -> void:
	balance_value.text = tr("DEBRIEF_CREDITS_FMT") % int(_transition.get("credits_before", 0))
	promotion_panel.visible = false
	promotion_panel.modulate.a = 0.0
	xp_progress.value = _progress_percent(_transition.get("rank_progress_before", {}) as Dictionary)
	_refresh_xp_progress_label(_transition.get("rank_progress_before", {}) as Dictionary)
	_animation_finished = false

func _play_sequence() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()

	var credits_before := int(_transition.get("credits_before", 0))
	var credits_after := int(_transition.get("credits_after", credits_before))
	var before_progress := _transition.get("rank_progress_before", {}) as Dictionary
	var after_progress := _transition.get("rank_progress_after", {}) as Dictionary
	var promoted := bool(_transition.get("promoted", false))

	_reward_player.play()
	_animation = create_tween()
	_animation.tween_method(_set_credit_balance, credits_before, credits_after, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_interval(0.10)

	if promoted:
		_animation.tween_method(
			_set_xp_progress_value,
			_progress_percent(before_progress),
			100.0,
			0.58
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_animation.tween_callback(_reveal_promotion)
		_animation.tween_method(
			_set_xp_progress_value,
			0.0,
			_progress_percent(after_progress),
			0.55
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_animation.tween_method(
			_set_xp_progress_value,
			_progress_percent(before_progress),
			_progress_percent(after_progress),
			0.74
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_animation.tween_callback(_finish_animation)

func _set_credit_balance(value: float) -> void:
	balance_value.text = tr("DEBRIEF_CREDITS_FMT") % int(round(value))

func _set_xp_progress_value(value: float) -> void:
	xp_progress.value = value
	var after_progress := _transition.get("rank_progress_after", {}) as Dictionary
	if bool(_transition.get("promoted", false)) and value >= 99.9 and not promotion_panel.visible:
		var before_progress := _transition.get("rank_progress_before", {}) as Dictionary
		_refresh_xp_progress_label(before_progress)
	else:
		_refresh_xp_progress_label(after_progress)

func _reveal_promotion() -> void:
	rank_value.text = tr(String(_transition.get("rank_after_key", "RANK_TRAINEE")))
	promotion_panel.visible = true
	_promotion_player.play()
	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(promotion_panel, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(promotion_panel, "scale", Vector2.ONE, 0.32).from(Vector2(0.985, 0.985)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish_animation() -> void:
	_animation_finished = true
	_set_credit_balance(float(_transition.get("credits_after", 0)))
	_set_xp_progress_value(_progress_percent(_transition.get("rank_progress_after", {}) as Dictionary))

func _progress_percent(progress: Dictionary) -> float:
	if progress.is_empty():
		return 0.0
	if bool(progress.get("is_max_rank", false)):
		return 100.0
	var current := float(progress.get("current_xp", 0))
	var low := float(progress.get("current_min_xp", 0))
	var high := float(progress.get("next_min_xp", low + 1.0))
	return clampf((current - low) / maxf(high - low, 1.0) * 100.0, 0.0, 100.0)

func _refresh_xp_progress_label(progress: Dictionary) -> void:
	if progress.is_empty():
		xp_progress_label.text = ""
	elif bool(progress.get("is_max_rank", false)):
		xp_progress_label.text = tr("DEBRIEF_XP_MAX_FMT") % int(progress.get("current_xp", 0))
	else:
		xp_progress_label.text = tr("DEBRIEF_XP_PROGRESS_FMT") % [
			int(progress.get("current_xp", 0)),
			int(progress.get("next_min_xp", 0)),
		]

func _continue_to_hq() -> void:
	if _audio != null:
		_audio.play_ui_click()
	continue_button.disabled = true
	if _platform != null:
		_platform.track_event("contract_debrief_continued", {
			"sector_id": String(_result.get("sector_id", "")),
			"animation_finished": _animation_finished,
		})

	if _ads != null:
		await _ads.show_contract_break()

	var return_path := String(_context.get("debrief_return_screen_path", OPERATIONS_SCREEN_PATH))
	var scene := load(return_path) as PackedScene
	assert(scene != null, "Debrief return screen must be loadable: %s" % return_path)

	var return_context := _context.duplicate(true)
	for key in [
		"debrief_result",
		"debrief_transition",
		"debrief_mission",
		"debrief_return_screen_path",
		"sector_id",
		"sector_definition",
		"endless_number",
		"return_screen_path",
	]:
		return_context.erase(key)
	_router.show_screen(scene, return_context)

func _play_ui_hover() -> void:
	if _audio != null:
		_audio.play_ui_hover()

func _create_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player
