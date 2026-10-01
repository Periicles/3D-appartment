extends Node
## Autoload holding the open project. Views never edit the data directly:
## they call the store and react to its signals. Every edit goes through
## Godot's UndoRedo so it can be undone.

signal project_loaded
## Any change to the edit history (edit, undo, redo); the autosave listens to it.
signal edited
signal dirty_changed(dirty: bool)
signal path_changed(path: String)
signal furniture_added(id: String)
signal furniture_changed(id: String)
signal furniture_removed(id: String)

## Fields of a FurnitureItem that update_furniture accepts.
const EDITABLE_FIELDS: PackedStringArray = ["name", "size", "color", "pos", "rotation_deg"]
## Offset of a duplicate from its original, so both stay visible.
const DUPLICATE_OFFSET := Vector2(0.3, 0.3)

var project: ProjectData = ProjectData.new()
## File the project was opened from or last saved to; "" for a new project.
var current_path := ""
var _history := UndoRedo.new()
## History version at the last open or save; -1 when restored unsaved work.
var _saved_version := 0


func _init() -> void:
	_saved_version = _history.get_version()
	_history.version_changed.connect(_on_version_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_history.free()


## True when the project has changes that are not saved to a file.
func is_dirty() -> bool:
	return _history.get_version() != _saved_version


## Replaces the open project with an empty one.
func new_project() -> void:
	_replace(ProjectData.new(), "")


## Replaces the open project with the file's content. With `as_template`, the
## file is only a starting point: the project stays untitled, so saving asks
## for a new path. On failure the current project is kept and the reasons are
## returned.
func load_from_file(path: String, as_template: bool = false) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray(["fichier introuvable : %s" % path])
	var result := ProjectSerializer.from_json(FileAccess.get_file_as_string(path))
	if not result.is_ok():
		return result.errors
	_replace(result.project, "" if as_template else path)
	return PackedStringArray()


## Reopens unsaved work (the autosave) as a modified version of `original_path`.
func restore_from_text(text: String, original_path: String) -> PackedStringArray:
	var result := ProjectSerializer.from_json(text)
	if not result.is_ok():
		return result.errors
	_replace(result.project, original_path, true)
	return PackedStringArray()


## Writes the project to `path` (through a temporary file, so a failed write
## never truncates an existing project) and makes it the current file. On
## failure nothing changes and the reasons are returned.
func save_to_file(path: String) -> PackedStringArray:
	var invalid := ProjectValidator.validate(project)
	if not invalid.is_empty():
		return invalid
	var error := _write_atomically(path, ProjectSerializer.to_json(project))
	if error != OK:
		return PackedStringArray(["écriture impossible : %s (%s)" % [path, error_string(error)]])
	current_path = path
	_saved_version = _history.get_version()
	path_changed.emit(path)
	dirty_changed.emit(false)
	return PackedStringArray()


func get_furniture(id: String) -> FurnitureItem:
	for item in project.furniture:
		if item.id == id:
			return item
	return null


## "f" followed by one more than the highest numbered "f<n>" id in use.
func next_furniture_id() -> String:
	var highest := 0
	for item in project.furniture:
		var suffix := item.id.substr(1)
		if item.id.begins_with("f") and suffix.is_valid_int():
			highest = maxi(highest, suffix.to_int())
	return "f%d" % (highest + 1)


## Adds a copy of `item`. Returns false (and changes nothing) if the item is
## invalid or its id is already used.
func add_furniture(item: FurnitureItem) -> bool:
	if get_furniture(item.id) != null or not _is_valid(item):
		return false
	var stored := item.copy()
	_history.create_action("Ajouter %s" % stored.name)
	_history.add_do_method(_insert.bind(stored, project.furniture.size()))
	_history.add_undo_method(_delete.bind(stored.id))
	_history.commit_action()
	return true


## Applies `changes` (keys from EDITABLE_FIELDS) to the item. Returns false
## (and changes nothing) for an unknown id, unknown field or invalid result.
func update_furniture(id: String, changes: Dictionary) -> bool:
	var item := get_furniture(id)
	if item == null or changes.is_empty():
		return false
	var previous := {}
	var preview := item.copy()
	for key in changes:
		if not key in EDITABLE_FIELDS:
			return false
		previous[key] = item.get(key)
		preview.set(key, changes[key])
	if not _is_valid(preview):
		return false
	_history.create_action("Modifier %s" % item.name)
	_history.add_do_method(_apply.bind(id, changes.duplicate()))
	_history.add_undo_method(_apply.bind(id, previous))
	_history.commit_action()
	return true


func remove_furniture(id: String) -> bool:
	var item := get_furniture(id)
	if item == null:
		return false
	var index := project.furniture.find(item)
	_history.create_action("Supprimer %s" % item.name)
	_history.add_do_method(_delete.bind(id))
	_history.add_undo_method(_insert.bind(item.copy(), index))
	_history.commit_action()
	return true


## Adds a copy of the item, offset by DUPLICATE_OFFSET. Returns the new id, or
## "" for an unknown id.
func duplicate_furniture(id: String) -> String:
	var item := get_furniture(id)
	if item == null:
		return ""
	var clone := item.copy()
	clone.id = next_furniture_id()
	clone.pos += DUPLICATE_OFFSET
	return clone.id if add_furniture(clone) else ""


func undo() -> bool:
	return _history.undo()


func redo() -> bool:
	return _history.redo()


func can_undo() -> bool:
	return _history.has_undo()


func can_redo() -> bool:
	return _history.has_redo()


func _replace(new_project_data: ProjectData, path: String, dirty := false) -> void:
	project = new_project_data
	current_path = path
	# Without a version bump: clearing is not an edit.
	_history.clear_history(false)
	_saved_version = -1 if dirty else _history.get_version()
	project_loaded.emit()
	path_changed.emit(path)
	dirty_changed.emit(dirty)


func _on_version_changed() -> void:
	edited.emit()
	dirty_changed.emit(is_dirty())


static func _write_atomically(path: String, text: String) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return write_error
	var error := DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


func _insert(item: FurnitureItem, index: int) -> void:
	project.furniture.insert(mini(index, project.furniture.size()), item.copy())
	furniture_added.emit(item.id)


func _delete(id: String) -> void:
	project.furniture.erase(get_furniture(id))
	furniture_removed.emit(id)


func _apply(id: String, values: Dictionary) -> void:
	var item := get_furniture(id)
	for key in values:
		item.set(key, values[key])
	furniture_changed.emit(id)


func _is_valid(item: FurnitureItem) -> bool:
	var probe := ProjectData.new()
	probe.furniture.append(item)
	return ProjectValidator.validate(probe).is_empty()
