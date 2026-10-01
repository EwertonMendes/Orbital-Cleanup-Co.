extends Control
class_name ShipSpeedometer

const SAMPLE_INTERVAL := 0.05
const SEGMENT_COUNT := 20
const ARC_START := PI * 0.72
const ARC_SWEEP := PI * 1.56

@onready var title_label: Label = %TitleLabel
@onready var speed_label: Label = %SpeedLabel
@onready var unit_label: Label = %UnitLabel
@onready var state_label: Label = %StateLabel

var _ship: PlayerShip
var _sample_clock := 0.0
var _display_world_speed := 0.0
var _normalized_speed := 0.0
var _cruise_ratio := 0.42

func configure(ship: PlayerShip) -> void:
	assert(ship != null, "ShipSpeedometer requires PlayerShip.")
	_ship = ship
	if is_node_ready():
		_refresh_copy()
		_refresh_sample(true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_copy()
	_refresh_sample(true)

func _process(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	_sample_clock += delta
	if _sample_clock < SAMPLE_INTERVAL:
		return
	var sample_delta := _sample_clock
	_sample_clock = 0.0
	var target_speed := _ship.velocity.length()
	var smoothing := 1.0 - exp(-9.0 * sample_delta)
	_display_world_speed = lerpf(_display_world_speed, target_speed, smoothing)
	_refresh_sample(false)

func _refresh_sample(force: bool) -> void:
	if _ship == null or _ship.tuning == null:
		speed_label.text = "0"
		state_label.text = tr("FLIGHT_SPEED_IDLE")
		return

	var cruise_speed := maxf(_ship.tuning.max_speed, 1.0)
	var safety_speed := maxf(_ship.tuning.absolute_speed_limit, cruise_speed + 1.0)
	_cruise_ratio = clampf(cruise_speed / safety_speed, 0.08, 0.92)
	var next_normalized := clampf(_display_world_speed / safety_speed, 0.0, 1.0)
	var changed := force or absf(next_normalized - _normalized_speed) >= 0.004
	_normalized_speed = next_normalized

	speed_label.text = FlightTelemetryUnits.format_speed_kmh(_display_world_speed)
	if _display_world_speed < 8.0:
		state_label.text = tr("FLIGHT_SPEED_IDLE")
	elif _display_world_speed <= cruise_speed:
		state_label.text = tr("FLIGHT_SPEED_CRUISE")
	else:
		state_label.text = tr("FLIGHT_SPEED_OVERSPEED")

	if changed:
		queue_redraw()

func _refresh_copy() -> void:
	if not is_node_ready():
		return
	title_label.text = tr("FLIGHT_SPEED")
	unit_label.text = tr("FLIGHT_SPEED_UNIT")

func _draw() -> void:
	var center := Vector2(49.0, size.y * 0.5)
	var radius := minf(31.0, maxf(size.y * 0.30, 24.0))
	var inactive := Color(0.35, 0.47, 0.55, 0.30)
	var active := Color(0.40, 0.89, 1.0, 0.92)
	var overspeed := Color(1.0, 0.75, 0.28, 0.96)

	for index in range(SEGMENT_COUNT):
		var ratio_start := float(index) / float(SEGMENT_COUNT)
		var ratio_end := float(index + 1) / float(SEGMENT_COUNT)
		var angle_start := ARC_START + ARC_SWEEP * ratio_start
		var angle_end := ARC_START + ARC_SWEEP * (ratio_end - 0.012)
		var lit := ratio_end <= _normalized_speed + 0.001
		var segment_color := inactive
		if lit:
			segment_color = overspeed if ratio_start >= _cruise_ratio else active
		draw_arc(center, radius, angle_start, angle_end, 5, segment_color, 3.2, true)

	var cruise_angle := ARC_START + ARC_SWEEP * _cruise_ratio
	var cruise_inner := center + Vector2.from_angle(cruise_angle) * (radius - 6.0)
	var cruise_outer := center + Vector2.from_angle(cruise_angle) * (radius + 5.0)
	draw_line(cruise_inner, cruise_outer, Color(1.0, 0.78, 0.34, 0.82), 1.5, true)

	var needle_angle := ARC_START + ARC_SWEEP * _normalized_speed
	var needle_tip := center + Vector2.from_angle(needle_angle) * (radius - 10.0)
	draw_line(center, needle_tip, Color(0.82, 0.97, 1.0, 0.92), 1.8, true)
	draw_circle(center, 3.2, Color(0.58, 0.92, 1.0, 0.96))
