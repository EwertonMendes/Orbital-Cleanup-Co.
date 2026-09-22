extends Node
class_name InputService

signal input_mode_changed(mode: InputMode)
signal primary_pointer_changed(position: Vector2, active: bool)
signal boost_requested

enum InputMode {
	POINTER_KEYBOARD,
	TOUCH,
	GAMEPAD,
}

const MOVE_LEFT := &"occ_move_left"
const MOVE_RIGHT := &"occ_move_right"
const MOVE_UP := &"occ_move_up"
const MOVE_DOWN := &"occ_move_down"
const BOOST := &"occ_boost"
const TOUCH_MOUSE_SUPPRESSION_MS := 350

var current_mode := InputMode.POINTER_KEYBOARD

var _primary_touch_index := -1
var _touch_position := Vector2.ZERO
var _touch_navigation_vector := Vector2.ZERO
var _suppress_mouse_until_msec := 0

func initialize() -> void:
	_ensure_default_navigation_actions()
	_ensure_key_action(BOOST, [KEY_SPACE])
	set_process_input(true)
	set_process_unhandled_input(true)

func _input(event: InputEvent) -> void:
	var next_mode := current_mode

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		next_mode = InputMode.TOUCH
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
		next_mode = InputMode.TOUCH
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_mode = InputMode.GAMEPAD
	elif event is InputEventMouse:
		if Time.get_ticks_msec() >= _suppress_mouse_until_msec:
			next_mode = InputMode.POINTER_KEYBOARD
	elif event is InputEventKey:
		next_mode = InputMode.POINTER_KEYBOARD

	if next_mode != current_mode:
		current_mode = next_mode
		input_mode_changed.emit(current_mode)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(BOOST):
		request_boost()
		get_viewport().set_input_as_handled()
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and current_mode == InputMode.POINTER_KEYBOARD
	):
		request_boost()
		get_viewport().set_input_as_handled()

func get_navigation_vector() -> Vector2:
	var action_vector := Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN)
	if action_vector.length_squared() > 0.001:
		return action_vector.limit_length(1.0)
	return _touch_navigation_vector.limit_length(1.0)

func set_touch_navigation_vector(value: Vector2) -> void:
	_touch_navigation_vector = value.limit_length(1.0)

func clear_touch_navigation() -> void:
	_touch_navigation_vector = Vector2.ZERO

func request_boost() -> void:
	boost_requested.emit()

func get_primary_pointer_position() -> Vector2:
	if current_mode == InputMode.TOUCH:
		return _touch_position
	return get_viewport().get_mouse_position()

func is_primary_pointer_active() -> bool:
	if current_mode == InputMode.TOUCH:
		return _primary_touch_index >= 0
	return current_mode == InputMode.POINTER_KEYBOARD

func uses_pointer_steering() -> bool:
	return current_mode == InputMode.POINTER_KEYBOARD

func prefers_touch() -> bool:
	return current_mode == InputMode.TOUCH

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

func _ensure_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)

	for key in keys:
		var input_event := InputEventKey.new()
		input_event.physical_keycode = int(key)
		if not InputMap.action_has_event(action, input_event):
			InputMap.action_add_event(action, input_event)
