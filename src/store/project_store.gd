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
## Corners, walls, openings or rooms changed (edit, undo or redo).
signal structure_changed
signal edit_mode_changed(mode: EditMode)

## Furniture and structure are edited in separate modes, so a stray click or
## key in one never changes the other.
enum EditMode { FURNITURE, STRUCTURE }

## Fields of a FurnitureItem that update_furniture accepts.
const EDITABLE_FIELDS: PackedStringArray = ["name", "size", "color", "pos", "rotation_deg"]
## Offset of a duplicate from its original, so both stay visible.
const DUPLICATE_OFFSET := Vector2(0.3, 0.3)
## Fields of a Wall that update_wall accepts; "length" moves the end node `b`.
const WALL_FIELDS: PackedStringArray = ["length", "thickness", "height"]
## Shortest wall an edit may leave, in metres (shorter ones have no footprint).
const MIN_WALL_LENGTH := 0.05
## Undo actions named with this prefix edit the structure; undoing or redoing
## one switches to the Structure mode, so the change happens where it is seen.
const STRUCTURE_ACTION_PREFIX := "Structure : "

var project: ProjectData = ProjectData.new()
## File the project was opened from or last saved to; "" for a new project.
var current_path := ""
var _history := UndoRedo.new()
## History version at the last open or save; -1 when restored unsaved work.
var _saved_version := 0
var edit_mode := EditMode.FURNITURE


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
	var error := AtomicFile.write(path, ProjectSerializer.to_json(project))
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


## Adds a copy of `item`. Returns false (and changes nothing) outside the
## Furniture mode, or if the item is invalid or its id is already used.
func add_furniture(item: FurnitureItem) -> bool:
	if edit_mode != EditMode.FURNITURE or get_furniture(item.id) != null or not _is_valid(item):
		return false
	var stored := item.copy()
	_begin_action("Ajouter %s" % stored.name)
	_history.add_do_method(_insert.bind(stored, project.furniture.size()))
	_history.add_undo_method(_delete.bind(stored.id))
	_history.commit_action()
	return true


## Applies `changes` (keys from EDITABLE_FIELDS) to the item. Returns false
## (and changes nothing) for an unknown id, unknown field or invalid result.
func update_furniture(id: String, changes: Dictionary) -> bool:
	var item := get_furniture(id)
	if edit_mode != EditMode.FURNITURE or item == null or changes.is_empty():
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
	_begin_action("Modifier %s" % item.name)
	_history.add_do_method(_apply.bind(id, changes.duplicate()))
	_history.add_undo_method(_apply.bind(id, previous))
	_history.commit_action()
	return true


func remove_furniture(id: String) -> bool:
	var item := get_furniture(id)
	if edit_mode != EditMode.FURNITURE or item == null:
		return false
	var index := project.furniture.find(item)
	_begin_action("Supprimer %s" % item.name)
	_history.add_do_method(_delete.bind(id))
	_history.add_undo_method(_insert.bind(item.copy(), index))
	_history.commit_action()
	return true


## Adds a copy of the item, offset by DUPLICATE_OFFSET. Returns the new id, or
## "" for an unknown id.
func duplicate_furniture(id: String) -> String:
	var item := get_furniture(id)
	if edit_mode != EditMode.FURNITURE or item == null:
		return ""
	var clone := item.copy()
	clone.id = next_furniture_id()
	clone.pos += DUPLICATE_OFFSET
	return clone.id if add_furniture(clone) else ""


func set_edit_mode(mode: EditMode) -> void:
	if mode == edit_mode:
		return
	edit_mode = mode
	edit_mode_changed.emit(mode)


## Moves a corner, dragging every wall joined to it. Returns false (and changes
## nothing) outside the Structure mode, for an unknown id, or when a wall would
## become too short or an opening would no longer fit.
func move_node(id: String, pos: Vector2) -> bool:
	var node := project.get_plan_node(id)
	if node == null or node.pos.is_equal_approx(pos):
		return false
	return _edit_structure("déplacer un coin", _set_node_pos.bind(id, pos))


## True when move_node(id, pos) would be accepted (live drag feedback).
func can_move_node(id: String, pos: Vector2) -> bool:
	var probe := project.copy()
	return probe.get_plan_node(id) != null and _set_node_pos(probe, id, pos) and _is_buildable(probe)


## Applies `changes` (keys from WALL_FIELDS, in metres) to the wall. A new
## length moves its end node `b` along the wall. Same refusals as move_node.
func update_wall(id: String, changes: Dictionary) -> bool:
	if project.get_wall(id) == null or changes.is_empty():
		return false
	for key in changes:
		if not key in WALL_FIELDS:
			return false
	return _edit_structure("modifier un mur", _set_wall_fields.bind(id, changes.duplicate()))


## Deletes the wall and the openings it carries. Corners left without any wall
## or room are deleted too.
func remove_wall(id: String) -> bool:
	if project.get_wall(id) == null:
		return false
	return _edit_structure("supprimer un mur", _delete_wall.bind(id))


## Undoes the last edit, first switching to the mode it was made in.
func undo() -> bool:
	if not _history.has_undo():
		return false
	_follow_action(_history.get_current_action_name())
	return _history.undo()


func redo() -> bool:
	if not _history.has_redo():
		return false
	_follow_action(_history.get_action_name(_history.get_current_action() + 1))
	return _history.redo()


func can_undo() -> bool:
	return _history.has_undo()


func can_redo() -> bool:
	return _history.has_redo()


func _replace(new_project_data: ProjectData, path: String, dirty := false) -> void:
	project = new_project_data
	current_path = path
	set_edit_mode(EditMode.FURNITURE)
	# Without a version bump: clearing is not an edit.
	_history.clear_history(false)
	_saved_version = -1 if dirty else _history.get_version()
	project_loaded.emit()
	path_changed.emit(path)
	dirty_changed.emit(dirty)


## Opens an undo action. A new edit discards the redo branch; if the saved
## state lives in it, the project can never be clean again (the version number
## would be reused by different content).
func _begin_action(action_name: String) -> void:
	if _saved_version > _history.get_version():
		_saved_version = -1
	_history.create_action(action_name)


func _on_version_changed() -> void:
	edited.emit()
	dirty_changed.emit(is_dirty())


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


func _follow_action(action_name: String) -> void:
	var structure := action_name.begins_with(STRUCTURE_ACTION_PREFIX)
	set_edit_mode(EditMode.STRUCTURE if structure else EditMode.FURNITURE)


## Applies `edit` (returns false to refuse) to a copy of the project and, if the
## result is buildable, records the swap of structure states as one undo step.
func _edit_structure(action_name: String, edit: Callable) -> bool:
	if edit_mode != EditMode.STRUCTURE:
		return false
	var probe := project.copy()
	if not edit.call(probe) or not _is_buildable(probe):
		return false
	_begin_action(STRUCTURE_ACTION_PREFIX + action_name)
	_history.add_do_method(_restore_structure.bind(probe.copy()))
	_history.add_undo_method(_restore_structure.bind(project.copy()))
	_history.commit_action()
	return true


## Takes the corners, walls, openings and rooms of `state` (copied again, so the
## recorded state stays untouched by later edits).
func _restore_structure(state: ProjectData) -> void:
	var fresh := state.copy()
	project.nodes = fresh.nodes
	project.walls = fresh.walls
	project.openings = fresh.openings
	project.rooms = fresh.rooms
	structure_changed.emit()


func _is_buildable(probe: ProjectData) -> bool:
	for wall in probe.walls:
		if probe.wall_length(wall) < MIN_WALL_LENGTH:
			return false
	return ProjectValidator.validate(probe).is_empty()


static func _set_node_pos(probe: ProjectData, id: String, pos: Vector2) -> bool:
	var node := probe.get_plan_node(id)
	if node == null:
		return false
	node.pos = pos
	return true


static func _set_wall_fields(probe: ProjectData, id: String, changes: Dictionary) -> bool:
	var wall := probe.get_wall(id)
	for key in changes:
		if key == "length":
			var a := probe.get_plan_node(wall.a)
			var b := probe.get_plan_node(wall.b)
			var direction := (b.pos - a.pos).normalized()
			if direction.is_zero_approx():
				return false
			b.pos = a.pos + direction * float(changes[key])
		else:
			wall.set(key, changes[key])
	return true


static func _delete_wall(probe: ProjectData, id: String) -> bool:
	var wall := probe.get_wall(id)
	probe.walls.erase(wall)
	probe.openings.assign(probe.openings.filter(func(o: Opening) -> bool: return o.wall_id != id))
	for node_id in [wall.a, wall.b]:
		if probe.walls_at(node_id).is_empty() and not _in_a_room(probe, node_id):
			probe.nodes.erase(probe.get_plan_node(node_id))
	return true


static func _in_a_room(probe: ProjectData, node_id: String) -> bool:
	for room in probe.rooms:
		if node_id in room.node_ids:
			return true
	return false
