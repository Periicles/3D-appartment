class_name FurnitureTool
extends Node
## Mouse and keyboard editing of furniture: place from the catalogue, select,
## drag, rotate, delete, duplicate, undo/redo. Changes go through the store;
## the view only shows previews while the mouse is down.
## Call setup() after the view's bind_store(), so the view has already reacted
## to a store signal when this tool reads the selection back.

signal selection_changed(id: String)

const ROTATE_STEP_DEG := 90.0
const FINE_ROTATE_STEP_DEG := 15.0

var store: Node
var view: FurnitureView
var camera: Camera3D

var _placing: FurniturePreset
var _ghost_pos := Vector2.ZERO
var _ghost_rotation := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO
var _drag_pos := Vector2.ZERO
var _drag_rotation := 0.0
var _selection := ""  # last id announced through selection_changed


func setup(p_store: Node, p_view: FurnitureView, p_camera: Camera3D) -> void:
	store = p_store
	view = p_view
	camera = p_camera
	store.furniture_removed.connect(_on_furniture_removed)
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
	view.show_ghost(preset.size, preset.color)
	var mouse := camera.get_viewport().get_mouse_position()
	_update_ghost(mouse, false)


func cancel_placement() -> void:
	_placing = null
	view.hide_ghost()


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
		_update_ghost(event.position, event.alt_pressed)
	elif _dragging:
		var ground = _ground_point(event.position)
		if ground == null:
			return
		var item: FurnitureItem = store.get_furniture(selected_id())
		var placed := _snap(ground + _drag_offset, item.size, _drag_rotation, event.alt_pressed)
		_drag_pos = placed.pos
		_drag_rotation = placed.rotation_deg
		view.preview_item(item.id, _drag_pos, _drag_rotation)
		get_viewport().set_input_as_handled()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press(event)
			elif _dragging:
				_finish_drag()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and event.shift_pressed and selected_id() != "":
				var step := FINE_ROTATE_STEP_DEG if event.button_index == MOUSE_BUTTON_WHEEL_UP else -FINE_ROTATE_STEP_DEG
				_rotate_selected(step)
				get_viewport().set_input_as_handled()


func _on_left_press(event: InputEventMouseButton) -> void:
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
		if event.shift_pressed:
			store.redo()
		else:
			store.undo()
	elif command and event.keycode == KEY_D:
		if selected_id() != "":
			_select(store.duplicate_furniture(selected_id()))
	elif event.keycode == KEY_ESCAPE:
		if _placing != null:
			cancel_placement()
		else:
			_select("")
	elif event.keycode == KEY_R and _placing != null:
		_ghost_rotation = fposmod(_ghost_rotation + ROTATE_STEP_DEG, 360.0)
		view.move_ghost(_ghost_pos, _ghost_rotation)
	elif event.keycode == KEY_R and selected_id() != "":
		_rotate_selected(ROTATE_STEP_DEG)
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE] and selected_id() != "":
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
	var placed := _snap(ground, _placing.size, _ghost_rotation, free_move)
	_ghost_pos = placed.pos
	_ghost_rotation = placed.rotation_deg
	view.move_ghost(_ghost_pos, _ghost_rotation)


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


func _on_furniture_removed(_id: String) -> void:
	_sync_selection()


func _on_project_loaded() -> void:
	cancel_placement()
	_sync_selection()
