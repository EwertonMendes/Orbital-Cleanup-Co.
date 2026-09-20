extends Node
class_name CargoHold

signal cargo_changed(used_units: int, capacity: int)
signal cargo_full
signal cargo_unloaded(units: int)

@export_range(1, 999, 1) var capacity := 12

var used_units := 0
var _manifest: Dictionary = {}

func can_accept(definition: SalvageDefinition) -> bool:
	return definition != null and used_units + definition.cargo_units <= capacity

func store(definition: SalvageDefinition) -> bool:
	if not can_accept(definition):
		return false

	used_units += definition.cargo_units
	var key := String(definition.id)
	_manifest[key] = int(_manifest.get(key, 0)) + 1
	cargo_changed.emit(used_units, capacity)

	if used_units >= capacity:
		cargo_full.emit()
	return true

func unload_all() -> int:
	if used_units <= 0:
		return 0

	var unloaded := used_units
	used_units = 0
	_manifest.clear()
	cargo_changed.emit(used_units, capacity)
	cargo_unloaded.emit(unloaded)
	return unloaded

func get_manifest() -> Dictionary:
	return _manifest.duplicate(true)

func get_free_units() -> int:
	return maxi(capacity - used_units, 0)
