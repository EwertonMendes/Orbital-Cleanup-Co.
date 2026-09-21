extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_app_root()
	_validate_operations_screen()
	_validate_hq_components()
	_validate_ship_steering()
	_validate_world_visual_language()
	_validate_content_runtime()
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
	root.free()

func _validate_operations_screen() -> void:
	var packed := load("res://src/ui/screens/operations/operations_screen.tscn") as PackedScene
	_expect(packed != null, "Headquarters screen must load.")
	if packed == null:
		return
	var screen := packed.instantiate()
	_expect(screen is Control, "Headquarters screen must inherit Control.")
	_expect(screen.find_child("PrimaryAction", true, false) is Button, "Headquarters requires deployment action.")
	_expect(screen.find_child("ShipArt", true, false) is TextureRect, "Headquarters requires contract ship preview.")
	_expect(screen.find_child("UpgradeGrid", true, false) is GridContainer, "Headquarters requires upgrade grid.")
	_expect(screen.find_child("CareerList", true, false) is VBoxContainer, "Headquarters requires career ladder.")
	_expect(screen.find_child("ContentScroll", true, false) is ScrollContainer, "Headquarters content must degrade gracefully on compact screens.")
	_expect(screen.find_child("PreviousContract", true, false) is Button, "Headquarters requires previous authored contract action.")
	_expect(screen.find_child("NextContract", true, false) is Button, "Headquarters requires next authored contract action.")
	_expect(screen.find_child("ContractPosition", true, false) is Label, "Headquarters requires authored contract position feedback.")

	for tab_name in ["ContractsTab", "UpgradesTab", "CareerTab", "ShipTab", "DiscoveryTab"]:
		_expect(screen.find_child(tab_name, true, false) is Button, "Headquarters requires tab: %s" % tab_name)

	for panel_name in ["ContractsPanel", "UpgradesPanel", "CareerPanel", "ShipPanel", "DiscoveryPanel"]:
		_expect(screen.find_child(panel_name, true, false) is VBoxContainer, "Headquarters requires panel: %s" % panel_name)

	var unique_refs := [
		"SafeArea", "Header", "TabGrid", "ContentScroll", "ContentShell",
		"ContractsPanel", "UpgradesPanel", "CareerPanel", "ShipPanel", "DiscoveryPanel",
		"ContractHero", "ShipBody", "PrimaryAction", "Footer", "UpgradeGrid", "CareerList",
		"CreditsLabel", "RankLabel", "XpLabel", "CareerRankValue", "CareerXpLabel", "CareerXpBar",
		"ContractState", "ContractSelector", "ContractPosition", "PreviousContract", "EndlessContract", "NextContract", "ContractTitle", "ContractDescription", "ContractTarget", "ContractRisk",
		"ContractPayout", "ContractRequirement", "NextUnlockPanel", "NextUnlockTitle",
		"NextUnlockLabel", "NextUnlockProgress", "NextUnlockProgressLabel",
		"LastResult", "ShipStats", "DiscoveryCount", "CompletedContracts",
		"EnglishButton", "PortugueseButton", "SpanishButton", "ContractsTab", "UpgradesTab",
		"CareerTab", "ShipTab", "DiscoveryTab", "CompanyLabel", "DeskLabel", "LanguageLabel",
		"ContractsTitle", "ContractsSubtitle", "ContractShipName", "ContractShipStatus",
		"UpgradesTitle", "UpgradesSubtitle", "CareerTitle", "CareerSubtitle", "ShipTitle",
		"ShipSubtitle", "ShipName", "ShipPreview", "ShipArt", "LoadoutTitle", "HullValue", "PaintValue", "TrailValue",
		"BeamStyleValue", "WorkshopStatus", "HullHeading", "PaintHeading", "TrailHeading", "BeamHeading",
		"HullOptions", "PaintOptions", "TrailOptions", "BeamOptions", "DiscoveryTitle", "DiscoverySubtitle",
		"DiscoveryEmptyTitle", "DiscoveryEmptyBody",
	]
	for node_name in unique_refs:
		_expect(
			screen.get_node_or_null(NodePath("%" + node_name)) != null,
			"Headquarters script reference must be unique: %%%s" % node_name
		)
	var operations_source := FileAccess.get_file_as_string("res://src/ui/screens/operations/operations_screen.gd")
	_expect("_active_contract_access()" in operations_source, "Headquarters deploy must consult centralized progression access.")
	_expect("primary_action.disabled = not unlocked" in operations_source, "Locked contracts must disable deploy action.")
	_expect("_refresh_next_unlock()" in operations_source, "Headquarters must surface the next career unlock.")
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
		salvage.free()

	var obstacle_packed := load("res://src/game/sector/sector_obstacle.tscn") as PackedScene
	_expect(obstacle_packed != null, "SectorObstacle scene must load.")
	if obstacle_packed != null:
		var obstacle := obstacle_packed.instantiate()
		_expect(obstacle.find_child("Marker", true, false) is SectorObstacleMarker, "Collision hazards require a semantic hazard marker.")
		obstacle.free()

	var landmark_packed := load("res://src/game/sector/sector_landmark.tscn") as PackedScene
	_expect(landmark_packed != null, "SectorLandmark scene must load.")
	if landmark_packed != null:
		var landmark := landmark_packed.instantiate()
		_expect(landmark.find_child("Marker", true, false) is SectorLandmarkMarker, "Landmarks require ambient visual treatment.")
		landmark.free()

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
	_expect(sector_ids.size() >= 13, "Initial content pack must expose at least 13 authored sectors.")
	_expect(String(sector_ids[0]) == "earth_training_01", "Career order must begin with Earth Training 01.")
	_expect(String(sector_ids[1]) == "earth_training_02", "Career order must keep Earth Training 02 second.")
	_expect(String(sector_ids[sector_ids.size() - 1]) == "blue_nebula_03", "Career order must end with Blue Nebula 03.")
	for required_sector in ["earth_orbit_03", "lunar_belt_01", "mars_freight_01", "blue_nebula_01"]:
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
	cleanup.record_salvage(target_salvage)
	_expect(cleanup.is_target_reached(), "Cleanup contract must complete at configured percentage.")
	_expect(not cleanup.is_perfect_cleanup(), "Cleanup target completion must not imply Perfect Cleanup.")
	var standard_result := cleanup.build_result()
	_expect(int(standard_result["credits_awarded"]) == 290, "Standard payout must combine base pay and recovered salvage.")
	_expect(int(standard_result["xp_awarded"]) == 120, "Standard completion must grant configured Company XP.")
	cleanup.record_salvage(final_salvage)
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
	recovery.record_salvage(target_salvage)
	_expect(not recovery.is_target_reached(), "Recovery contract must count recovered objects.")
	recovery.record_salvage(final_salvage)
	_expect(recovery.is_target_reached(), "Recovery contract must complete at target_count.")

	var valuable := ContractSession.new()
	valuable.configure({
		"sector_id": "qa_value",
		"contract": registry.get_contract("valuable_recovery"),
		"contract_ref": {"type": "valuable_recovery", "target_value": 75},
		"total_cleanliness": 100.0,
		"reward_multiplier": 1.0,
	})
	valuable.record_salvage(target_salvage)
	_expect(not valuable.is_target_reached(), "Valuable Recovery must track recovered credit value.")
	valuable.record_salvage(final_salvage)
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
	priority.record_salvage(target_salvage)
	_expect(not priority.is_target_reached(), "Priority contract must ignore non-priority salvage.")
	var navigation := registry.get_salvage_definition("navigation_core")
	priority.record_salvage(navigation)
	_expect(priority.is_target_reached(), "Priority contract must complete when designated salvage is recovered.")

	var full := ContractSession.new()
	full.configure({
		"sector_id": "qa_full",
		"contract": registry.get_contract("full_cleanup"),
		"contract_ref": {"type": "full_cleanup", "target_percent": 100.0},
		"total_cleanliness": 10.0,
		"reward_multiplier": 1.0,
	})
	full.record_salvage(target_salvage)
	_expect(not full.is_target_reached(), "Full Cleanup cannot complete below 100%.")
	full.record_salvage(final_salvage)
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
	var default_cosmetics := progression.get_equipped_cosmetic_ids()
	_expect(String(default_cosmetics["hull"]) == "pioneer_01", "Default hull must come from cosmetic content.")
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
		_expect(sprite.material is ShaderMaterial, "Gameplay ship requires paint ShaderMaterial.")
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

	var flight_source := FileAccess.get_file_as_string("res://src/ui/screens/flight/flight_screen.gd")
	_expect(
		"ship.position = deployment_position" in flight_source
		and "depot.position = deployment_position" in flight_source,
		"Flight deployment must place ship and cargo depot at the same sector position."
	)

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
	_expect(screen.find_child("Scroll", true, false) is ScrollContainer, "Debrief must remain scrollable on compact screens.")
	_expect(screen.find_child("ContentGrid", true, false) is GridContainer, "Debrief requires responsive mission summary.")
	_expect(screen.find_child("RewardGrid", true, false) is GridContainer, "Debrief requires reward breakdown.")
	_expect(screen.find_child("XpProgress", true, false) is ProgressBar, "Debrief requires animated career XP progress.")
	_expect(screen.find_child("PromotionPanel", true, false) is PanelContainer, "Debrief requires promotion reveal.")
	_expect(screen.find_child("UnlocksList", true, false) is VBoxContainer, "Debrief requires unlock reveal.")
	_expect(screen.find_child("DiscoveriesList", true, false) is VBoxContainer, "Debrief requires discovery reveal.")
	_expect(screen.find_child("ContinueButton", true, false) is Button, "Debrief requires explicit Continue to Headquarters action.")
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
		_expect(flight.find_child("FlightFeedback", true, false) is FlightFeedback, "Flight requires centralized gameplay feedback.")
		var engine_particles := flight.find_child("EngineParticles", true, false)
		_expect(engine_particles is CPUParticles2D, "Ship polish requires engine particles.")
		flight.free()

	var burst_packed := load("res://src/game/visual/world_burst.tscn") as PackedScene
	_expect(burst_packed != null, "Reusable WorldBurst effect must load.")

	var post_source := FileAccess.get_file_as_string("res://src/game/visual/world_post_process.gdshader")
	_expect("hint_screen_texture" in post_source, "Godot 4 post-process must read screen texture through hint_screen_texture.")

	var scanner := ProceduralSfx.scanner_ping()
	var discovery := ProceduralSfx.discovery()
	_expect(scanner != null and scanner.data.size() > 256, "Scanner feedback SFX must be generated.")
	_expect(discovery != null and discovery.data.size() > scanner.data.size(), "Discovery SFX must be a richer, longer cue.")

func _validate_render_quality() -> void:
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "Physics interpolation must remain enabled for smooth Web movement.")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[QA] %s" % message)
