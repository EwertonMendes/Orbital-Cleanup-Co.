extends Node
class_name AppRoot

const DEFAULT_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"
const FLIGHT_SCREEN_PATH := "res://src/ui/screens/flight/flight_screen.tscn"
const DEBRIEF_SCREEN_PATH := "res://src/ui/screens/debrief/contract_debrief_screen.tscn"
const SECTOR_PREVIEW_SCREEN_PATH := "res://src/debug/sector_preview/sector_preview.tscn"

@onready var build_info: BuildInfo = %BuildInfo
@onready var platform_service: PlatformService = %PlatformService
@onready var ad_service: AdService = %AdService
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
	ad_service.initialize(platform_service, audio_service)
	scene_router.configure(screen_host)

	var startup := _resolve_startup_route()
	var screen_path := String(startup["screen_path"])
	var screen := load(screen_path) as PackedScene
	assert(screen != null, "Startup screen must be loadable: %s" % screen_path)
	scene_router.show_screen(screen, startup["context"] as Dictionary)

	print("[OCC] READY")

func _resolve_startup_route() -> Dictionary:
	var context := _service_context()
	if not platform_service.is_debug_provider():
		return {"screen_path": DEFAULT_SCREEN_PATH, "context": context}

	var preview := platform_service.get_query_parameter("preview").to_lower()
	var debrief := platform_service.get_query_parameter("debrief").to_lower()
	var requested_sector := platform_service.get_query_parameter("sector")
	var endless_text := platform_service.get_query_parameter("endless")
	var seed_text := platform_service.get_query_parameter("seed")

	if not debrief.is_empty():
		var promoted := debrief in ["1", "true", "yes", "promotion", "promoted"]
		var perfect := debrief in ["1", "true", "yes", "promotion", "promoted", "perfect"]
		context["debrief_result"] = {
			"completed": true,
			"sector_id": "earth_training_02",
			"contract_id": "recovery_run",
			"contract_kind": "recovery",
			"cleanup_percent": 100.0 if perfect else 82.0,
			"perfect_cleanup": perfect,
			"recovered_count": 9,
			"base_pay": 270,
			"salvage_credits": 390,
			"perfect_bonus": 145 if perfect else 0,
			"credits_awarded": 805 if perfect else 660,
			"xp_awarded": 165 if perfect else 130,
			"new_discoveries": ["navigation_core", "explorer_core"],
		}
		context["debrief_transition"] = {
			"credits_before": 860,
			"credits_after": 1665 if perfect else 1520,
			"xp_before": 330 if promoted else 520,
			"xp_after": 495 if promoted else 650,
			"rank_before_id": "trainee" if promoted else "junior_cleaner",
			"rank_after_id": "junior_cleaner",
			"rank_before_key": "RANK_TRAINEE" if promoted else "RANK_JUNIOR_CLEANER",
			"rank_after_key": "RANK_JUNIOR_CLEANER",
			"rank_progress_before": {
				"current_xp": 330 if promoted else 520,
				"current_min_xp": 0 if promoted else 400,
				"next_min_xp": 400 if promoted else 1100,
				"is_max_rank": false,
			},
			"rank_progress_after": {
				"current_xp": 495 if promoted else 650,
				"current_min_xp": 400,
				"next_min_xp": 1100,
				"is_max_rank": false,
			},
			"promoted": promoted,
			"unlocks": [
				{"type": "cosmetic", "category": "paint", "id": "safety_amber", "display_name_key": "COSMETIC_PAINT_SAFETY_AMBER", "unlock_rank": "junior_cleaner"},
				{"type": "cosmetic", "category": "trail", "id": "amber_comet", "display_name_key": "COSMETIC_TRAIL_AMBER_COMET", "unlock_rank": "junior_cleaner"},
				{"type": "cosmetic", "category": "beam", "id": "amber_precision", "display_name_key": "COSMETIC_BEAM_AMBER_PRECISION", "unlock_rank": "junior_cleaner"},
			] if promoted else [],
		}
		context["debrief_mission"] = {
			"sector_display_name_key": "SECTOR_EARTH_TRAINING_02",
			"biome_display_name_key": "BIOME_EARTH_ORBIT",
		}
		context["debrief_return_screen_path"] = DEFAULT_SCREEN_PATH
		print("[QA] DEEP_LINK debrief=%s" % debrief)
		return {"screen_path": DEBRIEF_SCREEN_PATH, "context": context}

	if preview in ["1", "true", "yes"]:
		context["debug_sector_id"] = requested_sector
		if endless_text.is_valid_int():
			context["debug_endless_number"] = maxi(1, int(endless_text))
		if seed_text.is_valid_int():
			context["debug_seed"] = int(seed_text)
		return {"screen_path": SECTOR_PREVIEW_SCREEN_PATH, "context": context}

	var registry := ContentRegistry.new()
	if not requested_sector.is_empty():
		if registry.has_sector(requested_sector):
			context["sector_id"] = requested_sector
			print("[QA] DEEP_LINK sector=%s" % requested_sector)
			return {"screen_path": FLIGHT_SCREEN_PATH, "context": context}
		push_warning("Unknown ?sector= deep link: %s" % requested_sector)

	if endless_text.is_valid_int():
		var contract_number := maxi(1, int(endless_text))
		var endless := EndlessContractGenerator.new()
		endless.configure(registry)
		var sector_definition := endless.create_sector_definition(
			contract_number,
			int(seed_text) if seed_text.is_valid_int() else -1
		)
		context["sector_id"] = String(sector_definition["id"])
		context["sector_definition"] = sector_definition
		context["endless_number"] = contract_number
		print("[QA] DEEP_LINK endless=%d seed=%d" % [contract_number, int(sector_definition["seed"])])
		return {"screen_path": FLIGHT_SCREEN_PATH, "context": context}

	return {"screen_path": DEFAULT_SCREEN_PATH, "context": context}

func _service_context() -> Dictionary:
	return {
		"build_info": build_info,
		"platform": platform_service,
		"ads": ad_service,
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
	assert(ad_service != null, "AdService is required.")
	assert(settings_service != null, "SettingsService is required.")
	assert(save_service != null, "SaveService is required.")
	assert(audio_service != null, "AudioService is required.")
	assert(input_service != null, "InputService is required.")
	assert(scene_router != null, "SceneRouter is required.")
	assert(progression_service != null, "ProgressionService is required.")
	assert(screen_host != null, "ScreenHost is required.")
