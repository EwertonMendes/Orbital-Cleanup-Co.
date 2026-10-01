extends Node2D
class_name OperationalPerimeter

const SEGMENT_SPACING := 280.0
const SEGMENT_LENGTH := 172.0
const BEACON_SPACING := 560.0
const VISUAL_AWARENESS_PADDING := 360.0
const BASE_FIELD_ALPHA := 0.14
const BASE_BEACON_ALPHA := 0.34

var _play_bounds := Rect2()
var _accent_color := Color("#53d7f1")
var _field_color := Color("#53d7f1")
var _warning_color := Color("#ffd166")
var _effect_profile := "clean"
var _ship: PlayerShip
var _soft_margin := 320.0
var _hard_padding := 42.0
var _proximity := 0.0
var _awareness := 0.0
var _nearest_side := -1
var _nearest_distance := INF
var _animation_time := 0.0
var _redraw_elapsed := 0.0
var _was_animating := false

func configure(
	play_bounds: Rect2,
	palette: Dictionary,
	visual_profile: Dictionary,
	ship: PlayerShip,
	soft_margin: float,
	hard_padding: float
) -> void:
	assert(play_bounds.size.x > 0.0 and play_bounds.size.y > 0.0, "OperationalPerimeter requires valid play bounds.")
	assert(ship != null, "OperationalPerimeter requires PlayerShip.")
	assert(soft_margin > hard_padding, "OperationalPerimeter soft margin must exceed hard padding.")

	_play_bounds = play_bounds
	_accent_color = Color(String(palette.get("accent", "#53d7f1")))
	_effect_profile = WorldVisualLanguage.environment_effect_profile(visual_profile)
	_field_color = _resolve_field_color(_accent_color, _effect_profile)
	_warning_color = _resolve_warning_color(_effect_profile)
	_ship = ship
	_soft_margin = soft_margin
	_hard_padding = hard_padding
	_update_boundary_state()
	queue_redraw()

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if _ship == null or not is_instance_valid(_ship) or _play_bounds.size == Vector2.ZERO:
		return

	_animation_time = wrapf(_animation_time + delta, 0.0, 10000.0)
	_update_boundary_state()

	var should_animate := _nearest_distance <= _soft_margin + VISUAL_AWARENESS_PADDING
	_redraw_elapsed += delta
	if should_animate and _redraw_elapsed >= RuntimeQuality.ambient_redraw_interval():
		_redraw_elapsed = 0.0
		queue_redraw()
	elif should_animate != _was_animating:
		_redraw_elapsed = 0.0
		queue_redraw()
	_was_animating = should_animate

func _update_boundary_state() -> void:
	var position := _ship.global_position
	var distances := [
		position.x - _play_bounds.position.x,
		_play_bounds.end.x - position.x,
		position.y - _play_bounds.position.y,
		_play_bounds.end.y - position.y,
	]
	_nearest_side = 0
	_nearest_distance = float(distances[0])
	for index in range(1, distances.size()):
		var distance := float(distances[index])
		if distance < _nearest_distance:
			_nearest_distance = distance
			_nearest_side = index

	var usable_soft_range := maxf(_soft_margin - _hard_padding, 1.0)
	var physical_t := clampf(
		1.0 - (_nearest_distance - _hard_padding) / usable_soft_range,
		0.0,
		1.0
	)
	_proximity = smoothstep(0.0, 1.0, physical_t)

	var awareness_margin := _soft_margin + VISUAL_AWARENESS_PADDING
	var awareness_t := clampf(
		1.0 - (_nearest_distance - _hard_padding) / maxf(awareness_margin - _hard_padding, 1.0),
		0.0,
		1.0
	)
	_awareness = smoothstep(0.0, 1.0, awareness_t)

func _draw() -> void:
	if _play_bounds.size == Vector2.ZERO:
		return

	var left := _play_bounds.position.x
	var right := _play_bounds.end.x
	var top := _play_bounds.position.y
	var bottom := _play_bounds.end.y

	_draw_side(0, Vector2(left, top), Vector2(left, bottom), Vector2.RIGHT)
	_draw_side(1, Vector2(right, bottom), Vector2(right, top), Vector2.LEFT)
	_draw_side(2, Vector2(right, top), Vector2(left, top), Vector2.DOWN)
	_draw_side(3, Vector2(left, bottom), Vector2(right, bottom), Vector2.UP)

func _draw_side(side: int, start: Vector2, finish: Vector2, inward: Vector2) -> void:
	var tangent := (finish - start).normalized()
	var length := start.distance_to(finish)
	var local_focus := 1.0 if side == _nearest_side else 0.0
	var active_strength := maxf(_awareness * local_focus, 0.0)
	var field_alpha := BASE_FIELD_ALPHA + active_strength * 0.54
	var beacon_alpha := BASE_BEACON_ALPHA + active_strength * 0.58

	_draw_energy_band(start, finish, inward, field_alpha, active_strength)
	_draw_segmented_field(start, tangent, inward, length, field_alpha, active_strength)
	_draw_beacons(start, tangent, inward, length, beacon_alpha, active_strength)
	if active_strength > 0.02:
		_draw_scan_pulses(start, tangent, inward, length, active_strength)
		_draw_boundary_motes(start, tangent, inward, length, active_strength)
	if _proximity > 0.58 and side == _nearest_side:
		_draw_hard_limit_warning(start, tangent, inward, length)

func _draw_energy_band(
	start: Vector2,
	finish: Vector2,
	inward: Vector2,
	alpha: float,
	active_strength: float
) -> void:
	var quality := RuntimeQuality.visual_effects_factor()
	var outer_color := Color(_field_color, alpha * 0.14 * quality)
	var middle_color := Color(_field_color, alpha * 0.28 * quality)
	var core_color := Color(_field_color, alpha * (0.66 + active_strength * 0.22))

	draw_line(start + inward * 18.0, finish + inward * 18.0, outer_color, 54.0, true)
	draw_line(start + inward * 24.0, finish + inward * 24.0, middle_color, 22.0, true)
	draw_line(start + inward * 30.0, finish + inward * 30.0, core_color, 3.5 + active_strength * 2.5, true)

func _draw_segmented_field(
	start: Vector2,
	tangent: Vector2,
	inward: Vector2,
	length: float,
	alpha: float,
	active_strength: float
) -> void:
	var animation_offset := fmod(_animation_time * (38.0 + active_strength * 92.0), SEGMENT_SPACING)
	var cursor := -SEGMENT_SPACING + animation_offset
	var glow_width := 18.0 + active_strength * 14.0
	var core_width := 5.0 + active_strength * 2.5
	while cursor < length:
		var segment_start_distance := maxf(cursor, 0.0)
		var segment_end_distance := minf(cursor + SEGMENT_LENGTH, length)
		if segment_end_distance > segment_start_distance:
			var segment_start := start + tangent * segment_start_distance + inward * 30.0
			var segment_end := start + tangent * segment_end_distance + inward * 30.0
			draw_line(
				segment_start,
				segment_end,
				Color(_field_color, alpha * 0.22),
				glow_width,
				true
			)
			draw_line(
				segment_start,
				segment_end,
				Color(_field_color, minf(alpha * 1.08, 0.96)),
				core_width,
				true
			)
			var rail_start := segment_start + inward * 48.0
			var rail_end := segment_end + inward * 48.0
			draw_line(
				rail_start,
				rail_end,
				Color(_field_color, alpha * (0.18 + active_strength * 0.16)),
				2.0,
				true
			)
		cursor += SEGMENT_SPACING

func _draw_beacons(
	start: Vector2,
	tangent: Vector2,
	inward: Vector2,
	length: float,
	alpha: float,
	active_strength: float
) -> void:
	var count := maxi(int(floor(length / BEACON_SPACING)), 1)
	var spacing := length / float(count)
	for index in range(count + 1):
		var distance := minf(float(index) * spacing, length)
		var center := start + tangent * distance + inward * 34.0
		var pulse := 0.82 + 0.18 * sin(_animation_time * 2.4 + float(index) * 0.9)
		var beacon_alpha := clampf(alpha * pulse, 0.0, 1.0)
		_draw_beacon(center, tangent, inward, beacon_alpha, active_strength)

func _draw_beacon(
	center: Vector2,
	tangent: Vector2,
	inward: Vector2,
	alpha: float,
	active_strength: float
) -> void:
	var half_tangent := 10.0 + active_strength * 2.0
	var half_inward := 14.0 + active_strength * 3.0
	var diamond := PackedVector2Array([
		center - tangent * half_tangent,
		center - inward * half_inward,
		center + tangent * half_tangent,
		center + inward * half_inward,
		center - tangent * half_tangent,
	])
	draw_polyline(diamond, Color(_field_color, alpha), 3.0 + active_strength * 1.5, true)
	draw_circle(center, 3.0 + active_strength * 2.0, Color(_field_color, minf(alpha + 0.18, 1.0)))
	draw_line(
		center + inward * 18.0,
		center + inward * (64.0 + active_strength * 20.0),
		Color(_field_color, alpha * 0.44),
		2.0,
		true
	)
	_draw_inward_chevron(center + inward * 86.0, tangent, inward, alpha * 0.64, active_strength)

func _draw_inward_chevron(
	center: Vector2,
	tangent: Vector2,
	inward: Vector2,
	alpha: float,
	active_strength: float
) -> void:
	var half_width := 11.0 + active_strength * 3.0
	var depth := 13.0 + active_strength * 5.0
	var tip := center + inward * depth
	draw_line(center - tangent * half_width, tip, Color(_field_color, alpha), 2.4, true)
	draw_line(center + tangent * half_width, tip, Color(_field_color, alpha), 2.4, true)

func _draw_scan_pulses(
	start: Vector2,
	tangent: Vector2,
	inward: Vector2,
	length: float,
	active_strength: float
) -> void:
	var pulse_count := 2 if RuntimeQuality.is_constrained_render_target() else 4
	for index in range(pulse_count):
		var phase := fmod(
			_animation_time * (150.0 + active_strength * 110.0)
			+ float(index) * length / float(pulse_count),
			length
		)
		var center := start + tangent * phase + inward * 30.0
		var pulse_half := 44.0 + active_strength * 34.0
		draw_line(
			center - tangent * pulse_half,
			center + tangent * pulse_half,
			Color(_field_color, 0.16 + active_strength * 0.48),
			26.0 + active_strength * 18.0,
			true
		)
		draw_line(
			center - tangent * pulse_half * 0.72,
			center + tangent * pulse_half * 0.72,
			Color.WHITE.lerp(_field_color, 0.35),
			2.5 + active_strength * 2.0,
			true
		)

func _draw_boundary_motes(
	start: Vector2,
	tangent: Vector2,
	inward: Vector2,
	length: float,
	active_strength: float
) -> void:
	var mote_count := 8 if RuntimeQuality.is_constrained_render_target() else 16
	for index in range(mote_count):
		var seed := float(index) * 0.61803398875
		var along := fmod(seed * length + _animation_time * (21.0 + float(index % 3) * 7.0), length)
		var drift_phase := _animation_time * (1.2 + float(index % 4) * 0.17) + seed * TAU
		var depth := 58.0 + float(index % 5) * 22.0 + sin(drift_phase) * 18.0
		var position := start + tangent * along + inward * depth
		var radius := 1.5 + float(index % 3) * 0.8
		draw_circle(
			position,
			radius,
			Color(_field_color, (0.12 + active_strength * 0.34) * RuntimeQuality.visual_effects_factor())
		)

func _draw_hard_limit_warning(
	start: Vector2,
	tangent: Vector2,
	inward: Vector2,
	length: float
) -> void:
	var warning_strength := smoothstep(0.58, 1.0, _proximity)
	var warning_offset := _hard_padding + 4.0
	var warning_start := start + inward * warning_offset
	var cursor := fmod(_animation_time * 96.0, 180.0) - 180.0
	while cursor < length:
		var a := maxf(cursor, 0.0)
		var b := minf(cursor + 88.0, length)
		if b > a:
			draw_line(
				warning_start + tangent * a,
				warning_start + tangent * b,
				Color(_warning_color, 0.24 + warning_strength * 0.62),
				4.0 + warning_strength * 3.0,
				true
			)
		cursor += 180.0

func _resolve_field_color(accent: Color, profile: String) -> Color:
	match profile:
		"solar", "volcanic":
			return accent.lerp(Color("#ffd166"), 0.42)
		"anomaly", "electromagnetic", "deep_space":
			return accent.lerp(Color("#b68cff"), 0.32)
		"industrial", "debris", "graveyard":
			return accent.lerp(Color("#9bd8e8"), 0.24)
		"cryo", "gas", "ocean", "nebula", "crystal", "toxic", "remnant":
			return accent.lerp(Color("#8fe9ff"), 0.20)
		_:
			return accent

func _resolve_warning_color(profile: String) -> Color:
	match profile:
		"solar", "volcanic":
			return Color("#ff9f5c")
		"anomaly", "electromagnetic", "deep_space":
			return Color("#d8a6ff")
		_:
			return Color("#ffd166")
