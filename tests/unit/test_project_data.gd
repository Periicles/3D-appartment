extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func test_get_plan_node_returns_node_by_id() -> void:
	var project := Fixtures.square_room()
	assert_eq(project.get_plan_node("n3").pos, Vector2(4, 4))


func test_get_plan_node_returns_null_for_unknown_id() -> void:
	assert_null(Fixtures.square_room().get_plan_node("missing"))


func test_get_wall_returns_wall_by_id() -> void:
	assert_eq(Fixtures.square_room().get_wall("w2").b, "n3")


func test_get_wall_returns_null_for_unknown_id() -> void:
	assert_null(Fixtures.square_room().get_wall("missing"))


func test_wall_length_is_distance_between_nodes() -> void:
	var project := Fixtures.square_room()
	assert_almost_eq(project.wall_length(project.get_wall("w1")), 4.0, 1e-6)


func test_wall_length_handles_diagonal_walls() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 3, 4)])
	assert_almost_eq(project.wall_length(Fixtures.wall("w", "a", "b")), 5.0, 1e-6)


func test_wall_length_is_negative_when_node_missing() -> void:
	var project := Fixtures.square_room()
	assert_eq(project.wall_length(Fixtures.wall("w", "n1", "missing")), -1.0)
