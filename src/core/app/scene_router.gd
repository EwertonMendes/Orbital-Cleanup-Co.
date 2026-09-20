extends Node
class_name SceneRouter

signal screen_changed(screen: Control)

var _host: Control

func configure(host: Control) -> void:
	assert(host != null, "SceneRouter requires a valid Control host.")
	_host = host

func show_screen(scene: PackedScene, context: Dictionary = {}) -> Control:
	assert(_host != null, "SceneRouter must be configured before showing screens.")
	assert(scene != null, "SceneRouter requires a valid PackedScene.")

	for child in _host.get_children():
		child.free()

	var instance := scene.instantiate()
	assert(instance is Control, "Routed screens must inherit Control.")
	var screen := instance as Control

	if screen.has_method("configure"):
		screen.call("configure", context)

	_host.add_child(screen)
	screen_changed.emit(screen)
	return screen
