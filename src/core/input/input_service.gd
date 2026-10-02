extends Node
class_name InputService

signal input_mode_changed(mode: InputMode)
signal primary_pointer_changed(position: Vector2, active: bool)
signal boost_requested

enum InputMode {
	POINTER,
	KEYBOARD,
	TOUCH,
	GAMEPAD,
}

const MOVE_LEFT := &"occ_move_left"
const MOVE_RIGHT := &"occ_move_right"
const MOVE_UP := &"occ_move_up"
const MOVE_DOWN := &"occ_move_down"
const BOOST := &"occ_boost"
const OPERATIONS := &"occ_operations"
const CONTRACT_ACTION := &"occ_contract_action"
const TAB_PREVIOUS := &"occ_tab_previous"
const TAB_NEXT := &"occ_tab_next"
const TOUCH_MOUSE_SUPPRESSION_MS := 350
const GAMEPAD_DEADZONE := 0.18
const GAMEPAD_ACTIVATION_THRESHOLD := 0.24
const MOUSE_REACTIVATION_DISTANCE := 1.5

var current_mode := InputMode.POINTER

var _primary_touch_index := -1
var _touch_position := Vector2.ZERO
var _touch_navigation_vector := Vector2.ZERO
var _suppress_mouse_until_msec := 0
var _active_joypad_device := 0

func initialize() -> void:
	_ensure_default_navigation_actions()
	_ensure_key_action(BOOST, [KEY_SPACE])
	_ensure_joy_button_action(BOOST, JOY_BUTTON_A)
	_ensure_joy_button_action(OPERATIONS, JOY_BUTTON_START)
	_ensure_joy_button_action(CONTRACT_ACTION, JOY_BUTTON_Y)
	_ensure_joy_button_action(TAB_PREVIOUS, JOY_BUTTON_LEFT_SHOULDER)
	_ensure_joy_button_action(TAB_NEXT, JOY_BUTTON_RIGHT_SHOULDER)
	_ensure_default_ui_gamepad_actions()
	_apply_pointer_visibility()
	set_process_input(true)
	set_process_unhandled_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		_set_input_mode(InputMode.TOUCH)
		return

	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		_set_input_mode(InputMode.TOUCH)
		return

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(motion.axis_value) >= GAMEPAD_ACTIVATION_THRESHOLD:
			_active_joypad_device = motion.device
			_set_input_mode(InputMode.GAMEPAD)
		return

	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.pressed:
			_active_joypad_device = button.device
			_set_input_mode(InputMode.GAMEPAD)
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_set_input_mode(InputMode.KEYBOARD)
		return

	if event is InputEventMouseMotion:
		if Time.get_ticks_msec() < _suppress_mouse_until_msec:
			return
		var motion := event as InputEventMouseMotion
		if motion.relative.length() >= MOUSE_REACTIVATION_DISTANCE:
			_set_input_mode(InputMode.POINTER)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(BOOST):
		return
	if event is InputEventKey:
		_set_input_mode(InputMode.KEYBOARD)
	elif event is InputEventJoypadButton:
		_active_joypad_device = event.device
		_set_input_mode(InputMode.GAMEPAD)
	else:
		return
	request_boost()
	get_viewport().set_input_as_handled()

func get_navigation_vector() -> Vector2:
	match current_mode:
		InputMode.KEYBOARD:
			return _keyboard_navigation_vector()
		InputMode.GAMEPAD:
			return _gamepad_navigation_vector()
		InputMode.TOUCH:
			return _touch_navigation_vector.limit_length(1.0)
	return Vector2.ZERO

func set_touch_navigation_vector(value: Vector2) -> void:
	_touch_navigation_vector = value.limit_length(1.0)
	if _touch_navigation_vector.length_squared() > 0.001:
		_set_input_mode(InputMode.TOUCH)

func clear_touch_navigation() -> void:
	_touch_navigation_vector = Vector2.ZERO

func request_boost() -> void:
	boost_requested.emit()

func is_pointer_boost_event(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not event.double_click
		and current_mode == InputMode.POINTER
		and Time.get_ticks_msec() >= _suppress_mouse_until_msec
	)

func get_primary_pointer_position() -> Vector2:
	if current_mode == InputMode.TOUCH:
		return _touch_position
	return get_viewport().get_mouse_position()

func is_primary_pointer_active() -> bool:
	if current_mode == InputMode.TOUCH:
		return _primary_touch_index >= 0
	return current_mode == InputMode.POINTER

func uses_pointer_steering() -> bool:
	return current_mode == InputMode.POINTER

func prefers_touch() -> bool:
	return current_mode == InputMode.TOUCH

func prefers_gamepad() -> bool:
	return current_mode == InputMode.GAMEPAD

func _set_input_mode(mode: InputMode) -> void:
	if mode == current_mode:
		_apply_pointer_visibility()
		return
	current_mode = mode
	_apply_pointer_visibility()
	input_mode_changed.emit(current_mode)

func _apply_pointer_visibility() -> void:
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE
		if current_mode == InputMode.POINTER
		else Input.MOUSE_MODE_HIDDEN
	)

func _keyboard_navigation_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0
	return Vector2(x, y).limit_length(1.0)

func _gamepad_navigation_vector() -> Vector2:
	var x := _filtered_axis(Input.get_joy_axis(_active_joypad_device, JOY_AXIS_LEFT_X))
	var y := _filtered_axis(Input.get_joy_axis(_active_joypad_device, JOY_AXIS_LEFT_Y))
	if Input.is_joy_button_pressed(_active_joypad_device, JOY_BUTTON_DPAD_LEFT):
		x = -1.0
	elif Input.is_joy_button_pressed(_active_joypad_device, JOY_BUTTON_DPAD_RIGHT):
		x = 1.0
	if Input.is_joy_button_pressed(_active_joypad_device, JOY_BUTTON_DPAD_UP):
		y = -1.0
	elif Input.is_joy_button_pressed(_active_joypad_device, JOY_BUTTON_DPAD_DOWN):
		y = 1.0
	return Vector2(x, y).limit_length(1.0)

func _filtered_axis(value: float) -> float:
	var magnitude := absf(value)
	if magnitude <= GAMEPAD_DEADZONE:
		return 0.0
	var normalized := clampf(
		(magnitude - GAMEPAD_DEADZONE) / (1.0 - GAMEPAD_DEADZONE),
		0.0,
		1.0
	)
	return normalized * signf(value)

func _is_flight_key(event: InputEventKey) -> bool:
	return event.physical_keycode in [
		KEY_A, KEY_D, KEY_W, KEY_S,
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		KEY_SPACE,
	]

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _primary_touch_index < 0 or _primary_touch_index == event.index:
			_primary_touch_index = event.index
			_touch_position = event.position
			primary_pointer_changed.emit(_touch_position, true)
		return

	if event.index == _primary_touch_index:
		_touch_position = event.position
		_primary_touch_index = -1
		_suppress_mouse_until_msec = Time.get_ticks_msec() + TOUCH_MOUSE_SUPPRESSION_MS
		primary_pointer_changed.emit(_touch_position, false)

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _primary_touch_index:
		return
	_touch_position = event.position
	primary_pointer_changed.emit(_touch_position, true)

func _ensure_default_navigation_actions() -> void:
	_ensure_key_action(MOVE_LEFT, [KEY_A, KEY_LEFT])
	_ensure_key_action(MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_ensure_key_action(MOVE_UP, [KEY_W, KEY_UP])
	_ensure_key_action(MOVE_DOWN, [KEY_S, KEY_DOWN])

func _ensure_default_ui_gamepad_actions() -> void:
	_ensure_joy_button_action(&"ui_accept", JOY_BUTTON_A)
	_ensure_joy_button_action(&"ui_cancel", JOY_BUTTON_B)
	_ensure_joy_button_action(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button_action(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_button_action(&"ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy_button_action(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_axis_action(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis_action(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_axis_action(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis_action(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)

func _ensure_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, GAMEPAD_DEADZONE)

	for key in keys:
		var input_event := InputEventKey.new()
		input_event.physical_keycode = int(key)
		if not InputMap.action_has_event(action, input_event):
			InputMap.action_add_event(action, input_event)

func _ensure_joy_button_action(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, GAMEPAD_DEADZONE)
	var input_event := InputEventJoypadButton.new()
	input_event.button_index = button_index
	if not InputMap.action_has_event(action, input_event):
		InputMap.action_add_event(action, input_event)


func _ensure_joy_axis_action(action: StringName, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, GAMEPAD_DEADZONE)
	var input_event := InputEventJoypadMotion.new()
	input_event.axis = axis
	input_event.axis_value = axis_value
	if not InputMap.action_has_event(action, input_event):
		InputMap.action_add_event(action, input_event)
