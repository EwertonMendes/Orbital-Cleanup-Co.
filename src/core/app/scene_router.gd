extends Node
class_name SceneRouter

signal screen_changed(screen: Control)

const ENTER_DURATION := 0.22
const EXIT_DURATION := 0.16

var _host: Control
var _transition: Tween

func configure(host: Control) -> void:
	assert(host != null, "SceneRouter requires a valid Control host.")
	_host = host

func show_screen(scene: PackedScene, context: Dictionary = {}) -> Control:
	assert(_host != null, "SceneRouter must be configured before showing screens.")
	assert(scene != null, "SceneRouter requires a valid PackedScene.")

	if _transition != null and _transition.is_valid():
		_transition.kill()
	_cleanup_stale_screens()

	var previous: Control
	if _host.get_child_count() > 0:
		previous = _host.get_child(_host.get_child_count() - 1) as Control

	var instance := scene.instantiate()
	assert(instance is Control, "Routed screens must inherit Control.")
	var screen := instance as Control

	if screen.has_method("configure"):
		screen.call("configure", context)

	screen.modulate.a = 0.0
	screen.position = Vector2(0.0, 8.0)
	_host.add_child(screen)
	screen_changed.emit(screen)

	if previous == null:
		_transition = create_tween()
		_transition.set_parallel(true)
		_transition.tween_property(screen, "modulate:a", 1.0, ENTER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition.tween_property(screen, "position", Vector2.ZERO, ENTER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return screen

	previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previous.process_mode = Node.PROCESS_MODE_DISABLED

	_transition = create_tween()
	_transition.set_parallel(true)
	_transition.tween_property(screen, "modulate:a", 1.0, ENTER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition.tween_property(screen, "position", Vector2.ZERO, ENTER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(previous, "modulate:a", 0.0, EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(previous, "position", Vector2(0.0, -6.0), EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.chain().tween_callback(_retire_screen.bind(previous))
	return screen

func _retire_screen(screen: Control) -> void:
	if not is_instance_valid(screen):
		return
	if screen.get_parent() == _host:
		_host.remove_child(screen)
	screen.queue_free()

func _cleanup_stale_screens() -> void:
	if _host == null or _host.get_child_count() <= 1:
		return
	for index in range(_host.get_child_count() - 1):
		var stale := _host.get_child(index)
		_host.remove_child(stale)
		stale.queue_free()
