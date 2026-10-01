extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4
const SOFA := Vector3(2.0, 0.85, 0.9)


func _item(pos: Vector2, rotation_deg: float, size := SOFA) -> FurnitureItem:
	var item := Fixtures.sofa("f")
	item.pos = pos
	item.rotation_deg = rotation_deg
	item.size = size
	return item


func test_snap_to_grid_rounds_to_five_centimetres() -> void:
	assert_almost_eq(Placement.snap_to_grid(Vector2(1.023, 2.974)), Vector2(1.0, 2.95), Vector2(EPS, EPS))


func test_front_direction_matches_godot_y_rotation() -> void:
	for deg in [0.0, 90.0, 180.0, 33.0]:
		var basis := Basis(Vector3.UP, deg_to_rad(deg))
		var front_3d := basis * Vector3(0, 0, 1)
		assert_almost_eq(Placement.front_direction(deg), Vector2(front_3d.x, front_3d.z), Vector2(EPS, EPS), str(deg))


func test_to_world_matches_godot_y_rotation() -> void:
	var local := Vector2(0.7, -0.3)  # x along width, y towards the front
	var basis := Basis(Vector3.UP, deg_to_rad(40.0))
	var expected_3d := basis * Vector3(local.x, 0, local.y) + Vector3(1, 0, 2)
	assert_almost_eq(Placement.to_world(Vector2(1, 2), 40.0, local), Vector2(expected_3d.x, expected_3d.z),
		Vector2(EPS, EPS))


func test_footprint_unrotated() -> void:
	var corners := Placement.footprint(Vector2(1, 1), SOFA, 0.0)
	assert_almost_eq(Geometry.polygon_area(corners), 1.8, EPS)
	for corner in [Vector2(0, 0.55), Vector2(2, 0.55), Vector2(2, 1.45), Vector2(0, 1.45)]:
		var found := false
		for p in corners:
			found = found or p.distance_to(corner) < EPS
		assert_true(found, "missing %s in %s" % [corner, corners])


func test_footprint_rotated_quarter_turn_swaps_extent() -> void:
	var corners := Placement.footprint(Vector2.ZERO, SOFA, 90.0)
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for p in corners:
		bounds = bounds.expand(p)
	assert_almost_eq(bounds.size, Vector2(0.9, 2.0), Vector2(EPS, EPS))
	assert_false(Geometry2D.is_polygon_clockwise(corners))


func test_snaps_against_nearby_wall_facing_into_the_room() -> void:
	# Square room: wall w1 runs along z = 0 (thickness 0.2, inner face at z = 0.1).
	var project := Fixtures.square_room()
	var snap := Placement.snap_to_wall(project, Vector2(2.0, 0.65), SOFA)
	assert_false(snap.is_empty())
	assert_almost_eq(snap.pos, Vector2(2.0, 0.55), Vector2(EPS, EPS), "back flush with the inner face")
	assert_almost_eq(Placement.front_direction(snap.rotation_deg), Vector2(0, 1), Vector2(EPS, EPS),
		"front faces into the room")


func test_snaps_against_slanted_wall() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 4, 4)])
	project.walls.assign([Fixtures.wall("w", "a", "b")])
	var outward := Vector2(-1, 1).normalized()
	var near := Vector2(2, 2) + outward * (0.1 + 0.45 + 0.08)
	var snap := Placement.snap_to_wall(project, near, SOFA)
	assert_false(snap.is_empty())
	assert_almost_eq(snap.pos, Vector2(2, 2) + outward * 0.55, Vector2(EPS, EPS))
	assert_almost_eq(Placement.front_direction(snap.rotation_deg), outward, Vector2(EPS, EPS))


func test_no_snap_when_too_far_from_any_wall() -> void:
	assert_true(Placement.snap_to_wall(Fixtures.square_room(), Vector2(2, 2), SOFA).is_empty())


func test_no_snap_beyond_the_wall_ends() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 2, 0)])
	project.walls.assign([Fixtures.wall("w", "a", "b")])
	assert_true(Placement.snap_to_wall(project, Vector2(3.0, 0.6), SOFA).is_empty())


func test_closest_wall_wins_in_a_corner() -> void:
	# Near the n1 corner: 0.08 m from w4's face, 0.12 m from w1's face.
	var project := Fixtures.square_room()
	var snap := Placement.snap_to_wall(project, Vector2(0.1 + 0.45 + 0.08, 0.1 + 0.45 + 0.12), SOFA)
	assert_almost_eq(Placement.front_direction(snap.rotation_deg), Vector2(1, 0), Vector2(EPS, EPS),
		"snapped to the west wall")


func test_ray_from_above_hits_item_top() -> void:
	var item := _item(Vector2(1, 1), 30.0)
	var distance := Placement.ray_distance_to_item(Vector3(1, 5, 1), Vector3.DOWN, item)
	assert_almost_eq(distance, 5.0 - SOFA.y, EPS)


func test_ray_misses_item_beside_it() -> void:
	var item := _item(Vector2(1, 1), 0.0)
	assert_eq(Placement.ray_distance_to_item(Vector3(3, 5, 1), Vector3.DOWN, item), -1.0)


func test_ray_respects_item_rotation() -> void:
	# Unrotated, the sofa spans x in [0, 2]; turned 90°, it spans x in [0.55, 1.45].
	var item := _item(Vector2(1, 1), 90.0)
	assert_eq(Placement.ray_distance_to_item(Vector3(1.8, 5, 1), Vector3.DOWN, item), -1.0)
	assert_gt(Placement.ray_distance_to_item(Vector3(1, 5, 1.8), Vector3.DOWN, item), 0.0)


func test_pick_returns_closest_item() -> void:
	var low := _item(Vector2(1, 1), 0.0, Vector3(1, 0.5, 1))
	low.id = "low"
	var tall := _item(Vector2(1, 1), 0.0, Vector3(0.5, 2.0, 0.5))
	tall.id = "tall"
	var items: Array[FurnitureItem] = [low, tall]
	assert_eq(Placement.pick_item(Vector3(1, 5, 1), Vector3.DOWN, items), "tall")


func test_pick_returns_empty_when_nothing_hit() -> void:
	var items: Array[FurnitureItem] = [_item(Vector2(1, 1), 0.0)]
	assert_eq(Placement.pick_item(Vector3(9, 5, 9), Vector3.DOWN, items), "")
