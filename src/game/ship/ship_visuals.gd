extends Node2D
class_name ShipVisuals

@onready var steering_visual: Node2D = %SteeringVisual
@onready var ship_sprite: Sprite2D = %ShipSprite
@onready var engine_glow: Sprite2D = %EngineGlow
@onready var engine_trail: EngineTrail = %EngineTrail
@onready var engine_particles: CPUParticles2D = %EngineParticles
@onready var bump_particles: CPUParticles2D = %BumpParticles

var _impact_tween: Tween
var _drift_direction := Vector2.ZERO
var _drift_intensity := 0.0

func apply_cosmetics(loadout: Dictionary) -> void:
	assert(loadout.has("hull") and loadout.has("paint") and loadout.has("trail"), "ShipVisuals requires hull, paint and trail cosmetics.")

	var hull := loadout["hull"] as Dictionary
	var paint := loadout["paint"] as Dictionary
	var trail := loadout["trail"] as Dictionary

	var texture_path := String(hull.get("texture", ""))
	assert(not texture_path.is_empty(), "Hull cosmetic requires texture.")
	var hull_texture := load(texture_path) as Texture2D
	assert(hull_texture != null, "Hull texture must load: %s" % texture_path)
	ship_sprite.texture = hull_texture

	var material_instance := ship_sprite.material as ShaderMaterial
	assert(material_instance != null, "ShipSprite requires paint ShaderMaterial.")
	material_instance.set_shader_parameter(
		"paint_color",
		Color.from_string(String(paint.get("color", "#39B6E8")), Color(0.224, 0.714, 0.910, 1.0))
	)
	material_instance.set_shader_parameter("paint_strength", clampf(float(paint.get("strength", 0.0)), 0.0, 1.0))

	engine_trail.apply_style(trail)
	var glow_color := Color.from_string(String(trail.get("glow_color", "#55DFFF")), Color(0.33, 0.87, 1.0, 1.0))
	engine_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, engine_glow.modulate.a)
	engine_particles.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.72)

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
	engine_glow.modulate.a = clampf(lerpf(0.08, 0.76, engine_strength) + boost * 0.18, 0.0, 1.0)
	engine_glow.scale = Vector2(
		0.84 + engine_strength * 0.18 + boost * 0.10,
		0.78 + engine_strength * 0.42 + boost * 0.34
	)
	engine_trail.set_intensity(maxf(engine_strength, boost))
	engine_particles.emitting = engine_strength > 0.08
	engine_particles.speed_scale = 0.72 + engine_strength * 0.85 + boost * 0.62
	engine_particles.modulate.a = clampf(lerpf(0.20, 0.88, engine_strength) + boost * 0.10, 0.0, 1.0)

	if motion_velocity.length_squared() > 64.0:
		_drift_direction = motion_velocity.normalized()
		_drift_intensity = clampf((speed_ratio - 0.12) / 0.88, 0.0, 1.0)
	else:
		_drift_direction = Vector2.ZERO
		_drift_intensity = 0.0
	queue_redraw()

func play_boost() -> void:
	engine_trail.set_intensity(1.0)
	engine_particles.restart()

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
