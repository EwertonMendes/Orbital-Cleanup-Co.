extends Node
class_name AppRoot

const DEFAULT_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"

@onready var build_info: BuildInfo = %BuildInfo
@onready var platform_service: PlatformService = %PlatformService
@onready var settings_service: SettingsService = %SettingsService
@onready var save_service: SaveService = %SaveService
@onready var audio_service: AudioService = %AudioService
@onready var input_service: InputService = %InputService
@onready var scene_router: SceneRouter = %SceneRouter
@onready var progression_service: ProgressionService = %ProgressionService
@onready var screen_host: Control = %ScreenHost

func _ready() -> void:
	print("[OCC] BOOT")
	_validate_contracts()

	build_info.initialize()
	settings_service.initialize()
	audio_service.initialize(settings_service)
	save_service.initialize()
	progression_service.initialize(save_service)
	input_service.initialize()
	platform_service.initialize()
	scene_router.configure(screen_host)

	var screen := load(DEFAULT_SCREEN_PATH) as PackedScene
	assert(screen != null, "Default operations screen must be loadable.")
	scene_router.show_screen(screen, _service_context())

	print("[OCC] READY")

func _service_context() -> Dictionary:
	return {
		"build_info": build_info,
		"platform": platform_service,
		"settings": settings_service,
		"save": save_service,
		"audio": audio_service,
		"input": input_service,
		"router": scene_router,
		"progression": progression_service,
	}

func _validate_contracts() -> void:
	assert(build_info != null, "BuildInfo service is required.")
	assert(platform_service != null, "PlatformService is required.")
	assert(settings_service != null, "SettingsService is required.")
	assert(save_service != null, "SaveService is required.")
	assert(audio_service != null, "AudioService is required.")
	assert(input_service != null, "InputService is required.")
	assert(scene_router != null, "SceneRouter is required.")
	assert(progression_service != null, "ProgressionService is required.")
	assert(screen_host != null, "ScreenHost is required.")
