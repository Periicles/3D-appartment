extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func test_find_wall_between_matches_either_direction() -> void:
	var project := Fixtures.square_room()
	assert_eq(project.find_wall_between("n1", "n2").id, "w1")
	assert_eq(project.find_wall_between("n2", "n1").id, "w1")


func test_find_wall_between_returns_null_when_not_joined() -> void:
	assert_null(Fixtures.square_room().find_wall_between("n1", "n3"))
