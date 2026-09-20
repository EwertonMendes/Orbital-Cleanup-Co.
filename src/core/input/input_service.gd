extends Node
class_name InputService

signal input_mode_changed(mode: InputMode)

enum InputMode {
	POINTER_KEYBOARD,
	TOUCH,
	GAMEPAD,
}

var current_mode := InputMode.POINTER_KEYBOARD

func initialize() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	var next_mode := current_mode
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		next_mode = InputMode.TOUCH
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_mode = InputMode.GAMEPAD
	elif event is InputEventMouse or event is InputEventKey:
		next_mode = InputMode.POINTER_KEYBOARD

	if next_mode != current_mode:
		current_mode = next_mode
		input_mode_changed.emit(current_mode)

func prefers_touch() -> bool:
	return current_mode == InputMode.TOUCH
