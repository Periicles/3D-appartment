extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4


func _project(nodes: Array, walls: Array) -> ProjectData:
	var project := ProjectData.new()
	for n in nodes:
		project.nodes.append(Fixtures.plan_node(n[0], n[1], n[2]))
	for w in walls:
		var wall := Fixtures.wall(w[0], w[1], w[2])
		wall.thickness = w[3]
		project.walls.append(wall)
	return project


func _has_point(points: PackedVector2Array, expected: Vector2) -> bool:
	for p in points:
		if p.distance_to(expected) < EPS:
			return true
	return false


func test_isolated_wall_is_a_rectangle() -> void:
	var project := _project([["a", 0, 0], ["b", 4, 0]], [["w", "a", "b", 0.2]])
	var quad: PackedVector2Array = Geometry.wall_footprints(project)["w"]
	assert_eq(quad.size(), 4)
	assert_almost_eq(Geometry.polygon_area(quad), 0.8, EPS)
	for corner in [Vector2(0, 0.1), Vector2(0, -0.1), Vector2(4, 0.1), Vector2(4, -0.1)]:
		assert_true(_has_point(quad, corner), "missing %s in %s" % [corner, quad])


func test_footprints_are_counter_clockwise() -> void:
	var project := _project([["a", 0, 0], ["b", 4, 0]], [["w", "a", "b", 0.2]])
	assert_false(Geometry2D.is_polygon_clockwise(Geometry.wall_footprints(project)["w"]))


func test_right_angle_corner_is_mitred() -> void:
	var project := _project(
		[["a", 0, 0], ["b", 4, 0], ["c", 0, 4]],
		[["w1", "a", "b", 0.2], ["w2", "a", "c", 0.2]])
	var footprints := Geometry.wall_footprints(project)
	for id in ["w1", "w2"]:
		var quad: PackedVector2Array = footprints[id]
		assert_true(_has_point(quad, Vector2(-0.1, -0.1)), "%s outer corner: %s" % [id, quad])
		assert_true(_has_point(quad, Vector2(0.1, 0.1)), "%s inner corner: %s" % [id, quad])
		assert_almost_eq(Geometry.polygon_area(quad), 0.8, EPS)


func test_mitre_works_for_non_orthogonal_walls() -> void:
	var project := _project(
		[["a", 0, 0], ["b", 4, 0], ["c", 3, 3]],
		[["w1", "a", "b", 0.2], ["w2", "a", "c", 0.2]])
	var footprints := Geometry.wall_footprints(project)
	var shared := 0
	for p in footprints["w1"]:
		if _has_point(footprints["w2"], p):
			shared += 1
	assert_eq(shared, 2, "a mitred joint shares both corners")


func test_acute_angle_falls_back_to_square_cut() -> void:
	var project := _project(
		[["a", 0, 0], ["b", 4, 0], ["c", 4, 0.2]],
		[["w1", "a", "b", 0.2], ["w2", "a", "c", 0.2]])
	var quad: PackedVector2Array = Geometry.wall_footprints(project)["w1"]
	for p in quad:
		assert_true(p.x > -0.4 - EPS, "no spike past the miter limit: %s" % [quad])


func test_partition_stops_on_face_of_through_wall() -> void:
	var project := _project(
		[["a", 0, 0], ["m", 2, 0], ["b", 4, 0], ["c", 2, 3]],
		[["w1", "a", "m", 0.2], ["w2", "m", "b", 0.2], ["p", "m", "c", 0.08]])
	var footprints := Geometry.wall_footprints(project)
	var partition: PackedVector2Array = footprints["p"]
	assert_true(_has_point(partition, Vector2(1.96, 0.1)), "partition: %s" % [partition])
	assert_true(_has_point(partition, Vector2(2.04, 0.1)), "partition: %s" % [partition])
	assert_true(_has_point(footprints["w1"], Vector2(2, -0.1)), "through wall stays straight: %s" % [footprints["w1"]])


func test_wall_with_missing_node_has_no_footprint() -> void:
	var project := _project([["a", 0, 0]], [["w", "a", "ghost", 0.2]])
	assert_false(Geometry.wall_footprints(project).has("w"))


func test_zero_length_wall_has_no_footprint() -> void:
	var project := _project([["a", 0, 0], ["b", 0, 0]], [["w", "a", "b", 0.2]])
	assert_false(Geometry.wall_footprints(project).has("w"))


func test_polygon_area_of_square() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	assert_almost_eq(Geometry.polygon_area(square), 16.0, EPS)


func test_polygon_area_ignores_winding() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(0, 4), Vector2(4, 4), Vector2(4, 0)])
	assert_almost_eq(Geometry.polygon_area(square), 16.0, EPS)


func test_polygon_area_of_concave_l_shape() -> void:
	var l_shape := PackedVector2Array([
		Vector2(0, 0), Vector2(4, 0), Vector2(4, 2), Vector2(2, 2), Vector2(2, 4), Vector2(0, 4)])
	assert_almost_eq(Geometry.polygon_area(l_shape), 12.0, EPS)


func test_polygon_centroid_of_square() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	assert_almost_eq(Geometry.polygon_centroid(square), Vector2(2, 2), Vector2(EPS, EPS))


func test_room_net_area_subtracts_half_wall_thickness() -> void:
	var project := Fixtures.square_room()
	# 4 m x 4 m between wall centres, 0.2 m walls: 16 - 4 * 4 * 0.1 = 14.4
	assert_almost_eq(Geometry.room_net_area(project, project.rooms[0]), 14.4, EPS)


func test_room_net_area_keeps_open_edges() -> void:
	var project := Fixtures.square_room()
	project.walls.erase(project.get_wall("w3"))
	project.openings.clear()
	assert_almost_eq(Geometry.room_net_area(project, project.rooms[0]), 14.8, EPS)
