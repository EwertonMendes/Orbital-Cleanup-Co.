extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_app_root()
	_validate_responsive_ui()
	_validate_operations_screen()
	_validate_hq_components()
	_validate_ship_steering()
	_validate_world_visual_language()
	_validate_content_runtime()
	_validate_environment_fields()
	_validate_endless_contracts()
	_validate_sector_preview()
	_validate_contract_session()
	_validate_progression_service()
	_validate_cargo_hold()
	_validate_player_ship()
	_validate_flight_screen()
	_validate_debrief_screen()
	_validate_polish_systems()
	_validate_render_quality()
	if _failed:
		quit(1)
		return
	print("[QA] CORE_CONTRACTS_OK")
	quit(0)

func _validate_app_root() -> void:
	var packed := load("res://src/core/app/app_root.tscn") as PackedScene
	_expect(packed != null, "AppRoot scene must load.")
	if packed == null:
		return
	var root := packed.instantiate()
	_expect(root.get_node_or_null("Services/BuildInfo") is BuildInfo, "AppRoot must own BuildInfo.")
	_expect(root.get_node_or_null("Services/PlatformService") is PlatformService, "AppRoot must own PlatformService.")
	_expect(root.get_node_or_null("Services/AdService") is AdService, "AppRoot must own AdService.")
	_expect(root.get_node_or_null("Services/SettingsService") is SettingsService, "AppRoot must own SettingsService.")
	_expect(root.get_node_or_null("Services/SaveService") is SaveService, "AppRoot must own SaveService.")
	_expect(root.get_node_or_null("Services/AudioService") is AudioService, "AppRoot must own AudioService.")
	_expect(root.get_node_or_null("Services/InputService") is InputService, "AppRoot must own InputService.")
	_expect(root.get_node_or_null("Services/SceneRouter") is SceneRouter, "AppRoot must own SceneRouter.")
	_expect(root.get_node_or_null("Services/ProgressionService") is ProgressionService, "AppRoot must own ProgressionService.")
	_expect(root.get_node_or_null("ScreenHost") is Control, "AppRoot must expose ScreenHost.")
	_expect(root.get_node_or_null("TravelHandoffLayer/TravelCover") is ColorRect, "AppRoot must own a persistent travel handoff cover above routed screens.")
	_expect(root.get_node_or_null("TravelHandoffLayer/TravelCover/LoadingCenter/LoadingPanel") is PanelContainer, "Travel cover must present the shared styled loading panel.")
	_expect(root.get_node_or_null("TravelHandoffLayer/TravelCover/LoadingCenter/LoadingPanel/LoadingMargin/LoadingLayout/LoadingTitle") is Label, "Travel loading panel requires game-styled title copy.")
	var app_source := FileAccess.get_file_as_string("res://src/core/app/app_root.gd")
	_expect("const DEFAULT_SCREEN_PATH := FLIGHT_SCREEN_PATH" in app_source, "AppRoot must boot into continuous Flight instead of the legacy full-screen HQ.")
	_expect("context[\"free_roam\"] = true" in app_source, "Default startup must explicitly enter contract-free flight.")
	_expect("scene_router.configure(screen_host, travel_cover)" in app_source, "SceneRouter must receive the persistent travel cover from AppRoot.")
	var app_scene_source := FileAccess.get_file_as_string("res://src/core/app/app_root.tscn")
	_expect("occ_operations_theme.tres" in app_scene_source and "LoadingPanel" in app_scene_source, "Persistent loading UI must use the shared Kenney console style.")
	var bootstrap_scene_source := FileAccess.get_file_as_string("res://src/ui/screens/bootstrap/bootstrap_screen.tscn")
	_expect("occ_operations_theme.tres" in bootstrap_scene_source, "Bootstrap/loading screen must use the shared Kenney game UI theme.")
	_expect("StyleBoxFlat" not in bootstrap_scene_source, "Bootstrap/loading screen must not retain legacy flat UI chrome.")
	var router_source := FileAccess.get_file_as_string("res://src/core/app/scene_router.gd")
	_expect("travel_handoff" in router_source, "SceneRouter must expose a dedicated travel handoff path instead of reusing generic screen fades.")
	_expect("finish_travel_handoff" in router_source, "Travel handoff must wait for the destination before revealing it.")
	root.free()

func _validate_responsive_ui() -> void:
	_expect(
		ResponsiveUiProfile.classify(Vector2i(1280, 720)) == ResponsiveUiProfile.Profile.DESKTOP,
		"1280x720 must preserve desktop UI density."
	)
	_expect(
		ResponsiveUiProfile.classify(Vector2i(844, 390)) == ResponsiveUiProfile.Profile.PHONE_LANDSCAPE,
		"844x390 must use the phone-landscape UI profile."
	)
	_expect(
		ResponsiveUiProfile.classify(Vector2i(390, 844)) == ResponsiveUiProfile.Profile.PHONE_PORTRAIT,
		"390x844 must use the phone-portrait UI profile."
	)
	_expect(
		ResponsiveUiProfile.classify(Vector2i(1536, 691), true) == ResponsiveUiProfile.Profile.PHONE_LANDSCAPE,
		"Touch devices must keep phone-landscape density even when the browser reports a desktop-sized viewport."
	)
	_expect(
		ResponsiveUiProfile.touch_target_height(
			ResponsiveUiProfile.Profile.PHONE_LANDSCAPE,
			Vector2i(844, 390)
		) >= 90.0,
		"Phone UI must compensate touch targets for the physical Web canvas scale."
	)
	_expect(
		ResponsiveUiProfile.font_scale(
			ResponsiveUiProfile.Profile.PHONE_LANDSCAPE,
			Vector2i(844, 390)
		) > 2.0,
		"Phone typography must compensate for downscaled Web canvases."
	)

	var canvas_source := FileAccess.get_file_as_string("res://src/ui/utilities/responsive_canvas.gd")
	_expect(
		"JavaScriptBridge.get_interface(\"window\")" in canvas_source and "visualViewport" in canvas_source and "innerWidth" in canvas_source and "innerHeight" in canvas_source,
		"Web responsive layout must prefer the real visual viewport and fall back to the browser CSS viewport."
	)
	_expect(
		"DisplayServer.is_touchscreen_available()" in canvas_source and "maxTouchPoints" in canvas_source,
		"Web responsive layout must identify touch devices independently from inflated landscape viewport dimensions."
	)

	var profile_source := FileAccess.get_file_as_string("res://src/ui/utilities/responsive_ui_profile.gd")
	_expect("FONT_MINIMUMS" in profile_source and "build_theme" in profile_source, "Responsive UI must centralize semantic typography density.")
	_expect("apply_minimum_touch_targets" in profile_source, "Responsive UI must centralize minimum touch-target sizing.")
	_expect("\"BaseButton\"" in profile_source, "Responsive touch targets must cover Button and TextureButton controls.")

	var flight_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.gd")
	var operations_source := FileAccess.get_file_as_string("res://src/ui/screens/operations/operations_screen.gd")
	var debrief_source := FileAccess.get_file_as_string("res://src/ui/screens/debrief/contract_debrief_screen.gd")
	var touch_source := FileAccess.get_file_as_string("res://src/ui/components/touch_flight_controls.gd")
	var collected_handler_start := flight_source.find("func _on_salvage_collected")
	var unloaded_handler_start := flight_source.find("func _on_cargo_unloaded")
	_expect(collected_handler_start >= 0 and unloaded_handler_start > collected_handler_start, "Flight must expose collection and depot-delivery handlers.")
	if collected_handler_start >= 0 and unloaded_handler_start > collected_handler_start:
		var collected_handler_source := flight_source.substr(
			collected_handler_start,
			unloaded_handler_start - collected_handler_start
		)
		_expect("record_delivery" not in collected_handler_source, "Collecting salvage into the hold must not advance contract recovery.")
	_expect(
		"_contract_session.record_delivery(delivered_salvage)" in flight_source,
		"Depot unloading must be the point that confirms contract recovery."
	)
	_expect("ResponsiveUiProfile.current()" in flight_source, "Flight must consume the shared responsive UI profile.")
	_expect("ResponsiveUiProfile.current()" in operations_source, "Operations must consume the shared responsive UI profile.")
	_expect("available_width if phone" in operations_source, "Phone Operations must use the available viewport instead of the desktop console width cap.")
	_expect("ResponsiveUiProfile.current()" in debrief_source, "Debrief must consume the shared responsive UI profile.")
	_expect("touch_target_height" in touch_source, "Touch flight controls must size from the shared UI profile.")
	_expect("visible = _controls_enabled" in touch_source, "Boost HUD must remain visible on desktop as well as touch devices.")
	_expect("steering_area.visible = touch_steering" in touch_source, "Only the floating steering surface should be touch-specific.")
	_expect("recharge_bar.visible = true" in touch_source, "Boost recharge feedback must stay visible on desktop and mobile.")

	var flight_scene_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.tscn")
	_expect("theme_override_font_sizes/font_size = 11" not in flight_scene_source, "Flight depot telemetry must inherit semantic responsive typography.")


func _validate_operations_screen() -> void:
	var packed := load("res://src/ui/screens/operations/operations_screen.tscn") as PackedScene
	_expect(packed != null, "Operations screen must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is Control, "Operations screen must inherit Control.")
	_expect(screen.find_child("PrimaryAction", true, false) is Button, "Operations requires deployment action.")
	_expect(screen.find_child("ShipArt", true, false) is TextureRect, "Operations requires contract ship preview.")
	_expect(screen.find_child("UpgradeGrid", true, false) is GridContainer, "Operations requires upgrade grid.")
	_expect(screen.find_child("CareerList", true, false) is VBoxContainer, "Operations requires focused career milestones.")
	_expect(screen.find_child("ContentStage", true, false) is MarginContainer, "Operations requires a fixed no-scroll content stage.")
	_expect(screen.find_children("*", "ScrollContainer", true, false).is_empty(), "Operations must not depend on ScrollContainer at any breakpoint.")
	_expect(screen.find_child("PreviousContract", true, false) is Button, "Operations requires previous unlocked contract action.")
	_expect(screen.find_child("NextContract", true, false) is Button, "Operations requires next unlocked contract action.")
	_expect(screen.find_child("ContractPosition", true, false) is Label, "Operations requires contract position feedback.")
	_expect(screen.find_child("CloseOverlay", true, false) is Button, "Operations requires a close action when embedded over flight.")
	_expect(screen.find_child("OverlayScrim", true, false) is ColorRect, "Operations overlay requires a world scrim.")
	_expect(screen.find_child("FloatingSurface", true, false) is PanelContainer, "Operations requires a centered console surface.")
	_expect(screen.find_child("DiscoveryList", true, false) is GridContainer, "Discovery catalog must use a responsive card grid.")
	_expect(screen.find_child("SettingsLayer", true, false) is Control, "Operations requires a dedicated settings layer.")
	_expect(screen.find_child("SettingsModal", true, false) is PanelContainer, "Operations requires a physical settings panel.")
	_expect(screen.find_child("VolumeDown", true, false) is Button and screen.find_child("VolumeUp", true, false) is Button, "Settings requires audio controls.")
	_expect(screen.find_child("LanguageGroup", true, false) is HBoxContainer, "Language selection must live inside Settings.")
	_expect(screen.find_child("InterfaceParticles", true, false) == null, "Operations must not cover native Kenney chrome with generic UI particles.")
	_expect(screen.find_child("MenuWarpFX", true, false) == null, "Operations tab changes must not overlay blue warp streak particles.")

	for tab_name in ["ContractsTab", "UpgradesTab", "CareerTab", "ShipTab", "DiscoveryTab"]:
		_expect(screen.find_child(tab_name, true, false) is Button, "Operations requires navigation button: %s" % tab_name)

	for panel_name in ["ContractsPanel", "UpgradesPanel", "CareerPanel", "ShipPanel", "DiscoveryPanel"]:
		_expect(screen.find_child(panel_name, true, false) is VBoxContainer, "Operations requires panel: %s" % panel_name)

	var unique_refs := [
		"SafeArea", "Header", "MainRow", "TabGrid", "ContentScroll", "ContentShell",
		"ContractsPanel", "UpgradesPanel", "CareerPanel", "ShipPanel", "DiscoveryPanel",
		"ContractHero", "ShipBody", "PrimaryAction", "Footer", "UpgradeGrid", "CareerList",
		"CreditsLabel", "RankLabel", "XpLabel", "CareerRankValue", "CareerXpLabel", "CareerXpBar",
		"ContractState", "ContractSelector", "ContractPosition", "PreviousContract", "EndlessContract", "NextContract",
		"ContractTitle", "ContractDescription", "ContractTarget", "ContractRisk", "ContractPayout", "ContractRequirement",
		"NextUnlockPanel", "NextUnlockTitle", "NextUnlockLabel", "NextUnlockProgress", "NextUnlockProgressLabel",
		"LastResult", "ShipStats", "DiscoveryCount", "CompletedContracts",
		"EnglishButton", "PortugueseButton", "SpanishButton", "ContractsTab", "UpgradesTab",
		"CareerTab", "ShipTab", "DiscoveryTab", "CompanyLabel", "DeskLabel", "LanguageLabel",
		"ContractsTitle", "ContractsSubtitle", "ContractShipName", "ContractShipStatus",
		"UpgradesTitle", "UpgradesSubtitle", "CareerTitle", "CareerSubtitle", "ShipTitle",
		"ShipSubtitle", "ShipName", "ShipPreview", "ShipArt", "LoadoutTitle", "HullValue", "PaintValue", "TrailValue",
		"BeamStyleValue", "WorkshopStatus", "HullHeading", "PaintHeading", "TrailHeading", "BeamHeading",
		"HullOptions", "PaintOptions", "TrailOptions", "BeamOptions", "DiscoveryTitle", "DiscoverySubtitle",
		"DiscoveryEmptyTitle", "DiscoveryEmptyBody", "CloseOverlay", "OverlayScrim", "FloatingSurface",
		"SettingsButton", "SettingsLayer", "SettingsModal", "SettingsClose", "VolumeDown", "VolumeUp", "VolumeValue",
	]
	for node_name in unique_refs:
		_expect(
			screen.get_node_or_null(NodePath("%" + node_name)) != null,
			"Operations script reference must be unique: %%%s" % node_name
		)

	var operations_source := FileAccess.get_file_as_string("res://src/ui/screens/operations/operations_screen.gd")
	_expect("_active_contract_access()" in operations_source, "Operations deploy must consult centralized progression access.")
	_expect("is_sector_unlocked" in operations_source, "Contract navigation must expose unlocked sectors only.")
	_expect("endless_contract.visible = _progression.is_endless_unlocked()" in operations_source, "Endless navigation must stay hidden before unlock.")
	_expect("discovery_tab.visible = _progression.get_discovery_count() > 0" in operations_source, "Discovery navigation must stay hidden before first discovery.")
	_expect("if not unlocked:" in operations_source and "continue" in operations_source, "Locked cosmetics must stay absent instead of cluttering the workshop.")
	_expect("_open_settings" in operations_source and "_adjust_volume" in operations_source, "Language/audio controls must be routed through Settings.")
	_expect("ResponsiveUiProfile.viewport_size()" in operations_source and "console_height := 1180.0 if portrait else 650.0" in operations_source, "Operations must use the shared real viewport source and a tall portrait console to prevent clipping.")
	_expect("settings_modal.custom_minimum_size" in operations_source and "footer_spacer.visible = not portrait" in operations_source, "Operations must protect compact Settings and portrait deployment layouts from overflow.")
	_expect("position:x" in operations_source and "_update_tab_visuals" in operations_source, "Operations tab changes require smooth directional panel motion and explicit selected-tab styling.")
	_expect("menu_warp_fx" not in operations_source, "Operations tab changes must not use the removed blue warp-particle overlay.")
	_expect('event.is_action_pressed("ui_cancel")' in operations_source, "Operations overlay must close from ESC / ui_cancel.")
	var operations_scene_source := FileAccess.get_file_as_string("res://src/ui/screens/operations/operations_screen.tscn")
	_expect('text = "-"' in operations_scene_source, "Settings volume-down must use an ASCII minus glyph supported by the display font.")

	var theme_source := FileAccess.get_file_as_string("res://src/ui/themes/occ_operations_theme.tres")
	_expect("StyleBoxTexture" in theme_source, "Operations must skin controls with original Kenney textures.")
	_expect("StyleBoxFlat" not in theme_source, "Operations must not redraw Kenney UI as generic Godot flat chrome.")
	_expect("bar_shadow_round_large.png" in theme_source, "Operations requires clean native-height Kenney button chrome.")
	_expect("Yellow/Double/bar_round_gloss_large.png" in theme_source, "Selected navigation requires a full yellow Kenney state.")
	_expect("button_square_header_blade_rectangle" not in theme_source, "Operations buttons must not use colored blade overlays.")
	_expect('Button/styles/hover = SubResource("ButtonDarkHover")' in theme_source, "Dark buttons must communicate hover through the Kenney surface instead of recoloring text.")
	_expect('Button/styles/pressed = SubResource("ButtonDark")' in theme_source, "Kenney buttons must keep one stable physical footprint across click states.")
	_expect('PrimaryButton/styles/hover = SubResource("ButtonYellowHover")' in theme_source, "Primary yellow actions must use a surface hover state without changing geometry.")
	_expect('PrimaryButton/colors/font_focus_color = Color(0.08, 0.09, 0.11, 1)' in theme_source, "Focused primary actions must keep black text on yellow instead of falling back to white.")
	_expect('PrimaryButton/colors/font_hover_color = Color(0.08, 0.09, 0.11, 1)' in theme_source, "Primary action hover must never trade contrast for feedback.")
	_expect('TabButton/styles/pressed = SubResource("ButtonYellow")' in theme_source, "Selected navigation must use the yellow full-surface state.")
	_expect('SecondaryButton/fonts/font = ExtResource("1")' in theme_source, "All interactive button labels must use Neuropol.")
	_expect("panel_rectangle_screws.png" in theme_source, "Operations requires native Kenney panel chrome.")
	_expect('modulate_color = Color(0.16, 0.20, 0.24, 1)' in theme_source, "Shared console chrome must keep the Kenney screw asset while rendering in dark mode.")
	_expect('modulate_color = Color(0.18, 0.24, 0.28, 0.98)' in theme_source, "Shared glass/card chrome must render as a layered dark surface.")
	_expect("Label/colors/font_color = Color(0.92, 0.96, 0.98, 1)" in theme_source, "Shared console text must use high-contrast light foregrounds.")
	_expect("SuccessValue/colors/font_color = Color(0.56, 0.95, 0.81, 1)" in theme_source, "Dark console success values must remain readable.")
	_expect("RewardValue/colors/font_color = Color(1, 0.82, 0.40, 1)" in theme_source, "Dark console rewards must retain readable amber emphasis.")
	_expect("NEUROPOL.ttf" in theme_source, "OCC display typography must use Neuropol.")
	_expect("Inter[opsz,wght].ttf" in theme_source, "OCC body typography must use Inter.")
	_expect("JetBrainsMono[wght].ttf" in theme_source, "OCC telemetry typography must use JetBrains Mono.")

	var cursor_source := FileAccess.get_file_as_string("res://src/ui/themes/occ_cursor_skin.gd")
	_expect("Input.set_custom_mouse_cursor" in cursor_source, "Desktop UI must use the original Kenney cursor set.")
	var app_source := FileAccess.get_file_as_string("res://src/core/app/app_root.gd")
	_expect("OccCursorSkin.apply()" in app_source, "AppRoot must install the custom cursor exactly once.")
	var audio_source := FileAccess.get_file_as_string("res://src/core/audio/audio_service.gd")
	_expect("play_ui_hover" in audio_source and "play_ui_click" in audio_source and "play_ui_back" in audio_source, "UI interactions require centralized Kenney audio feedback.")
	screen.free()

func _validate_hq_components() -> void:
	var upgrade_packed := load("res://src/ui/components/hq_upgrade_card.tscn") as PackedScene
	_expect(upgrade_packed != null, "HQ upgrade card scene must load.")
	if upgrade_packed != null:
		var upgrade := upgrade_packed.instantiate()
		_expect(upgrade is HqUpgradeCard, "HQ upgrade card must use HqUpgradeCard.")
		_expect(upgrade.find_child("PurchaseButton", true, false) is Button, "HQ upgrade card requires purchase action.")
		_expect(upgrade.find_child("Description", true, false) is Label, "HQ upgrade card requires readable description.")
		upgrade.free()

	var rank_packed := load("res://src/ui/components/hq_rank_row.tscn") as PackedScene
	_expect(rank_packed != null, "HQ rank row scene must load.")
	if rank_packed != null:
		var rank := rank_packed.instantiate()
		_expect(rank is HqRankRow, "HQ rank row must use HqRankRow.")
		_expect(rank.find_child("Status", true, false) is Label, "HQ rank row requires status.")
		_expect(rank.find_child("Xp", true, false) is Label, "HQ rank row requires XP threshold.")
		rank.free()

func _validate_ship_steering() -> void:
	var origin := Vector2(100, 100)
	_expect(ShipSteering.pointer_intent(origin, origin + Vector2(20, 0), 50, 250) == Vector2.ZERO, "Pointer steering must respect deadzone.")
	var far_intent := ShipSteering.pointer_intent(origin, origin + Vector2(400, 0), 50, 250)
	_expect(is_equal_approx(far_intent.length(), 1.0), "Far pointer must reach full steering intent.")
	var keyboard := Vector2.UP
	_expect(ShipSteering.combine_intent(keyboard, Vector2.RIGHT) == keyboard, "Keyboard input must override pointer steering while held.")

func _validate_world_visual_language() -> void:
	var salvage_packed := load("res://src/game/salvage/salvage_object.tscn") as PackedScene
	_expect(salvage_packed != null, "SalvageObject scene must load.")
	if salvage_packed != null:
		var salvage := salvage_packed.instantiate()
		_expect(salvage.find_child("Marker", true, false) is SalvageMarker, "Recoverable salvage requires a semantic marker.")
		var definition_source := FileAccess.get_file_as_string("res://src/game/salvage/salvage_definition.gd")
		_expect("motion_profile" in definition_source and "effect_profile" in definition_source, "Salvage definitions require data-driven motion and effect profiles.")
		var salvage_source := FileAccess.get_file_as_string("res://src/game/salvage/salvage_object.gd")
		_expect("_apply_motion" in salvage_source and "_effect_shader_mode" in salvage_source, "Salvage runtime must compose shared motion/effect profiles without per-item scenes.")
		salvage.free()

	var registry := ContentRegistry.new()

	var obstacle_packed := load("res://src/game/sector/sector_obstacle.tscn") as PackedScene
	_expect(obstacle_packed != null, "SectorObstacle scene must load.")
	if obstacle_packed != null:
		var obstacle := obstacle_packed.instantiate() as SectorObstacle
		_expect(obstacle != null, "SectorObstacle scene must instantiate the typed runtime.")
		if obstacle != null:
			var earth_biome := registry.get_biome("earth_orbit")
			var obstacle_defs := earth_biome.get("obstacles", []) as Array
			_expect(not obstacle_defs.is_empty(), "Earth Orbit requires at least one obstacle definition for collision QA.")
			if not obstacle_defs.is_empty():
				obstacle.configure(obstacle_defs[0] as Dictionary, 1.0)
				root.add_child(obstacle)
				_expect(obstacle is AnimatableBody2D, "Spinning obstacles require physics-synchronized bodies.")
				_expect(obstacle.find_child("Marker", true, false) is SectorObstacleMarker, "Collision hazards require a semantic hazard marker.")
				_expect(obstacle.find_child("CollisionRoot", true, false) == null, "Collision polygons must not be nested under an intermediate Node2D.")
				_expect(CollisionGeometry2D.generated_part_count(obstacle) == 1, "Obstacle alpha collision must use one concave boundary shape.")
				_expect(_has_concave_boundary_shape(obstacle), "Obstacle body must register a ConcavePolygonShape2D alpha boundary.")
				_expect(CollisionGeometry2D.generated_boundary_segment_count(obstacle) > 8, "Obstacle alpha boundary requires meaningful contour segments.")
				obstacle.queue_free()
			else:
				obstacle.free()

	var landmark_packed := load("res://src/game/sector/sector_landmark.tscn") as PackedScene
	_expect(landmark_packed != null, "SectorLandmark scene must load.")
	if landmark_packed != null:
		var landmark := landmark_packed.instantiate() as SectorLandmark
		_expect(landmark != null, "SectorLandmark scene must instantiate the typed runtime.")
		if landmark != null:
			var landmark_definition := registry.get_landmark("service_satellite")
			landmark.configure(landmark_definition)
			root.add_child(landmark)
			_expect(landmark is AnimatableBody2D, "Rotating landmarks require physics-synchronized navigation bodies.")
			_expect(landmark.find_child("Marker", true, false) is SectorLandmarkMarker, "Landmarks require ambient visual treatment.")
			_expect(landmark.find_child("CollisionRoot", true, false) == null, "Landmark collision polygons must be owned directly by the physics body.")
			_expect(CollisionGeometry2D.generated_part_count(landmark) == 1, "Landmark alpha silhouette must use one concave boundary shape.")
			_expect(_has_concave_boundary_shape(landmark), "Landmark body must register a ConcavePolygonShape2D alpha boundary.")
			_expect(CollisionGeometry2D.generated_boundary_segment_count(landmark) > 12, "Service satellite alpha boundary requires detailed contour segments.")
			landmark.queue_free()

	_validate_all_world_alpha_collisions(registry, obstacle_packed, landmark_packed)

	var collision_geometry_source := FileAccess.get_file_as_string("res://src/game/sector/collision_geometry_2d.gd")
	_expect(
		"ConcavePolygonShape2D.new()" in collision_geometry_source
		and "ConvexPolygonShape2D.new()" in collision_geometry_source
		and "image.get_pixel(x, y).a > threshold" in collision_geometry_source
		and "_source_boundary_cache" in collision_geometry_source
		and "_source_rect_cache" in collision_geometry_source
		and "shape_owner_add_shape" in collision_geometry_source,
		"Collision geometry must derive both static boundaries and dynamic solids directly from source alpha."
	)
	_expect(
		"opaque_to_polygons" not in collision_geometry_source,
		"World collision cannot rely on a filled outer contour that erases transparent holes."
	)
	var obstacle_source := FileAccess.get_file_as_string("res://src/game/sector/sector_obstacle.gd")
	var landmark_source := FileAccess.get_file_as_string("res://src/game/sector/sector_landmark.gd")
	_expect("CircleShape2D" not in obstacle_source, "Obstacle runtime must not fall back to circular collision.")
	_expect("CollisionGeometry2D.build_static_boundary" in obstacle_source, "Obstacle runtime must trace a hollow static boundary from rendered sprite alpha.")
	_expect("CollisionGeometry2D.build_static_boundary" in landmark_source, "Landmark runtime must trace a hollow static boundary from rendered sprite alpha.")
	_expect("position = _base_position +" in obstacle_source, "Obstacle drift must move the physics body, not only its sprite.")
	_expect("position = _base_position +" in landmark_source, "Landmark drift must move the physics body, not only its sprite.")

	var ship_scene_source := FileAccess.get_file_as_string("res://src/game/ship/player_ship.tscn")
	var ship_source := FileAccess.get_file_as_string("res://src/game/ship/player_ship.gd")
	_expect('id="ShipCollision"' not in ship_scene_source, "Player ship must not retain the primitive circle hull collider.")
	_expect("CollisionGeometry2D.build_dynamic_solid(self, visuals.ship_sprite)" in ship_source, "Player ship hull collision must remain solid and come from active hull texture alpha.")
	_expect("_sync_hull_collision_rotation()" in ship_source, "Player ship alpha collision must rotate with the visible hull.")

	for asset_path in [
		"res://assets/original/landmarks/service_satellite.svg",
		"res://assets/original/landmarks/cargo_waystation.svg",
		"res://assets/original/landmarks/relay_satellite.svg",
		"res://assets/original/landmarks/mining_rig.svg",
		"res://assets/original/landmarks/fractured_moonlet.svg",
		"res://assets/original/landmarks/comms_array.svg",
		"res://assets/original/landmarks/research_outpost.svg",
		"res://assets/original/landmarks/derelict_explorer.svg",
	]:
		_expect(load(asset_path) is Texture2D, "Original landmark SVG must import as texture: %s" % asset_path)

	var recovery_color := WorldVisualLanguage.salvage_recovery_color()
	var hazard_color := WorldVisualLanguage.hazard_color()
	_expect(recovery_color != hazard_color, "Recoverable and hazard primary semantic colors must remain distinct.")
	_expect(
		WorldVisualLanguage.salvage_progress_color() != hazard_color,
		"Tractor progress cannot reuse the hazard color."
	)

func _validate_content_runtime() -> void:
	var registry := ContentRegistry.new()
	var scrap := registry.get_salvage_definition("scrap_fragment")
	var dense := registry.get_salvage_definition("dense_composite")
	_expect(scrap != null and dense != null, "ContentRegistry must build salvage definitions from JSON.")
	if scrap != null:
		_expect(String(scrap.id) == "scrap_fragment", "Salvage JSON id must reach runtime definition.")
		_expect(scrap.sprite != null, "Salvage JSON asset path must load.")

	var scaler := DifficultyScaler.new()
	scaler.configure(registry)
	var level_one := scaler.evaluate(1)
	var level_high := scaler.evaluate(10000)
	_expect(float(level_one["salvage_count"]) > 0.0, "DifficultyScaler must produce salvage count.")
	_expect(float(level_high["reward_multiplier"]) <= 8.0, "DifficultyScaler must respect configured caps.")
	_expect(float(level_high["mass_multiplier"]) <= 2.2, "DifficultyScaler mass curve must remain bounded.")

	var sector_ids := registry.list_sector_ids()
	_expect(sector_ids.size() >= 59, "Destination expansion must expose at least 59 authored sectors.")
	_expect(String(sector_ids[0]) == "earth_training_01", "Career order must begin with Earth Training 01.")
	_expect(String(sector_ids[1]) == "earth_training_02", "Career order must keep Earth Training 02 second.")
	_expect(String(sector_ids[sector_ids.size() - 1]) == "supernova_remnant_01", "Career order must end with Supernova Remnant.")
	for required_sector in ["earth_orbit_03", "lunar_belt_01", "mars_freight_01", "blue_nebula_01", "saturn_rings_01", "abandoned_station_01", "black_hole_01", "supernova_remnant_01"]:
		_expect(sector_ids.has(required_sector), "Initial content pack missing authored sector: %s" % required_sector)

	var generator := SectorGenerator.new()
	generator.configure(registry, scaler)
	var authored_kinds: Dictionary = {}
	for sector_id in sector_ids:
		var authored_plan := generator.generate(sector_id)
		_expect(not authored_plan.is_empty(), "Every authored sector must generate: %s" % sector_id)
		_expect((authored_plan["salvage_spawns"] as Array).size() >= 5, "Every authored sector needs salvage: %s" % sector_id)
		var sector := authored_plan["sector"] as Dictionary
		var contract_ref := sector["contract"] as Dictionary
		var contract := registry.get_contract(String(contract_ref["type"]))
		authored_kinds[String(contract["kind"])] = true
		_validate_contract_plan_feasibility(authored_plan, registry)
		_validate_landmark_plan(authored_plan)
	_expect(authored_kinds.size() == 5, "Authored content must exercise all five contract kinds.")

	var plan_a := generator.generate("earth_training_01")
	var plan_b := generator.generate("earth_training_01")
	var plan_variant := generator.generate("earth_training_02")

	_expect(
		String(plan_a["generation_signature"]) == String(plan_b["generation_signature"]),
		"Sector generation must be deterministic for the same seed."
	)
	_expect(
		String(plan_a["generation_signature"]) != String(plan_variant["generation_signature"]),
		"Different sector data must produce a different generation signature without new code."
	)
	_expect((plan_a["salvage_spawns"] as Array).size() >= 5, "Generated sector requires salvage.")
	_expect((plan_a["obstacle_spawns"] as Array).size() >= 1, "Generated sector requires environmental obstacles.")
	_expect((plan_a["landmark_spawns"] as Array).size() >= 1, "Generated sector requires configured landmark.")
	var first_salvage := (plan_a["salvage_spawns"] as Array)[0] as Dictionary
	_expect(
		(first_salvage["position"] as Vector2).length() <= 280.0,
		"Training biome starter cluster must place recoverable salvage near deployment."
	)

	var bounds := plan_a["play_bounds"] as Rect2
	_expect(bounds.size.x >= 9000.0 and bounds.size.y >= 5500.0, "Generated training sector must preserve large play bounds.")

func _validate_landmark_plan(plan: Dictionary) -> void:
	for landmark_value in plan["landmark_spawns"] as Array:
		var landmark := landmark_value as Dictionary
		var definition := landmark["definition"] as Dictionary
		var asset_path := String(definition.get("sprite", ""))
		_expect(
			asset_path.begins_with("res://assets/original/landmarks/"),
			"Authored landmarks must use project-owned OCC landmark art."
		)
		var landmark_position := landmark["position"] as Vector2
		var reserved_radius := float(definition.get("reserved_radius", 0.0))
		_expect(reserved_radius >= 80.0, "Landmark requires meaningful navigation clearance.")
		for salvage_value in plan["salvage_spawns"] as Array:
			var salvage := salvage_value as Dictionary
			_expect(
				landmark_position.distance_to(salvage["position"] as Vector2) >= reserved_radius,
				"Salvage cannot spawn inside landmark reserved clearance."
			)
		for obstacle_value in plan["obstacle_spawns"] as Array:
			var obstacle := obstacle_value as Dictionary
			_expect(
				landmark_position.distance_to(obstacle["position"] as Vector2) >= reserved_radius,
				"Collision hazards cannot spawn inside landmark reserved clearance."
			)

func _validate_environment_fields() -> void:
	var registry := ContentRegistry.new()
	var scaler := DifficultyScaler.new()
	scaler.configure(registry)
	var generator := SectorGenerator.new()
	generator.configure(registry, scaler)

	var earth_plan := generator.generate("earth_orbit_03")
	var lunar_plan := generator.generate("lunar_belt_01")
	var mars_plan := generator.generate("mars_freight_01")
	var blue_plan := generator.generate("blue_nebula_01")

	_expect(
		(earth_plan["environment_fields"] as Array).is_empty(),
		"Earth Orbit must remain the neutral environmental baseline."
	)

	var lunar_kinds := _environment_kind_set(lunar_plan)
	_expect(lunar_kinds.has("gravity_well"), "Lunar Belt requires gravity wells.")
	_expect(lunar_kinds.has("safe_corridor"), "Lunar Belt requires a safe corridor.")

	var mars_kinds := _environment_kind_set(mars_plan)
	_expect(mars_kinds.has("drift_current"), "Mars Freight requires directional drift currents.")
	_expect(
		float((mars_plan["parameters"] as Dictionary)["mass_multiplier"]) >
		float((earth_plan["parameters"] as Dictionary)["mass_multiplier"]),
		"Mars Freight must make salvage meaningfully heavier than Earth Orbit."
	)

	var blue_kinds := _environment_kind_set(blue_plan)
	for required_kind in [
		"visibility_pocket",
		"scanner_interference",
		"tractor_distortion",
		"magnetic_zone",
		"gas_drag",
		"turbulence",
	]:
		_expect(
			blue_kinds.has(required_kind),
			"Blue Nebula missing environmental mechanic: %s" % required_kind
		)

	for field_value in lunar_plan["environment_fields"] as Array:
		var field := field_value as Dictionary
		if String(field["kind"]) != "safe_corridor":
			continue
		var half := (field["size"] as Vector2) * 0.5 + Vector2.ONE * 70.0
		for obstacle_value in lunar_plan["obstacle_spawns"] as Array:
			var obstacle := obstacle_value as Dictionary
			var local := ((obstacle["position"] as Vector2) - (field["position"] as Vector2)).rotated(
				-float(field["rotation"])
			)
			_expect(
				not (absf(local.x) <= half.x and absf(local.y) <= half.y),
				"Lunar safe corridor must remain clear of generated collision hazards."
			)

	var palette := {"accent": "#72d7ff", "nebula": "#183b72"}

	var gravity := EnvironmentalField.new()
	gravity.configure({
		"kind": "gravity_well",
		"shape": "circle",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"radius": 500.0,
		"strength": 0.6,
		"color": "#c4d8ef",
		"secondary_color": "#65758c",
	}, palette)
	var gravity_sample := gravity.sample(Vector2(180.0, 0.0))
	_expect(
		gravity_sample.linear_acceleration.x < 0.0,
		"Gravity well must apply mass-independent acceleration toward its center."
	)
	gravity.free()

	var current := EnvironmentalField.new()
	current.configure({
		"kind": "drift_current",
		"shape": "box",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"size": Vector2(1200.0, 600.0),
		"strength": 0.5,
		"color": "#ff9c63",
		"secondary_color": "#a84a32",
	}, palette)
	_expect(
		current.sample(Vector2.ZERO).external_force.x > 0.0,
		"Drift current must apply directional external force."
	)
	current.free()

	var scanner := EnvironmentalField.new()
	scanner.configure({
		"kind": "scanner_interference",
		"shape": "circle",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"radius": 600.0,
		"strength": 0.7,
		"color": "#80dfff",
		"secondary_color": "#5a73d6",
	}, palette)
	_expect(
		scanner.sample(Vector2.ZERO).scanner_multiplier < 1.0,
		"Scanner interference must reduce effective scan range."
	)
	scanner.free()

	var gas_drag := EnvironmentalField.new()
	gas_drag.configure({
		"kind": "gas_drag",
		"shape": "circle",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"radius": 600.0,
		"strength": 0.7,
		"color": "#72d7ff",
		"secondary_color": "#244e86",
	}, palette)
	var gas_sample := gas_drag.sample(Vector2.ZERO)
	_expect(gas_sample.linear_drag > 0.0, "Dense gas must add real velocity-dependent drag.")
	_expect(gas_sample.thrust_multiplier < 1.0, "Dense gas must reduce effective thrust authority slightly.")
	gas_drag.free()

	var turbulence := EnvironmentalField.new()
	turbulence.configure({
		"kind": "turbulence",
		"shape": "circle",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"radius": 600.0,
		"strength": 0.6,
		"color": "#9effe6",
		"secondary_color": "#5849a5",
	}, palette)
	_expect(
		turbulence.sample(Vector2(80.0, 20.0)).external_force.length() > 0.0,
		"Turbulence must produce a physical external force."
	)
	turbulence.free()

	var tractor := EnvironmentalField.new()
	tractor.configure({
		"kind": "tractor_distortion",
		"shape": "circle",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"radius": 600.0,
		"strength": 0.7,
		"color": "#a28bff",
		"secondary_color": "#3157a5",
	}, palette)
	_expect(
		float(tractor.sample(Vector2.ZERO)["tractor_multiplier"]) < 1.0,
		"Tractor distortion must reduce collection efficiency."
	)
	tractor.free()

	var visibility := EnvironmentalField.new()
	visibility.configure({
		"kind": "visibility_pocket",
		"shape": "circle",
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"radius": 650.0,
		"strength": 0.6,
		"color": "#72d7ff",
		"secondary_color": "#5849a5",
	}, palette)
	_expect(
		float(visibility.sample(Vector2.ZERO)["visibility"]) < 1.0,
		"Visibility pocket must reduce world visibility."
	)
	visibility.free()

	var biome_ids := registry.list_biome_ids()
	_expect(biome_ids.size() >= 50, "Destination library must expose at least 50 distinct visual biomes.")
	var primary_assets := {}
	for biome_id in biome_ids:
		var biome := registry.get_biome(biome_id)
		var visual := biome["visual_profile"] as Dictionary
		var asset_path := String(visual["primary_asset"])
		_expect(asset_path.begins_with("res://assets/original/"), "Biome must use project-owned primary art: %s" % biome_id)
		_expect(load(asset_path) is Texture2D, "Biome primary asset must import as Texture2D: %s" % biome_id)
		_expect(not primary_assets.has(asset_path), "Every biome requires its own primary visual asset: %s" % biome_id)
		primary_assets[asset_path] = true
	_expect(primary_assets.size() == biome_ids.size(), "Destination primary assets must remain one-to-one with biomes.")
	var earth_biome := registry.get_biome("earth_orbit")
	var earth_visual := earth_biome["visual_profile"] as Dictionary
	_expect(
		String(earth_visual["primary_asset"]) == "res://assets/original/planets/earth_orbit_hd.webp",
		"Earth Orbit must use the staged HD runtime artwork."
	)
	_expect(
		is_equal_approx(float(earth_visual["primary_scale"]), 0.98),
		"HD Earth scale must preserve the authored on-screen diameter."
	)
	_expect(
		FileAccess.file_exists("res://assets/original/planets/earth_orbit.svg"),
		"Original Earth SVG must remain available while HD art is under evaluation."
	)

	var staged_planets := {
		"lunar_belt": {
			"asset": "res://assets/original/planets/lunar_belt_hd.webp",
			"scale": 0.9,
			"fallback": "res://assets/original/planets/lunar_belt.svg",
		},
		"mars_freight": {
			"asset": "res://assets/original/planets/mars_freight_hd.webp",
			"scale": 1.01,
			"fallback": "res://assets/original/planets/mars_freight.svg",
		},
		"blue_nebula": {
			"asset": "res://assets/original/planets/blue_giant_hd.webp",
			"scale": 0.87,
			"fallback": "res://assets/original/planets/blue_giant.svg",
		},
	}
	for biome_id in staged_planets:
		var expected := staged_planets[biome_id] as Dictionary
		var biome := registry.get_biome(biome_id)
		var visual := biome["visual_profile"] as Dictionary
		_expect(
			String(visual["primary_asset"]) == String(expected["asset"]),
			"%s must use its staged HD runtime artwork." % biome_id
		)
		_expect(
			is_equal_approx(float(visual["primary_scale"]), float(expected["scale"])),
			"%s HD scale must preserve the authored on-screen composition." % biome_id
		)
		_expect(
			FileAccess.file_exists(String(expected["fallback"])),
			"%s original SVG must remain available while HD art is under evaluation." % biome_id
		)

	var waystation_variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/landmarks/cargo_waystation.json")
	)
	_expect(waystation_variant is Dictionary, "Cargo Waystation definition must remain valid JSON.")
	if waystation_variant is Dictionary:
		var waystation := waystation_variant as Dictionary
		_expect(
			String(waystation["sprite"]) == "res://assets/original/landmarks/cargo_waystation_hd.webp",
			"Cargo Waystation must use the staged HD runtime artwork."
		)
		_expect(
			is_equal_approx(float(waystation["scale"]), 0.58),
			"Cargo Waystation HD scale must preserve large-landmark readability."
		)
		var waystation_collision := waystation["collision"] as Dictionary
		_expect(
			String(waystation_collision["shape"]) == "circle"
			and is_equal_approx(float(waystation_collision["radius"]), 280.0),
			"Cargo Waystation collision must match the new circular HD silhouette."
		)
	_expect(
		FileAccess.file_exists("res://assets/original/landmarks/cargo_waystation.svg"),
		"Original Cargo Waystation SVG must remain available while HD art is under evaluation."
	)

func _environment_kind_set(plan: Dictionary) -> Dictionary:
	var output := {}
	for value in plan["environment_fields"] as Array:
		var field := value as Dictionary
		output[String(field["kind"])] = true
	return output

func _validate_endless_contracts() -> void:
	var registry := ContentRegistry.new()
	var scaler := DifficultyScaler.new()
	scaler.configure(registry)
	var generator := SectorGenerator.new()
	generator.configure(registry, scaler)
	var endless := EndlessContractGenerator.new()
	endless.configure(registry)

	var definition_a := endless.create_sector_definition(10000)
	var definition_b := endless.create_sector_definition(10000)
	_expect(definition_a == definition_b, "Endless contract definition must be deterministic for the same contract number.")
	_expect(int(definition_a["difficulty"]) == 10000, "Endless difficulty must preserve the requested contract number.")
	_expect(String(definition_a["id"]) == "endless_010000", "Endless IDs must be stable and reproducible.")

	var plan_a := generator.generate_definition(definition_a)
	var plan_b := generator.generate_definition(definition_b)
	_expect(
		String(plan_a["generation_signature"]) == String(plan_b["generation_signature"]),
		"Endless sector generation must be deterministic."
	)
	_expect((plan_a["salvage_spawns"] as Array).size() >= 5, "High endless contracts must remain generatable.")
	_expect((plan_a["obstacle_spawns"] as Array).size() >= 1, "High endless contracts must retain environmental composition.")

	var next_definition := endless.create_sector_definition(10001)
	var next_plan := generator.generate_definition(next_definition)
	_expect(
		String(plan_a["generation_signature"]) != String(next_plan["generation_signature"]),
		"Adjacent endless contracts must not collapse to the same generation signature."
	)

	var endless_kinds: Dictionary = {}
	for contract_number in range(1, 7):
		var varied_definition := endless.create_sector_definition(contract_number)
		var varied_plan := generator.generate_definition(varied_definition)
		var contract_ref := varied_definition["contract"] as Dictionary
		var contract := registry.get_contract(String(contract_ref["type"]))
		endless_kinds[String(contract["kind"])] = true
		_validate_contract_plan_feasibility(varied_plan, registry)
	_expect(endless_kinds.size() == 5, "First endless rotation must expose all five contract kinds.")

	var biome_ids := registry.list_biome_ids()
	var endless_biomes: Dictionary = {}
	for contract_number in range(1, biome_ids.size() + 1):
		var definition := endless.create_sector_definition(contract_number)
		endless_biomes[String(definition["biome"])] = true
	_expect(
		endless_biomes.size() == biome_ids.size(),
		"A complete endless rotation must cover every authored biome."
	)

func _validate_sector_preview() -> void:
	var packed := load("res://src/debug/sector_preview/sector_preview.tscn") as PackedScene
	_expect(packed != null, "Sector Preview scene must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is Control, "Sector Preview must be a Control screen.")
	for node_name in ["PreviewCanvas", "SectorPicker", "ContractNumber", "SeedOverride", "GenerateEndless", "DeployPreview", "ReturnToHq"]:
		_expect(screen.find_child(node_name, true, false) != null, "Sector Preview requires node: %s" % node_name)
	screen.free()

func _validate_contract_session() -> void:
	var registry := ContentRegistry.new()
	var target_salvage := registry.get_salvage_definition("scrap_fragment").duplicate(true) as SalvageDefinition
	target_salvage.cleanliness_value = 7.0
	target_salvage.base_value = 50
	var final_salvage := registry.get_salvage_definition("service_scrap").duplicate(true) as SalvageDefinition
	final_salvage.cleanliness_value = 3.0
	final_salvage.base_value = 30

	var cleanup := ContractSession.new()
	cleanup.configure({
		"sector_id": "qa_cleanup",
		"contract": registry.get_contract("standard_cleanup"),
		"contract_ref": {"type": "standard_cleanup", "target_percent": 70.0},
		"total_cleanliness": 10.0,
		"reward_multiplier": 1.0,
	})
	cleanup.record_delivery([target_salvage])
	_expect(cleanup.is_target_reached(), "Cleanup contract must complete at configured percentage.")
	_expect(not cleanup.is_perfect_cleanup(), "Cleanup target completion must not imply Perfect Cleanup.")
	var standard_result := cleanup.build_result()
	_expect(int(standard_result["credits_awarded"]) == 290, "Standard payout must combine base pay and recovered salvage.")
	_expect(int(standard_result["xp_awarded"]) == 120, "Standard completion must grant configured Company XP.")
	cleanup.record_delivery([final_salvage])
	_expect(cleanup.is_perfect_cleanup(), "100% cleanliness must trigger Perfect Cleanup.")
	var perfect_result := cleanup.build_result()
	_expect(int(perfect_result["perfect_bonus"]) == 160, "Perfect Cleanup must grant configured credit bonus.")
	_expect(int(perfect_result["xp_awarded"]) == 160, "Perfect Cleanup must grant configured XP bonus.")
	_expect(int(perfect_result["credits_awarded"]) == 480, "Perfect payout must include base, salvage and perfect bonus.")

	var recovery := ContractSession.new()
	recovery.configure({
		"sector_id": "qa_recovery",
		"contract": registry.get_contract("recovery_run"),
		"contract_ref": {"type": "recovery_run", "target_count": 2},
		"total_cleanliness": 100.0,
		"reward_multiplier": 1.0,
	})
	recovery.record_delivery([target_salvage])
	_expect(not recovery.is_target_reached(), "Recovery contract must count recovered objects.")
	recovery.record_delivery([final_salvage])
	_expect(recovery.is_target_reached(), "Recovery contract must complete at target_count.")

	var valuable := ContractSession.new()
	valuable.configure({
		"sector_id": "qa_value",
		"contract": registry.get_contract("valuable_recovery"),
		"contract_ref": {"type": "valuable_recovery", "target_value": 75},
		"total_cleanliness": 100.0,
		"reward_multiplier": 1.0,
	})
	valuable.record_delivery([target_salvage])
	_expect(not valuable.is_target_reached(), "Valuable Recovery must track recovered credit value.")
	valuable.record_delivery([final_salvage])
	_expect(valuable.is_target_reached(), "Valuable Recovery must complete at target_value.")

	var priority := ContractSession.new()
	priority.configure({
		"sector_id": "qa_priority",
		"contract": registry.get_contract("priority_recovery"),
		"contract_ref": {
			"type": "priority_recovery",
			"target_count": 1,
			"target_salvage_id": "navigation_core",
		},
		"total_cleanliness": 100.0,
		"reward_multiplier": 1.0,
	})
	priority.record_delivery([target_salvage])
	_expect(not priority.is_target_reached(), "Priority contract must ignore non-priority salvage.")
	var navigation := registry.get_salvage_definition("navigation_core")
	priority.record_delivery([navigation])
	_expect(priority.is_target_reached(), "Priority contract must complete when designated salvage is recovered.")

	var full := ContractSession.new()
	full.configure({
		"sector_id": "qa_full",
		"contract": registry.get_contract("full_cleanup"),
		"contract_ref": {"type": "full_cleanup", "target_percent": 100.0},
		"total_cleanliness": 10.0,
		"reward_multiplier": 1.0,
	})
	full.record_delivery([target_salvage])
	_expect(not full.is_target_reached(), "Full Cleanup cannot complete below 100%.")
	full.record_delivery([final_salvage])
	_expect(full.is_target_reached() and full.is_perfect_cleanup(), "Full Cleanup must complete only at 100%.")

func _validate_contract_plan_feasibility(plan: Dictionary, registry: ContentRegistry) -> void:
	var sector := plan["sector"] as Dictionary
	var contract_ref := sector["contract"] as Dictionary
	var contract := registry.get_contract(String(contract_ref["type"]))
	var kind := String(contract["kind"])
	var spawns := plan["salvage_spawns"] as Array

	match kind:
		"cleanup", "full_cleanup":
			_expect(float(contract_ref["target_percent"]) <= 100.0, "Cleanup target must be reachable.")
		"recovery":
			_expect(int(contract_ref["target_count"]) <= spawns.size(), "Recovery target cannot exceed generated salvage count.")
		"valuable_recovery":
			var multiplier := float((plan["parameters"] as Dictionary).get("reward_multiplier", 1.0))
			var total_value := 0
			for value in spawns:
				var entry := value as Dictionary
				var definition := registry.get_salvage_definition(String(entry["salvage_id"]))
				total_value += int(round(float(definition.base_value) * multiplier))
			var scaled_target := int(round(float(contract_ref["target_value"]) * multiplier))
			_expect(scaled_target <= total_value, "Valuable Recovery target cannot exceed generated recovery value.")
		"priority_object":
			var target_id := String(contract_ref["target_salvage_id"])
			var required := int(contract_ref["target_count"])
			var marked := 0
			for value in spawns:
				var entry := value as Dictionary
				if bool(entry.get("priority_target", false)) and String(entry["salvage_id"]) == target_id:
					marked += 1
			_expect(marked >= required, "Priority contract must guarantee every required target spawn.")

func _validate_progression_service() -> void:
	var save := SaveService.new()
	save.delete_save()
	var progression := ProgressionService.new()
	progression.initialize(save)

	_expect(progression.get_credits() == 0, "New progression must start with zero Credits.")
	_expect(progression.get_rank_id() == "trainee", "New progression must start at Trainee.")
	_expect(progression.is_sector_unlocked("earth_training_01"), "Trainee must have first training contract.")
	_expect(progression.is_sector_unlocked("earth_training_02"), "Trainee must have second training contract.")
	_expect(not progression.is_sector_unlocked("earth_orbit_03"), "Advanced Earth contract must wait for Junior Cleaner.")
	_expect(not progression.is_endless_unlocked(), "Endless Contracts must be a late-career unlock.")
	var first_unlock := progression.get_next_content_unlock()
	_expect(String(first_unlock["sector_id"]) == "earth_orbit_03", "First career unlock must be Earth Orbit 03.")
	_expect(int(first_unlock["min_xp"]) == 300, "Junior Cleaner unlock threshold must match balanced career pacing.")
	var base_ship := progression.get_ship_modifiers()
	_expect(is_equal_approx(float(base_ship["scan_range"]), 320.0), "Base Tractor Beam range must come from progression data.")
	_expect(int(round(float(base_ship["cargo_capacity"]))) == 12, "Base cargo capacity must come from progression data.")
	_expect(is_equal_approx(float(base_ship["boost_recharge_rate"]), 1.0), "Base boost recharge must come from progression data.")
	_expect(int(round(float(base_ship["boost_charge_capacity"]))) == 1, "Base ship must start with one boost charge.")
	var default_cosmetics := progression.get_equipped_cosmetic_ids()
	_expect(String(default_cosmetics["hull"]) == "pioneer_01", "Default hull must come from cosmetic content.")
	var cosmetics_source := FileAccess.get_file_as_string("res://content/cosmetics/ship_customization.json")
	_expect(
		"res://assets/original/ships/pioneer_01_hd.webp" in cosmetics_source,
		"Pioneer-01 cosmetic content must use the staged HD runtime artwork."
	)
	var ship_scene_source := FileAccess.get_file_as_string("res://src/game/ship/player_ship.tscn")
	_expect(
		"res://assets/original/ships/pioneer_01_hd.webp" in ship_scene_source,
		"PlayerShip scene must render the staged HD Pioneer-01."
	)
	_expect(
		"scale = Vector2(0.14, 0.14)" in ship_scene_source,
		"HD Pioneer-01 normalization must preserve gameplay footprint and engine alignment."
	)
	_expect(
		FileAccess.file_exists("res://assets/third_party/kenney_space_shooter/ships/player_ship_01_blue.png"),
		"Previous Kenney ship must remain available while HD art is under evaluation."
	)
	_expect(String(default_cosmetics["paint"]) == "company_blue", "Default paint must come from cosmetic content.")
	_expect(progression.is_cosmetic_unlocked("paint", "mint_service"), "Starting-rank cosmetic must be unlocked.")
	_expect(not progression.is_cosmetic_unlocked("paint", "safety_amber"), "Junior cosmetic must stay locked for Trainee.")
	_expect(progression.equip_cosmetic("paint", "mint_service"), "Unlocked cosmetic must equip.")
	_expect(progression.get_equipped_cosmetic_id("paint") == "mint_service", "Equipped cosmetic must update persistent state.")

	var registry := ContentRegistry.new()
	var rare_salvage := registry.get_salvage_definition("navigation_core")
	var common_salvage := registry.get_salvage_definition("scrap_fragment")
	_expect(not progression.register_discovery(common_salvage), "Common salvage must not enter the special Discovery catalog.")
	_expect(progression.register_discovery(rare_salvage), "First rare recovery must register a Discovery.")
	_expect(not progression.register_discovery(rare_salvage), "Repeated rare recovery must not duplicate a Discovery.")
	_expect(progression.get_discovery_count() == 1, "Discovery count must remain unique.")

	var restored := ProgressionService.new()
	restored.initialize(save)
	_expect(restored.get_equipped_cosmetic_id("paint") == "mint_service", "Equipped cosmetic must survive save reload.")
	_expect(restored.get_discovery_ids().has("navigation_core"), "Discovery catalog must survive save reload.")
	restored.free()

	var payout_transition := progression.apply_contract_result({
		"completed": true,
		"sector_id": "qa_sector",
		"perfect_cleanup": false,
		"credits_awarded": 500,
		"xp_awarded": 450,
	})
	_expect(int(payout_transition["credits_before"]) == 0, "Debrief transition must preserve pre-payout Credits.")
	_expect(int(payout_transition["credits_after"]) == 500, "Debrief transition must preserve post-payout Credits.")
	_expect(bool(payout_transition["promoted"]), "Debrief transition must report career promotion.")
	_expect(String(payout_transition["rank_before_id"]) == "trainee", "Debrief transition must preserve previous rank.")
	_expect(String(payout_transition["rank_after_id"]) == "junior_cleaner", "Debrief transition must preserve promoted rank.")
	var unlocked_safety_amber := false
	var unlocked_earth_orbit := false
	for value in payout_transition["unlocks"] as Array:
		var unlock := value as Dictionary
		if String(unlock.get("id", "")) == "safety_amber":
			unlocked_safety_amber = true
		if String(unlock.get("id", "")) == "earth_orbit_03":
			unlocked_earth_orbit = true
	_expect(unlocked_safety_amber, "Promotion transition must expose newly unlocked cosmetics.")
	_expect(unlocked_earth_orbit, "Promotion transition must expose newly unlocked authored contracts.")
	_expect(progression.get_credits() == 500, "Contract payout must persist Credits.")
	_expect(progression.get_rank_id() == "junior_cleaner", "Company XP must promote career rank.")
	_expect(progression.is_cosmetic_unlocked("paint", "safety_amber"), "Rank promotion must unlock configured cosmetics.")
	_expect(progression.is_sector_unlocked("earth_orbit_03"), "Junior Cleaner promotion must unlock advanced Earth contracts.")
	_expect(not progression.is_sector_unlocked("lunar_belt_01"), "Lunar Belt must remain gated until Orbital Cleaner.")

	var cost := progression.get_upgrade_cost("tractor_range")
	_expect(progression.purchase_upgrade("tractor_range"), "Affordable upgrade purchase must succeed.")
	_expect(progression.get_credits() == 500 - cost, "Upgrade purchase must deduct Credits.")
	_expect(progression.get_upgrade_level("tractor_range") == 1, "Upgrade level must increment.")
	var upgraded_ship := progression.get_ship_modifiers()
	_expect(float(upgraded_ship["scan_range"]) > float(base_ship["scan_range"]), "Tractor upgrade must change gameplay modifier.")

	save.delete_save()
	progression.free()
	save.free()

func _validate_cargo_hold() -> void:
	var registry := ContentRegistry.new()
	var cargo := CargoHold.new()
	cargo.capacity = 4
	var small := registry.get_salvage_definition("scrap_fragment")
	var heavy := registry.get_salvage_definition("dense_composite")
	_expect(cargo.store(small), "CargoHold must accept fitting salvage.")
	_expect(cargo.used_units == 1, "CargoHold must track occupied units.")
	_expect(cargo.get_total_mass() > 0.0, "CargoHold must track recovered physical mass.")
	var mass_after_small := cargo.get_total_mass()
	_expect(cargo.store(heavy), "CargoHold must accept salvage that exactly fills remaining space.")
	_expect(cargo.used_units == 4, "CargoHold must reach configured capacity.")
	_expect(cargo.get_total_mass() > mass_after_small, "Heavier recovered cargo must increase total carried mass.")
	_expect(not cargo.can_accept(small), "CargoHold must reject salvage when full.")
	var delivered := cargo.unload_all()
	_expect(delivered.size() == 2, "CargoHold unload must return every delivered salvage item.")
	var delivered_units := 0
	for value in delivered:
		var definition := value as SalvageDefinition
		_expect(definition != null, "CargoHold delivery payload must contain salvage definitions.")
		if definition != null:
			delivered_units += definition.cargo_units
	_expect(delivered_units == 4, "CargoHold delivery payload must preserve unloaded cargo units.")
	_expect(cargo.used_units == 0, "CargoHold unload must clear used units.")
	_expect(is_zero_approx(cargo.get_total_mass()), "CargoHold unload must clear carried physical mass.")
	cargo.free()

func _validate_player_ship() -> void:
	var packed := load("res://src/game/ship/player_ship.tscn") as PackedScene
	_expect(packed != null, "PlayerShip scene must load.")
	if packed == null:
		return
	var ship := packed.instantiate() as PlayerShip
	_expect(ship != null, "PlayerShip root must use PlayerShip controller.")
	if ship == null:
		return
	var qa_input := InputService.new()
	ship.configure(qa_input)
	root.add_child(ship)
	_expect(CollisionGeometry2D.generated_part_count(ship) > 0, "PlayerShip must build alpha-derived hull collision at runtime.")
	_expect(_physics_shape_count(ship) > 0, "PlayerShip alpha hull must register real physics shapes.")
	_expect(ship.find_child("CargoHold", true, false) is CargoHold, "PlayerShip requires CargoHold.")
	_expect(ship.find_child("TractorBeam", true, false) is TractorBeam, "PlayerShip requires TractorBeam.")
	var sprite := ship.find_child("ShipSprite", true, false) as Sprite2D
	_expect(sprite != null, "PlayerShip requires ShipSprite.")
	if sprite != null:
		_expect(sprite.texture != null, "Gameplay ship sprite requires a texture.")
		if sprite.texture != null:
			var native_size := sprite.texture.get_size()
			var rendered_size := native_size * sprite.scale
			_expect(native_size.x >= 512.0 and native_size.y >= 512.0, "HD gameplay ship source must retain enough raster detail.")
			_expect(
				rendered_size.x >= 70.0 and rendered_size.x <= 110.0
				and rendered_size.y >= 70.0 and rendered_size.y <= 110.0,
				"Gameplay ship HD artwork must be normalized to the established on-screen footprint."
			)
		_expect(sprite.material is ShaderMaterial, "Gameplay ship requires paint ShaderMaterial.")
		var ship_alpha_qa := _alpha_collision_sample_mismatches(ship, sprite)
		_expect(
			int(ship_alpha_qa["visible_uncovered"]) == 0,
			"PlayerShip hull collision must cover confidently visible sampled pixels."
		)
		_expect(
			int(ship_alpha_qa["transparent_covered"]) == 0,
			"PlayerShip solid alpha collision must not cover confidently transparent sampled pixels."
		)
	var engine_anchor := ship.find_child("EngineAnchor", true, false) as Marker2D
	_expect(engine_anchor != null, "PlayerShip requires an engine trail anchor.")
	if engine_anchor != null:
		_expect(absf(engine_anchor.position.y - 41.0) <= 1.0, "Pioneer-01 engine anchor must remain aligned with the normalized rear engine.")
	var trail := ship.find_child("EngineTrail", true, false) as EngineTrail
	_expect(trail != null, "PlayerShip requires engine trail.")
	if trail != null:
		_expect(trail.sample_interval <= 0.03, "Engine trail must sample frequently enough to stay continuous.")
		_expect(trail.minimum_sample_distance <= 2.0, "Engine trail cannot depend on large movement jumps.")
	var camera := ship.find_child("ShipCamera", true, false) as ShipCamera
	_expect(camera != null, "PlayerShip requires ship camera.")
	if camera != null:
		_expect(camera.zoom == Vector2.ONE, "Gameplay camera must avoid raster-magnifying zoom.")
	var tuning := (ship as PlayerShip).tuning
	_expect(tuning != null, "PlayerShip requires tuning resource.")
	if tuning != null:
		_expect(tuning.pointer_deadzone >= 70.0, "Pointer deadzone should prevent twitchy center steering.")
		_expect(tuning.pointer_full_thrust_distance >= 360.0, "Pointer full-thrust distance should preserve fine control.")
		_expect(tuning.boundary_warning_seconds >= 6.0 and tuning.boundary_warning_seconds <= 7.0, "Operational warning must remain readable for roughly six to seven seconds before auto-return.")
		_expect(tuning.boundary_hard_escape_margin > 0.0, "Numerical containment must stay behind the timed operational return.")
		_expect(tuning.boundary_return_speed > tuning.absolute_speed_limit, "Operational boundary return must be visibly faster than ordinary ship containment speed.")
		_expect(tuning.boundary_return_max_speed >= 5200.0, "Emergency return needs enough headroom to recover distant exits in about one second.")
		_expect(tuning.boundary_return_target_seconds >= 0.8 and tuning.boundary_return_target_seconds <= 1.2, "Operational boundary return should complete in about one second.")
		_expect(tuning.boundary_return_reentry_depth >= 120.0, "Operational boundary return must carry the ship clearly back inside the playable map before releasing control.")
		_expect(tuning.boundary_return_exit_speed <= tuning.absolute_speed_limit, "Control must return at a normal manageable ship speed.")
		_expect(tuning.boundary_return_turn_response > tuning.turn_response, "Auto-return must visibly rotate the ship inward more decisively than normal steering.")
		_expect(tuning.absolute_speed_limit > tuning.max_speed * 2.0, "Nominal cruise speed must not behave as a tight hard clamp.")
		_expect(tuning.boost_acceleration > 0.0, "Pulse boost must add physical acceleration instead of setting target velocity.")
		_expect(tuning.boost_recharge_seconds > tuning.boost_duration, "Pulse boost must recharge slower than its active window.")
		var coasting_velocity := Vector2(190.0, -70.0)
		var coast_result := ShipDynamics.integrate_velocity(
			coasting_velocity,
			Vector2.ZERO,
			0.0,
			tuning.absolute_speed_limit,
			1.0 / 60.0
		)
		_expect(coast_result.is_equal_approx(coasting_velocity), "Open-space coasting must preserve velocity with no thrust, drag or external force.")
		var empty_mass := ShipDynamics.effective_mass(tuning.dry_mass, 0.0, tuning.cargo_inertia_factor)
		var loaded_mass := ShipDynamics.effective_mass(tuning.dry_mass, 8.0, tuning.cargo_inertia_factor)
		_expect(loaded_mass > empty_mass, "Recovered cargo must increase effective ship inertia.")
		var collision_result := ShipDynamics.collision_response(
			Vector2(120.0, 80.0),
			Vector2.LEFT,
			tuning.collision_restitution,
			tuning.collision_tangent_retention
		)
		_expect(collision_result.x < 0.0 and collision_result.y > 0.0, "Collision response must reflect the normal component while retaining tangential motion.")
	var ship_source := FileAccess.get_file_as_string("res://src/game/ship/player_ship.gd")
	_expect("ShipDynamics.propulsion_acceleration" in ship_source, "PlayerShip must integrate thrust through ShipDynamics.")
	_expect("ShipSteering.target_velocity" not in ship_source, "PlayerShip must not drive flight through a target-velocity controller.")
	_expect("velocity.move_toward(desired_velocity" not in ship_source, "Open-space flight must not contain implicit auto-deceleration.")
	_expect("_apply_soft_world_bounds" not in ship_source, "Operational limits must not apply a distant continuous soft-wall correction.")
	_expect("_update_operational_boundary" in ship_source and "_apply_boundary_repel" in ship_source, "Operational limits must use warning state plus a timed physical return response.")
	_expect("_boundary_warning_elapsed" in ship_source and "boundary_warning_seconds" in ship_source, "Operational return must wait through the configured readable warning grace.")
	_expect("closest_inside_point" in ship_source and "outside_offset" in ship_source, "Boundary warning must be derived from the ship actually crossing the authored play bounds.")
	_expect("time_to_edge" not in ship_source and "boundary_warning_margin" not in ship_source, "Operational warning must never shrink usable play space through predictive or pre-edge activation.")
	_expect("desired_velocity" in ship_source and "_update_boundary_return_velocity" in ship_source, "Emergency return must actively steer velocity toward the safe re-entry target.")
	_expect("motion_intent = _boundary_return_direction" in ship_source, "Auto-return must steer propulsion inward instead of only changing velocity.")
	_expect("_boundary_return_active" in ship_source and "_has_completed_boundary_return" in ship_source, "Auto-return must remain active until spatial re-entry is complete, not expire on a fixed timer.")
	_expect("boundary_return_target_seconds" in ship_source and "boundary_return_max_speed" in ship_source, "Emergency return speed must adapt to distance so recovery completes in roughly one second.")
	_expect("_boundary_safe_reentry_rect" in ship_source and "boundary_return_reentry_depth" in ship_source and "_finish_boundary_return" in ship_source, "Player control must return only after the ship enters a safe inset area inside the map.")
	_expect("boundary_return_exit_speed" in ship_source, "Emergency return must hand control back at a normal controllable velocity.")
	_expect("boundary_return_control_seconds" not in ship_source, "Boundary return must not release control because an arbitrary number of seconds elapsed.")
	_expect("boundary_return_turn_response" in ship_source, "Auto-return must visibly rotate the ship toward the safe area.")
	_expect("absolute_speed_limit * tuning.boundary_warning_seconds" in ship_source, "Numerical fail-safe must not cut the post-boundary warning grace short at high speed.")
	var input_source := FileAccess.get_file_as_string("res://src/core/input/input_service.gd")
	_expect("set_touch_navigation_vector" in input_source, "Touch steering must use a dedicated analog navigation vector.")
	_expect("signal boost_requested" in input_source, "InputService must expose one device-agnostic boost request.")
	_expect("is_pointer_boost_event" in input_source, "InputService must expose a stable desktop pointer-boost event contract.")
	_expect("POINTER_KEYBOARD" not in input_source, "Mouse and keyboard must not share one ambiguous active input mode.")
	_expect("InputMode.POINTER" in input_source and "InputMode.KEYBOARD" in input_source and "InputMode.GAMEPAD" in input_source, "InputService must arbitrate pointer, keyboard and gamepad as distinct active sources.")
	_expect("Input.mouse_mode" in input_source and "MOUSE_MODE_HIDDEN" in input_source, "Keyboard/gamepad control must hide the inactive mouse cursor.")
	_expect("InputEventMouseMotion" in input_source and "MOUSE_REACTIVATION_DISTANCE" in input_source, "Real mouse movement must explicitly reactivate pointer steering.")
	_expect("Input.get_joy_axis" in input_source, "Gamepad steering must read its own analog source instead of sharing keyboard action state.")
	_expect(
		"InputEventMouseButton" not in input_source.split("func _unhandled_input", false, 1)[1].split("func get_navigation_vector", false, 1)[0],
		"Desktop world-click boost must not depend on _unhandled_input after GUI dispatch."
	)
	ship.free()
	qa_input.free()

func _validate_flight_screen() -> void:
	var packed := load("res://src/ui/screens/flight/flight_screen.tscn") as PackedScene
	_expect(packed != null, "Flight screen must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is Control, "Flight screen must inherit Control.")
	_expect(screen.find_child("PlayerShip", true, false) is PlayerShip, "Flight screen requires PlayerShip.")
	_expect(screen.find_child("SectorRuntime", true, false) is SectorRuntime, "Flight screen requires generic SectorRuntime.")
	_expect(screen.find_child("EnvironmentRuntime", true, false) is EnvironmentRuntime, "Flight screen requires reusable biome EnvironmentRuntime.")
	_expect(screen.find_child("TouchFlightControls", true, false) is TouchFlightControls, "Flight screen requires dedicated floating touch steering and boost controls.")
	_expect(screen.find_child("ShipSpeedometer", true, false) is ShipSpeedometer, "Flight HUD requires reusable live speed telemetry.")
	_expect(screen.find_child("SpeedometerAnchor", true, false) is MarginContainer, "Flight HUD must own an explicit bottom-left speedometer anchor.")
	_expect(screen.find_child("HintPanel", true, false) == null, "Legacy flight steering hint must be removed from the HUD.")
	var speedometer_source := FileAccess.get_file_as_string("res://src/ui/components/ship_speedometer.gd")
	var flight_input_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.gd")
	_expect("velocity.length()" in speedometer_source, "Speedometer must report the real physical velocity magnitude.")
	_expect("absolute_speed_limit" in speedometer_source and "max_speed" in speedometer_source, "Speedometer must distinguish cruise speed from the higher physical safety range.")
	_expect("FlightTelemetryUnits.format_speed_kmh" in speedometer_source, "Speedometer must convert world velocity through the shared orbital telemetry scale.")
	_expect(is_equal_approx(FlightTelemetryUnits.speed_kmh(300.0), 27000.0), "300 world units/s must display as 27,000 km/h on the orbital telemetry scale.")
	_expect(is_equal_approx(FlightTelemetryUnits.distance_km(1000.0), 25.0), "1,000 world units must display as 25 km on the orbital telemetry scale.")
	_expect("offset_left" not in speedometer_source and "anchor_bottom" not in speedometer_source, "Reusable speedometer must not own screen placement.")
	_expect("_validate_speedometer_runtime_layout" in flight_input_source, "Flight must verify speedometer visibility inside the resolved HUD viewport.")
	_expect("_input_service.is_pointer_boost_event(event)" in flight_input_source, "Flight must route desktop world clicks before GUI can consume them.")
	_expect("_is_pointer_over_flight_ui" in flight_input_source, "Flight must explicitly guard HUD regions from world-click boost.")
	_expect("touch_controls.is_pointer_over_boost_hud" in flight_input_source, "Boost HUD clicks must never fall through into world-click boost.")
	_expect("_operations_overlay != null" in flight_input_source and "_travel_in_progress" in flight_input_source, "World-click boost must be disabled while menus or travel own input.")
	_expect(screen.find_child("AmbientSpace", true, false) is SectorBackdrop, "Flight screen requires data-configurable SectorBackdrop.")
	_expect(screen.find_child("OperationalZoneWarning", true, false) is OperationalZoneWarning, "Flight HUD requires reusable operational-zone warning feedback.")
	var flight_backdrop_source := FileAccess.get_file_as_string("res://src/game/sector/sector_backdrop.gd")
	_expect("MultiMeshInstance2D" in flight_backdrop_source, "SectorBackdrop must batch the starfield through MultiMeshInstance2D.")
	_expect("multimesh.mesh = quad" in flight_backdrop_source, "SectorBackdrop MultiMesh must own an explicit QuadMesh for GLES3/Web rendering.")
	_expect("queue_redraw()" not in flight_backdrop_source.split("func _process", false, 1)[1].split("func _draw", false, 1)[0], "SectorBackdrop must not redraw its static starfield during frame updates.")
	_expect("_draw_perimeter" not in flight_backdrop_source, "SectorBackdrop must not own gameplay-boundary presentation.")
	var zone_warning_source := FileAccess.get_file_as_string("res://src/ui/components/operational_zone_warning.gd")
	_expect("operational_boundary_changed" in zone_warning_source and "operational_boundary_repelled" in zone_warning_source, "Operational warning must consume ship-owned boundary state instead of duplicating world-bound physics.")
	_expect("_draw_vertical_edge" in zone_warning_source and "_draw_horizontal_edge" in zone_warning_source, "Operational warning must indicate the side being exited without drawing a permanent world border.")
	_expect("zone_warning.bind(ship)" in flight_input_source, "Flight must bind the reusable HUD warning to the configured ship.")
	var quality_source := FileAccess.get_file_as_string("res://src/core/performance/runtime_quality.gd")
	_expect("OS.has_feature(\"web\")" in quality_source, "Runtime quality profile must explicitly protect Web builds.")
	_expect("use_screen_texture_post_process" in quality_source, "Runtime quality profile must own post-process policy.")
	_expect(screen.find_child("UnloadDepot", true, false) is UnloadZone, "Flight screen requires cargo unload zone.")
	var depot_station := screen.find_child("Station", true, false) as Sprite2D
	_expect(depot_station != null, "Cargo unload zone requires a physical depot station sprite.")
	if depot_station != null:
		_expect(
			depot_station.texture != null
			and depot_station.texture.resource_path == "res://assets/original/depots/cargo_depot_hd.webp",
			"Cargo unload zone must use the staged HD depot artwork."
		)
		_expect(
			depot_station.scale.is_equal_approx(Vector2(0.3, 0.3)),
			"HD depot must stay normalized inside the 145 px unload radius."
		)
		if depot_station.texture != null:
			var depot_rendered_size := depot_station.texture.get_size() * depot_station.scale
			_expect(
				depot_rendered_size.x >= 180.0 and depot_rendered_size.x <= 205.0
				and depot_rendered_size.y >= 180.0 and depot_rendered_size.y <= 205.0,
				"HD depot artwork must remain readable without covering the gameplay ring."
			)
	_expect(
		FileAccess.file_exists("res://assets/third_party/kenney_simple_space/scenery/station_a.png"),
		"Previous Kenney depot station must remain available while HD art is under evaluation."
	)
	_expect(screen.find_child("ReturnButton", true, false) is Button, "Flight screen requires return action.")
	_expect(screen.find_child("OperationsButton", true, false) is Button, "Free flight requires compact Operations access.")
	_expect(screen.find_child("OperationsOverlayHost", true, false) is Control, "Flight requires an overlay host instead of routing to a full-screen menu.")
	var operations_host := screen.find_child("OperationsOverlayHost", true, false) as Control
	_expect(operations_host.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Empty Operations overlay host must never intercept clicks intended for the flight HUD.")
	_expect(screen.find_child("WarpTravelTransition", true, false) is WarpTravelTransition, "Flight requires reusable warp departure and arrival feedback.")
	_expect(screen.find_child("TopBar", true, false) is BoxContainer, "Flight HUD requires responsive TopBar.")
	_expect(screen.find_child("BiomeThumbnail", true, false) is TextureRect, "Flight HUD must show the current biome primary artwork.")
	_expect(screen.find_child("MissionChrome", true, false) is NinePatchRect, "Current-flight card must use the shared Kenney panel chrome.")
	_expect(screen.find_child("CargoChrome", true, false) is NinePatchRect, "Cargo card must use the shared Kenney panel chrome.")
	var cargo_content := screen.find_child("CargoContent", true, false) as VBoxContainer
	_expect(cargo_content != null and cargo_content.alignment == BoxContainer.ALIGNMENT_CENTER, "Cargo content must stay vertically centered inside the dark-mode card, including while tractor progress is visible.")
	var cargo_label := screen.find_child("CargoLabel", true, false) as Label
	_expect(cargo_label != null and cargo_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Cargo title must stay horizontally centered inside the dark-mode card.")
	var hud_root := screen.find_child("HudRoot", true, false) as Control
	_expect(hud_root != null and hud_root.theme != null, "Flight HudRoot must own the flight HUD theme because CanvasLayer interrupts Control theme inheritance.")
	_expect(screen.find_child("CleanupStatus", true, false) is Label, "Flight HUD requires sector cleanliness status.")
	_expect(screen.find_child("CleanupProgress", true, false) is ProgressBar, "Flight HUD requires sector cleanliness progress.")
	_expect(screen.find_child("EnvironmentStatus", true, false) is Label, "Flight HUD must identify active environmental effects.")
	_expect(screen.find_child("DepotNavigationGuide", true, false) is DepotNavigationGuide, "Flight HUD requires contextual cargo-depot guidance.")
	_expect(screen.find_child("DepotNavLabel", true, false) is Label, "Depot navigation requires localized distance feedback.")

	var flight_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.gd")
	_expect(
		"ship.position = deployment_position" in flight_source
		and "depot.position = deployment_position" in flight_source,
		"Flight deployment must place ship and cargo depot at the same sector position."
	)

	_expect("navigation.configure(ship, depot)" in flight_source, "Flight must bind depot navigation to the real per-sector depot world node.")
	_expect("depot_navigation.set_cargo_state" in flight_source, "Depot guide must react to cargo state without owning cargo rules.")
	_expect("_contract_active = not bool(context.get(\"free_roam\", false))" in flight_source, "Flight must separate free-roam and contract states explicitly.")
	_expect("warp_transition.play_departure" in flight_source and "warp_transition.play_arrival" in flight_source, "Travel must use the same reusable transition for departure and arrival.")
	_expect("warp_transition.prime_arrival" in flight_source, "Destination warp must be primed behind the persistent cover before reveal.")
	_expect("_router.begin_travel_handoff()" in flight_source and "_router.finish_travel_handoff()" in flight_source, "Contract deploy/abort must hide routed scene replacement inside the travel handoff.")
	var warp_source := FileAccess.get_file_as_string("res://src/ui/components/warp_travel_transition.gd")
	_expect("func prime_arrival" in warp_source and "func play_primed_arrival" in warp_source, "Warp transition must support a covered destination handoff without restarting the effect.")
	_expect("_open_operations()" in flight_source, "Free flight must open Operations over the live world.")
	_expect('event.is_action_pressed("ui_cancel")' in flight_source, "Free flight must open Operations from ESC / ui_cancel.")
	var flight_scene_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.tscn")
	_expect("occ_flight_hud_theme.tres" in flight_scene_source, "Live flight HUD must use the dedicated dark flight theme.")
	_expect("HudActionButton" in flight_scene_source and "HudDangerButton" in flight_scene_source, "Flight Operations/abort actions must use compact HUD button variants.")
	_expect(flight_scene_source.count("size_flags_vertical = 4") >= 2, "Flight action buttons must stay at native 48 px height instead of stretching with the HUD row.")
	_expect("HudSuccessButton" in flight_source, "Completed contracts must switch the return action to the green success button state.")
	_expect("_refresh_biome_thumbnail" in flight_source and 'visual_profile.get("primary_asset", "")' in flight_source, "Flight biome thumbnail must come from the same data-driven primary artwork used in the world.")
	var flight_theme_source := FileAccess.get_file_as_string("res://src/ui/themes/occ_flight_hud_theme.tres")
	_expect("HudThumbnailEmpty" in flight_theme_source, "Biome preview must not draw a second internal cyan frame.")
	_expect('StyleBoxEmpty" id="HudPanel"' in flight_theme_source, "Flight status card hosts must not draw a second flat border/background around the Kenney asset.")
	_expect("panel_glass.png" in flight_scene_source, "Flight status cards must reuse the rounded Kenney glass panel chrome.")
	_expect("panel_glass_notches.png" not in flight_scene_source, "Flight status cards must not regress to the notched octagonal panel chrome.")
	_expect(flight_scene_source.count("self_modulate = Color(0.12, 0.13, 0.15, 1)") >= 2, "Mission and cargo Kenney frames must use the shared near-black treatment.")
	_expect(flight_scene_source.count("draw_center = true") >= 2, "Dark-mode Kenney status cards must own their full background, not sit over a separate black rectangle.")
	_expect("Blue/Double/bar_round_gloss_large.png" in flight_theme_source, "Operations requires a clearly clickable blue Kenney action state.")
	_expect('HudActionButton/styles/normal = SubResource("HudButtonAction")' in flight_theme_source, "Operations must render with the full blue action surface, not the dark outline-only state.")
	_expect('HudActionButton/styles/hover = SubResource("HudButtonActionHover")' in flight_theme_source, "Flight action hover must be visualized by the surface, not text recoloring or resizing.")
	_expect('HudActionButton/colors/font_focus_color = Color(0.02, 0.09, 0.14, 1)' in flight_theme_source, "Focused blue HUD actions must preserve their readable dark label.")
	_expect('HudDangerButton/colors/font_hover_color = Color(0.12, 0.06, 0.07, 1)' in flight_theme_source, "Danger button hover must keep the same readable label color.")
	_expect('HudSuccessButton/colors/font_hover_color = Color(0.035, 0.11, 0.07, 1)' in flight_theme_source, "Success button hover must keep the same readable label color.")
	_expect("Red/Double/bar_round_gloss_large.png" in flight_theme_source, "Abort Contract requires a clearly clickable red Kenney state.")
	_expect("Green/Double/bar_round_gloss_large.png" in flight_theme_source, "Complete Contract requires a clearly clickable green Kenney state.")
	_expect('theme_override_styles/panel = SubResource("MissionPanel")' not in flight_scene_source, "Flight mission HUD must not retain legacy cyan panel chrome.")
	_expect('theme_override_styles/normal = SubResource("ReturnButtonNormal")' not in flight_scene_source, "Flight action buttons must use stable Kenney theme states.")

	var guide_source := FileAccess.get_file_as_string("res://src/ui/components/depot_navigation_guide.gd")
	_expect("FlightTelemetryUnits.format_distance" in guide_source, "Depot navigation must use the same orbital telemetry scale as the speedometer.")
	_expect("_format_distance" not in guide_source, "Depot navigation must not maintain a second independent distance conversion.")
	_expect("get_canvas_transform()" in guide_source, "Depot guide must project the real world target through the active camera transform.")
	_expect("NEAR_DISTANCE" in guide_source, "Depot guide must hide near the depot instead of remaining invasive.")
	_expect("UPDATE_INTERVAL := 1.0 / 30.0" in guide_source, "Depot guide must use a bounded lightweight update cadence.")

	var ship_source := FileAccess.get_file_as_string("res://src/game/ship/player_ship.gd")
	var tractor_source := FileAccess.get_file_as_string("res://src/game/salvage/tractor_beam.gd")
	_expect(
		"func _is_locked_target_valid" in tractor_source,
		"TractorBeam must distinguish acquisition range from an already locked tether."
	)
	var area_exit_start := tractor_source.find("func _on_area_exited")
	var cargo_change_start := tractor_source.find("func _on_cargo_changed")
	_expect(
		area_exit_start >= 0 and cargo_change_start > area_exit_start,
		"TractorBeam must expose area-exit and cargo-validity handlers."
	)
	if area_exit_start >= 0 and cargo_change_start > area_exit_start:
		var area_exit_source := tractor_source.substr(
			area_exit_start,
			cargo_change_start - area_exit_start
		)
		_expect(
			"_set_target(null)" not in area_exit_source,
			"Leaving scanner overlap must not break an active tractor tether."
		)
	var locked_validity_start := tractor_source.find("func _is_locked_target_valid")
	var target_setter_start := tractor_source.find("func _set_target")
	_expect(
		locked_validity_start >= 0 and target_setter_start > locked_validity_start,
		"TractorBeam must keep locked-target validation separate from target mutation."
	)
	if locked_validity_start >= 0 and target_setter_start > locked_validity_start:
		var locked_validity_source := tractor_source.substr(
			locked_validity_start,
			target_setter_start - locked_validity_start
		)
		_expect(
			"_candidates.has" not in locked_validity_source
			and "_effective_scan_range" not in locked_validity_source,
			"Locked tractor targets must remain valid outside scanner overlap/range."
		)

	_expect(
		"func set_capture_enabled" in tractor_source
		and "_capture_enabled and _target.is_collection_ready" in tractor_source,
		"TractorBeam must be able to suspend cargo capture without breaking the active tether."
	)
	_expect(
		"_capture_enabled = true" in tractor_source.split("func set_interaction_enabled", false, 1)[1].split("func set_capture_enabled", false, 1)[0],
		"Disabling tractor interaction must clear any temporary boundary capture suspension."
	)
	_expect(
		"_capture_enabled" in tractor_source
		and "_target.tractor_step(" in tractor_source,
		"TractorBeam must keep driving its locked target while capture is suspended."
	)
	var salvage_source := FileAccess.get_file_as_string("res://src/game/salvage/salvage_object.gd")
	_expect(
		"advance_collection: bool = true" in salvage_source
		and "if advance_collection:" in salvage_source,
		"SalvageObject must separate physical tether motion from collection-progress advancement."
	)
	_expect(
		"tractor_beam.set_capture_enabled(false)" in ship_source
		and "tractor_beam.set_capture_enabled(true)" in ship_source,
		"Boundary auto-return must suspend capture until player control is restored."
	)

	var depot_source := FileAccess.get_file_as_string("res://src/game/salvage/unload_zone.gd")
	_expect("set_cargo_state" in depot_source, "Depot world beacon must react to full cargo.")
	_expect("1.0 / 20.0" in depot_source, "Animated depot beacon must throttle redraws for Web performance.")
	_expect("mast_top" not in depot_source, "HD depot artwork must own its antenna silhouette instead of duplicating a procedural mast.")

	var authored_salvage := 0
	for node in screen.find_children("*", "Area2D", true, false):
		if node is SalvageObject:
			authored_salvage += 1
	_expect(authored_salvage == 0, "Flight scene must not manually author normal salvage objects.")

	var authored_obstacles := 0
	for node in screen.find_children("*", "StaticBody2D", true, false):
		if node is SectorObstacle:
			authored_obstacles += 1
	_expect(authored_obstacles == 0, "Flight scene must not manually author normal sector obstacles.")
	screen.free()

func _validate_debrief_screen() -> void:
	var packed := load("res://src/ui/screens/debrief/contract_debrief_screen.tscn") as PackedScene
	_expect(packed != null, "Contract Debrief scene must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is ContractDebriefScreen, "Contract Debrief root must use ContractDebriefScreen.")
	_expect(screen.find_child("Stage", true, false) is MarginContainer, "Debrief requires a fixed no-scroll stage.")
	_expect(screen.find_children("*", "ScrollContainer", true, false).is_empty(), "Debrief must not depend on ScrollContainer at any breakpoint.")
	_expect(screen.find_child("SummaryPage", true, false) is VBoxContainer and screen.find_child("ProgressPage", true, false) is VBoxContainer, "Debrief must split variable content into fixed pages.")
	_expect(screen.find_child("ContentGrid", true, false) is GridContainer, "Debrief requires responsive mission summary.")
	_expect(screen.find_child("RewardGrid", true, false) is GridContainer, "Debrief requires reward breakdown.")
	_expect(screen.find_child("XpProgress", true, false) is ProgressBar, "Debrief requires animated career XP progress.")
	_expect(screen.find_child("PromotionPanel", true, false) is PanelContainer, "Debrief requires promotion reveal.")
	_expect(screen.find_child("UnlocksList", true, false) is VBoxContainer, "Debrief requires unlock reveal.")
	_expect(screen.find_child("DiscoveriesList", true, false) is VBoxContainer, "Debrief requires discovery reveal.")
	_expect(screen.find_child("ContinueButton", true, false) is Button, "Debrief requires explicit Continue to Headquarters action.")
	var debrief_scene_source := FileAccess.get_file_as_string("res://src/ui/screens/debrief/contract_debrief_screen.tscn")
	_expect("occ_operations_theme.tres" in debrief_scene_source, "Contract Debrief must use the shared Kenney game UI theme.")
	_expect("theme_type_variation = &\"ConsolePanel\"" in debrief_scene_source, "Contract Debrief must use the physical console surface.")
	_expect("theme_type_variation = &\"PrimaryButton\"" in debrief_scene_source, "Contract Debrief primary action must use the shared button language.")
	_expect("occ_theme.tres" not in debrief_scene_source and "StyleBoxFlat" not in debrief_scene_source, "Contract Debrief must not retain legacy flat UI chrome.")
	screen.free()

	var flight_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.gd")
	_expect("DEBRIEF_SCREEN_PATH" in flight_source, "Completed contracts must route through Contract Debrief.")
	_expect("debrief_transition" in flight_source, "Flight must pass immutable progression transition into Debrief.")
	_expect("_ads.show_contract_break()" not in flight_source, "Contract ad break must happen after Debrief acknowledgment, not before rewards are shown.")

	var debrief_source := FileAccess.get_file_as_string("res://src/ui/screens/debrief/contract_debrief_screen.gd")
	_expect("_ads.show_contract_break()" in debrief_source, "Debrief Continue must preserve the natural ad-break policy.")
	_expect("debrief_return_screen_path" in debrief_source, "Debrief must preserve the configured return destination.")

	var promotion := ProceduralSfx.promotion()
	_expect(promotion != null and promotion.data.size() > 1024, "Promotion reveal requires a generated reward cue.")

func _validate_polish_systems() -> void:
	var flight_packed := load("res://src/ui/screens/flight/flight_screen.tscn") as PackedScene
	_expect(flight_packed != null, "Polished Flight scene must load.")
	if flight_packed != null:
		var flight := flight_packed.instantiate()
		_expect(flight.find_child("WorldPostProcess", true, false) is WorldPostProcess, "Flight requires world-only post-processing.")
		_expect(flight.find_child("AmbientMotion", true, false) is AmbientOrbitLayer, "Flight requires lightweight animated ambient orbits.")
		_expect(flight.find_child("EnvironmentalVfx", true, false) is EnvironmentalVfxLayer, "Flight requires bounded profile-driven environmental VFX.")
		_expect(flight.find_child("SpaceEnvironment", true, false) is SpaceEnvironmentLayer, "Flight requires layered procedural atmosphere behind and in front of gameplay.")
		_expect(flight.find_child("WorldVisualRuntime", true, false) is WorldVisualRuntime, "Flight requires one visual coordinator between environment simulation and rendering.")
		_expect(flight.find_child("FlightFeedback", true, false) is FlightFeedback, "Flight requires centralized gameplay feedback.")
		var engine_particles := flight.find_child("EngineParticles", true, false)
		_expect(engine_particles is CPUParticles2D, "Ship polish requires engine particles.")
		flight.free()

	var burst_packed := load("res://src/game/visual/world_burst.tscn") as PackedScene
	_expect(burst_packed != null, "Reusable WorldBurst effect must load.")

	var post_source := FileAccess.get_file_as_string("res://src/game/visual/world_post_process.gdshader")
	_expect("hint_screen_texture" in post_source, "Godot 4 post-process must read screen texture through hint_screen_texture.")
	_expect(
		post_source.count("texture(screen_texture") == 1,
		"World post-process must keep exactly one full-screen texture fetch for Web performance."
	)
	_expect("environment_fog_strength" in post_source, "World post-process must support localized biome visibility haze.")
	_expect("environment_distortion" in post_source, "World post-process must support subtle biome interference distortion.")
	_expect("profile_mode" in post_source and "profile_strength" in post_source, "World post-process must consume the data-driven environmental profile.")
	_expect("sin(" not in post_source and "cos(" not in post_source, "Full-screen compositor must avoid per-pixel trigonometry.")

	var space_environment_source := FileAccess.get_file_as_string("res://src/game/visual/space_environment_layer.gd")
	_expect("NoiseTexture2D.new()" in space_environment_source, "Space environment noise must use Godot's native threaded NoiseTexture2D generation.")
	_expect("get_noise_2d(" not in space_environment_source, "Space environment must not generate noise pixels through GDScript sampling loops.")
	_expect("seamless = true" in space_environment_source, "Environment noise textures must remain tileable for moving atmosphere layers.")

	var environment_shader_source := FileAccess.get_file_as_string("res://src/game/visual/space_environment.gdshader")
	_expect("noise_a" in environment_shader_source and "noise_b" in environment_shader_source, "Space environment must use layered noise fields instead of flat procedural circles.")
	_expect("hint_screen_texture" not in environment_shader_source, "Atmosphere shader must not add another screen copy.")
	_expect("foreground_mix" in environment_shader_source and "focal_point" in environment_shader_source, "Space environment must support foreground depth and focal effects.")
	_expect("profile_mode == 17" in environment_shader_source, "Space environment shader must retain the complete authored profile catalogue.")

	var visual_language_source := FileAccess.get_file_as_string("res://src/game/visual/world_visual_language.gd")
	_expect("environment_space_mode" in visual_language_source, "Visual language must keep a rich atmosphere mode separate from coarse post-process modes.")
	var required_profiles := [
		"clean", "dust", "nebula", "solar", "anomaly", "industrial", "debris",
		"cryo", "gas", "ocean", "electromagnetic", "rings", "volcanic",
		"deep_space", "crystal", "toxic", "graveyard", "remnant"
	]
	for profile in required_profiles:
		_expect(('"%s"' % profile) in visual_language_source, "Visual language is missing required profile %s." % profile)

	var biome_schema_source := FileAccess.get_file_as_string("res://schemas/biome.schema.json")
	_expect('"effect_profile"' in biome_schema_source and '"effect_intensity"' in biome_schema_source, "Biome schema must require explicit environmental art direction.")

	var vfx_source := FileAccess.get_file_as_string("res://src/game/visual/environmental_vfx_layer.gd")
	_expect(vfx_source.count("CPUParticles2D.new()") == 3, "Environmental VFX must own three interpolated particle depth fields.")
	_expect("z_as_relative = false" in vfx_source, "Foreground particles must be able to cross world gameplay elements.")
	_expect("PARTICLE_STREAK" in vfx_source and "PARTICLE_SHARD" in vfx_source and "PARTICLE_GLOW" in vfx_source, "Environmental particles require distinct energy, dust and glow textures.")
	for profile in required_profiles:
		if profile == "clean":
			continue
		_expect(('"%s"' % profile) in vfx_source, "Environmental VFX is missing particle routing for profile %s." % profile)

	var celestial_source := FileAccess.get_file_as_string("res://src/game/visual/celestial_body.gdshader")
	_expect("atmosphere_strength" in celestial_source, "Celestial-body shader must consume authored atmosphere strength.")
	_expect("shimmer_strength" in celestial_source, "Celestial-body shader must consume authored shimmer strength.")
	_expect("sin(" not in celestial_source and "cos(" not in celestial_source, "Celestial-body shader must avoid per-pixel trigonometry.")
	var backdrop_source := FileAccess.get_file_as_string("res://src/game/sector/sector_backdrop.gd")
	_expect("CELESTIAL_BODY_SHADER" in backdrop_source, "SectorBackdrop must use the shared bounded celestial-body shader.")
	_expect("_primary_visual.material = _primary_material" in backdrop_source, "Primary biome artwork must receive the shared celestial material.")
	_expect("CELESTIAL_GLOW_SHADER" in backdrop_source and "_primary_glow" in backdrop_source, "Primary celestial artwork must receive a separate additive aura pass.")

	var ambient_source := FileAccess.get_file_as_string("res://src/game/visual/ambient_orbit_layer.gd")
	_expect("match _biome_id" not in ambient_source, "Ambient visual behavior must never branch on authored biome IDs.")
	_expect("environment_effect_profile" in ambient_source, "Ambient visual behavior must consume reusable effect profiles.")

	var environment_source := FileAccess.get_file_as_string("res://src/game/environment/environment_runtime.gd")
	_expect("environment_visual_state_changed" in environment_source, "EnvironmentRuntime must publish presentation state without owning a renderer.")
	_expect("WorldPostProcess" not in environment_source, "EnvironmentRuntime must stay decoupled from the post-process implementation.")

	var quality_source := FileAccess.get_file_as_string("res://src/core/performance/runtime_quality.gd")
	_expect("EFFECTS_LOW" in quality_source and "EFFECTS_MEDIUM" in quality_source and "EFFECTS_HIGH" in quality_source, "RuntimeQuality must expose explicit environmental VFX tiers.")
	_expect("return not is_mobile_render_target()" in quality_source, "Desktop Web must keep the single-pass compositor while mobile uses the lightweight fallback.")

	var scanner := ProceduralSfx.scanner_ping()
	var discovery := ProceduralSfx.discovery()
	_expect(scanner != null and scanner.data.size() > 256, "Scanner feedback SFX must be generated.")
	_expect(discovery != null and discovery.data.size() > scanner.data.size(), "Discovery SFX must be a richer, longer cue.")

func _validate_render_quality() -> void:
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "Physics interpolation must remain enabled for smooth Web movement.")

func _validate_all_world_alpha_collisions(
	registry: ContentRegistry,
	obstacle_packed: PackedScene,
	landmark_packed: PackedScene
) -> void:
	if obstacle_packed != null:
		var checked_obstacles: Dictionary = {}
		for biome_id in ["earth_orbit", "lunar_belt", "mars_freight", "blue_nebula"]:
			var biome := registry.get_biome(biome_id)
			for value in biome.get("obstacles", []) as Array:
				var definition := value as Dictionary
				var obstacle_id := String(definition.get("id", ""))
				if obstacle_id.is_empty() or checked_obstacles.has(obstacle_id):
					continue
				checked_obstacles[obstacle_id] = true
				var obstacle := obstacle_packed.instantiate() as SectorObstacle
				_expect(obstacle != null, "Alpha boundary QA must instantiate obstacle: %s" % obstacle_id)
				if obstacle == null:
					continue
				obstacle.configure(definition, 1.0)
				root.add_child(obstacle)
				var segment_count := CollisionGeometry2D.generated_boundary_segment_count(obstacle)
				_expect(
					CollisionGeometry2D.generated_part_count(obstacle) == 1
					and _has_concave_boundary_shape(obstacle),
					"Obstacle must use one static concave alpha boundary: %s" % obstacle_id
				)
				_expect(segment_count > 8, "Obstacle alpha boundary is unexpectedly empty: %s" % obstacle_id)
				print("[QA] ALPHA_BOUNDARY kind=obstacle id=%s shapes=1 segments=%d" % [
					obstacle_id,
					segment_count,
				])
				obstacle.free()
		_expect(checked_obstacles.size() >= 18, "Alpha boundary QA must cover the authored obstacle families.")

	if landmark_packed != null:
		for landmark_id in [
			"service_satellite",
			"cargo_waystation",
			"relay_satellite",
			"mining_rig",
			"fractured_moonlet",
			"comms_array",
			"research_outpost",
			"derelict_explorer",
		]:
			var definition := registry.get_landmark(landmark_id)
			var landmark := landmark_packed.instantiate() as SectorLandmark
			_expect(landmark != null, "Alpha boundary QA must instantiate landmark: %s" % landmark_id)
			if landmark == null:
				continue
			landmark.configure(definition)
			root.add_child(landmark)
			var segment_count := CollisionGeometry2D.generated_boundary_segment_count(landmark)
			_expect(
				CollisionGeometry2D.generated_part_count(landmark) == 1
				and _has_concave_boundary_shape(landmark),
				"Landmark must use one static concave alpha boundary: %s" % landmark_id
			)
			_expect(segment_count > 12, "Landmark alpha boundary is unexpectedly empty: %s" % landmark_id)
			print("[QA] ALPHA_BOUNDARY kind=landmark id=%s shapes=1 segments=%d" % [
				landmark_id,
				segment_count,
			])
			landmark.free()

func _has_concave_boundary_shape(body: CollisionObject2D) -> bool:
	var concave_count := 0
	var other_generated_shapes := 0
	for owner_id in body.get_shape_owners():
		for shape_index in range(body.shape_owner_get_shape_count(owner_id)):
			var shape := body.shape_owner_get_shape(owner_id, shape_index)
			if shape is ConcavePolygonShape2D:
				concave_count += 1
			elif shape is ConvexPolygonShape2D:
				other_generated_shapes += 1
	return concave_count == 1 and other_generated_shapes == 0

func _alpha_collision_sample_mismatches(body: CollisionObject2D, sprite: Sprite2D) -> Dictionary:
	var result := {
		"transparent_covered": 0,
		"visible_uncovered": 0,
	}
	if sprite == null or sprite.texture == null:
		result["visible_uncovered"] = 1
		return result
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		result["visible_uncovered"] = 1
		return result
	if image.is_compressed() and image.decompress() != OK:
		result["visible_uncovered"] = 1
		return result

	var texture_size := sprite.texture.get_size()
	var origin := texture_size * 0.5 if sprite.centered else Vector2.ZERO
	var step_x := maxi(int(texture_size.x / 28.0), 6)
	var step_y := maxi(int(texture_size.y / 28.0), 6)
	var convex_shapes: Array[Dictionary] = []
	for owner_id in body.get_shape_owners():
		var owner_transform := body.shape_owner_get_transform(owner_id)
		for shape_index in range(body.shape_owner_get_shape_count(owner_id)):
			var shape := body.shape_owner_get_shape(owner_id, shape_index)
			if shape is ConvexPolygonShape2D:
				convex_shapes.append({
					"shape": shape,
					"transform": owner_transform,
				})

	for y in range(step_y / 2, image.get_height(), step_y):
		for x in range(step_x / 2, image.get_width(), step_x):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.02 and alpha < 0.15:
				continue
			# The bitmap bit represents the full source pixel cell [x,x+1] x [y,y+1].
			# Sample its center so an adjacent opaque cell boundary is never mistaken
			# for collision coverage of this pixel.
			var source_sample := Vector2(float(x) + 0.5, float(y) + 0.5)
			var local := (source_sample - origin + sprite.offset) * sprite.scale
			var covered := false
			for shape_entry in convex_shapes:
				var shape := shape_entry["shape"] as ConvexPolygonShape2D
				var owner_transform := shape_entry["transform"] as Transform2D
				var point := owner_transform.affine_inverse() * local
				if Geometry2D.is_point_in_polygon(point, shape.points):
					covered = true
					break

			if alpha <= 0.02 and covered:
				var mismatch_count := int(result["transparent_covered"])
				if mismatch_count < 5:
					print("[QA] ALPHA_FALSE_POSITIVE body=%s pixel=(%d,%d) alpha=%.4f local=%s" % [
						body.name,
						x,
						y,
						alpha,
						str(local),
					])
				result["transparent_covered"] = mismatch_count + 1
			elif alpha >= 0.15 and not covered:
				var mismatch_count := int(result["visible_uncovered"])
				if mismatch_count < 5:
					print("[QA] ALPHA_FALSE_NEGATIVE body=%s pixel=(%d,%d) alpha=%.4f local=%s" % [
						body.name,
						x,
						y,
						alpha,
						str(local),
					])
				result["visible_uncovered"] = mismatch_count + 1
	return result

func _physics_shape_count(body: CollisionObject2D) -> int:
	var count := 0
	for owner_id in body.get_shape_owners():
		count += body.shape_owner_get_shape_count(owner_id)
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[QA] %s" % message)
