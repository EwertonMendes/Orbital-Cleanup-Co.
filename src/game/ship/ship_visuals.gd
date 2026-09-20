extends Node2D
class_name ShipVisuals

@onready var steering_visual: Node2D = %SteeringVisual
@onready var ship_sprite: Sprite2D = %ShipSprite
@onready var engine_glow: Sprite2D = %EngineGlow
@onready var engine_trail: EngineTrail = %EngineTrail
@onready var bump_particles: CPUParticles2D = %BumpParticles

var _impact_tween: Tween

func update_motion(
	speed_ratio: float,
	thrust_ratio: float,
	facing_rotation: float,
	turn_amount: float,
	delta: float
) -> void:
	steering_visual.rotation = facing_rotation

	var visual_weight := 1.0 - exp(-8.0 * delta)
	var target_skew := -turn_amount * 0.055
	steering_visual.skew = lerpf(steering_visual.skew, target_skew, visual_weight)

	var turn_compression := absf(turn_amount) * 0.03
	var target_scale := Vector2(1.0 - turn_compression, 1.0 + turn_compression * 0.35)
	steering_visual.scale = steering_visual.scale.lerp(target_scale, visual_weight)

	var engine_strength := clampf(maxf(thrust_ratio, speed_ratio * 0.40), 0.0, 1.0)
	engine_glow.modulate.a = lerpf(0.10, 0.68, engine_strength)
	engine_glow.scale = Vector2(0.82 + engine_strength * 0.22, 0.72 + engine_strength * 0.45)
	engine_trail.set_intensity(engine_strength)

func play_bump(intensity: float, normal: Vector2) -> void:
	var strength := clampf(intensity, 0.0, 1.0)

	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()

	scale = Vector2(1.0 + 0.055 * strength, 1.0 - 0.045 * strength)
	ship_sprite.modulate = Color(1.0, 0.88, 0.62, 1.0)

	_impact_tween = create_tween()
	_impact_tween.set_parallel(true)
	_impact_tween.tween_property(self, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(ship_sprite, "modulate", Color.WHITE, 0.17)

	bump_particles.global_rotation = normal.angle()
	bump_particles.amount = 6 + int(round(strength * 6.0))
	bump_particles.restart()
