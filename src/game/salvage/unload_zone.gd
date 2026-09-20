extends Area2D
class_name UnloadZone

signal cargo_unloaded(units: int)

@export_range(60.0, 400.0, 5.0) var radius := 145.0

var _pulse := 0.0

func _ready() -> void:
	var collision := get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D
	assert(circle != null, "UnloadZone requires CircleShape2D.")
	circle.radius = radius
	body_entered.connect(_on_body_entered)
	%DepotLabel.text = tr("FLIGHT_DEPOT")
	queue_redraw()

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 1.8, TAU)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var ship := body as PlayerShip
	if ship == null:
		return

	var unloaded := ship.unload_cargo()
	if unloaded <= 0:
		return

	cargo_unloaded.emit(unloaded)
	print("[Cargo] UNLOAD units=%d" % unloaded)

func _draw() -> void:
	var pulse_alpha := 0.20 + (sin(_pulse) + 1.0) * 0.045
	draw_circle(Vector2.ZERO, radius, Color(0.18, 0.82, 0.72, 0.035))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.48, 0.96, 0.78, pulse_alpha + 0.18), 2.5, true)
	draw_arc(Vector2.ZERO, radius - 16.0, 0.0, TAU, 72, Color(0.27, 0.70, 0.82, 0.15), 1.0, true)
