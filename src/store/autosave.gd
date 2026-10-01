class_name Autosave
extends Node
## Keeps a copy of unsaved work in user://, written DELAY_SECONDS after the
## last edit, so a crash or a forced quit never loses it. The copy is removed
## as soon as the project is saved or replaced.

const PROJECT_PATH := "user://autosave.json"
const META_PATH := "user://autosave.cfg"
const DELAY_SECONDS := 2.0
const SECTION := "autosave"

var store: Node
var project_path := PROJECT_PATH
var meta_path := META_PATH
var delay := DELAY_SECONDS
var _timer: Timer


func _init() -> void:
	name = "Autosave"
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(flush)
	add_child(_timer)


## Starts watching the store. Call it only after deciding what to do with a
## pending copy: replacing the project clears the copy.
func start(p_store: Node) -> void:
	store = p_store
	if not store.edited.is_connected(_on_edited):
		store.edited.connect(_on_edited)
		store.dirty_changed.connect(_on_dirty_changed)


func has_pending() -> bool:
	return FileAccess.file_exists(project_path)


## The file the pending copy was a modified version of ("" if untitled).
func pending_source_path() -> String:
	var meta := ConfigFile.new()
	if meta.load(meta_path) != OK:
		return ""
	return str(meta.get_value(SECTION, "source_path", ""))


func is_scheduled() -> bool:
	return not _timer.is_stopped()


## Writes the copy now. Returns the write error, if any.
func flush() -> Error:
	_timer.stop()
	var file := FileAccess.open(project_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(ProjectSerializer.to_json(store.project))
	file.close()
	var meta := ConfigFile.new()
	meta.set_value(SECTION, "source_path", store.current_path)
	meta.set_value(SECTION, "saved_at", Time.get_unix_time_from_system())
	return meta.save(meta_path)


## Loads the pending copy into `target` (the store, before start()).
func restore_into(target: Node) -> PackedStringArray:
	if not has_pending():
		return PackedStringArray(["aucune sauvegarde automatique"])
	return target.restore_from_text(FileAccess.get_file_as_string(project_path), pending_source_path())


func clear() -> void:
	_timer.stop()
	for path in [project_path, meta_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _on_edited() -> void:
	if store.is_dirty():
		_timer.start(delay)


func _on_dirty_changed(dirty: bool) -> void:
	if not dirty:
		clear()
