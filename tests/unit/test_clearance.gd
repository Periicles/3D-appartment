extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3
const BOX := Vector3(1.0, 0.5, 0.6)  # 1 m wide, 0.6 m deep


func _empty_room() -> ProjectData:
	var project := Fixtures.square_room()
	project.furniture.clear()
	return project


func _square(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(-half, -half), center + Vector2(half, -half),
		center + Vector2(half, half), center + Vector2(-half, half)])


func test_distances_to_the_walls_of_the_square_room() -> void:
	# The room's free floor spans 0.1 .. 3.9 on both axes (0.2 m walls on a 4 m square).
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, Clearance.obstacles_for(_empty_room(), ""))
	assert_almost_eq(result.front.distance, 3.9 - 2.3, EPS, "front faces +z")
	assert_almost_eq(result.back.distance, 1.7 - 0.1, EPS)
	assert_almost_eq(result.right.distance, 3.9 - 2.5, EPS)
	assert_almost_eq(result.left.distance, 1.5 - 0.1, EPS)


func test_rotation_turns_the_sides() -> void:
	# A quarter turn: the front faces +x, the right side faces -z.
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 90.0, Clearance.obstacles_for(_empty_room(), ""))
	assert_almost_eq(result.front.distance, 3.9 - 2.3, EPS)
	assert_almost_eq(result.right.distance, 1.5 - 0.1, EPS)
	assert_almost_eq(result.left.distance, 3.9 - 2.5, EPS)


func test_reports_where_the_gap_starts_and_ends() -> void:
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, Clearance.obstacles_for(_empty_room(), ""))
	assert_almost_eq(result.back.from.y, 1.7, EPS)
	assert_almost_eq(result.back.to.y, 0.1, EPS)
	assert_almost_eq(result.back.from.distance_to(result.back.to), result.back.distance, EPS)


func test_nearest_furniture_counts_and_the_item_itself_is_ignored() -> void:
	var project := _empty_room()
	var sofa := Fixtures.sofa("neighbour")
	sofa.pos = Vector2(2, 3.2)
	sofa.rotation_deg = 0.0
	sofa.size = Vector3(2.0, 0.85, 0.6)  # spans z 2.9 .. 3.5
	project.furniture.append(sofa)
	var me := Fixtures.sofa("me")
	me.pos = Vector2(2, 2)
	project.furniture.append(me)
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, Clearance.obstacles_for(project, "me"))
	assert_almost_eq(result.front.distance, 2.9 - 2.3, EPS, "the neighbour, not the wall")


func test_the_shortest_ray_wins_when_an_obstacle_covers_part_of_a_side() -> void:
	var post := _square(Vector2(2.45, 2.6), 0.05)  # in front of the right end only
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, [post] as Array[PackedVector2Array])
	assert_almost_eq(result.front.distance, 2.55 - 2.3, EPS)


func test_open_space_reports_nothing() -> void:
	var far_wall := _square(Vector2(50, 50), 1.0)
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, [far_wall] as Array[PackedVector2Array])
	assert_true(result.is_empty())


func test_overlap_counts_as_zero() -> void:
	var block := _square(Vector2(2, 2.4), 0.2)  # covers the middle of the front side
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, [block] as Array[PackedVector2Array])
	assert_eq(result.front.distance, 0.0)


func test_a_narrow_neighbour_between_the_old_three_rays_is_seen() -> void:
	# 1 m wide box: the old rays sat at x = 1.52, 2.0 and 2.48; this table spans 2.1 .. 2.4.
	var table := _square(Vector2(2.25, 2.6), 0.15)
	var result := Clearance.free_distances(Vector2(2, 2), BOX, 0.0, [table] as Array[PackedVector2Array])
	assert_almost_eq(result.front.distance, 2.45 - 2.3, EPS)


func test_a_side_without_length_casts_a_single_ray() -> void:
	var result := Clearance.free_distances(Vector2(2, 2), Vector3(0.0, 0.5, 0.0), 0.0,
		[_square(Vector2(2, 3), 0.1)] as Array[PackedVector2Array])
	assert_almost_eq(result.front.distance, 0.9, EPS)
