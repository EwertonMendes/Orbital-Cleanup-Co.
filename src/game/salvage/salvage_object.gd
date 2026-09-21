extends Area2D
class_name SalvageObject

const ENERGY_SHADER := preload("res://src/game/visual/salvage_energy.gdshader")

@export var definition: SalvageDefinition
@export var priority_target := false
@export_range(-3.0, 3.0, 0.05) var spin_speed := 0.35

@onready var sprite: Sprite2D = %Sprite
@onready var marker: SalvageMarker = %Marker
@onready var collision_shape: CollisionShape2D = %CollisionShape

var _tractor_progress := 0.0
var _tractor_velocity := Vector2.ZERO
var _targeted := false
var _base_scale := Vector2.ONE
var _float_phase := 0.0
var _environment_velocity := Vector2.ZERO
var _environment_anchor := Vector2.ZERO

func _ready() -> void:
	assert(definition != null, "SalvageObject requires a SalvageDefinition.")
	definition.validate()
	add_to_group("salvage")
	_float_phase = fposmod(float(hash(String(definition.id)) % 628), 628.0) / 100.0
	_environment_anchor = global_position
	_apply_definition()
	queue_redraw()

func _process(delta: float) -> void:
	sprite.rotation = wrapf(sprite.rotation + spin_speed * delta, -PI, PI)
	_float_phase = fmod(_float_phase + delta, TAU * 100.0)
	var float_strength := 1.6 if _targeted else 3.2
	sprite.position = Vector2(
		cos(_float_phase * 0.78),
		sin(_float_phase * 1.07)
	) * float_strength

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
		_environment_anchor = global_position
	queue_redraw()

func apply_environment_force(force: Vector2, delta: float, play_bounds: Rect2) -> void:
	if _targeted:
		_environment_velocity = Vector2.ZERO
		return

	var desired_velocity := force * 0.16
	var response := minf(delta * 2.6, 1.0)
	_environment_velocity = _environment_velocity.lerp(desired_velocity, response)
	_environment_velocity = _environment_velocity.move_toward(Vector2.ZERO, 7.5 * delta)
	global_position += _environment_velocity * delta

	var offset := global_position - _environment_anchor
	if offset.length() > 220.0:
		global_position = _environment_anchor + offset.limit_length(220.0)
		_environment_velocity *= 0.35

	var safe_bounds := play_bounds.grow(-42.0)
	global_position.x = clampf(global_position.x, safe_bounds.position.x, safe_bounds.end.x)
	global_position.y = clampf(global_position.y, safe_bounds.position.y, safe_bounds.end.y)

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
	var category_tint := WorldVisualLanguage.salvage_category_color(definition.category)
	var rarity_tint := WorldVisualLanguage.salvage_rarity_color(definition.rarity)
	var rarity_name := String(definition.rarity)
	if rarity_name in ["rare", "epic"]:
		var energy_material := ShaderMaterial.new()
		energy_material.shader = ENERGY_SHADER
		energy_material.set_shader_parameter("category_tint", category_tint)
		energy_material.set_shader_parameter("rarity_tint", rarity_tint)
		energy_material.set_shader_parameter("energy_strength", 0.72 if rarity_name == "rare" else 0.94)
		sprite.material = energy_material
		sprite.modulate = Color.WHITE
	else:
		sprite.material = null
		sprite.modulate = Color.WHITE.lerp(category_tint, 0.16)
	marker.configure(definition, priority_target)

	var circle := collision_shape.shape as CircleShape2D
	assert(circle != null, "SalvageObject requires a CircleShape2D.")
	circle.radius = definition.collision_radius

