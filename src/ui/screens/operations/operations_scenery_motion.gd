extends Control

@onready var station: TextureRect = $Station
@onready var satellite: TextureRect = $Satellite

var _phase := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_pivots()
	if not resized.is_connected(_update_pivots):
		resized.connect(_update_pivots)

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU * 100.0)
	station.rotation = sin(_phase * 0.16) * 0.012
	satellite.rotation = sin(_phase * 0.31 + 1.2) * 0.045
	station.modulate.a = 0.075 + (sin(_phase * 0.22) + 1.0) * 0.012
	satellite.modulate.a = 0.075 + (sin(_phase * 0.52 + 0.8) + 1.0) * 0.018

func _update_pivots() -> void:
	station.pivot_offset = station.size * 0.5
	satellite.pivot_offset = satellite.size * 0.5
