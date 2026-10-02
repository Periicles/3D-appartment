class_name StructureTool
extends Node
## Structure mode editing: click a corner or a wall to select it, drag a corner
## (with magnetism, Alt for a free move), Suppr deletes the selected wall. Only
## active while the store is in the Structure mode. Changes go through the
## store; while dragging, the walls are previewed from a copy of the project.

## `kind` is &"node", &"wall" or &"" when nothing is selected.
signal selection_changed(kind: StringName, id: String)

## A click this close to a corner (in screen pixels) grabs it.
const PICK_RADIUS_PX := 14.0
const RAY_LENGTH := 1000.0

var store: Node
var camera: Camera3D
var world: WorldView
var overlay: StructureView

var _kind: StringName = &""
var _id := ""
var _dragging := false
var _drag_offset := Vector2.ZERO
var _drag_pos := Vector2.ZERO


func setup(p_store: Node, p_camera: Camera3D, p_world: WorldView, p_overlay: StructureView) -> void:
	store = p_store
	camera = p_camera
	world = p_world
	overlay = p_overlay
	store.structure_changed.connect(_on_structure_changed)
	store.project_loaded.connect(_on_project_loaded)
	store.edit_mode_changed.connect(_on_edit_mode_changed)
	_on_edit_mode_changed(store.edit_mode)


func is_active() -> bool:
	return store != null and store.edit_mode == store.EditMode.STRUCTURE


func is_dragging() -> bool:
	return _dragging


func selected_kind() -> StringName:
	return _kind


func selected_id() -> String:
	return _id


func select(kind: StringName, id: String) -> void:
	if kind == _kind and id == _id:
		return
	_kind = kind
	_id = id
	world.highlight_wall(id if kind == &"wall" else "")
	_redraw(store.project)
	selection_changed.emit(kind, id)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event is InputEventMouseMotion and _dragging:
		_on_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_press(event)
		elif _dragging:
			_finish_drag()
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)


func _on_left_press(event: InputEventMouseButton) -> void:
	# Lets a focused panel field commit before the selection changes.
	get_viewport().gui_release_focus()
	var node_id := _pick_node(event.position)
	if node_id != "":
		select(&"node", node_id)
		var ground = _ground_point(event.position)
		if ground != null:
			_dragging = true
			_drag_pos = store.project.get_plan_node(node_id).pos
			_drag_offset = _drag_pos - ground
		get_viewport().set_input_as_handled()
		return
	var wall_id := _pick_wall(event.position)
	if wall_id != "":
		select(&"wall", wall_id)
		get_viewport().set_input_as_handled()
		return
	select(&"", "")  # Left unhandled so the camera still sees double clicks.


func _on_drag(event: InputEventMouseMotion) -> void:
	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_finish_drag()  # The release went to a GUI control.
		return
	var ground = _ground_point(event.position)
	if ground == null:
		return
	var target := StructureSnap.snap_node(store.project, _id, ground + _drag_offset, event.alt_pressed)
	# An invalid spot (a door squeezed out, a wall collapsed) keeps the last valid one.
	if store.can_move_node(_id, target):
		_drag_pos = target
		var preview: ProjectData = store.project.copy()
		preview.get_plan_node(_id).pos = target
		world.refresh(preview)
		_redraw(preview)
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	_dragging = false
	var moved: bool = not store.project.get_plan_node(_id).pos.is_equal_approx(_drag_pos)
	if moved and not store.move_node(_id, _drag_pos):
		_show_stored()  # Refused after all: drop the preview.
	get_viewport().set_input_as_handled()


func _cancel_drag() -> void:
	if _dragging:
		_dragging = false
		_show_stored()


func _on_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		if _dragging:
			_cancel_drag()
		elif _kind != &"":
			select(&"", "")
		else:
			return
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE] and _kind == &"wall" and not _dragging:
		store.remove_wall(_id)
	else:
		return
	get_viewport().set_input_as_handled()


## Nearest corner within PICK_RADIUS_PX of the screen point, or "".
func _pick_node(screen_pos: Vector2) -> String:
	var best := ""
	var best_distance := PICK_RADIUS_PX
	for node in store.project.nodes:
		var world_pos := Vector3(node.pos.x, StructureView.LIFT, node.pos.y)
		if camera.is_position_behind(world_pos):
			continue
		var distance := camera.unproject_position(world_pos).distance_to(screen_pos)
		if distance <= best_distance:
			best = node.id
			best_distance = distance
	return best


## Nearest wall the mouse ray hits, at its displayed height (lowered walls are
## picked at their lowered height), or "".
func _pick_wall(screen_pos: Vector2) -> String:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * RAY_LENGTH
	var footprints := Geometry.wall_footprints(store.project)
	var best := ""
	var best_distance := INF
	for wall_id in footprints:
		var hit := Geometry3D.segment_intersects_convex(from, to,
			_prism_planes(footprints[wall_id], world.wall_display_height(wall_id)))
		if not hit.is_empty() and from.distance_to(hit[0]) < best_distance:
			best = wall_id
			best_distance = from.distance_to(hit[0])
	return best


## Outward planes of a footprint (counter-clockwise in x/z) extruded to `height`.
static func _prism_planes(footprint: PackedVector2Array, height: float) -> Array[Plane]:
	var planes: Array[Plane] = [Plane(Vector3.DOWN, 0.0), Plane(Vector3.UP, height)]
	for i in footprint.size():
		var p := footprint[i]
		var q := footprint[(i + 1) % footprint.size()]
		var outward := Vector3(q.y - p.y, 0.0, -(q.x - p.x)).normalized()
		planes.append(Plane(outward, Vector3(p.x, 0.0, p.y)))
	return planes


func _ground_point(screen_pos: Vector2) -> Variant:
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos))
	return null if hit == null else Vector2(hit.x, hit.z)


func _show_stored() -> void:
	world.refresh(store.project)
	_redraw(store.project)


func _redraw(project: ProjectData) -> void:
	if overlay.visible:
		overlay.show_structure(project, _kind, _id)


func _on_structure_changed() -> void:
	_cancel_drag()
	var project: ProjectData = store.project
	var gone := (_kind == &"node" and project.get_plan_node(_id) == null) \
			or (_kind == &"wall" and project.get_wall(_id) == null)
	if gone:
		select(&"", "")
	else:
		_redraw(project)


func _on_project_loaded() -> void:
	_cancel_drag()
	select(&"", "")
	_redraw(store.project)


func _on_edit_mode_changed(_mode: int) -> void:
	_cancel_drag()
	select(&"", "")
	overlay.visible = is_active()
	_redraw(store.project)
