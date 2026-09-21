extends Node2D
class_name WorldBurst

@onready var particles: CPUParticles2D = %Particles

var _life := 0.0
var _duration := 0.62
var _color := Color.WHITE
var _intensity := 1.0

func play(color: Color, intensity: float = 1.0) -> void:
	_color = color
	_intensity = clampf(intensity, 0.4, 2.2)
	_life = 0.0
	particles.amount = 9 + int(round(9.0 * _intensity))
	particles.color = Color(_color, 0.92)
	particles.initial_velocity_min = 52.0 * _intensity
	particles.initial_velocity_max = 118.0 * _intensity
	particles.scale_amount_min = 0.055
	particles.scale_amount_max = 0.13 + 0.035 * _intensity
	particles.restart()
	set_process(true)
	queue_redraw()

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	_life += delta
	queue_redraw()
	if _life >= _duration:
		queue_free()

func _draw() -> void:
	var t := clampf(_life / _duration, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - t, 3.0)
	var radius := lerpf(8.0, 62.0 * _intensity, ease)
	var alpha := (1.0 - t) * 0.62
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(_color, alpha), maxf(1.0, 3.0 * (1.0 - t)), true)
	draw_circle(Vector2.ZERO, maxf(0.0, 11.0 * (1.0 - t)), Color(_color, alpha * 0.18))
