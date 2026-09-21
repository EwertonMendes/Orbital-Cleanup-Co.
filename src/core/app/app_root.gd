extends Node
class_name AppRoot

const OPERATIONS_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"
const FLIGHT_SCREEN_PATH := "res://src/ui/screens/flight/flight_screen.tscn"
const DEFAULT_SCREEN_PATH := FLIGHT_SCREEN_PATH
const HOME_SECTOR_ID := "earth_training_01"
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
@onready var travel_cover: ColorRect = %TravelCover
@onready var loading_title: Label = %LoadingTitle
@onready var loading_status: Label = %LoadingStatus

func _ready() -> void:
	print("[OCC] BOOT")
	_validate_contracts()
	build_info.initialize()
	settings_service.initialize()
	_refresh_loading_copy()
	settings_service.locale_changed.connect(_on_loading_locale_changed)
	OccCursorSkin.apply()
	audio_service.initialize(settings_service)
	save_service.initialize()
	progression_service.initialize(save_service)
	input_service.initialize()
	platform_service.initialize()
	ad_service.initialize(platform_service, audio_service)
	scene_router.configure(screen_host, travel_cover)

	var startup := _resolve_startup_route()
	var screen_path := String(startup["screen_path"])
	var screen := load(screen_path) as PackedScene
	assert(screen != null, "Startup screen must be loadable: %s" % screen_path)
	scene_router.show_screen(screen, startup["context"] as Dictionary)

	print("[OCC] READY")

func _refresh_loading_copy() -> void:
	loading_title.text = tr("LOADING_TITLE")
	loading_status.text = tr("LOADING_STATUS")

func _on_loading_locale_changed(_locale: String) -> void:
	_refresh_loading_copy()

func _resolve_startup_route() -> Dictionary:
	var context := _service_context()
	context["sector_id"] = HOME_SECTOR_ID
	context["free_roam"] = true
	if not platform_service.is_debug_provider():
		return {"screen_path": DEFAULT_SCREEN_PATH, "context": context}

	var preview := platform_service.get_query_parameter("preview").to_lower()
	var debrief := platform_service.get_query_parameter("debrief").to_lower()
	var hq_sector := platform_service.get_query_parameter("hq_sector")
	var requested_sector := platform_service.get_query_parameter("sector")
	var landmark_focus := platform_service.get_query_parameter("landmark_focus")
	var depot_nav_preview := platform_service.get_query_parameter("depot_nav").to_lower()
	var operations_preview := platform_service.get_query_parameter("operations").to_lower()
	var arrival_preview := platform_service.get_query_parameter("arrival_warp").to_lower()
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
			"xp_before": 250 if promoted else 420,
			"xp_after": 415 if promoted else 540,
			"rank_before_id": "trainee" if promoted else "junior_cleaner",
			"rank_after_id": "junior_cleaner",
			"rank_before_key": "RANK_TRAINEE" if promoted else "RANK_JUNIOR_CLEANER",
			"rank_after_key": "RANK_JUNIOR_CLEANER",
			"rank_progress_before": {
				"current_xp": 250 if promoted else 420,
				"current_min_xp": 0 if promoted else 400,
				"next_min_xp": 300 if promoted else 650,
				"is_max_rank": false,
			},
			"rank_progress_after": {
				"current_xp": 415 if promoted else 540,
				"current_min_xp": 300,
				"next_min_xp": 650,
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
		context["free_roam"] = true
		context["arrival_warp"] = true
		context["travel_direction"] = -1
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
	if not hq_sector.is_empty():
		if registry.has_sector(hq_sector):
			context["debug_hq_sector_id"] = hq_sector
			context.erase("free_roam")
			context.erase("sector_id")
			print("[QA] DEEP_LINK hq_sector=%s" % hq_sector)
			return {"screen_path": OPERATIONS_SCREEN_PATH, "context": context}
		push_warning("Unknown ?hq_sector= deep link: %s" % hq_sector)

	if not requested_sector.is_empty():
		if registry.has_sector(requested_sector):
			context.erase("free_roam")
			context["sector_id"] = requested_sector
			if not landmark_focus.is_empty():
				context["debug_landmark_focus"] = landmark_focus
			if depot_nav_preview in ["1", "true", "yes"]:
				context["debug_ship_offset"] = Vector2(1850.0, 980.0)
			if arrival_preview in ["1", "true", "yes"]:
				context["arrival_warp"] = true
			print("[QA] DEEP_LINK sector=%s" % requested_sector)
			return {"screen_path": FLIGHT_SCREEN_PATH, "context": context}
		push_warning("Unknown ?sector= deep link: %s" % requested_sector)

	if endless_text.is_valid_int():
		context.erase("free_roam")
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

	if operations_preview in ["1", "true", "yes"]:
		context["open_operations"] = true
	print("[QA] FREE_FLIGHT sector=%s operations=%s" % [HOME_SECTOR_ID, str(context.get("open_operations", false))])
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
	assert(travel_cover != null, "Persistent TravelCover is required.")
	assert(loading_title != null and loading_status != null, "Travel loading cover requires styled loading copy.")
