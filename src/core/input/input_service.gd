extends Node
class_name InputService

signal input_mode_changed(mode: InputMode)
signal primary_pointer_changed(position: Vector2, active: bool)

enum InputMode {
	POINTER_KEYBOARD,
	TOUCH,
	GAMEPAD,
}

const MOVE_LEFT := &"occ_move_left"
const MOVE_RIGHT := &"occ_move_right"
const MOVE_UP := &"occ_move_up"
const MOVE_DOWN := &"occ_move_down"
const TOUCH_MOUSE_SUPPRESSION_MS := 350

var current_mode := InputMode.POINTER_KEYBOARD

var _primary_touch_index := -1
var _touch_position := Vector2.ZERO
var _suppress_mouse_until_msec := 0

func initialize() -> void:
	_ensure_default_navigation_actions()
	set_process_input(true)

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

func get_navigation_vector() -> Vector2:
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN)

func get_primary_pointer_position() -> Vector2:
	if current_mode == InputMode.TOUCH:
		return _touch_position
	return get_viewport().get_mouse_position()

func is_primary_pointer_active() -> bool:
	if current_mode == InputMode.TOUCH:
		return _primary_touch_index >= 0
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
