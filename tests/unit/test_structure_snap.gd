extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4


## An L of walls: a (0,0) - b (4,0) - c (4,3); the corner c is the one dragged.
func _l_shape() -> ProjectData:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 4, 0),
		Fixtures.plan_node("c", 4, 3)])
	project.walls.assign([Fixtures.wall("w1", "a", "b"), Fixtures.wall("w2", "b", "c")])
	return project


func test_free_move_keeps_the_raw_position() -> void:
	var raw := Vector2(4.03, 2.97)
	assert_eq(StructureSnap.snap_node(_l_shape(), "c", raw, true), raw)


func test_far_from_any_guide_snaps_to_the_grid() -> void:
	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(5.33, 1.61), false)
	assert_almost_eq(snapped, Vector2(5.35, 1.6), Vector2(EPS, EPS))


func test_near_square_locks_the_wall_at_ninety_degrees() -> void:
	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(4.07, 3.13), false)
	assert_almost_eq(snapped.x, 4.0, EPS, "w2 stays perpendicular to w1")
	assert_almost_eq(snapped.y, 3.15, EPS, "the length snaps to the grid")


func test_a_guide_lock_also_snaps_along_the_guide() -> void:
	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(4.03, 2.47), false)
	assert_almost_eq(snapped.x, 4.0, EPS, "locked on the vertical guide")
	assert_almost_eq(snapped.y, 2.45, EPS, "the length from b is a multiple of 5 cm")


func test_near_forty_five_degrees_locks_the_diagonal() -> void:
	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(6.05, 1.95), false)
	assert_almost_eq(snapped.x - 4.0, snapped.y, EPS, "45° from w1 at b")


func test_angles_follow_a_slanted_neighbour() -> void:
	var project := _l_shape()
	project.get_plan_node("a").pos = Vector2(0, -2)  # w1 is no longer horizontal
	var direction := (project.get_plan_node("b").pos - project.get_plan_node("a").pos).normalized()
	var square := Vector2(-direction.y, direction.x)
	var raw := Vector2(4, 0) + square * 3.0 + direction * 0.05
	var snapped := StructureSnap.snap_node(project, "c", raw, false)
	assert_almost_eq((snapped - Vector2(4, 0)).normalized().dot(direction), 0.0, EPS, "90° to the slanted wall")


func test_two_neighbours_lock_the_corner_on_their_crossing() -> void:
	# Square a-b-c-d with c dragged: w2 (b-c) and w3 (c-d) both lock at 90°.
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 4, 0),
		Fixtures.plan_node("c", 4, 3), Fixtures.plan_node("d", 0, 3)])
	project.walls.assign([Fixtures.wall("w1", "a", "b"), Fixtures.wall("w2", "b", "c"),
		Fixtures.wall("w3", "c", "d"), Fixtures.wall("w4", "d", "a")])
	var snapped := StructureSnap.snap_node(project, "c", Vector2(4.06, 3.08), false)
	assert_almost_eq(snapped, Vector2(4, 3), Vector2(EPS, EPS))


func test_a_neighbour_without_other_walls_uses_the_axes() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 3, 0.2)])
	project.walls.assign([Fixtures.wall("w1", "a", "b")])
	var snapped := StructureSnap.snap_node(project, "b", Vector2(3, 0.07), false)
	assert_almost_eq(snapped.y, 0.0, EPS, "horizontal")


func test_a_lone_corner_only_snaps_to_the_grid() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0)])
	assert_almost_eq(StructureSnap.snap_node(project, "a", Vector2(0.92, 0.07), false),
		Vector2(0.9, 0.05), Vector2(EPS, EPS))


func test_a_far_crossing_is_ignored() -> void:
	# Guides through b (horizontal) and d (15°) cross at (1.27, 0), yet the mouse
	# is 0.35 m away from that crossing while within reach of both guides.
	var project := ProjectData.new()
	var e := Vector2(5, 1) + Vector2.from_angle(deg_to_rad(15.0)) * 2.0
	project.nodes.assign([Fixtures.plan_node("a", -3, 0), Fixtures.plan_node("b", 0, 0),
		Fixtures.plan_node("c", 1.6, 0), Fixtures.plan_node("d", 5, 1),
		Fixtures.plan_node("e", e.x, e.y)])
	project.walls.assign([Fixtures.wall("w1", "a", "b"), Fixtures.wall("w2", "b", "c"),
		Fixtures.wall("w3", "d", "c"), Fixtures.wall("w4", "d", "e")])
	var snapped := StructureSnap.snap_node(project, "c", Vector2(1.62, 0.01), false)
	assert_almost_eq(snapped, Vector2(1.6, 0.0), Vector2(EPS, EPS), "the horizontal guide alone, snapped along it")
