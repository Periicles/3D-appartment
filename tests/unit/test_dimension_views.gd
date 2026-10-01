extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3


func test_text_is_rounded_centimetres() -> void:
	assert_eq(DimensionLine.text_for(1.2349), "123 cm")
	assert_eq(DimensionLine.text_for(0.004), "0 cm")


func test_line_spans_its_points() -> void:
	var line: DimensionLine = add_child_autofree(DimensionLine.new())
	line.set_points(Vector2(1, 1), Vector2(3, 1))
	assert_true(line.visible)
	assert_eq(line.label_text(), "200 cm")
	var bar := line.get_node("Bar") as MeshInstance3D
	assert_almost_eq((bar.mesh as BoxMesh).size.x, 2.0, EPS)
	assert_almost_eq(bar.position, Vector3(2, DimensionLine.HEIGHT, 1), Vector3(EPS, EPS, EPS))


func test_line_follows_a_slanted_direction() -> void:
	var line: DimensionLine = add_child_autofree(DimensionLine.new())
	line.set_points(Vector2(0, 0), Vector2(3, 4))
	var bar := line.get_node("Bar") as MeshInstance3D
	var along := bar.transform.basis.x.normalized()
	assert_almost_eq(Vector2(along.x, along.z), Vector2(0.6, 0.8), Vector2(EPS, EPS))
	assert_eq(line.label_text(), "500 cm")


func test_zero_length_line_hides() -> void:
	var line: DimensionLine = add_child_autofree(DimensionLine.new())
	line.set_points(Vector2(1, 1), Vector2(1, 1))
	assert_false(line.visible)


func test_clearance_view_shows_one_line_per_blocked_side() -> void:
	var view: ClearanceView = add_child_autofree(ClearanceView.new())
	var project := Fixtures.square_room()
	project.furniture.clear()
	view.show_for(project, "", Vector2(2, 2), Vector3(1, 0.5, 0.6), 0.0)
	assert_eq(view.visible_sides(), PackedStringArray(["front", "back", "left", "right"]))
	assert_eq(view.line("back").label_text(), "160 cm")


func test_clearance_view_hides_touching_sides_and_clears() -> void:
	var view: ClearanceView = add_child_autofree(ClearanceView.new())
	var project := Fixtures.square_room()
	project.furniture.clear()
	# Back flush against the north wall's inner face (z = 0.1).
	view.show_for(project, "", Vector2(2, 0.4), Vector3(1, 0.5, 0.6), 0.0)
	assert_false(view.line("back").visible)
	view.clear()
	assert_eq(view.visible_sides(), PackedStringArray())


func test_clearance_view_follows_the_tool_focus() -> void:
	var store: Node = autofree(preload("res://src/store/project_store.gd").new())
	store.project = Fixtures.square_room()
	store.project.furniture.clear()
	var furniture_view: FurnitureView = add_child_autofree(FurnitureView.new())
	furniture_view.bind_store(store)
	var camera: Camera3D = add_child_autofree(Camera3D.new())
	var tool: FurnitureTool = add_child_autofree(FurnitureTool.new())
	tool.setup(store, furniture_view, camera)
	var view: ClearanceView = add_child_autofree(ClearanceView.new())
	view.bind(tool, store)
	tool.focus_changed.emit("", Vector2(2, 2), Vector3(1, 0.5, 0.6), 0.0)
	assert_eq(view.visible_sides().size(), 4)
	tool.focus_cleared.emit()
	assert_eq(view.visible_sides().size(), 0)
