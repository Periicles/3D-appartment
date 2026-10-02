extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const CORNERS := ["n1", "n2", "n3", "n4"]

var _view: StructureView
var _project: ProjectData


func before_each() -> void:
	_project = Fixtures.square_room()
	_view = add_child_autofree(StructureView.new())


func _lengths() -> Array[Node]:
	return _view.get_children().filter(func(child: Node) -> bool: return child.name.begins_with("Length_"))


func test_one_handle_per_corner_at_floor_level() -> void:
	_view.show_structure(_project, &"", "")
	for id in CORNERS:
		var handle := _view.handle(id)
		assert_not_null(handle, "handle for %s" % id)
		var pos := _project.get_plan_node(id).pos
		assert_eq(handle.position, Vector3(pos.x, StructureView.LIFT, pos.y))
	assert_eq(_lengths().size(), 0)
	assert_null(_view.get_node_or_null("Highlight"))


func test_selected_corner_is_highlighted_and_shows_its_walls_lengths() -> void:
	_view.show_structure(_project, &"node", "n1")
	assert_true(_view.is_handle_selected("n1"))
	assert_false(_view.is_handle_selected("n2"))
	assert_not_null(_view.get_node_or_null("Length_w1"))
	assert_not_null(_view.get_node_or_null("Length_w4"))
	assert_eq((_view.get_node("Length_w1") as DimensionLine).label_text(), "400 cm")


func test_selected_wall_gets_a_highlight_and_its_length() -> void:
	_view.show_structure(_project, &"wall", "w2")
	assert_not_null(_view.get_node_or_null("Highlight"))
	assert_not_null(_view.get_node_or_null("Length_w2"))
	for id in CORNERS:
		assert_false(_view.is_handle_selected(id))


func test_unknown_ids_draw_only_handles() -> void:
	for kind in [&"wall", &"node"]:
		_view.show_structure(_project, kind, "nope")
		assert_not_null(_view.handle("n4"))
		assert_null(_view.get_node_or_null("Highlight"))
		assert_eq(_lengths().size(), 0)
	assert_eq(_view.get_child_count(), CORNERS.size())
	await wait_physics_frames(1)


func test_redraw_replaces_previous_overlay() -> void:
	_view.show_structure(_project, &"wall", "w2")
	_view.show_structure(_project, &"node", "n1")
	await wait_physics_frames(1)
	assert_eq(_view.get_child_count(), CORNERS.size() + 2)
	assert_null(_view.get_node_or_null("Highlight"))
