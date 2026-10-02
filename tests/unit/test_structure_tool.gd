extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3
## The headless root viewport is 64 px wide, too small for pixel pick radii.
const SCREEN_SIZE := Vector2i(1000, 1000)

var _store: Node
var _world: WorldView
var _overlay: StructureView
var _camera: Camera3D
var _tool: StructureTool


func before_each() -> void:
	_store = autofree(Store.new())
	_store.project = Fixtures.square_room()
	_world = WorldView.new()
	add_child_autofree(_world)
	_world.show_project(_store.project)
	_overlay = StructureView.new()
	add_child_autofree(_overlay)
	var screen := SubViewport.new()
	screen.size = SCREEN_SIZE
	add_child_autofree(screen)
	_camera = Camera3D.new()
	screen.add_child(_camera)
	_camera.look_at_from_position(Vector3(2, 12, 2), Vector3(2, 0, 2), Vector3(0, 0, -1))
	_camera.current = true
	_tool = StructureTool.new()
	add_child_autofree(_tool)
	_tool.setup(_store, _camera, _world, _overlay)
	_store.set_edit_mode(Store.EditMode.STRUCTURE)
	# The handled flag is per viewport and only the engine clears it, between events.
	get_viewport().push_input(InputEventJoypadMotion.new())


func _screen(pos: Vector2, height := 0.0) -> Vector2:
	return _camera.unproject_position(Vector3(pos.x, height, pos.y))


func _click(pos: Vector2, pressed := true, height := 0.0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _screen(pos, height)
	_tool._unhandled_input(event)


func _move(pos: Vector2, alt := false, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _screen(pos)
	event.alt_pressed = alt
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_tool._unhandled_input(event)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_tool._unhandled_input(event)


func _node_pos(id: String) -> Vector2:
	return _store.project.get_plan_node(id).pos


func test_overlay_shows_a_handle_per_corner_only_in_structure_mode() -> void:
	assert_true(_overlay.visible)
	for id in ["n1", "n2", "n3", "n4"]:
		assert_not_null(_overlay.handle(id), id)
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	assert_false(_overlay.visible)


func test_click_near_a_corner_selects_it() -> void:
	watch_signals(_tool)
	_click(Vector2(4.03, 3.98))
	assert_eq(_tool.selected_kind(), &"node")
	assert_eq(_tool.selected_id(), "n3")
	assert_signal_emitted_with_parameters(_tool, "selection_changed", [&"node", "n3"])
	assert_true(_overlay.is_handle_selected("n3"))
	assert_true(get_viewport().is_input_handled())


func test_click_on_a_wall_selects_it_and_shows_its_length() -> void:
	_click(Vector2(2, 4), true, 2.5)  # top of the south wall w3
	assert_eq(_tool.selected_kind(), &"wall")
	assert_eq(_tool.selected_id(), "w3")
	var line := _overlay.get_node_or_null("Length_w3") as DimensionLine
	assert_not_null(line)
	assert_eq(line.label_text(), "400 cm")


func test_click_on_the_floor_clears_the_selection_and_leaves_it_to_the_camera() -> void:
	_tool.select(&"node", "n3")
	_click(Vector2(2, 2))
	assert_eq(_tool.selected_kind(), &"")
	assert_false(get_viewport().is_input_handled(), "double clicks still reach the camera")


func test_dragging_a_corner_previews_then_commits_one_step() -> void:
	_click(Vector2(4, 4))
	_move(Vector2(5.02, 4.51), true)
	assert_eq(_node_pos("n3"), Vector2(4, 4), "nothing stored while dragging")
	assert_not_null(_overlay.get_node_or_null("Length_w2"), "lengths of the corner's walls")
	_click(Vector2(5.02, 4.51), false)
	assert_almost_eq(_node_pos("n3"), Vector2(5.02, 4.51), Vector2(EPS, EPS))
	_store.undo()
	assert_eq(_node_pos("n3"), Vector2(4, 4))


func test_drag_snaps_unless_alt_is_held() -> void:
	_click(Vector2(4, 4))
	_move(Vector2(4.06, 5.13))
	_click(Vector2(4.06, 5.13), false)
	assert_almost_eq(_node_pos("n3").x, 4.0, EPS, "w2 locked square to w1")


func test_drag_keeps_the_last_valid_spot() -> void:
	# Squeezing w1 below its door (0.6 m to 1.4 m from n1) is refused.
	_click(Vector2(4, 0))
	_move(Vector2(2.0, 0), true)
	_move(Vector2(1.2, 0), true)
	_click(Vector2(1.2, 0), false)
	assert_almost_eq(_node_pos("n2"), Vector2(2, 0), Vector2(EPS, EPS))


func test_click_on_a_corner_without_moving_records_nothing() -> void:
	_click(Vector2(4, 4))
	_click(Vector2(4, 4), false)
	assert_false(_store.can_undo())


func test_escape_cancels_a_drag_then_clears_the_selection() -> void:
	_click(Vector2(4, 4))
	_move(Vector2(5, 5), true)
	_key(KEY_ESCAPE)
	assert_false(_tool.is_dragging())
	assert_eq(_tool.selected_id(), "n3")
	_click(Vector2(5, 5), false)
	assert_eq(_node_pos("n3"), Vector2(4, 4), "the release after a cancel moves nothing")
	_key(KEY_ESCAPE)
	assert_eq(_tool.selected_kind(), &"")


func test_delete_removes_the_selected_wall() -> void:
	_click(Vector2(2, 4), true, 2.5)
	_key(KEY_DELETE)
	assert_null(_store.project.get_wall("w3"))
	assert_eq(_tool.selected_kind(), &"", "a deleted wall is no longer selected")


func test_delete_ignores_a_selected_corner() -> void:
	_click(Vector2(4, 4))
	_click(Vector2(4, 4), false)
	_key(KEY_BACKSPACE)
	assert_eq(_store.project.walls.size(), 4)


func test_tool_is_off_in_furniture_mode() -> void:
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	_click(Vector2(4, 4))
	assert_eq(_tool.selected_kind(), &"")
	assert_false(get_viewport().is_input_handled())


func test_leaving_structure_mode_mid_drag_drops_the_preview() -> void:
	_click(Vector2(4, 4))
	_move(Vector2(5, 5), true)
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	assert_false(_tool.is_dragging())
	assert_eq(_tool.selected_kind(), &"")
	assert_eq(_node_pos("n3"), Vector2(4, 4))


func test_undo_that_removes_the_selected_corner_clears_the_selection() -> void:
	_store.project.nodes.append(Fixtures.plan_node("n5", 6, 0))
	_store.project.walls.append(Fixtures.wall("w5", "n2", "n5"))
	_store.remove_wall("w5")
	_store.undo()  # n5 is back
	_tool.select(&"node", "n5")
	_store.redo()  # n5 is gone again
	assert_eq(_tool.selected_kind(), &"")


func test_corner_hidden_by_a_lowered_wall_is_still_picked_before_the_wall() -> void:
	_click(Vector2(0, 4))
	assert_eq(_tool.selected_id(), "n4")


func test_selected_wall_is_highlighted_in_the_view() -> void:
	_tool.select(&"wall", "w3")
	assert_eq(_world.highlighted_wall(), "w3")
	_tool.select(&"node", "n3")
	assert_eq(_world.highlighted_wall(), "")
