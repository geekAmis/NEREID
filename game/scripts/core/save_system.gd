extends Node
## JSON-сохранения и настройки. Только примитивы, никаких NodePath/Resource.

const SETTINGS_PATH := "user://settings.json"
const SAVE_PATH := "user://nereid_save.json"
const PHOTO_DIR := "user://photos"
const SAVE_VERSION := 1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(state: Dictionary) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": state,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed
	if int(payload.get("version", 0)) != SAVE_VERSION:
		push_warning("Save version mismatch; ignoring.")
		return {}
	var state: Variant = payload.get("state", {})
	return state if typeof(state) == TYPE_DICTIONARY else {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func save_settings(settings: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(settings, "\t"))
	f.close()

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func photo_path(index: int) -> String:
	return "%s/photo_%03d.png" % [PHOTO_DIR, index]

func next_photo_index() -> int:
	var best := 0
	var dir := DirAccess.open(PHOTO_DIR)
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.begins_with("photo_") and name.ends_with(".png"):
				var digits := name.substr(6, name.length() - 10)
				if digits.is_valid_int():
					best = maxi(best, digits.to_int())
			name = dir.get_next()
		dir.list_dir_end()
	return best + 1

func list_photos() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(PHOTO_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".png"):
			result.append("%s/%s" % [PHOTO_DIR, name])
		name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
