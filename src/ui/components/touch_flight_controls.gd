extends Control
class_name TouchFlightControls

const STEERING_DEADZONE := 12.0
const STEERING_FULL_THRUST_DISTANCE := 88.0
const RING_RADIUS := 44.0
const KNOB_RADIUS := 18.0

@onready var steering_area: Control = %SteeringArea
@onready var boost_button: Button = %BoostButton
@onready var boost_status: Label = %BoostStatus
@onready var recharge_bar: ProgressBar = %RechargeBar

var _input_service: InputService
var _ship: PlayerShip
var _controls_enabled := true
var _steering_touch_index := -1
var _touch_origin := Vector2.ZERO
var _touch_position := Vector2.ZERO

func configure(input_service: InputService, ship: PlayerShip) -> void:
	assert(input_service != null, "TouchFlightControls requires InputService.")
	assert(ship != null, "TouchFlightControls requires PlayerShip.")
	_input_service = input_service
	_ship = ship

func _ready() -> void:
	assert(_input_service != null and _ship != null, "TouchFlightControls must be configured before entering the tree.")
	steering_area.gui_input.connect(_on_steering_input)
	boost_button.pressed.connect(_on_boost_pressed)
	_input_service.input_mode_changed.connect(_on_input_mode_changed)
	boost_button.focus_mode = Control.FOCUS_NONE
	_refresh_visibility()
	_refresh_copy()
	queue_redraw()

func _process(_delta: float) -> void:
	if _ship == null:
		return
	boost_button.disabled = not _ship.can_boost()
	boost_status.text = tr("FLIGHT_BOOST_CHARGES_FMT") % [
		_ship.get_boost_charges(),
		_ship.get_boost_capacity(),
	]
	recharge_bar.value = _ship.get_boost_recharge_progress() * 100.0
	recharge_bar.visible = _ship.get_boost_charges() < _ship.get_boost_capacity()

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_release_steering()
	_refresh_visibility()

func _on_input_mode_changed(_mode: InputService.InputMode) -> void:
	_refresh_visibility()
	_refresh_copy()

func _refresh_visibility() -> void:
	visible = _controls_enabled and (
		_input_service.prefers_touch()
		or DisplayServer.is_touchscreen_available()
	)

func _refresh_copy() -> void:
	boost_button.text = tr("FLIGHT_BOOST")

func _on_boost_pressed() -> void:
	if _input_service != null:
		_input_service.request_boost()

func _on_steering_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _steering_touch_index >= 0:
				return
			_steering_touch_index = event.index
			_touch_origin = _to_root_position(event.position)
			_touch_position = _touch_origin
			_update_touch_vector()
			steering_area.accept_event()
			return

		if event.index == _steering_touch_index:
			_release_steering()
			steering_area.accept_event()
		return

	if event is InputEventScreenDrag and event.index == _steering_touch_index:
		_touch_position = _to_root_position(event.position)
		_update_touch_vector()
		steering_area.accept_event()

func _update_touch_vector() -> void:
	var offset := _touch_position - _touch_origin
	var distance := offset.length()
	if distance <= STEERING_DEADZONE or distance <= 0.001:
		_input_service.set_touch_navigation_vector(Vector2.ZERO)
	else:
		var usable_range := STEERING_FULL_THRUST_DISTANCE - STEERING_DEADZONE
		var linear_strength := clampf((distance - STEERING_DEADZONE) / usable_range, 0.0, 1.0)
		var eased_strength := linear_strength * linear_strength * (3.0 - 2.0 * linear_strength)
		_input_service.set_touch_navigation_vector(offset.normalized() * eased_strength)
	queue_redraw()

func _release_steering() -> void:
	_steering_touch_index = -1
	if _input_service != null:
		_input_service.clear_touch_navigation()
	queue_redraw()

func _to_root_position(area_local_position: Vector2) -> Vector2:
	var global_point := steering_area.get_global_transform() * area_local_position
	return get_global_transform().affine_inverse() * global_point

func _draw() -> void:
	if _steering_touch_index < 0:
		return
	var offset := _touch_position - _touch_origin
	var knob_offset := offset.limit_length(STEERING_FULL_THRUST_DISTANCE)
	draw_circle(_touch_origin, RING_RADIUS, Color(0.03, 0.08, 0.12, 0.32))
	draw_arc(_touch_origin, STEERING_FULL_THRUST_DISTANCE, 0.0, TAU, 48, Color(0.58, 0.91, 1.0, 0.38), 2.0, true)
	draw_circle(_touch_origin + knob_offset, KNOB_RADIUS, Color(0.68, 0.95, 1.0, 0.66))
