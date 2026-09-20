extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_app_root()
	_validate_operations_screen()
	_validate_ship_steering()
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

func _validate_player_ship() -> void:
	var packed := load("res://src/game/ship/player_ship.tscn") as PackedScene
	_expect(packed != null, "PlayerShip scene must load.")
	if packed == null:
		return
	var ship := packed.instantiate()
	_expect(ship is PlayerShip, "PlayerShip root must use PlayerShip controller.")
	_expect(ship.get_node_or_null("CollisionShape2D") is CollisionShape2D, "PlayerShip requires collision.")
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
