extends SceneTree

var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_app_root()
	_validate_operations_screen()
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
	_expect(screen.find_child("Body", true, false) is BoxContainer, "Operations screen needs responsive Body.")
	_expect(screen.find_child("PrimaryAction", true, false) is Button, "Operations screen needs PrimaryAction.")
	_expect(screen.find_child("ShipArt", true, false) is TextureRect, "Operations screen needs ship art.")
	screen.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("[QA] %s" % message)
