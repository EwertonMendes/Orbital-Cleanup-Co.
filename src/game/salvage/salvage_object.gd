extends Area2D
class_name SalvageObject

@export var definition: SalvageDefinition
@export_range(-3.0, 3.0, 0.05) var spin_speed := 0.35

@onready var sprite: Sprite2D = %Sprite
@onready var marker: SalvageMarker = %Marker
@onready var collision_shape: CollisionShape2D = %CollisionShape

var _tractor_progress := 0.0
var _tractor_velocity := Vector2.ZERO
var _targeted := false
var _base_scale := Vector2.ONE

func _ready() -> void:
	assert(definition != null, "SalvageObject requires a SalvageDefinition.")
	definition.validate()
	add_to_group("salvage")
	_apply_definition()
	queue_redraw()

func _process(delta: float) -> void:
	sprite.rotation = wrapf(sprite.rotation + spin_speed * delta, -PI, PI)

	if _targeted:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.009) * 0.035
		sprite.scale = _base_scale * pulse
	else:
		sprite.scale = sprite.scale.lerp(_base_scale, minf(delta * 8.0, 1.0))

func set_targeted(value: bool) -> void:
	if _targeted == value:
		return
	_targeted = value
	marker.set_targeted(value)
	if not value:
		_tractor_progress = 0.0
		_tractor_velocity = Vector2.ZERO
	queue_redraw()

func tractor_step(anchor: Vector2, delta: float, base_pull_speed: float, collection_speed_multiplier: float = 1.0) -> void:
	assert(_targeted, "tractor_step requires an active target.")
	var effective_speed := maxf(collection_speed_multiplier, 0.1)
	_tractor_progress = minf(_tractor_progress + (delta * effective_speed) / definition.collect_duration, 1.0)
	marker.set_progress(_tractor_progress)

	var offset := anchor - global_position
	var distance := offset.length()
	if distance > 0.01:
		var direction := offset / distance
		var mass_factor := 1.0 / maxf(definition.mass, 0.2)
		var pull_speed := base_pull_speed * clampf(mass_factor, 0.34, 1.4) + minf(distance * 0.55, 240.0)
		var desired_velocity := direction * pull_speed
		var acceleration := base_pull_speed * 2.8 * clampf(mass_factor, 0.35, 1.5)
		_tractor_velocity = _tractor_velocity.move_toward(desired_velocity, acceleration * delta)
		global_position += _tractor_velocity * delta

	queue_redraw()

func is_collection_ready(anchor: Vector2, capture_distance: float) -> bool:
	return _tractor_progress >= 1.0 and global_position.distance_to(anchor) <= capture_distance

func get_tractor_progress() -> float:
	return _tractor_progress

func _apply_definition() -> void:
	sprite.texture = definition.sprite
	_base_scale = Vector2.ONE * definition.visual_scale
	sprite.scale = _base_scale
	sprite.modulate = Color(0.96, 1.0, 1.0, 1.0)
	marker.configure(definition)

	var circle := collision_shape.shape as CircleShape2D
	assert(circle != null, "SalvageObject requires a CircleShape2D.")
	circle.radius = definition.collision_radius

