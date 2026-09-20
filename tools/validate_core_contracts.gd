extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_app_root()
	_validate_operations_screen()
	_validate_ship_steering()
	_validate_salvage_definitions()
	_validate_cargo_hold()
	_validate_player_ship()
	_validate_flight_screen()
	_validate_training_bounds()
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
	screen.free()

func _validate_ship_steering() -> void:
	var origin := Vector2(100, 100)
	_expect(ShipSteering.pointer_intent(origin, origin + Vector2(20, 0), 50, 250) == Vector2.ZERO, "Pointer steering must respect deadzone.")
	var far_intent := ShipSteering.pointer_intent(origin, origin + Vector2(400, 0), 50, 250)
	_expect(is_equal_approx(far_intent.length(), 1.0), "Far pointer must reach full steering intent.")
	var keyboard := Vector2.UP
	_expect(ShipSteering.combine_intent(keyboard, Vector2.RIGHT) == keyboard, "Keyboard input must override pointer steering while held.")

func _validate_salvage_definitions() -> void:
	var paths := [
		"res://content/salvage/scrap_fragment.tres",
		"res://content/salvage/service_scrap.tres",
		"res://content/salvage/sensor_pod.tres",
		"res://content/salvage/satellite_panel.tres",
		"res://content/salvage/dense_composite.tres",
	]
	var ids: Dictionary = {}
	for path in paths:
		var definition := load(path) as SalvageDefinition
		_expect(definition != null, "Salvage definition must load: %s" % path)
		if definition == null:
			continue
		definition.validate()
		_expect(not ids.has(String(definition.id)), "Salvage ids must be unique.")
		ids[String(definition.id)] = true
		_expect(definition.sprite != null, "Salvage definition requires sprite.")
		_expect(definition.cargo_units > 0, "Salvage cargo units must be positive.")

func _validate_cargo_hold() -> void:
	var cargo := CargoHold.new()
	cargo.capacity = 4
	var small := load("res://content/salvage/scrap_fragment.tres") as SalvageDefinition
	var heavy := load("res://content/salvage/dense_composite.tres") as SalvageDefinition
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
	_expect(screen.find_child("ReturnButton", true, false) is Button, "Flight screen requires return action.")
	_expect(screen.find_child("TopBar", true, false) is BoxContainer, "Flight HUD requires responsive TopBar.")
	_expect(screen.find_child("UnloadDepot", true, false) is UnloadZone, "Training flight requires cargo unload zone.")
	var salvage_count := 0
	for node in screen.find_children("Salvage*", "Area2D", true, false):
		if node is SalvageObject:
			salvage_count += 1
	_expect(salvage_count >= 5, "Training flight requires multiple generic SalvageObject instances.")
	var obstacle_count := 0
	for node in screen.find_children("*Meteor", "StaticBody2D", true, false):
		obstacle_count += 1
	_expect(obstacle_count >= 3, "Training flight requires multiple bump obstacles.")
	screen.free()

func _validate_training_bounds() -> void:
	_expect(TrainingSpace.PLAY_BOUNDS.size.x >= 9000.0, "Training area should provide a substantially larger horizontal route.")
	_expect(TrainingSpace.PLAY_BOUNDS.size.y >= 5500.0, "Training area should provide a substantially larger vertical route.")

func _validate_render_quality() -> void:
	_expect(bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)), "Physics interpolation must remain enabled for smooth Web movement.")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[QA] %s" % message)
