extends RefCounted
class_name FlightTelemetryUnits

# Presentation-only flight scale.
#
# One Godot world unit is intentionally not treated as one literal meter.
# Mapping it to 25 m gives the current 300 wu/s cruise reference a displayed
# orbital speed of 27,000 km/h, close to low-Earth-orbit spacecraft velocity,
# while keeping sectors compact and readable as a game space.
const WORLD_UNIT_METERS := 25.0
const METERS_PER_KILOMETER := 1000.0
const SECONDS_PER_HOUR := 3600.0

static func speed_kmh(world_units_per_second: float) -> float:
	return (
		maxf(world_units_per_second, 0.0)
		* WORLD_UNIT_METERS
		/ METERS_PER_KILOMETER
		* SECONDS_PER_HOUR
	)

static func distance_km(world_units: float) -> float:
	return maxf(world_units, 0.0) * WORLD_UNIT_METERS / METERS_PER_KILOMETER

static func format_speed_kmh(world_units_per_second: float) -> String:
	return _group_integer(int(round(speed_kmh(world_units_per_second))))

static func format_distance(world_units: float) -> String:
	var kilometers := distance_km(world_units)
	if kilometers < 1.0:
		var meters := int(round(kilometers * METERS_PER_KILOMETER / 10.0)) * 10
		return TranslationServer.translate("FLIGHT_DISTANCE_M_FMT") % meters
	if kilometers < 100.0:
		return TranslationServer.translate("FLIGHT_DISTANCE_KM_FMT") % kilometers
	return TranslationServer.translate("FLIGHT_DISTANCE_KM_LONG_FMT") % int(round(kilometers))

static func _group_integer(value: int) -> String:
	var raw := str(maxi(value, 0))
	var output := ""
	var digits := 0
	for index in range(raw.length() - 1, -1, -1):
		if digits > 0 and digits % 3 == 0:
			output = " " + output
		output = raw[index] + output
		digits += 1
	return output
