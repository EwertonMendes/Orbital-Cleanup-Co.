extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_app_root()
	_validate_operations_screen()
	_validate_ship_steering()
	_validate_content_runtime()
	_validate_contract_session()
	_validate_progression_service()
	_validate_cargo_hold()
	_validate_player_ship()
	_validate_flight_screen()
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
	_expect(root.get_node_or_null("Services/SettingsService") is SettingsService, "AppRoot must own SettingsService.")
	_expect(root.get_node_or_null("Services/SaveService") is SaveService, "AppRoot must own SaveService.")
	_expect(root.get_node_or_null("Services/AudioService") is AudioService, "AppRoot must own AudioService.")
	_expect(root.get_node_or_null("Services/InputService") is InputService, "AppRoot must own InputService.")
	_expect(root.get_node_or_null("Services/SceneRouter") is SceneRouter, "AppRoot must own SceneRouter.")
	_expect(root.get_node_or_null("Services/ProgressionService") is ProgressionService, "AppRoot must own ProgressionService.")
	_expect(root.get_node_or_null("ScreenHost") is Control, "AppRoot must expose ScreenHost.")
	root.free()

func _validate_operations_screen() -> void:
	var packed := load("res://src/ui/screens/operations/operations_screen.tscn") as PackedScene
	_expect(packed != null, "Operations screen must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is Control, "Operations screen must inherit Control.")
	_expect(screen.find_child("PrimaryAction", true, false) is Button, "Operations screen needs deployment action.")
	_expect(screen.find_child("ShipArt", true, false) is TextureRect, "Operations screen requires ship preview.")
	_expect(screen.find_child("CreditsLabel", true, false) is Label, "Operations screen requires Credits feedback.")
	_expect(screen.find_child("TractorUpgrade", true, false) is Button, "Operations screen requires Tractor upgrade control.")
	_expect(screen.find_child("CollectionUpgrade", true, false) is Button, "Operations screen requires Collection Speed upgrade control.")
	_expect(screen.find_child("CargoUpgrade", true, false) is Button, "Operations screen requires Cargo upgrade control.")
	screen.free()

func _validate_ship_steering() -> void:
	var origin := Vector2(100, 100)
	_expect(ShipSteering.pointer_intent(origin, origin + Vector2(20, 0), 50, 250) == Vector2.ZERO, "Pointer steering must respect deadzone.")
	var far_intent := ShipSteering.pointer_intent(origin, origin + Vector2(400, 0), 50, 250)
	_expect(is_equal_approx(far_intent.length(), 1.0), "Far pointer must reach full steering intent.")
	var keyboard := Vector2.UP
	_expect(ShipSteering.combine_intent(keyboard, Vector2.RIGHT) == keyboard, "Keyboard input must override pointer steering while held.")

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

	var generator := SectorGenerator.new()
	generator.configure(registry, scaler)
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

func _validate_contract_session() -> void:
	var registry := ContentRegistry.new()
	var contract := registry.get_contract("standard_cleanup")
	var session := ContractSession.new()
	session.configure({
		"sector_id": "qa_sector",
		"contract": contract,
		"target_percent": 70.0,
		"total_cleanliness": 10.0,
		"reward_multiplier": 1.0,
	})

	var target_salvage := registry.get_salvage_definition("scrap_fragment").duplicate(true) as SalvageDefinition
	target_salvage.cleanliness_value = 7.0
	target_salvage.base_value = 50
	session.record_salvage(target_salvage)
	_expect(session.is_target_reached(), "ContractSession must complete at configured target.")
	_expect(not session.is_perfect_cleanup(), "Target completion must not imply Perfect Cleanup.")
	var standard_result := session.build_result()
	_expect(int(standard_result["credits_awarded"]) == 290, "Standard payout must combine base pay and recovered salvage.")
	_expect(int(standard_result["xp_awarded"]) == 120, "Standard completion must grant configured Company XP.")

	var final_salvage := registry.get_salvage_definition("service_scrap").duplicate(true) as SalvageDefinition
	final_salvage.cleanliness_value = 3.0
	final_salvage.base_value = 30
	session.record_salvage(final_salvage)
	_expect(session.is_perfect_cleanup(), "100% cleanliness must trigger Perfect Cleanup.")
	var perfect_result := session.build_result()
	_expect(int(perfect_result["perfect_bonus"]) == 160, "Perfect Cleanup must grant configured credit bonus.")
	_expect(int(perfect_result["xp_awarded"]) == 160, "Perfect Cleanup must grant configured XP bonus.")
	_expect(int(perfect_result["credits_awarded"]) == 480, "Perfect payout must include base, salvage and perfect bonus.")

func _validate_progression_service() -> void:
	var save := SaveService.new()
	save.delete_save()
	var progression := ProgressionService.new()
	progression.initialize(save)

	_expect(progression.get_credits() == 0, "New progression must start with zero Credits.")
	_expect(progression.get_rank_id() == "trainee", "New progression must start at Trainee.")
	var base_ship := progression.get_ship_modifiers()
	_expect(is_equal_approx(float(base_ship["scan_range"]), 320.0), "Base Tractor Beam range must come from progression data.")
	_expect(int(round(float(base_ship["cargo_capacity"]))) == 12, "Base cargo capacity must come from progression data.")

	progression.apply_contract_result({
		"completed": true,
		"sector_id": "qa_sector",
		"perfect_cleanup": false,
		"credits_awarded": 500,
		"xp_awarded": 450,
	})
	_expect(progression.get_credits() == 500, "Contract payout must persist Credits.")
	_expect(progression.get_rank_id() == "junior_cleaner", "Company XP must promote career rank.")

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
	_expect(cargo.store(heavy), "CargoHold must accept salvage that exactly fills remaining space.")
	_expect(cargo.used_units == 4, "CargoHold must reach configured capacity.")
	_expect(not cargo.can_accept(small), "CargoHold must reject salvage when full.")
	_expect(cargo.unload_all() == 4, "CargoHold unload must return unloaded units.")
	_expect(cargo.used_units == 0, "CargoHold unload must clear used units.")
	cargo.free()

func _validate_player_ship() -> void:
	var packed := load("res://src/game/ship/player_ship.tscn") as PackedScene
	_expect(packed != null, "PlayerShip scene must load.")
	if packed == null:
		return
	var ship := packed.instantiate()
	_expect(ship is PlayerShip, "PlayerShip root must use PlayerShip controller.")
	_expect(ship.get_node_or_null("CollisionShape2D") is CollisionShape2D, "PlayerShip requires collision.")
	_expect(ship.find_child("CargoHold", true, false) is CargoHold, "PlayerShip requires CargoHold.")
	_expect(ship.find_child("TractorBeam", true, false) is TractorBeam, "PlayerShip requires TractorBeam.")
	var sprite := ship.find_child("ShipSprite", true, false) as Sprite2D
	_expect(sprite != null, "PlayerShip requires ShipSprite.")
	if sprite != null:
		_expect(sprite.scale == Vector2.ONE, "Gameplay ship sprite must stay at native raster scale.")
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
		_expect(tuning.boundary_soft_margin > tuning.boundary_hard_padding, "Soft boundary margin must precede hard containment.")
	ship.free()

func _validate_flight_screen() -> void:
	var packed := load("res://src/ui/screens/flight/flight_screen.tscn") as PackedScene
	_expect(packed != null, "Flight screen must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is Control, "Flight screen must inherit Control.")
	_expect(screen.find_child("PlayerShip", true, false) is PlayerShip, "Flight screen requires PlayerShip.")
	_expect(screen.find_child("SectorRuntime", true, false) is SectorRuntime, "Flight screen requires generic SectorRuntime.")
	_expect(screen.find_child("AmbientSpace", true, false) is SectorBackdrop, "Flight screen requires data-configurable SectorBackdrop.")
	_expect(screen.find_child("UnloadDepot", true, false) is UnloadZone, "Flight screen requires cargo unload zone.")
	_expect(screen.find_child("ReturnButton", true, false) is Button, "Flight screen requires return action.")
	_expect(screen.find_child("TopBar", true, false) is BoxContainer, "Flight HUD requires responsive TopBar.")
	_expect(screen.find_child("CleanupStatus", true, false) is Label, "Flight HUD requires sector cleanliness status.")
	_expect(screen.find_child("CleanupProgress", true, false) is ProgressBar, "Flight HUD requires sector cleanliness progress.")

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

func _validate_render_quality() -> void:
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "Physics interpolation must remain enabled for smooth Web movement.")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[QA] %s" % message)
