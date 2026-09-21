extends Node2D
class_name ShipVisuals

@onready var steering_visual: Node2D = %SteeringVisual
@onready var ship_sprite: Sprite2D = %ShipSprite
@onready var engine_glow: Sprite2D = %EngineGlow
@onready var engine_trail: EngineTrail = %EngineTrail
@onready var engine_particles: CPUParticles2D = %EngineParticles
@onready var bump_particles: CPUParticles2D = %BumpParticles

var _impact_tween: Tween

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
	_delta: float
) -> void:
	# Keep the ship silhouette rigid. Continuous skew/scale changes on a small
	# raster sprite cause visible shimmer while steering in Web builds.
	steering_visual.rotation = facing_rotation
	steering_visual.skew = 0.0
	steering_visual.scale = Vector2.ONE

	var engine_strength := clampf(maxf(thrust_ratio, speed_ratio * 0.52), 0.0, 1.0)
	engine_glow.modulate.a = lerpf(0.16, 0.76, engine_strength)
	engine_glow.scale = Vector2(0.84 + engine_strength * 0.18, 0.78 + engine_strength * 0.42)
	engine_trail.set_intensity(engine_strength)
	engine_particles.emitting = engine_strength > 0.08
	engine_particles.speed_scale = 0.72 + engine_strength * 0.85
	engine_particles.modulate.a = lerpf(0.24, 0.88, engine_strength)

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
