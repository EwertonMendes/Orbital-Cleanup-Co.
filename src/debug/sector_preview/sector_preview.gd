extends Control

const HQ_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"
const FLIGHT_SCREEN_PATH := "res://src/ui/screens/flight/flight_screen.tscn"
const PREVIEW_SCREEN_PATH := "res://src/debug/sector_preview/sector_preview.tscn"

@onready var sector_picker: OptionButton = %SectorPicker
@onready var contract_number: SpinBox = %ContractNumber
@onready var seed_override: SpinBox = %SeedOverride
@onready var preview_canvas: SectorPreviewCanvas = %PreviewCanvas
@onready var summary: Label = %Summary
@onready var mode_label: Label = %ModeLabel
@onready var load_authored: Button = %LoadAuthored
@onready var generate_endless: Button = %GenerateEndless
@onready var previous_endless: Button = %PreviousEndless
@onready var next_endless: Button = %NextEndless
@onready var deploy_preview: Button = %DeployPreview
@onready var return_to_hq: Button = %ReturnToHq

var _context: Dictionary = {}
var _router: SceneRouter
var _registry := ContentRegistry.new()
var _scaler := DifficultyScaler.new()
var _generator := SectorGenerator.new()
var _endless := EndlessContractGenerator.new()
var _plan: Dictionary = {}
var _generated_definition: Dictionary = {}
var _mode := "authored"

func configure(context: Dictionary) -> void:
	_context = context
	_router = context.get("router") as SceneRouter
	assert(_router != null, "SectorPreview requires SceneRouter.")

func _ready() -> void:
	_scaler.configure(_registry)
	_generator.configure(_registry, _scaler)
	_endless.configure(_registry)
	_populate_authored_sectors()

	load_authored.pressed.connect(_load_authored_selection)
	generate_endless.pressed.connect(_generate_endless_selection)
	previous_endless.pressed.connect(_step_endless.bind(-1))
	next_endless.pressed.connect(_step_endless.bind(1))
	deploy_preview.pressed.connect(_deploy)
	return_to_hq.pressed.connect(_return_hq)

	contract_number.min_value = 1
	contract_number.max_value = 1000000
	contract_number.step = 1
	contract_number.value = maxi(1, int(_context.get("debug_endless_number", 1)))
	seed_override.min_value = -1
	seed_override.max_value = 2147483647
	seed_override.step = 1
	seed_override.value = int(_context.get("debug_seed", -1))

	var requested_sector := String(_context.get("debug_sector_id", ""))
	if not requested_sector.is_empty() and _registry.has_sector(requested_sector):
		_select_picker_id(requested_sector)
		_load_authored_selection()
	elif _context.has("debug_endless_number") or _context.has("debug_seed"):
		_generate_endless_selection()
	else:
		_load_authored_selection()

func _populate_authored_sectors() -> void:
	sector_picker.clear()
	for sector_id in _registry.list_sector_ids():
		var sector := _registry.get_sector(sector_id)
		sector_picker.add_item(tr(String(sector["display_name_key"])))
		sector_picker.set_item_metadata(sector_picker.item_count - 1, sector_id)

func _select_picker_id(sector_id: String) -> void:
	for index in range(sector_picker.item_count):
		if String(sector_picker.get_item_metadata(index)) == sector_id:
			sector_picker.select(index)
			return

func _load_authored_selection() -> void:
	if sector_picker.item_count == 0:
		return
	var sector_id := String(sector_picker.get_item_metadata(sector_picker.selected))
	_generated_definition = {}
	_mode = "authored"
	_plan = _generator.generate(sector_id)
	_refresh_preview()

func _generate_endless_selection() -> void:
	var number := maxi(1, int(contract_number.value))
	var requested_seed := int(seed_override.value)
	_generated_definition = _endless.create_sector_definition(number, requested_seed)
	_mode = "endless"
	_plan = _generator.generate_definition(_generated_definition)
	_refresh_preview()

func _step_endless(delta: int) -> void:
	contract_number.value = maxi(1, int(contract_number.value) + delta)
	_generate_endless_selection()

func _refresh_preview() -> void:
	preview_canvas.set_plan(_plan)
	var sector := _plan["sector"] as Dictionary
	var biome := _plan["biome"] as Dictionary
	var contract_ref := sector["contract"] as Dictionary
	var modifier_names := PackedStringArray()
	for modifier_id in sector.get("modifiers", []) as Array:
		modifier_names.append(String(modifier_id))
	var landmark_names := PackedStringArray()
	for landmark_id in sector.get("landmarks", []) as Array:
		landmark_names.append(String(landmark_id))

	mode_label.text = "%s · %s" % [_mode.to_upper(), String(sector["id"])]
	summary.text = "Biome: %s   Difficulty: %d   Seed: %d\nTarget: %d%%   Salvage: %d   Obstacles: %d\nLandmarks: %s\nModifiers: %s\nSignature: %s" % [
		tr(String(biome["display_name_key"])),
		int(sector["difficulty"]),
		int(sector["seed"]),
		int(contract_ref["target_percent"]),
		(_plan["salvage_spawns"] as Array).size(),
		(_plan["obstacle_spawns"] as Array).size(),
		", ".join(landmark_names) if not landmark_names.is_empty() else "none",
		", ".join(modifier_names) if not modifier_names.is_empty() else "none",
		String(_plan["generation_signature"]),
	]
	print("[SectorPreview] READY mode=%s id=%s seed=%d signature=%s" % [
		_mode,
		String(sector["id"]),
		int(sector["seed"]),
		String(_plan["generation_signature"]),
	])

func _deploy() -> void:
	var scene := load(FLIGHT_SCREEN_PATH) as PackedScene
	assert(scene != null, "Sector Preview flight screen must load.")
	var flight_context := _context.duplicate(true)
	flight_context["return_screen_path"] = PREVIEW_SCREEN_PATH
	if _mode == "endless":
		flight_context["sector_definition"] = _generated_definition.duplicate(true)
		flight_context["sector_id"] = String(_generated_definition["id"])
		flight_context["endless_number"] = int(contract_number.value)
		flight_context["debug_endless_number"] = int(contract_number.value)
		flight_context["debug_seed"] = int(_generated_definition["seed"])
	else:
		var sector := _plan["sector"] as Dictionary
		flight_context["sector_id"] = String(sector["id"])
		flight_context["debug_sector_id"] = String(sector["id"])
	_router.show_screen(scene, flight_context)

func _return_hq() -> void:
	var scene := load(HQ_SCREEN_PATH) as PackedScene
	assert(scene != null, "Headquarters screen must load.")
	var context := _context.duplicate(true)
	context.erase("debug_sector_id")
	context.erase("debug_endless_number")
	context.erase("debug_seed")
	_router.show_screen(scene, context)
