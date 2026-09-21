extends Control

const OPERATIONS_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"
const FLIGHT_SCREEN_PATH := "res://src/ui/screens/flight/flight_screen.tscn"
const DEBRIEF_SCREEN_PATH := "res://src/ui/screens/debrief/contract_debrief_screen.tscn"
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
@onready var flight_feedback: FlightFeedback = %FlightFeedback
@onready var environment_runtime: EnvironmentRuntime = %EnvironmentRuntime
@onready var environment_status: Label = %EnvironmentStatus
@onready var depot_navigation: DepotNavigationGuide = %DepotNavigationGuide
@onready var mission_card: PanelContainer = %MissionCard
@onready var cargo_card: PanelContainer = %CargoCard
@onready var operations_button: Button = %OperationsButton
@onready var operations_overlay_host: Control = %OperationsOverlayHost
@onready var warp_transition: WarpTravelTransition = %WarpTravelTransition

var _context: Dictionary = {}
var _router: SceneRouter
var _input_service: InputService
var _platform: PlatformService
var _ads: AdService
var _progression: ProgressionService
var _registry := ContentRegistry.new()
var _contract_session := ContractSession.new()
var _gameplay_active := false
var _hint_tween: Tween
var _toast_tween: Tween
var _active_salvage: SalvageDefinition
var _new_discovery_ids: Array[String] = []
var _configured_sector_id := DEFAULT_SECTOR_ID
var _contract_active := true
var _operations_overlay: Control
var _travel_in_progress := false

func configure(context: Dictionary) -> void:
	_context = context
	_contract_active = not bool(context.get("free_roam", false))
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
	var ambient_motion := get_node("World/AmbientMotion") as AmbientOrbitLayer
	var environment := get_node("World/EnvironmentRuntime") as EnvironmentRuntime
	var post_process := get_node("WorldPost/WorldPostProcess") as WorldPostProcess
	var feedback := get_node("FlightFeedback") as FlightFeedback
	var depot := get_node("World/UnloadDepot") as UnloadZone
	var ship := get_node("World/PlayerShip") as PlayerShip
	var navigation := get_node("HUD/HudRoot/DepotNavigationGuide") as DepotNavigationGuide

	assert(runtime != null, "FlightScreen requires SectorRuntime.")
	assert(backdrop != null, "FlightScreen requires SectorBackdrop.")
	assert(ambient_motion != null, "FlightScreen requires AmbientOrbitLayer.")
	assert(environment != null, "FlightScreen requires EnvironmentRuntime.")
	assert(post_process != null, "FlightScreen requires WorldPostProcess.")
	assert(feedback != null, "FlightScreen requires FlightFeedback.")
	assert(depot != null, "FlightScreen requires UnloadZone.")
	assert(ship != null, "FlightScreen requires PlayerShip.")
	assert(navigation != null, "FlightScreen requires DepotNavigationGuide.")

	if generated_definition.is_empty():
		runtime.configure_sector(_configured_sector_id)
	else:
		runtime.configure_sector_definition(generated_definition)
	if _contract_active:
		_contract_session.configure(runtime.get_contract_context())
	var biome_palette := runtime.get_biome_palette()
	var visual_profile := runtime.get_biome_visual_profile()
	backdrop.configure(
		runtime.get_play_bounds(),
		biome_palette,
		runtime.get_biome_id(),
		visual_profile
	)
	ambient_motion.configure(
		runtime.get_play_bounds(),
		biome_palette,
		runtime.get_biome_id(),
		visual_profile
	)
	environment.configure(
		runtime.get_environment_fields(),
		runtime.get_play_bounds(),
		biome_palette,
		runtime.get_biome_id()
	)
	feedback.configure(biome_palette)

	var deployment_position := runtime.get_depot_position()
	depot.position = deployment_position
	ship.position = deployment_position
	if not _contract_active:
		var bounds := runtime.get_play_bounds()
		ship.position = Vector2(
			clampf(deployment_position.x + 420.0, bounds.position.x + 180.0, bounds.end.x - 180.0),
			clampf(deployment_position.y - 130.0, bounds.position.y + 180.0, bounds.end.y - 180.0)
		)
	ship.velocity = Vector2.ZERO
	if _context.has("debug_ship_offset"):
		ship.position += _context["debug_ship_offset"] as Vector2
		print("[QA] DEPOT_NAV_PREVIEW ship_offset=%s" % str(_context["debug_ship_offset"]))

	ship.configure(
		_input_service,
		runtime.get_play_bounds(),
		_progression.get_ship_modifiers(),
		_progression.get_ship_cosmetics()
	)
	environment.bind(ship, runtime, post_process)
	navigation.configure(ship, depot)
	print("[Flight] DEPLOYMENT position=(%.1f, %.1f) depot=(%.1f, %.1f)" % [
		ship.position.x,
		ship.position.y,
		depot.position.x,
		depot.position.y,
	])

func _ready() -> void:
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	return_button.pressed.connect(_return_to_operations)
	operations_button.pressed.connect(_open_operations)
	player_ship.movement_started.connect(_schedule_hint_fade)
	player_ship.cargo_changed.connect(_on_cargo_changed)
	player_ship.tractor_target_changed.connect(_on_tractor_target_changed)
	player_ship.tractor_progress_changed.connect(_on_tractor_progress_changed)
	player_ship.salvage_collected.connect(_on_salvage_collected)
	player_ship.cargo_collection_blocked.connect(_on_cargo_collection_blocked)
	player_ship.bumped.connect(_on_ship_bumped)
	unload_zone.cargo_unloaded.connect(_on_cargo_unloaded)
	_input_service.input_mode_changed.connect(_on_input_mode_changed)
	environment_runtime.environment_state_changed.connect(_on_environment_state_changed)

	if _contract_active:
		_contract_session.cleanliness_changed.connect(_on_cleanliness_changed)
		_contract_session.objective_changed.connect(_on_objective_changed)
		_contract_session.target_reached.connect(_on_contract_target_reached)
		_contract_session.perfect_cleanup_reached.connect(_on_perfect_cleanup_reached)
	else:
		sector_runtime.set_salvage_enabled(false)
		player_ship.set_collection_enabled(false)

	_apply_debug_landmark_focus()

	toast_panel.modulate.a = 0.0
	beam_progress.value = 0.0
	cleanup_progress.value = 0.0
	_apply_responsive_layout()
	_refresh_copy()
	_refresh_cleanup()
	_on_cargo_changed(player_ship.get_cargo_used(), player_ship.get_cargo_capacity())

	if _platform != null:
		_platform.gameplay_started()
	_gameplay_active = true

	if bool(_context.get("arrival_warp", false)):
		_travel_in_progress = true
		var direction_sign := -1.0 if int(_context.get("travel_direction", 1)) < 0 else 1.0
		await warp_transition.play_arrival(player_ship, Vector2.RIGHT * direction_sign, _contract_active)
		_travel_in_progress = false

	if _contract_active:
		_contract_session.start()
		if _platform != null:
			_platform.track_event("contract_started", {"sector_id": _configured_sector_id})

	if bool(_context.get("open_operations", false)) and not _contract_active:
		call_deferred("_open_operations")

	print("[Flight] READY mode=%s" % ("contract" if _contract_active else "free_roam"))

func _apply_debug_landmark_focus() -> void:
	var requested := String(_context.get("debug_landmark_focus", ""))
	if requested.is_empty():
		return
	if _platform == null or not _platform.is_debug_provider():
		return

	var landmarks := sector_runtime.get_landmark_nodes()
	if landmarks.is_empty():
		push_warning("Landmark QA focus requested but sector has no landmarks.")
		return

	var target := landmarks[0]
	if requested not in ["1", "true", "yes", "first"]:
		for candidate in landmarks:
			if candidate.get_landmark_id() == requested:
				target = candidate
				break

	var clearance := maxf(360.0, target.get_reserved_radius() * 0.72)
	var focus_position := target.global_position + Vector2.LEFT * clearance
	var bounds := sector_runtime.get_play_bounds()
	focus_position.x = clampf(focus_position.x, bounds.position.x + 160.0, bounds.end.x - 160.0)
	focus_position.y = clampf(focus_position.y, bounds.position.y + 160.0, bounds.end.y - 160.0)
	player_ship.global_position = focus_position
	player_ship.velocity = Vector2.ZERO
	var to_landmark := target.global_position - player_ship.global_position
	player_ship.ship_camera.set_framing_offset(to_landmark * 0.5)
	print("[QA] LANDMARK_FOCUS id=%s ship=(%.1f, %.1f) landmark=(%.1f, %.1f)" % [
		target.get_landmark_id(),
		player_ship.global_position.x,
		player_ship.global_position.y,
		target.global_position.x,
		target.global_position.y,
	])

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
	assert(flight_feedback != null, "FlightScreen requires FlightFeedback.")
	assert(environment_runtime != null and environment_status != null, "FlightScreen requires biome environment feedback.")
	assert(depot_navigation != null, "FlightScreen requires contextual depot navigation.")
	assert(mission_card != null and cargo_card != null, "FlightScreen requires compact flight cards.")
	assert(operations_button != null and operations_overlay_host != null, "FlightScreen requires floating operations access.")
	assert(warp_transition != null, "FlightScreen requires reusable warp travel transition.")
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
	if not _contract_active or _travel_in_progress:
		return

	var completed := _contract_session.is_target_reached()
	_stop_gameplay()
	_travel_in_progress = true
	await warp_transition.play_departure(player_ship, Vector2.LEFT)

	if completed:
		var result := _contract_session.build_result()
		result["new_discoveries"] = _new_discovery_ids.duplicate()
		var transition := _progression.apply_contract_result(result)

		if _platform != null:
			_platform.track_event("contract_completed", {
				"sector_id": _configured_sector_id,
				"perfect": bool(result["perfect_cleanup"]),
				"credits": int(result["credits_awarded"]),
				"promoted": bool(transition.get("promoted", false)),
			})

		var debrief_scene := load(DEBRIEF_SCREEN_PATH) as PackedScene
		assert(debrief_scene != null, "Contract Debrief scene must be loadable.")

		var debrief_context := _context.duplicate(true)
		debrief_context["debrief_result"] = result
		debrief_context["debrief_transition"] = transition
		debrief_context["debrief_return_screen_path"] = FLIGHT_SCREEN_PATH
		debrief_context["free_roam"] = true
		debrief_context["arrival_warp"] = true
		debrief_context["travel_direction"] = -1
		debrief_context["debrief_mission"] = {
			"sector_display_name_key": sector_runtime.get_sector_display_name_key(),
			"biome_display_name_key": sector_runtime.get_biome_display_name_key(),
		}
		if _context.has("endless_number"):
			(debrief_context["debrief_mission"] as Dictionary)["endless_number"] = int(_context["endless_number"])

		_router.show_screen(debrief_scene, debrief_context)
		return

	print("[Contract] ABORT sector=%s cleanliness=%.1f" % [
		_configured_sector_id,
		_contract_session.get_cleanup_percent(),
	])
	if _platform != null:
		_platform.track_event("contract_aborted", {"sector_id": _configured_sector_id})

	_route_to_home_orbit()

func _route_to_home_orbit() -> void:
	var scene := load(FLIGHT_SCREEN_PATH) as PackedScene
	assert(scene != null, "Free-flight screen must be loadable.")
	var return_context := _context.duplicate(true)
	for key in [
		"sector_definition",
		"endless_number",
		"return_screen_path",
		"debug_landmark_focus",
		"debug_ship_offset",
		"open_operations",
	]:
		return_context.erase(key)
	return_context["sector_id"] = DEFAULT_SECTOR_ID
	return_context["free_roam"] = true
	return_context["arrival_warp"] = true
	return_context["travel_direction"] = -1
	_router.show_screen(scene, return_context)

func _open_operations() -> void:
	if _contract_active or _travel_in_progress:
		return
	if _operations_overlay != null and is_instance_valid(_operations_overlay):
		return

	var packed := load(OPERATIONS_SCREEN_PATH) as PackedScene
	assert(packed != null, "Operations overlay must be loadable.")
	var overlay := packed.instantiate() as Control
	assert(overlay != null, "Operations overlay must instantiate as Control.")

	var overlay_context := _context.duplicate(true)
	overlay_context["operations_overlay"] = true
	overlay_context["debug_hq_sector_id"] = _configured_sector_id
	overlay_context.erase("open_operations")
	overlay.call("configure", overlay_context)
	overlay.connect("deployment_requested", Callable(self, "_on_operations_deployment_requested"))
	overlay.connect("close_requested", Callable(self, "_close_operations"))

	player_ship.set_flight_controls_enabled(false)
	_operations_overlay = overlay
	operations_overlay_host.add_child(overlay)
	overlay.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(overlay, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	print("[Flight] OPERATIONS_OPEN")

func _close_operations() -> void:
	if _operations_overlay == null or not is_instance_valid(_operations_overlay):
		return
	var overlay := _operations_overlay
	_operations_overlay = null
	if overlay.get_parent() != null:
		overlay.get_parent().remove_child(overlay)
	overlay.queue_free()
	player_ship.set_flight_controls_enabled(true)
	print("[Flight] OPERATIONS_CLOSED")

func _on_operations_deployment_requested(target_context: Dictionary) -> void:
	if _travel_in_progress:
		return
	if _operations_overlay != null and is_instance_valid(_operations_overlay):
		var overlay := _operations_overlay
		_operations_overlay = null
		if overlay.get_parent() != null:
			overlay.get_parent().remove_child(overlay)
		overlay.queue_free()

	_travel_in_progress = true
	_stop_gameplay()
	await warp_transition.play_departure(player_ship, Vector2.RIGHT)
	var scene := load(FLIGHT_SCREEN_PATH) as PackedScene
	assert(scene != null, "Contract flight screen must be loadable.")
	_router.show_screen(scene, target_context)

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

	operations_button.text = tr("FLIGHT_OPERATIONS")
	operations_button.visible = not _contract_active
	return_button.visible = _contract_active
	cargo_card.visible = _contract_active
	depot_navigation.visible = _contract_active

	if not _contract_active:
		%FlightEyebrow.text = tr("FLIGHT_FREE_EYEBROW")
		%FlightTitle.text = tr(sector_runtime.get_biome_display_name_key())
		cleanup_status.text = tr("FLIGHT_FREE_STATUS")
		cleanup_progress.visible = false
		%DepotLabel.text = tr("FLIGHT_DEPOT")
		environment_status.text = tr("FLIGHT_ENVIRONMENT_FMT") % tr("ENV_STABLE_ORBIT")
		var steering_hint := tr("FLIGHT_HINT_TOUCH") if _input_service.prefers_touch() else tr("FLIGHT_HINT_POINTER")
		hint_label.text = "%s\n%s" % [steering_hint, tr("FLIGHT_VISUAL_LEGEND")]
		return

	cleanup_progress.visible = true
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
	environment_status.text = tr("FLIGHT_ENVIRONMENT_FMT") % tr("ENV_STABLE_ORBIT")
	_refresh_return_button()
	_refresh_cleanup()

	_on_cargo_changed(player_ship.get_cargo_used(), player_ship.get_cargo_capacity())
	if _active_salvage == null:
		beam_status.text = tr("FLIGHT_BEAM_SCANNING")
	else:
		beam_status.text = tr("FLIGHT_BEAM_LOCK_FMT") % tr(String(_active_salvage.display_name_key))

func _refresh_cleanup() -> void:
	if not is_node_ready() or not _contract_active:
		return
	var objective := _contract_session.get_objective_snapshot()
	var progress := float(objective["progress_percent"])
	var cleanup := int(round(float(objective["cleanup_percent"])))
	cleanup_progress.value = progress

	match String(objective["kind"]):
		"cleanup":
			cleanup_status.text = tr("FLIGHT_CLEANLINESS_FMT") % [
				int(round(float(objective["current"]))),
				int(round(float(objective["target"]))),
			]
		"full_cleanup":
			cleanup_status.text = tr("FLIGHT_OBJECTIVE_FULL_FMT") % cleanup
		"recovery":
			cleanup_status.text = tr("FLIGHT_OBJECTIVE_RECOVERY_FMT") % [
				int(objective["current"]),
				int(objective["target"]),
				cleanup,
			]
		"valuable_recovery":
			cleanup_status.text = tr("FLIGHT_OBJECTIVE_VALUE_FMT") % [
				int(objective["current"]),
				int(objective["target"]),
				cleanup,
			]
		"priority_object":
			var target_definition := _registry.get_salvage_definition(String(objective["priority_salvage_id"]))
			cleanup_status.text = tr("FLIGHT_OBJECTIVE_PRIORITY_FMT") % [
				tr(String(target_definition.display_name_key)),
				int(objective["current"]),
				int(objective["target"]),
				cleanup,
			]

func _refresh_return_button() -> void:
	if not is_node_ready() or not _contract_active:
		return
	if _contract_session.is_perfect_cleanup():
		return_button.text = tr("FLIGHT_RETURN_PERFECT")
	elif _contract_session.is_target_reached():
		return_button.text = tr("FLIGHT_COMPLETE_CONTRACT")
	else:
		return_button.text = tr("FLIGHT_ABORT_CONTRACT")

func _on_cleanliness_changed(_percent: float, _cleaned: float, _total: float) -> void:
	_refresh_return_button()

func _on_objective_changed(_snapshot: Dictionary) -> void:
	_refresh_cleanup()
	_refresh_return_button()

func _on_contract_target_reached() -> void:
	_show_toast(tr("FLIGHT_CONTRACT_COMPLETE"))
	flight_feedback.contract_target_reached()
	_refresh_return_button()

func _on_perfect_cleanup_reached() -> void:
	_show_toast(tr("FLIGHT_PERFECT_CLEANUP"))
	flight_feedback.perfect_cleanup()
	_refresh_return_button()

func _on_cargo_changed(used_units: int, capacity: int) -> void:
	cargo_label.text = tr("FLIGHT_CARGO_FMT") % [used_units, capacity]
	depot_navigation.set_cargo_state(used_units, capacity)
	unload_zone.set_cargo_state(used_units, capacity)
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
	flight_feedback.target_acquired(_active_salvage)

func _on_tractor_progress_changed(progress: float) -> void:
	beam_progress.value = clampf(progress, 0.0, 1.0) * 100.0

func _on_salvage_collected(definition, _used_units: int, _capacity: int) -> void:
	if not _contract_active:
		return
	var salvage := definition as SalvageDefinition
	if salvage == null:
		return
	var is_new_discovery := _progression.register_discovery(salvage)
	_contract_session.record_salvage(salvage)
	flight_feedback.salvage_collected(salvage, is_new_discovery, player_ship.global_position)
	if is_new_discovery:
		if not _new_discovery_ids.has(String(salvage.id)):
			_new_discovery_ids.append(String(salvage.id))
		_show_toast(tr("FLIGHT_NEW_DISCOVERY_FMT") % tr(String(salvage.display_name_key)))
		if _platform != null:
			_platform.track_event("discovery_registered", {
				"salvage_id": String(salvage.id),
				"rarity": String(salvage.rarity),
			})
	else:
		_show_toast(tr("FLIGHT_RECOVERED_FMT") % tr(String(salvage.display_name_key)))

func _on_cargo_collection_blocked() -> void:
	beam_status.text = tr("FLIGHT_CARGO_NO_SPACE")
	_show_toast(tr("FLIGHT_CARGO_NO_SPACE"))

func _on_cargo_unloaded(units: int) -> void:
	_show_toast(tr("FLIGHT_UNLOADED_FMT") % units)
	flight_feedback.cargo_unloaded(units, unload_zone.global_position)
	beam_status.text = tr("FLIGHT_BEAM_SCANNING")

func _on_environment_state_changed(label_key: String, intensity: float) -> void:
	environment_status.text = tr("FLIGHT_ENVIRONMENT_FMT") % tr(label_key)
	var calm := Color("#79e6c4")
	var active := Color("#ffc857")
	environment_status.add_theme_color_override(
		"font_color",
		calm.lerp(active, clampf(intensity, 0.0, 1.0))
	)

func _on_ship_bumped(intensity: float, _normal: Vector2) -> void:
	flight_feedback.ship_bumped(intensity, player_ship.global_position)

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
