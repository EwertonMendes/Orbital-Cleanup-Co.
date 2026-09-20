extends Control

const OPERATIONS_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"
const DEFAULT_SECTOR_ID := "earth_training_01"

@onready var safe_area: MarginContainer = %SafeArea
@onready var top_bar: BoxContainer = %TopBar
@onready var return_button: Button = %ReturnButton
@onready var hint_panel: Control = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var cargo_label: Label = %CargoLabel
@onready var beam_status: Label = %BeamStatus
@onready var beam_progress: ProgressBar = %BeamProgress
@onready var cleanup_status: Label = %CleanupStatus
@onready var cleanup_progress: ProgressBar = %CleanupProgress
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var unload_zone: UnloadZone = %UnloadDepot
@onready var sector_runtime: SectorRuntime = %SectorRuntime
@onready var player_ship: PlayerShip = %PlayerShip

var _context: Dictionary = {}
var _router: SceneRouter
var _input_service: InputService
var _platform: PlatformService
var _ads: AdService
var _progression: ProgressionService
var _contract_session := ContractSession.new()
var _gameplay_active := false
var _hint_tween: Tween
var _toast_tween: Tween
var _active_salvage: SalvageDefinition
var _configured_sector_id := DEFAULT_SECTOR_ID

func configure(context: Dictionary) -> void:
	_context = context
	_router = context.get("router") as SceneRouter
	_input_service = context.get("input") as InputService
	_platform = context.get("platform") as PlatformService
	_ads = context.get("ads") as AdService
	_progression = context.get("progression") as ProgressionService
	assert(_input_service != null, "FlightScreen requires InputService.")
	assert(_progression != null, "FlightScreen requires ProgressionService.")

	var generated_definition := context.get("sector_definition", {}) as Dictionary
	_configured_sector_id = String(
		generated_definition.get("id", context.get("sector_id", DEFAULT_SECTOR_ID))
	)
	var runtime := get_node("World/SectorRuntime") as SectorRuntime
	var backdrop := get_node("World/AmbientSpace") as SectorBackdrop
	var depot := get_node("World/UnloadDepot") as UnloadZone
	var ship := get_node("World/PlayerShip") as PlayerShip

	assert(runtime != null, "FlightScreen requires SectorRuntime.")
	assert(backdrop != null, "FlightScreen requires SectorBackdrop.")
	assert(depot != null, "FlightScreen requires UnloadZone.")
	assert(ship != null, "FlightScreen requires PlayerShip.")

	if generated_definition.is_empty():
		runtime.configure_sector(_configured_sector_id)
	else:
		runtime.configure_sector_definition(generated_definition)
	_contract_session.configure(runtime.get_contract_context())
	backdrop.configure(runtime.get_play_bounds(), runtime.get_biome_palette())
	depot.position = runtime.get_depot_position()
	ship.configure(
		_input_service,
		runtime.get_play_bounds(),
		_progression.get_ship_modifiers(),
		_progression.get_ship_cosmetics()
	)

func _ready() -> void:
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	return_button.pressed.connect(_return_to_operations)
	player_ship.movement_started.connect(_schedule_hint_fade)
	player_ship.cargo_changed.connect(_on_cargo_changed)
	player_ship.tractor_target_changed.connect(_on_tractor_target_changed)
	player_ship.tractor_progress_changed.connect(_on_tractor_progress_changed)
	player_ship.salvage_collected.connect(_on_salvage_collected)
	player_ship.cargo_collection_blocked.connect(_on_cargo_collection_blocked)
	unload_zone.cargo_unloaded.connect(_on_cargo_unloaded)
	_input_service.input_mode_changed.connect(_on_input_mode_changed)
	_contract_session.cleanliness_changed.connect(_on_cleanliness_changed)
	_contract_session.target_reached.connect(_on_contract_target_reached)
	_contract_session.perfect_cleanup_reached.connect(_on_perfect_cleanup_reached)
	_contract_session.start()

	toast_panel.modulate.a = 0.0
	beam_progress.value = 0.0
	cleanup_progress.value = 0.0
	_apply_responsive_layout()
	_refresh_copy()
	_refresh_cleanup()
	_on_cargo_changed(player_ship.get_cargo_used(), player_ship.get_cargo_capacity())

	if _platform != null:
		_platform.gameplay_started()
		_platform.track_event("contract_started", {"sector_id": _configured_sector_id})
	_gameplay_active = true
	print("[Flight] READY")

func _exit_tree() -> void:
	_stop_gameplay()

func _validate_contracts() -> void:
	assert(safe_area != null, "FlightScreen requires SafeArea.")
	assert(top_bar != null, "FlightScreen requires responsive TopBar.")
	assert(return_button != null, "FlightScreen requires ReturnButton.")
	assert(hint_panel != null and hint_label != null, "FlightScreen requires steering hint.")
	assert(cargo_label != null and beam_status != null and beam_progress != null, "FlightScreen requires salvage HUD.")
	assert(cleanup_status != null and cleanup_progress != null, "FlightScreen requires contract cleanliness HUD.")
	assert(toast_panel != null and toast_label != null, "FlightScreen requires collection feedback.")
	assert(unload_zone != null, "FlightScreen requires UnloadZone.")
	assert(sector_runtime != null, "FlightScreen requires SectorRuntime.")
	assert(player_ship != null, "FlightScreen requires PlayerShip.")
	assert(sector_runtime.get_play_bounds().size.x > 0.0, "SectorRuntime must provide valid play bounds.")

func _apply_responsive_layout() -> void:
	var portrait := ResponsiveCanvas.apply_reference(get_tree().root)
	var compact := portrait or size.x < 640.0
	top_bar.vertical = compact

	var horizontal_margin := 14 if compact else 24
	var vertical_margin := 14 if compact else 20
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

	hint_panel.custom_minimum_size.x = 300.0 if compact else 500.0
	toast_panel.custom_minimum_size.x = 280.0 if compact else 390.0

func _return_to_operations() -> void:
	var completed := _contract_session.is_target_reached()
	if completed:
		var result := _contract_session.build_result()
		_progression.apply_contract_result(result)
		if _platform != null:
			_platform.track_event("contract_completed", {
				"sector_id": _configured_sector_id,
				"perfect": bool(result["perfect_cleanup"]),
				"credits": int(result["credits_awarded"]),
			})
	else:
		print("[Contract] ABORT sector=%s cleanliness=%.1f" % [
			_configured_sector_id,
			_contract_session.get_cleanup_percent(),
		])
		if _platform != null:
			_platform.track_event("contract_aborted", {"sector_id": _configured_sector_id})

	_stop_gameplay()
	if completed and _ads != null:
		await _ads.show_contract_break()

	var return_path := String(_context.get("return_screen_path", OPERATIONS_SCREEN_PATH))
	var scene := load(return_path) as PackedScene
	assert(scene != null, "Return screen must be loadable: %s" % return_path)
	var return_context := _context.duplicate(true)
	return_context.erase("sector_id")
	return_context.erase("sector_definition")
	return_context.erase("endless_number")
	return_context.erase("return_screen_path")
	_router.show_screen(scene, return_context)

func _stop_gameplay() -> void:
	if not _gameplay_active:
		return
	if _platform != null:
		_platform.gameplay_stopped()
	_gameplay_active = false

func _on_input_mode_changed(_mode: InputService.InputMode) -> void:
	_refresh_copy()
	_show_hint_temporarily()

func _refresh_copy() -> void:
	if not is_node_ready():
		return
	%FlightEyebrow.text = tr("FLIGHT_EYEBROW")
	if _context.has("endless_number"):
		%FlightTitle.text = tr("SECTOR_ENDLESS_CONTRACT_FMT") % [
			int(_context["endless_number"]),
			tr(sector_runtime.get_biome_display_name_key()),
		]
	else:
		%FlightTitle.text = tr(sector_runtime.get_sector_display_name_key())
	var steering_hint := tr("FLIGHT_HINT_TOUCH") if _input_service.prefers_touch() else tr("FLIGHT_HINT_POINTER")
	hint_label.text = "%s\n%s" % [steering_hint, tr("FLIGHT_VISUAL_LEGEND")]
	%DepotLabel.text = tr("FLIGHT_DEPOT")
	_refresh_return_button()
	_refresh_cleanup()

	_on_cargo_changed(player_ship.get_cargo_used(), player_ship.get_cargo_capacity())
	if _active_salvage == null:
		beam_status.text = tr("FLIGHT_BEAM_SCANNING")
	else:
		beam_status.text = tr("FLIGHT_BEAM_LOCK_FMT") % tr(String(_active_salvage.display_name_key))

func _refresh_cleanup() -> void:
	if not is_node_ready():
		return
	var percent := _contract_session.get_cleanup_percent()
	var target := _contract_session.get_target_percent()
	cleanup_progress.value = percent
	cleanup_status.text = tr("FLIGHT_CLEANLINESS_FMT") % [int(round(percent)), int(round(target))]

func _refresh_return_button() -> void:
	if not is_node_ready():
		return
	if _contract_session.is_perfect_cleanup():
		return_button.text = tr("FLIGHT_RETURN_PERFECT")
	elif _contract_session.is_target_reached():
		return_button.text = tr("FLIGHT_COMPLETE_CONTRACT")
	else:
		return_button.text = tr("FLIGHT_ABORT_CONTRACT")

func _on_cleanliness_changed(_percent: float, _cleaned: float, _total: float) -> void:
	_refresh_cleanup()
	_refresh_return_button()

func _on_contract_target_reached() -> void:
	_show_toast(tr("FLIGHT_CONTRACT_COMPLETE"))
	_refresh_return_button()

func _on_perfect_cleanup_reached() -> void:
	_show_toast(tr("FLIGHT_PERFECT_CLEANUP"))
	_refresh_return_button()

func _on_cargo_changed(used_units: int, capacity: int) -> void:
	cargo_label.text = tr("FLIGHT_CARGO_FMT") % [used_units, capacity]
	if used_units >= capacity and _active_salvage == null:
		beam_status.text = tr("FLIGHT_CARGO_FULL")

func _on_tractor_target_changed(definition) -> void:
	_active_salvage = definition as SalvageDefinition
	beam_progress.value = 0.0
	beam_progress.visible = _active_salvage != null

	if _active_salvage == null:
		if player_ship.get_cargo_used() >= player_ship.get_cargo_capacity():
			beam_status.text = tr("FLIGHT_CARGO_FULL")
		else:
			beam_status.text = tr("FLIGHT_BEAM_SCANNING")
		return

	beam_status.text = tr("FLIGHT_BEAM_LOCK_FMT") % tr(String(_active_salvage.display_name_key))

func _on_tractor_progress_changed(progress: float) -> void:
	beam_progress.value = clampf(progress, 0.0, 1.0) * 100.0

func _on_salvage_collected(definition, _used_units: int, _capacity: int) -> void:
	var salvage := definition as SalvageDefinition
	if salvage == null:
		return
	_contract_session.record_salvage(salvage)
	_show_toast(tr("FLIGHT_RECOVERED_FMT") % tr(String(salvage.display_name_key)))

func _on_cargo_collection_blocked() -> void:
	beam_status.text = tr("FLIGHT_CARGO_NO_SPACE")
	_show_toast(tr("FLIGHT_CARGO_NO_SPACE"))

func _on_cargo_unloaded(units: int) -> void:
	_show_toast(tr("FLIGHT_UNLOADED_FMT") % units)
	beam_status.text = tr("FLIGHT_BEAM_SCANNING")

func _show_toast(message: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	toast_label.text = message
	toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_interval(1.65)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.32)

func _show_hint_temporarily() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	hint_panel.modulate.a = 1.0
	_schedule_hint_fade()

func _schedule_hint_fade() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(2.4)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.10, 0.65)
