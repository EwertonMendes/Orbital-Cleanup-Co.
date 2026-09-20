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
	_hide_beam()

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
	_beam_phase += delta * 10.0
	var start := to_local(_collect_anchor.global_position)
	var finish := to_local(target_global_position)

	_beam_glow.clear_points()
	_beam_glow.add_point(start)
	_beam_glow.add_point(finish)
	_beam_glow.visible = true

	_beam_core.clear_points()
	_beam_core.add_point(start)
	_beam_core.add_point(finish)
	_beam_core.visible = true

	_beam_glow.width = 9.0 + sin(_beam_phase) * 1.5
	_beam_glow.modulate.a = 0.45 + sin(_beam_phase * 1.6) * 0.08
	_beam_core.width = 2.2

func _hide_beam() -> void:
	if _beam_glow != null:
		_beam_glow.visible = false
	if _beam_core != null:
		_beam_core.visible = false

func _prune_candidates() -> void:
	for index in range(_candidates.size() - 1, -1, -1):
		var candidate := _candidates[index]
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			_candidates.remove_at(index)
