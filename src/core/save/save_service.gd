extends Node
class_name SaveService

const SAVE_PATH := "user://save_v2.json"
const LEGACY_SAVE_PATH := "user://save_v1.json"
const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1

var _last_read_schema_version := -1
var _last_read_path := ""

func initialize() -> void:
	pass

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(LEGACY_SAVE_PATH)

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
	_last_read_schema_version = -1
	_last_read_path = ""

	if FileAccess.file_exists(SAVE_PATH):
		return _read_envelope(SAVE_PATH, SCHEMA_VERSION)

	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		return _read_envelope(LEGACY_SAVE_PATH, LEGACY_SCHEMA_VERSION)

	return {}

func get_last_read_schema_version() -> int:
	return _last_read_schema_version

func was_legacy_save_loaded() -> bool:
	return _last_read_schema_version == LEGACY_SCHEMA_VERSION

func get_last_read_path() -> String:
	return _last_read_path

func delete_save() -> Error:
	var first_error := OK
	for path in [SAVE_PATH, LEGACY_SAVE_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if error != OK and first_error == OK:
			first_error = error
	return first_error

func _read_envelope(path: String, expected_schema: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open save file for reading: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Save envelope is not a dictionary: %s" % path)
		return {}

	var envelope := parsed as Dictionary
	var schema := int(envelope.get("schema_version", -1))
	if schema != expected_schema:
		push_error("Unsupported save schema %s at %s" % [schema, path])
		return {}

	var payload = envelope.get("payload", {})
	if not payload is Dictionary:
		push_error("Save payload is not a dictionary: %s" % path)
		return {}

	_last_read_schema_version = schema
	_last_read_path = path
	return (payload as Dictionary).duplicate(true)
