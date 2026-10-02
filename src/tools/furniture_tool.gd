class_name FurnitureTool
extends Node
## Mouse and keyboard editing of furniture: place from the catalogue, select,
## drag, rotate, delete, duplicate, undo/redo. Changes go through the store;
## the view only shows previews while the mouse is down.
## Call setup() after the view's bind_store(), so the view has already reacted
## to a store signal when this tool reads the selection back.

signal selection_changed(id: String)
## The footprint whose clearances should be shown (the ghost, the dragged item
## or the selection) moved; `ignore_id` is the item itself ("" for the ghost).
signal focus_changed(ignore_id: String, pos: Vector2, size: Vector3, rotation_deg: float)
## Nothing to measure around any more.
signal focus_cleared

const ROTATE_STEP_DEG := 90.0
const FINE_ROTATE_STEP_DEG := 15.0

var store: Node
var view: FurnitureView
var camera: Camera3D

var _placing: FurniturePreset
var _ghost_pos := Vector2.ZERO
var _ghost_rotation := 0.0  # displayed rotation, may come from a wall
var _user_rotation := 0.0  # what the player asked for, kept apart from wall snapping
var _last_mouse := Vector2.ZERO
var _dragging := false
var _drag_offset := Vector2.ZERO
var _drag_pos := Vector2.ZERO
var _drag_rotation := 0.0
var _drag_start_rotation := 0.0
var _selection := ""  # last id announced through selection_changed


func setup(p_store: Node, p_view: FurnitureView, p_camera: Camera3D) -> void:
	store = p_store
	view = p_view
	camera = p_camera
	store.furniture_added.connect(_on_furniture_added)
	store.furniture_removed.connect(_on_furniture_removed)
	store.furniture_changed.connect(_on_furniture_changed)
	store.project_loaded.connect(_on_project_loaded)


func is_placing() -> bool:
	return _placing != null


func selected_id() -> String:
	return view.selected_id()


## Starts placing a new item: a ghost follows the mouse until a left click.
func begin_placement(preset: FurniturePreset) -> void:
	_select("")
	_placing = preset
	_ghost_rotation = 0.0
	_user_rotation = 0.0
	view.show_ghost(preset.size, preset.color)
	_last_mouse = camera.get_viewport().get_mouse_position()
	_update_ghost(_last_mouse, false)


func cancel_placement() -> void:
	_placing = null
	view.hide_ghost()
	_emit_focus()


func _unhandled_input(event: InputEvent) -> void:
	if store == null:
		return
	if event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _placing != null:
		_last_mouse = event.position
		_update_ghost(event.position, event.alt_pressed)
	elif _dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_finish_drag()  # The release went to a GUI control.
			return
		var ground = _ground_point(event.position)
		if ground == null:
			return
		var item: FurnitureItem = store.get_furniture(selected_id())
		var placed := _snap(ground + _drag_offset, item.size, _drag_start_rotation, event.alt_pressed)
		_drag_pos = placed.pos
		_drag_rotation = placed.rotation_deg
		view.preview_item(item.id, _drag_pos, _drag_rotation)
		focus_changed.emit(item.id, _drag_pos, item.size, _drag_rotation)
		get_viewport().set_input_as_handled()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press(event)
			elif _dragging:
				_finish_drag()
		# macOS turns Shift + wheel into a horizontal wheel, so accept both axes.
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
			if event.pressed and event.shift_pressed and selected_id() != "" and not _dragging:
				var positive: bool = event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]
				_rotate_selected(FINE_ROTATE_STEP_DEG if positive else -FINE_ROTATE_STEP_DEG)
				get_viewport().set_input_as_handled()


func _on_left_press(event: InputEventMouseButton) -> void:
	# Lets a focused panel field commit while it still shows the previous item.
	get_viewport().gui_release_focus()
	if _placing != null:
		_place_ghost()
		get_viewport().set_input_as_handled()
		return
	var id := Placement.pick_item(camera.project_ray_origin(event.position),
		camera.project_ray_normal(event.position), store.project.furniture)
	if id == "":
		_select("")  # Left unhandled so the camera still sees double clicks.
		return
	_select(id)
	var ground = _ground_point(event.position)
	var item: FurnitureItem = store.get_furniture(id)
	if ground != null:
		_dragging = true
		_drag_offset = item.pos - ground
		_drag_pos = item.pos
		_drag_rotation = item.rotation_deg
		_drag_start_rotation = item.rotation_deg
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	_dragging = false
	var item: FurnitureItem = store.get_furniture(selected_id())
	if item == null:
		return
	if not item.pos.is_equal_approx(_drag_pos) or not is_equal_approx(item.rotation_deg, _drag_rotation):
		store.update_furniture(item.id, {"pos": _drag_pos, "rotation_deg": _drag_rotation})
	get_viewport().set_input_as_handled()


func _on_key(event: InputEventKey) -> void:
	var command := event.is_command_or_control_pressed()
	if command and event.keycode == KEY_Z:
		if _dragging:
			return  # The release would overwrite whatever the undo reverted.
		if event.shift_pressed:
			store.redo()
		else:
			store.undo()
	elif command and event.keycode == KEY_D:
		if selected_id() != "" and not _dragging:
			_select(store.duplicate_furniture(selected_id()))
	elif event.keycode == KEY_ESCAPE:
		if _placing != null:
			cancel_placement()
		else:
			_select("")
	elif event.keycode == KEY_R and _placing != null:
		_user_rotation = fposmod(_user_rotation + ROTATE_STEP_DEG, 360.0)
		_update_ghost(_last_mouse, false)
	elif event.keycode == KEY_R and selected_id() != "" and not _dragging:
		_rotate_selected(ROTATE_STEP_DEG)
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE] and selected_id() != "" and not _dragging:
		store.remove_furniture(selected_id())
	else:
		return
	get_viewport().set_input_as_handled()


func _rotate_selected(step_deg: float) -> void:
	var item: FurnitureItem = store.get_furniture(selected_id())
	store.update_furniture(item.id, {"rotation_deg": fposmod(item.rotation_deg + step_deg, 360.0)})


func _update_ghost(screen_pos: Vector2, free_move: bool) -> void:
	var ground = _ground_point(screen_pos)
	if ground == null:
		return
	var placed := _snap(ground, _placing.size, _user_rotation, free_move)
	_ghost_pos = placed.pos
	_ghost_rotation = placed.rotation_deg
	view.move_ghost(_ghost_pos, _ghost_rotation)
	focus_changed.emit("", _ghost_pos, _placing.size, _ghost_rotation)


func _place_ghost() -> void:
	var item := _placing.make_item(store.next_furniture_id(), _ghost_pos)
	item.rotation_deg = _ghost_rotation
	cancel_placement()
	if store.add_furniture(item):
		_select(item.id)


## Grid snapping (unless `free_move`), then wall snapping which may also turn the item.
func _snap(pos: Vector2, size: Vector3, rotation_deg: float, free_move: bool) -> Dictionary:
	var snapped := pos if free_move else Placement.snap_to_grid(pos)
	var wall := Placement.snap_to_wall(store.project, snapped, size)
	if wall.is_empty():
		return {"pos": snapped, "rotation_deg": rotation_deg}
	return wall


## Where the mouse ray meets the floor (y = 0), or null.
func _ground_point(screen_pos: Vector2) -> Variant:
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos))
	return null if hit == null else Vector2(hit.x, hit.z)


func _select(id: String) -> void:
	view.set_selected(id)
	_sync_selection()


## Announces the view's selection if it changed (e.g. the item was deleted or undone).
func _sync_selection() -> void:
	var current := view.selected_id()
	if current == _selection:
		return
	if current == "":
		_dragging = false
	_selection = current
	selection_changed.emit(current)
	_emit_focus()


## Re-announces the focus from the current state (ghost, else selection).
func _emit_focus() -> void:
	if _placing != null:
		focus_changed.emit("", _ghost_pos, _placing.size, _ghost_rotation)
		return
	var item: FurnitureItem = store.get_furniture(view.selected_id()) if view.selected_id() != "" else null
	if item == null:
		focus_cleared.emit()
	else:
		focus_changed.emit(item.id, item.pos, item.size, item.rotation_deg)


# Any piece of furniture can be the obstacle a clearance measures against, so
# every edit refreshes the focus, not only edits of the focused item.
func _on_furniture_added(_id: String) -> void:
	_refresh_focus()


func _on_furniture_removed(_id: String) -> void:
	_sync_selection()
	_refresh_focus()


func _on_furniture_changed(_id: String) -> void:
	_refresh_focus()


func _refresh_focus() -> void:
	if not _dragging:
		_emit_focus()


func _on_project_loaded() -> void:
	cancel_placement()
	_sync_selection()
