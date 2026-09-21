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
var _effect_redraw_clock := 0.0
var _environment_velocity := Vector2.ZERO
var _environment_force := Vector2.ZERO
var _environment_anchor := Vector2.ZERO
var _environment_bounds := Rect2()

func _ready() -> void:
	assert(definition != null, "SalvageObject requires a SalvageDefinition.")
	definition.validate()
	add_to_group("salvage")
	_float_phase = fposmod(float(hash(String(definition.id)) % 628), 628.0) / 100.0
	_environment_anchor = global_position
	_apply_definition()
	queue_redraw()

func _process(delta: float) -> void:
	_float_phase = fmod(_float_phase + delta, TAU * 100.0)
	_apply_motion(delta)
	if definition.effect_profile != &"none":
		_effect_redraw_clock += delta
		if _effect_redraw_clock >= 1.0 / 30.0:
			_effect_redraw_clock = 0.0
			queue_redraw()
	_integrate_environment(delta)

func _apply_motion(delta: float) -> void:
	var amplitude := definition.float_amplitude * (0.58 if _targeted else 1.0)
	var spin := spin_speed * definition.spin_multiplier
	var profile_scale := 1.0
	match String(definition.motion_profile):
		"drift":
			sprite.rotation = sin(_float_phase * 0.42) * 0.12
			sprite.position = Vector2(cos(_float_phase * 0.48), sin(_float_phase * 0.61)) * amplitude
		"heavy":
			sprite.rotation = wrapf(sprite.rotation + spin * 0.22 * delta, -PI, PI)
			sprite.position = Vector2(cos(_float_phase * 0.35), sin(_float_phase * 0.46)) * amplitude * 0.62
		"stable":
			sprite.rotation = lerp_angle(sprite.rotation, sin(_float_phase * 0.44) * 0.045, minf(delta * 3.0, 1.0))
			sprite.position = Vector2(cos(_float_phase * 0.40), sin(_float_phase * 0.52)) * amplitude * 0.72
		"pulse":
			sprite.rotation = lerp_angle(sprite.rotation, sin(_float_phase * 0.34) * 0.035, minf(delta * 2.5, 1.0))
			sprite.position = Vector2(cos(_float_phase * 0.42), sin(_float_phase * 0.55)) * amplitude * 0.78
			profile_scale = 1.0 + sin(_float_phase * 2.4) * 0.022
		"spin":
			sprite.rotation = wrapf(sprite.rotation + spin * 1.45 * delta, -PI, PI)
			sprite.position = Vector2(cos(_float_phase * 0.68), sin(_float_phase * 0.82)) * amplitude * 0.82
		_:
			sprite.rotation = wrapf(sprite.rotation + spin * delta, -PI, PI)
			sprite.position = Vector2(cos(_float_phase * 0.78), sin(_float_phase * 1.07)) * amplitude

	var target_scale := 1.0 + (sin(Time.get_ticks_msec() * 0.009) * 0.035 if _targeted else 0.0)
	sprite.scale = _base_scale * profile_scale * target_scale

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

func set_environment_force(force: Vector2, play_bounds: Rect2) -> void:
	_environment_force = force.limit_length(150.0)
	_environment_bounds = play_bounds

func _integrate_environment(delta: float) -> void:
	if _targeted:
		_environment_velocity = Vector2.ZERO
		return
	if _environment_bounds.size == Vector2.ZERO:
		return

	var desired_velocity := _environment_force * 0.16
	var response := minf(delta * 2.6, 1.0)
	_environment_velocity = _environment_velocity.lerp(desired_velocity, response)
	_environment_velocity = _environment_velocity.move_toward(Vector2.ZERO, 7.5 * delta)
	global_position += _environment_velocity * delta

	var offset := global_position - _environment_anchor
	if offset.length_squared() > 48400.0:
		global_position = _environment_anchor + offset.limit_length(220.0)
		_environment_velocity *= 0.35

	var safe_bounds := _environment_bounds.grow(-42.0)
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
		energy_material.set_shader_parameter("energy_strength", 0.70 if rarity_name == "rare" else 0.96)
		energy_material.set_shader_parameter("outline_strength", 0.72 if rarity_name == "rare" else 1.0)
		energy_material.set_shader_parameter("pulse_speed", 2.5 if rarity_name == "rare" else 3.6)
		energy_material.set_shader_parameter("sweep_speed", 0.11 if rarity_name == "rare" else 0.16)
		energy_material.set_shader_parameter("effect_mode", _effect_shader_mode())
		sprite.material = energy_material
		sprite.modulate = Color.WHITE
	else:
		sprite.material = null
		sprite.modulate = Color.WHITE.lerp(category_tint, 0.10 if rarity_name == "common" else 0.18)
	marker.configure(definition, priority_target)

	var circle := collision_shape.shape as CircleShape2D
	assert(circle != null, "SalvageObject requires a CircleShape2D.")
	circle.radius = definition.collision_radius

func _effect_shader_mode() -> float:
	match String(definition.effect_profile):
		"scan":
			return 1.0
		"pulse":
			return 2.0
		"orbit":
			return 3.0
		"spark":
			return 4.0
		_:
			return 0.0

func _draw() -> void:
	if definition == null or definition.effect_profile == &"none":
		return
	var category := WorldVisualLanguage.salvage_category_color(definition.category)
	var rarity := WorldVisualLanguage.salvage_rarity_color(definition.rarity)
	var radius := definition.collision_radius + 7.0
	var phase := _float_phase
	match String(definition.effect_profile):
		"scan":
			for index in range(2):
				var start := phase * (0.65 + index * 0.14) + index * PI
				draw_arc(Vector2.ZERO, radius + float(index) * 4.0, start, start + 0.86, 16, Color(category, 0.26), 1.4, true)
		"pulse":
			var pulse := (sin(phase * 2.6) + 1.0) * 0.5
			draw_arc(Vector2.ZERO, radius + pulse * 6.0, 0.0, TAU, 40, Color(category, 0.10 + pulse * 0.13), 1.4, true)
		"orbit":
			for index in range(2 if String(definition.rarity) != "epic" else 3):
				var angle := phase * (0.72 + index * 0.08) + TAU * float(index) / 3.0
				var position := Vector2.from_angle(angle) * (radius + 7.0)
				draw_circle(position, 2.0 + float(index % 2) * 0.6, Color(rarity, 0.64))
		"spark":
			var flash := maxf(sin(phase * 5.4), 0.0)
			if flash > 0.72:
				var angle := phase * 1.7
				var start := Vector2.from_angle(angle) * radius
				draw_line(start, start + Vector2.from_angle(angle + 0.5) * 8.0, Color(category, flash * 0.62), 1.5, true)
