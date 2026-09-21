extends Node
class_name SceneRouter

signal screen_changed(screen: Control)

const ENTER_DURATION := 0.22
const EXIT_DURATION := 0.16
const TRAVEL_COVER_IN_DURATION := 0.10
const TRAVEL_COVER_OUT_DURATION := 0.20

var _host: Control
var _travel_cover: ColorRect
var _transition: Tween
var _cover_transition: Tween
var _travel_handoff_active := false

func configure(host: Control, travel_cover: ColorRect = null) -> void:
	assert(host != null, "SceneRouter requires a valid Control host.")
	_host = host
	_travel_cover = travel_cover
	if _travel_cover != null:
		_travel_cover.visible = false
		_travel_cover.modulate.a = 0.0
		_travel_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	var travel_handoff := bool(context.get("travel_handoff", false))
	if travel_handoff:
		assert(_travel_handoff_active, "Travel-routed screens require an active persistent handoff cover.")
		screen.modulate.a = 1.0
		screen.position = Vector2.ZERO
	else:
		screen.modulate.a = 0.0
		screen.position = Vector2(0.0, 8.0)

	_host.add_child(screen)
	screen_changed.emit(screen)

	if previous == null:
		if travel_handoff:
			return screen
		_transition = create_tween()
		_transition.set_parallel(true)
		_transition.tween_property(screen, "modulate:a", 1.0, ENTER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition.tween_property(screen, "position", Vector2.ZERO, ENTER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return screen

	previous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previous.process_mode = Node.PROCESS_MODE_DISABLED

	if travel_handoff:
		_retire_screen(previous)
		return screen

	_transition = create_tween()
	_transition.set_parallel(true)
	_transition.tween_property(screen, "modulate:a", 1.0, ENTER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition.tween_property(screen, "position", Vector2.ZERO, ENTER_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(previous, "modulate:a", 0.0, EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(previous, "position", Vector2(0.0, -6.0), EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.chain().tween_callback(_retire_screen.bind(previous))
	return screen

func begin_travel_handoff() -> void:
	assert(_travel_cover != null, "Travel handoff requires a persistent cover.")
	if _cover_transition != null and _cover_transition.is_valid():
		_cover_transition.kill()

	_travel_handoff_active = true
	_travel_cover.visible = true
	_travel_cover.modulate.a = 0.0
	_cover_transition = create_tween()
	_cover_transition.tween_property(
		_travel_cover,
		"modulate:a",
		1.0,
		TRAVEL_COVER_IN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _cover_transition.finished
	print("[Router] TRAVEL_HANDOFF_COVERED")

func finish_travel_handoff() -> void:
	if not _travel_handoff_active:
		return
	assert(_travel_cover != null, "Travel handoff requires a persistent cover.")

	# Give the destination one complete frame in-tree before exposing it. This
	# keeps sector spawning/import work behind the persistent warp seam instead
	# of flashing a partially initialized world.
	await get_tree().process_frame
	await get_tree().process_frame

	if _cover_transition != null and _cover_transition.is_valid():
		_cover_transition.kill()
	_cover_transition = create_tween()
	_cover_transition.tween_property(
		_travel_cover,
		"modulate:a",
		0.0,
		TRAVEL_COVER_OUT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _cover_transition.finished

	_travel_cover.visible = false
	_travel_handoff_active = false
	print("[Router] TRAVEL_HANDOFF_REVEALED")

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
