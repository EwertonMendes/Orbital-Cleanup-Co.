extends Node
class_name SaveService

const SAVE_PATH := "user://save_v1.json"
const SCHEMA_VERSION := 1

func initialize() -> void:
	pass

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func write_state(payload: Dictionary) -> Error:
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"payload": payload,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("Could not open save file for writing: %s" % error)
		return error
	file.store_string(JSON.stringify(envelope))
	return OK

func read_state() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open save file for reading.")
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Save envelope is not a dictionary.")
		return {}

	var envelope := parsed as Dictionary
	var schema := int(envelope.get("schema_version", -1))
	if schema != SCHEMA_VERSION:
		push_error("Unsupported save schema: %s" % schema)
		return {}

	var payload = envelope.get("payload", {})
	if not payload is Dictionary:
		push_error("Save payload is not a dictionary.")
		return {}
	return payload as Dictionary

func delete_save() -> Error:
	if not has_save():
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
