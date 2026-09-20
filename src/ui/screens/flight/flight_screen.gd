extends Control

const OPERATIONS_SCREEN_PATH := "res://src/ui/screens/operations/operations_screen.tscn"

@onready var safe_area: MarginContainer = %SafeArea
@onready var return_button: Button = %ReturnButton
@onready var hint_panel: Control = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var player_ship: PlayerShip = %PlayerShip

var _context: Dictionary = {}
var _router: SceneRouter
var _input_service: InputService
var _platform: PlatformService
var _gameplay_active := false
var _hint_tween: Tween

func configure(context: Dictionary) -> void:
	_context = context
	_router = context.get("router") as SceneRouter
	_input_service = context.get("input") as InputService
	_platform = context.get("platform") as PlatformService
	assert(_input_service != null, "FlightScreen requires InputService.")
	player_ship = get_node("World/PlayerShip") as PlayerShip
	assert(player_ship != null, "FlightScreen requires PlayerShip.")
	player_ship.configure(_input_service, TrainingSpace.PLAY_BOUNDS)

func _ready() -> void:
	_validate_contracts()
	resized.connect(_apply_responsive_layout)
	return_button.pressed.connect(_return_to_operations)
	player_ship.movement_started.connect(_schedule_hint_fade)
	_input_service.input_mode_changed.connect(_on_input_mode_changed)
	_apply_responsive_layout()
	_refresh_copy()

	if _platform != null:
		_platform.gameplay_started()
		_platform.track_event("training_flight_started")
	_gameplay_active = true
	print("[Flight] READY")

func _exit_tree() -> void:
	if _gameplay_active and _platform != null:
		_platform.gameplay_stopped()
	_gameplay_active = false

func _validate_contracts() -> void:
	assert(safe_area != null, "FlightScreen requires SafeArea.")
	assert(return_button != null, "FlightScreen requires ReturnButton.")
	assert(hint_panel != null and hint_label != null, "FlightScreen requires steering hint.")
	assert(player_ship != null, "FlightScreen requires PlayerShip.")
	assert(TrainingSpace.PLAY_BOUNDS.size.x > 0.0 and TrainingSpace.PLAY_BOUNDS.size.y > 0.0, "Training play bounds must be valid.")

func _apply_responsive_layout() -> void:
	var portrait := ResponsiveCanvas.apply_reference(get_tree().root)
	var horizontal_margin := 18 if portrait else 28
	var vertical_margin := 16 if portrait else 22
	safe_area.add_theme_constant_override("margin_left", horizontal_margin)
	safe_area.add_theme_constant_override("margin_right", horizontal_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)

func _return_to_operations() -> void:
	var scene := load(OPERATIONS_SCREEN_PATH) as PackedScene
	assert(scene != null, "Operations screen must be loadable.")
	_router.show_screen(scene, _context)

func _on_input_mode_changed(_mode: InputService.InputMode) -> void:
	_refresh_copy()
	_show_hint_temporarily()

func _refresh_copy() -> void:
	if not is_node_ready():
		return
	%FlightEyebrow.text = tr("FLIGHT_EYEBROW")
	%FlightTitle.text = tr("FLIGHT_TITLE")
	return_button.text = tr("FLIGHT_RETURN")
	hint_label.text = tr("FLIGHT_HINT_TOUCH") if _input_service.prefers_touch() else tr("FLIGHT_HINT_POINTER")

func _show_hint_temporarily() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	hint_panel.modulate.a = 1.0
	_schedule_hint_fade()

func _schedule_hint_fade() -> void:
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(2.3)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.12, 0.65)
