extends Node2D
class_name ShipVisuals

@onready var steering_visual: Node2D = %SteeringVisual
@onready var ship_sprite: Sprite2D = %ShipSprite
@onready var engine_glow: Sprite2D = %EngineGlow
@onready var engine_trail: EngineTrail = %EngineTrail
@onready var engine_particles: CPUParticles2D = %EngineParticles
@onready var engine_anchor: Marker2D = %EngineAnchor
@onready var bump_particles: CPUParticles2D = %BumpParticles

var _impact_tween: Tween
var _drift_direction := Vector2.ZERO
var _drift_intensity := 0.0
var _layer_sprites: Dictionary = {}
var _extra_engine_nodes: Array[Node] = []
var _engine_glows: Array[Sprite2D] = []
var _engine_particles: Array[CPUParticles2D] = []
var _engine_trails: Array[EngineTrail] = []

func _ready() -> void:
	_engine_glows = [engine_glow]
	_engine_particles = [engine_particles]
	_engine_trails = [engine_trail]

func apply_ship_build(build: Dictionary) -> void:
	assert(build.has("visual") and build.has("cosmetics"), "ShipVisuals requires resolved visual and cosmetic data.")
	var visual := build["visual"] as Dictionary
	var loadout := build["cosmetics"] as Dictionary

	var texture_path := String(visual.get("base_texture", ""))
	assert(not texture_path.is_empty(), "Ship model requires a base texture.")
	var hull_texture := load(texture_path) as Texture2D
	assert(hull_texture != null, "Ship base texture must load: %s" % texture_path)
	ship_sprite.texture = hull_texture

	var render_scale := maxf(float(visual.get("render_scale", 1.0)), 0.001)
	ship_sprite.scale = Vector2.ONE * render_scale

	_apply_paint(visual, loadout)
	_apply_model_layers(visual, render_scale)
	_apply_cosmetic_layers(loadout, render_scale)
	_configure_engine_sockets(visual.get("engine_sockets", []) as Array, loadout)

func apply_cosmetics(loadout: Dictionary) -> void:
	# Compatibility entry point for old previews/tests. Runtime flight should use
	# apply_ship_build so model geometry and cosmetics remain separate concepts.
	assert(loadout.has("hull") and loadout.has("paint") and loadout.has("trail"), "ShipVisuals requires hull, paint and trail cosmetics.")
	var hull := loadout["hull"] as Dictionary
	apply_ship_build({
		"visual": {
			"base_texture": String(hull.get("texture", "")),
			"render_scale": 0.14,
			"paint_mode": "legacy_blue_bias",
			"paint_mask": "",
			"details_texture": "",
			"emissive_texture": "",
			"engine_sockets": [{"id": "main", "position": [0.0, 41.0]}],
		},
		"cosmetics": loadout,
	})

func _apply_paint(visual: Dictionary, loadout: Dictionary) -> void:
	var paint := loadout.get("paint", {}) as Dictionary
	var material_instance := ship_sprite.material as ShaderMaterial
	assert(material_instance != null, "ShipSprite requires paint ShaderMaterial.")

	material_instance.set_shader_parameter(
		"paint_color",
		Color.from_string(String(paint.get("color", "#39B6E8")), Color(0.224, 0.714, 0.910, 1.0))
	)
	material_instance.set_shader_parameter(
		"secondary_color",
		Color.from_string(String(paint.get("secondary_color", "#1B3345")), Color(0.106, 0.200, 0.271, 1.0))
	)
	material_instance.set_shader_parameter(
		"accent_color",
		Color.from_string(String(paint.get("accent_color", "#E7F8FF")), Color(0.906, 0.973, 1.0, 1.0))
	)
	material_instance.set_shader_parameter("paint_strength", clampf(float(paint.get("strength", 0.0)), 0.0, 1.0))

	var mask_path := String(visual.get("paint_mask", ""))
	var masked := String(visual.get("paint_mode", "legacy_blue_bias")) == "rgb_mask" and not mask_path.is_empty()
	material_instance.set_shader_parameter("use_rgb_mask", masked)
	if masked:
		var mask_texture := load(mask_path) as Texture2D
		assert(mask_texture != null, "Ship paint mask must load: %s" % mask_path)
		material_instance.set_shader_parameter("paint_mask", mask_texture)

func _apply_model_layers(visual: Dictionary, render_scale: float) -> void:
	_configure_layer("details", String(visual.get("details_texture", "")), render_scale, 3, Color.WHITE)
	_configure_layer("emissive", String(visual.get("emissive_texture", "")), render_scale, 7, Color.WHITE)

func _apply_cosmetic_layers(loadout: Dictionary, render_scale: float) -> void:
	for entry in [
		{"category": "livery", "z": 4},
		{"category": "decal", "z": 5},
		{"category": "canopy", "z": 6},
		{"category": "body_kit", "z": 8},
	]:
		var category := String(entry["category"])
		var option := loadout.get(category, {}) as Dictionary
		var tint := Color.WHITE
		if category == "canopy":
			tint = Color.from_string(String(option.get("color", "#FFFFFF")), Color.WHITE)
		_configure_layer(category, String(option.get("texture", "")), render_scale, int(entry["z"]), tint)

func _configure_layer(layer_id: String, texture_path: String, render_scale: float, z: int, tint: Color) -> void:
	var sprite := _layer_sprites.get(layer_id) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "ShipLayer_%s" % layer_id
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		steering_visual.add_child(sprite)
		_layer_sprites[layer_id] = sprite

	sprite.z_index = z
	sprite.scale = Vector2.ONE * render_scale
	sprite.modulate = tint
	if texture_path.is_empty():
		sprite.visible = false
		sprite.texture = null
		return

	var texture := load(texture_path) as Texture2D
	assert(texture != null, "Ship layer texture must load: %s" % texture_path)
	sprite.texture = texture
	sprite.visible = true

func _configure_engine_sockets(sockets: Array, loadout: Dictionary) -> void:
	_clear_extra_engines()
	_engine_glows = [engine_glow]
	_engine_particles = [engine_particles]
	_engine_trails = [engine_trail]

	var socket_list := sockets
	if socket_list.is_empty():
		socket_list = [{"id": "main", "position": [0.0, 41.0]}]

	var trail := loadout.get("trail", {}) as Dictionary
	var engine_style := loadout.get("engine", trail) as Dictionary
	var glow_color := Color.from_string(
		String(engine_style.get("glow_color", trail.get("glow_color", "#55DFFF"))),
		Color(0.33, 0.87, 1.0, 1.0)
	)
	var particle_color := Color.from_string(
		String(engine_style.get("particle_color", engine_style.get("glow_color", "#55DFFF"))),
		glow_color
	)

	var primary_position := _socket_position(socket_list[0] as Dictionary)
	engine_anchor.position = primary_position
	engine_glow.position = primary_position + Vector2(0.0, -2.0)
	engine_particles.position = primary_position
	engine_trail.apply_style(trail)
	engine_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, engine_glow.modulate.a)
	engine_particles.color = Color(particle_color.r, particle_color.g, particle_color.b, 0.72)

	for index in range(1, socket_list.size()):
		var socket := socket_list[index] as Dictionary
		var position := _socket_position(socket)

		var anchor := Marker2D.new()
		anchor.name = "EngineAnchor_%d" % index
		anchor.position = position
		steering_visual.add_child(anchor)
		_extra_engine_nodes.append(anchor)

		var glow := engine_glow.duplicate() as Sprite2D
		glow.unique_name_in_owner = false
		glow.name = "EngineGlow_%d" % index
		glow.position = position + Vector2(0.0, -2.0)
		steering_visual.add_child(glow)
		_engine_glows.append(glow)
		_extra_engine_nodes.append(glow)

		var particles := engine_particles.duplicate() as CPUParticles2D
		particles.unique_name_in_owner = false
		particles.name = "EngineParticles_%d" % index
		particles.position = position
		steering_visual.add_child(particles)
		_engine_particles.append(particles)
		_extra_engine_nodes.append(particles)

		var trail_copy := engine_trail.duplicate() as EngineTrail
		trail_copy.unique_name_in_owner = false
		trail_copy.name = "EngineTrail_%d" % index
		trail_copy.source_path = anchor.get_path()
		get_parent().add_child(trail_copy)
		trail_copy.apply_style(trail)
		_engine_trails.append(trail_copy)
		_extra_engine_nodes.append(trail_copy)

func _socket_position(socket: Dictionary) -> Vector2:
	var values := socket.get("position", [0.0, 41.0]) as Array
	assert(values.size() == 2, "Ship engine socket position requires two values.")
	return Vector2(float(values[0]), float(values[1]))

func _clear_extra_engines() -> void:
	for node in _extra_engine_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_extra_engine_nodes.clear()

func update_motion(
	speed_ratio: float,
	thrust_ratio: float,
	facing_rotation: float,
	_turn_amount: float,
	_delta: float,
	boost_ratio: float = 0.0,
	motion_velocity: Vector2 = Vector2.ZERO
) -> void:
	# The hull points where thrust is being commanded, while the drift cue shows
	# the actual inertial trajectory. This is deliberately not the same thing.
	steering_visual.rotation = facing_rotation
	steering_visual.skew = 0.0
	steering_visual.scale = Vector2.ONE

	var boost := clampf(boost_ratio, 0.0, 1.0)
	var engine_strength := clampf(maxf(thrust_ratio, boost), 0.0, 1.0)
	for glow in _engine_glows:
		glow.modulate.a = clampf(lerpf(0.08, 0.76, engine_strength) + boost * 0.18, 0.0, 1.0)
		glow.scale = Vector2(
			0.84 + engine_strength * 0.18 + boost * 0.10,
			0.78 + engine_strength * 0.42 + boost * 0.34
		)
	for trail in _engine_trails:
		trail.set_intensity(maxf(engine_strength, boost))
	for particles in _engine_particles:
		particles.emitting = engine_strength > 0.08
		particles.speed_scale = 0.72 + engine_strength * 0.85 + boost * 0.62
		particles.modulate.a = clampf(lerpf(0.20, 0.88, engine_strength) + boost * 0.10, 0.0, 1.0)

	if motion_velocity.length_squared() > 64.0:
		_drift_direction = motion_velocity.normalized()
		_drift_intensity = clampf((speed_ratio - 0.12) / 0.88, 0.0, 1.0)
	else:
		_drift_direction = Vector2.ZERO
		_drift_intensity = 0.0
	queue_redraw()

func play_boost() -> void:
	for trail in _engine_trails:
		trail.set_intensity(1.0)
	for particles in _engine_particles:
		particles.restart()

func play_bump(intensity: float, normal: Vector2) -> void:
	var strength := clampf(intensity, 0.0, 1.0)

	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()

	scale = Vector2(1.0 + 0.04 * strength, 1.0 - 0.035 * strength)
	ship_sprite.modulate = Color(1.0, 0.90, 0.68, 1.0)

	_impact_tween = create_tween()
	_impact_tween.set_parallel(true)
	_impact_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(ship_sprite, "modulate", Color.WHITE, 0.16)

	bump_particles.global_rotation = normal.angle()
	bump_particles.amount = 6 + int(round(strength * 6.0))
	bump_particles.restart()

func _draw() -> void:
	if _drift_direction == Vector2.ZERO or _drift_intensity <= 0.01:
		return

	var alpha := 0.10 + _drift_intensity * 0.18
	var start := _drift_direction * 43.0
	var tip := _drift_direction * (50.0 + _drift_intensity * 7.0)
	var perpendicular := _drift_direction.orthogonal()
	var color := Color(0.45, 0.88, 1.0, alpha)
	draw_line(start, tip, color, 1.35, true)
	draw_line(tip, tip - _drift_direction * 5.0 + perpendicular * 3.2, color, 1.2, true)
	draw_line(tip, tip - _drift_direction * 5.0 - perpendicular * 3.2, color, 1.2, true)
