extends RefCounted
class_name EnvironmentSample

var linear_acceleration := Vector2.ZERO
var external_force := Vector2.ZERO
var salvage_force := Vector2.ZERO
var linear_drag := 0.0
var thrust_multiplier := 1.0
var scanner_multiplier := 1.0
var tractor_multiplier := 1.0
var visibility := 1.0
var dominant_intensity := 0.0
var label_key := "ENV_STABLE_ORBIT"

func combine(other: EnvironmentSample) -> void:
	if other == null or other.dominant_intensity <= 0.0:
		return

	linear_acceleration += other.linear_acceleration
	external_force += other.external_force
	salvage_force += other.salvage_force
	linear_drag += other.linear_drag
	thrust_multiplier *= other.thrust_multiplier
	scanner_multiplier *= other.scanner_multiplier
	tractor_multiplier *= other.tractor_multiplier
	visibility = minf(visibility, other.visibility)

	if other.dominant_intensity > dominant_intensity:
		dominant_intensity = other.dominant_intensity
		label_key = other.label_key

func finalize_limits() -> void:
	linear_acceleration = linear_acceleration.limit_length(460.0)
	external_force = external_force.limit_length(360.0)
	salvage_force = salvage_force.limit_length(180.0)
	linear_drag = clampf(linear_drag, 0.0, 1.8)
	thrust_multiplier = clampf(thrust_multiplier, 0.65, 1.15)
	scanner_multiplier = clampf(scanner_multiplier, 0.46, 1.0)
	tractor_multiplier = clampf(tractor_multiplier, 0.52, 1.0)
	visibility = clampf(visibility, 0.46, 1.0)
