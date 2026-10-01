extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3
const SOFA_PRESET := "res://data/presets/sofa_3.tres"

var _store: Node
var _view: FurnitureView
var _camera: Camera3D
var _tool: FurnitureTool


func before_each() -> void:
	_store = autofree(Store.new())
	_store.project = Fixtures.square_room()
	_store.project.furniture.clear()
	_view = FurnitureView.new()
	add_child_autofree(_view)
	_view.bind_store(_store)
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.look_at_from_position(Vector3(2, 12, 2), Vector3(2, 0, 2), Vector3(0, 0, -1))
	_camera.current = true
	_tool = FurnitureTool.new()
	add_child_autofree(_tool)
	_tool.setup(_store, _view, _camera)


func _screen(pos: Vector2, height := 0.0) -> Vector2:
	return _camera.unproject_position(Vector3(pos.x, height, pos.y))


func _move(pos: Vector2, alt := false, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _screen(pos)
	event.alt_pressed = alt
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_tool._unhandled_input(event)


func _click(pos: Vector2, pressed := true, height := 0.0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _screen(pos, height)
	_tool._unhandled_input(event)


func _key(keycode: Key, command := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	# Cmd on macOS, Ctrl elsewhere: set both so the test runs on any platform.
	event.ctrl_pressed = command
	event.meta_pressed = command
	event.shift_pressed = shift
	_tool._unhandled_input(event)


func _wheel(up: bool, shift: bool, horizontal := false) -> void:
	var event := InputEventMouseButton.new()
	if horizontal:
		event.button_index = MOUSE_BUTTON_WHEEL_LEFT if up else MOUSE_BUTTON_WHEEL_RIGHT
	else:
		event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.shift_pressed = shift
	_tool._unhandled_input(event)


func _add_sofa(pos: Vector2, rotation_deg := 0.0) -> String:
	var item := Fixtures.sofa(_store.next_furniture_id())
	item.pos = pos
	item.rotation_deg = rotation_deg
	_store.add_furniture(item)
	return item.id


func test_placement_ghost_follows_mouse_on_the_grid() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	assert_true(_view.has_ghost())
	_move(Vector2(2.013, 2.037))
	var ghost := _view.get_node("Ghost") as Node3D
	assert_almost_eq(ghost.position, Vector3(2.0, 0, 2.05), Vector3(EPS, EPS, EPS))


func test_alt_disables_grid_snapping() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2.013, 2.037), true)
	assert_almost_eq((_view.get_node("Ghost") as Node3D).position, Vector3(2.013, 0, 2.037), Vector3(EPS, EPS, EPS))


func test_click_places_item_and_selects_it() -> void:
	watch_signals(_tool)
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 2))
	_click(Vector2(2, 2))
	assert_eq(_store.project.furniture.size(), 1)
	var item: FurnitureItem = _store.project.furniture[0]
	assert_eq(item.preset, "sofa_3")
	assert_almost_eq(item.pos, Vector2(2, 2), Vector2(EPS, EPS))
	assert_false(_tool.is_placing())
	assert_eq(_tool.selected_id(), item.id)
	assert_signal_emitted_with_parameters(_tool, "selection_changed", [item.id])
	await wait_physics_frames(1)
	assert_false(_view.has_ghost())


func test_ghost_snaps_against_a_wall() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 0.62))
	var ghost := _view.get_node("Ghost") as Node3D
	assert_almost_eq(ghost.position, Vector3(2, 0, 0.55), Vector3(EPS, EPS, EPS))


func test_escape_cancels_placement() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_key(KEY_ESCAPE)
	_click(Vector2(2, 2))
	assert_false(_tool.is_placing())
	assert_eq(_store.project.furniture.size(), 0)


func test_r_turns_the_ghost_a_quarter() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 2))
	_key(KEY_R)
	_click(Vector2(2, 2))
	assert_almost_eq(_store.project.furniture[0].rotation_deg, 90.0, EPS)


func test_click_on_item_selects_and_click_on_floor_deselects() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2), true, 0.85)
	_click(Vector2(2, 2), false, 0.85)
	assert_eq(_tool.selected_id(), id)
	_click(Vector2(3.5, 3.5))
	_click(Vector2(3.5, 3.5), false)
	assert_eq(_tool.selected_id(), "")


func test_drag_moves_item_in_one_undo_step() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2))
	_move(Vector2(2.5, 2.3), false, true)
	_move(Vector2(2.6, 2.4), false, true)
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS), "data waits for release")
	_click(Vector2(2.6, 2.4), false)
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2.6, 2.4), Vector2(EPS, EPS))
	_store.undo()
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS))


func test_click_without_moving_adds_no_history() -> void:
	_add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2))
	_click(Vector2(2, 2), false)
	_store.undo()
	assert_eq(_store.project.furniture.size(), 0, "the only step was the add")


func test_r_rotates_selected_item() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_key(KEY_R)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 90.0, EPS)


func test_shift_wheel_rotates_in_fine_steps() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_wheel(true, true)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 15.0, EPS)
	_wheel(false, true)
	_wheel(false, true)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 345.0, EPS)


func test_shift_horizontal_wheel_rotates_in_fine_steps() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_wheel(true, true, true)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 15.0, EPS, "wheel left is +15")
	_wheel(false, true, true)
	_wheel(false, true, true)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 345.0, EPS, "wheel right is -15")


func test_plain_horizontal_wheel_is_left_to_the_camera() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_wheel(true, false, true)
	assert_eq(_store.get_furniture(id).rotation_deg, 0.0)


func test_plain_wheel_is_left_to_the_camera() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_wheel(true, false)
	assert_eq(_store.get_furniture(id).rotation_deg, 0.0)


func test_delete_removes_selected_and_clears_selection() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_tool._select(id)
	watch_signals(_tool)
	_key(KEY_DELETE)
	assert_null(_store.get_furniture(id))
	assert_eq(_tool.selected_id(), "")
	assert_signal_emitted_with_parameters(_tool, "selection_changed", [""])


func test_command_d_duplicates_and_selects_the_copy() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_tool._select(id)
	_key(KEY_D, true)
	assert_eq(_store.project.furniture.size(), 2)
	assert_ne(_tool.selected_id(), id)


func test_command_z_undoes_and_shift_redoes() -> void:
	_add_sofa(Vector2(2, 2))
	_key(KEY_Z, true)
	assert_eq(_store.project.furniture.size(), 0)
	_key(KEY_Z, true, true)
	assert_eq(_store.project.furniture.size(), 1)


func test_undoing_the_selected_items_creation_clears_selection() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_tool._select(id)
	_store.undo()
	assert_eq(_tool.selected_id(), "")


func test_loading_a_project_cancels_placement() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_store.load_from_file("res://data/log16.json")
	assert_false(_tool.is_placing())


func test_user_rotation_survives_a_wall_touch_while_placing() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 2))
	_key(KEY_R)
	var ghost := _view.get_node("Ghost") as Node3D
	assert_almost_eq(ghost.rotation_degrees.y, 90.0, EPS)
	_move(Vector2(2, 0.62))
	assert_almost_eq(ghost.rotation_degrees.y, 0.0, EPS)
	_move(Vector2(2, 2))
	assert_almost_eq(ghost.rotation_degrees.y, 90.0, EPS)
	_click(Vector2(2, 2))
	assert_almost_eq(_store.project.furniture[0].rotation_deg, 90.0, EPS)


func test_user_rotation_survives_a_wall_touch_while_dragging() -> void:
	var id := _add_sofa(Vector2(2, 2), 90.0)
	_click(Vector2(2, 2))
	_move(Vector2(2, 0.62), false, true)
	_move(Vector2(2, 2.2), false, true)
	_click(Vector2(2, 2.2), false)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 90.0, EPS)


func test_drag_finishes_when_the_release_was_swallowed() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2))
	_move(Vector2(2.5, 2.3), false, true)
	_move(Vector2(2.6, 2.4))
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2.5, 2.3), Vector2(EPS, EPS), "committed at the last preview")
	_move(Vector2(3.0, 3.0), false, true)
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2.5, 2.3), Vector2(EPS, EPS))


func test_rotating_during_a_drag_is_ignored() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2))
	_move(Vector2(2.5, 2.3), false, true)
	_key(KEY_R)
	_wheel(true, true)
	_wheel(true, true, true)
	assert_eq(_store.get_furniture(id).rotation_deg, 0.0)
	_click(Vector2(2.5, 2.3), false)
	_store.undo()
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS))
	assert_eq(_store.get_furniture(id).rotation_deg, 0.0)


func test_undo_redo_during_a_drag_are_ignored() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_store.update_furniture(id, {"name": "Renamed"})
	_click(Vector2(2, 2))
	_move(Vector2(2.5, 2.3), false, true)
	_key(KEY_Z, true)
	assert_eq(_store.get_furniture(id).name, "Renamed", "nothing undone while dragging")
	_key(KEY_Z, true, true)
	_click(Vector2(2.5, 2.3), false)
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2.5, 2.3), Vector2(EPS, EPS))
	_store.undo()
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS), "release is one update step")
	assert_eq(_store.get_furniture(id).name, "Renamed")


func test_scene_click_releases_gui_focus() -> void:
	var field: LineEdit = add_child_autofree(LineEdit.new())
	field.grab_focus()
	assert_not_null(get_viewport().gui_get_focus_owner(), "precondition: the field has focus")
	_click(Vector2(1, 1))
	assert_null(get_viewport().gui_get_focus_owner())
