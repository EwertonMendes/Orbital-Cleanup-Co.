extends Area2D
class_name UnloadZone

signal cargo_unloaded(units: int)

@export_range(60.0, 400.0, 5.0) var radius := 145.0

var _pulse := 0.0
var _unload_flash := 0.0
var _cargo_full := false
var _redraw_accumulator := 0.0

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
	_unload_flash = maxf(_unload_flash - delta * 2.8, 0.0)
	_redraw_accumulator += delta
	if _redraw_accumulator >= 1.0 / 20.0:
		_redraw_accumulator = 0.0
		queue_redraw()

func set_cargo_state(used_units: int, capacity: int) -> void:
	var next_full := capacity > 0 and used_units >= capacity
	if next_full == _cargo_full:
		return
	_cargo_full = next_full
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var ship := body as PlayerShip
	if ship == null:
		return

	var unloaded := ship.unload_cargo()
	if unloaded <= 0:
		return

	_unload_flash = 1.0
	cargo_unloaded.emit(unloaded)
	print("[Cargo] UNLOAD units=%d" % unloaded)

func _draw() -> void:
	var pulse_alpha := 0.20 + (sin(_pulse) + 1.0) * 0.045
	var beacon_color := Color("#ffc857") if _cargo_full else Color("#8ff2c7")
	draw_circle(Vector2.ZERO, radius, Color(0.18, 0.82, 0.72, 0.035))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.48, 0.96, 0.78, pulse_alpha + 0.18), 2.5, true)
	draw_arc(Vector2.ZERO, radius - 16.0, 0.0, TAU, 72, Color(0.27, 0.70, 0.82, 0.15), 1.0, true)

	for index in range(6):
		var start := _pulse * 0.16 + float(index) * TAU / 6.0
		draw_arc(
			Vector2.ZERO,
			radius + 9.0,
			start,
			start + 0.22,
			8,
			Color(0.56, 0.95, 0.81, 0.32 + _unload_flash * 0.34),
			2.0 + _unload_flash * 1.8,
			true
		)

	for index in range(4):
		var angle := _pulse * 0.24 + float(index) * PI * 0.5
		var beacon := Vector2.from_angle(angle) * (radius - 28.0)
		draw_circle(beacon, 2.5 + _unload_flash * 2.0, Color(beacon_color, 0.68))

	if _cargo_full:
		draw_arc(Vector2.ZERO, radius + 22.0, 0.0, TAU, 36, Color(beacon_color, 0.20), 2.0, true)

	if _unload_flash > 0.0:
		var flash_radius := lerpf(radius * 0.65, radius * 1.32, 1.0 - _unload_flash)
		draw_arc(Vector2.ZERO, flash_radius, 0.0, TAU, 64, Color(0.56, 0.95, 0.81, _unload_flash * 0.58), 3.0, true)
