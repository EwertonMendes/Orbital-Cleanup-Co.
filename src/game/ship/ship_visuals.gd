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
