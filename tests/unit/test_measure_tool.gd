extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3

var _store: Node
var _camera: Camera3D
var _layer: Node3D
var _tool: MeasureTool


func before_each() -> void:
	_store = autofree(Store.new())
	_store.project = Fixtures.square_room()
	_store.project.furniture.clear()
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.look_at_from_position(Vector3(2, 12, 2), Vector3(2, 0, 2), Vector3(0, 0, -1))
	_camera.current = true
	_layer = Node3D.new()
	add_child_autofree(_layer)
	_tool = MeasureTool.new()
	add_child_autofree(_tool)
	_tool.setup(_store, _camera, _layer)
	# The handled flag is per viewport and only the engine clears it, between events.
	get_viewport().push_input(InputEventJoypadMotion.new())


func _click(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _camera.unproject_position(Vector3(pos.x, 0, pos.y))
	_tool._unhandled_input(event)


func _move(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _camera.unproject_position(Vector3(pos.x, 0, pos.y))
	_tool._unhandled_input(event)


func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_tool._unhandled_input(event)


func _handled() -> bool:
	return get_viewport().is_input_handled()


func _lines() -> Array:
	return _layer.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Measure"))


func test_inactive_tool_ignores_clicks() -> void:
	_click(Vector2(1, 1))
	_click(Vector2(3, 1))
	assert_eq(_tool.measurements().size(), 0)


func test_two_clicks_make_a_measurement() -> void:
	watch_signals(_tool)
	_tool.toggle()
	assert_signal_emitted_with_parameters(_tool, "active_changed", [true])
	_click(Vector2(1, 2))
	_click(Vector2(3, 2))
	assert_eq(_tool.measurements().size(), 1)
	assert_eq(_lines().size(), 1)
	assert_eq((_lines()[0] as DimensionLine).label_text(), "200 cm")


func test_points_snap_to_wall_faces() -> void:
	_tool.toggle()
	_click(Vector2(2, 0.18))  # near the north wall's inner face (z = 0.1)
	_click(Vector2(2, 3.83))  # near the south wall's inner face (z = 3.9)
	var pair: Array = _tool.measurements()[0]
	assert_almost_eq(pair[0], Vector2(2, 0.1), Vector2(EPS, EPS))
	assert_almost_eq(pair[1], Vector2(2, 3.9), Vector2(EPS, EPS))


func test_preview_follows_the_mouse_after_the_first_point() -> void:
	_tool.toggle()
	_click(Vector2(1, 2))
	_move(Vector2(2.5, 2))
	var preview := _layer.get_node("Preview") as DimensionLine
	assert_true(preview.visible)
	assert_eq(preview.label_text(), "150 cm")


func test_several_measurements_stay_drawn() -> void:
	_tool.toggle()
	for pair in [[Vector2(1, 1), Vector2(2, 1)], [Vector2(1, 2), Vector2(1, 3)]]:
		_click(pair[0])
		_click(pair[1])
	assert_eq(_lines().size(), 2)


func test_clicking_twice_on_the_same_point_adds_nothing() -> void:
	_tool.toggle()
	_click(Vector2(2, 2))
	_click(Vector2(2, 2))
	assert_eq(_tool.measurements().size(), 0)


func test_escape_clears_everything_and_leaves_the_tool() -> void:
	_tool.toggle()
	_click(Vector2(1, 2))
	_click(Vector2(3, 2))
	_click(Vector2(1, 3))
	_escape()
	await wait_physics_frames(1)
	assert_eq(_tool.measurements().size(), 0)
	assert_eq(_lines().size(), 0)
	assert_false(_tool.is_active())
	assert_false((_layer.get_node("Preview") as DimensionLine).visible)


func test_leaving_with_m_keeps_the_measurements() -> void:
	_tool.toggle()
	_click(Vector2(1, 2))
	_click(Vector2(3, 2))
	_tool.toggle()
	assert_false(_tool.is_active())
	assert_eq(_lines().size(), 1)


func test_escape_while_measuring_marks_the_event_handled() -> void:
	_tool.toggle()
	_escape()
	assert_true(_handled())


func test_a_measuring_click_marks_the_event_handled() -> void:
	_tool.toggle()
	_click(Vector2(1, 2))
	assert_true(_handled())


func test_escape_after_leaving_the_tool_still_clears_the_measurements() -> void:
	_tool.toggle()
	_click(Vector2(1, 2))
	_click(Vector2(3, 2))
	_tool.toggle()
	_escape()
	await wait_physics_frames(1)
	assert_eq(_tool.measurements().size(), 0)
	assert_eq(_lines().size(), 0)
	assert_true(_handled())


func test_escape_with_nothing_to_clear_falls_through_to_deselection() -> void:
	_escape()
	assert_false(_handled())


func test_a_measuring_click_releases_gui_focus() -> void:
	var field: LineEdit = add_child_autofree(LineEdit.new())
	field.grab_focus()
	_tool.toggle()
	_click(Vector2(1, 2))
	assert_null(get_viewport().gui_get_focus_owner())
