extends Node2D
class_name TractorBeam

signal target_changed(definition)
signal progress_changed(progress: float)
signal salvage_collected(definition, used_units: int, capacity: int)
signal blocked_by_cargo_space

@export var cargo_hold_path: NodePath
@export var scan_area_path: NodePath
@export var collect_anchor_path: NodePath
@export var beam_glow_path: NodePath
@export var beam_core_path: NodePath
@export_range(80.0, 1200.0, 10.0) var scan_range := 320.0
@export_range(20.0, 160.0, 2.0) var capture_distance := 58.0
@export_range(100.0, 1200.0, 10.0) var pull_speed := 520.0
@export_range(0.1, 5.0, 0.05) var collection_speed_multiplier := 1.0

var _cargo_hold: CargoHold
var _scan_area: Area2D
var _collect_anchor: Marker2D
var _beam_glow: Line2D
var _beam_core: Line2D
var _candidates: Array[SalvageObject] = []
var _target: SalvageObject
var _beam_phase := 0.0
var _reported_blocked := false
var _style: Dictionary = {}
var _glow_base_width := 9.0
var _core_base_width := 2.2
var _pulse_width := 1.5
var _pulse_speed := 10.0
var _beam_start := Vector2.ZERO
var _beam_finish := Vector2.ZERO
var _beam_active := false

func _ready() -> void:
	_cargo_hold = get_node(cargo_hold_path) as CargoHold
	_scan_area = get_node(scan_area_path) as Area2D
	_collect_anchor = get_node(collect_anchor_path) as Marker2D
	_beam_glow = get_node(beam_glow_path) as Line2D
	_beam_core = get_node(beam_core_path) as Line2D

	assert(_cargo_hold != null, "TractorBeam requires CargoHold.")
	assert(_scan_area != null, "TractorBeam requires scan Area2D.")
	assert(_collect_anchor != null, "TractorBeam requires collection anchor.")
	assert(_beam_glow != null and _beam_core != null, "TractorBeam requires beam lines.")

	var scan_collision := _scan_area.get_node("CollisionShape2D") as CollisionShape2D
	assert(scan_collision != null, "TractorBeam scan requires CollisionShape2D.")
	var circle := scan_collision.shape as CircleShape2D
	assert(circle != null, "TractorBeam scan requires CircleShape2D.")
	circle.radius = scan_range

	_scan_area.area_entered.connect(_on_area_entered)
	_scan_area.area_exited.connect(_on_area_exited)
	_cargo_hold.cargo_changed.connect(_on_cargo_changed)
	if not _style.is_empty():
		_apply_visual_style()
	_hide_beam()

func apply_style(style: Dictionary) -> void:
	assert(not style.is_empty(), "TractorBeam style cannot be empty.")
	_style = style.duplicate(true)
	_glow_base_width = clampf(float(style.get("glow_width", 9.0)), 2.0, 20.0)
	_core_base_width = clampf(float(style.get("core_width", 2.2)), 0.5, 8.0)
	_pulse_width = clampf(float(style.get("pulse_width", 1.5)), 0.0, 6.0)
	_pulse_speed = clampf(float(style.get("pulse_speed", 10.0)), 1.0, 30.0)
	if _beam_glow != null and _beam_core != null:
		_apply_visual_style()

func _apply_visual_style() -> void:
	_beam_glow.default_color = Color.from_string(
		String(_style.get("glow_color", "#2ED1FF")),
		Color(0.18, 0.82, 1.0, 0.34)
	)
	_beam_core.default_color = Color.from_string(
		String(_style.get("core_color", "#9EFFE6")),
		Color(0.62, 0.98, 0.90, 0.96)
	)
	_beam_glow.default_color.a = 0.34
	_beam_core.default_color.a = 0.96
	_beam_glow.width = _glow_base_width
	_beam_core.width = _core_base_width

func _physics_process(delta: float) -> void:
	_prune_candidates()

	if not _is_target_valid(_target):
		_set_target(null)

	if _target == null:
		_set_target(_choose_target())

	if _target == null:
		_hide_beam()
		return

	var anchor := _collect_anchor.global_position
	_target.tractor_step(anchor, delta, pull_speed, collection_speed_multiplier)
	var progress := _target.get_tractor_progress()
	progress_changed.emit(progress)
	_update_beam_visual(_target.global_position, delta)

	if _target.is_collection_ready(anchor, capture_distance):
		_complete_target()

func _on_area_entered(area: Area2D) -> void:
	var salvage := area as SalvageObject
	if salvage == null or _candidates.has(salvage):
		return
	_candidates.append(salvage)
	_reported_blocked = false

func _on_area_exited(area: Area2D) -> void:
	var salvage := area as SalvageObject
	if salvage == null:
		return
	_candidates.erase(salvage)
	if salvage == _target:
		_set_target(null)
	if _candidates.is_empty():
		_reported_blocked = false

func _on_cargo_changed(_used_units: int, _capacity: int) -> void:
	_reported_blocked = false
	if _target != null and not _cargo_hold.can_accept(_target.definition):
		_set_target(null)

func _choose_target() -> SalvageObject:
	var best: SalvageObject
	var best_distance := INF
	var found_salvage := false

	for candidate in _candidates:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		found_salvage = true
		if not _cargo_hold.can_accept(candidate.definition):
			continue

		var distance := candidate.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate

	if best == null and found_salvage and not _reported_blocked:
		_reported_blocked = true
		blocked_by_cargo_space.emit()

	return best

func _is_target_valid(candidate: SalvageObject) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and _candidates.has(candidate)
		and _cargo_hold.can_accept(candidate.definition)
	)

func _set_target(next_target: SalvageObject) -> void:
	if _target == next_target:
		return

	if _target != null and is_instance_valid(_target):
		_target.set_targeted(false)

	_target = next_target
	progress_changed.emit(0.0)

	if _target != null:
		_reported_blocked = false
		_target.set_targeted(true)
		target_changed.emit(_target.definition)
	else:
		target_changed.emit(null)

func _complete_target() -> void:
	if _target == null:
		return

	var collected := _target
	var definition := collected.definition
	if not _cargo_hold.store(definition):
		blocked_by_cargo_space.emit()
		_set_target(null)
		return

	var used := _cargo_hold.used_units
	var capacity := _cargo_hold.capacity
	_candidates.erase(collected)
	_target = null
	collected.queue_free()
	_hide_beam()
	progress_changed.emit(0.0)
	target_changed.emit(null)
	salvage_collected.emit(definition, used, capacity)
	print("[Salvage] COLLECTED id=%s cargo=%d/%d" % [String(definition.id), used, capacity])

func _update_beam_visual(target_global_position: Vector2, delta: float) -> void:
	_beam_phase += delta * _pulse_speed
	var start := to_local(_collect_anchor.global_position)
	var finish := to_local(target_global_position)
	_beam_start = start
	_beam_finish = finish
	_beam_active = true

	_beam_glow.clear_points()
	_beam_glow.add_point(start)
	_beam_glow.add_point(finish)
	_beam_glow.visible = true

	_beam_core.clear_points()
	_beam_core.add_point(start)
	_beam_core.add_point(finish)
	_beam_core.visible = true

	_beam_glow.width = _glow_base_width + sin(_beam_phase) * _pulse_width
	_beam_glow.modulate.a = 0.45 + sin(_beam_phase * 1.6) * 0.08
	_beam_core.width = _core_base_width
	queue_redraw()

func _draw() -> void:
	if not _beam_active:
		return
	var packet_color := _beam_core.default_color
	for index in range(6):
		var offset := float(index) / 6.0
		var t := fposmod(offset + _beam_phase * 0.035, 1.0)
		var position := _beam_finish.lerp(_beam_start, t)
		var size := 1.3 + (1.0 - t) * 1.5
		draw_circle(position, size, Color(packet_color, 0.72 * (1.0 - t * 0.35)))
	draw_circle(_beam_finish, 4.0 + sin(_beam_phase * 0.7) * 1.2, Color(packet_color, 0.18))

func _hide_beam() -> void:
	_beam_active = false
	queue_redraw()
	if _beam_glow != null:
		_beam_glow.visible = false
	if _beam_core != null:
		_beam_core.visible = false

func _prune_candidates() -> void:
	for index in range(_candidates.size() - 1, -1, -1):
		var candidate := _candidates[index]
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			_candidates.remove_at(index)
