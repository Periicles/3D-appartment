extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4


func _window(id: String, wall_id: String) -> Opening:
	var window := Fixtures.door(id, wall_id, 2.0, 1.2)
	window.kind = "window"
	window.sill = 0.9
	window.height = 1.2
	window.swing = "none"
	return window


func test_builds_one_node_per_wall() -> void:
	var walls: Node3D = autofree(WallBuilder.build(Fixtures.square_room()))
	assert_eq(walls.get_child_count(), 4)
	for id in ["w1", "w2", "w3", "w4"]:
		assert_not_null(walls.get_node_or_null(id), id)


func test_wall_body_is_extruded_footprint() -> void:
	var project := Fixtures.square_room()
	var walls: Node3D = autofree(WallBuilder.build(project))
	var body := walls.get_node("w2/Body") as CSGPolygon3D
	assert_eq(body.polygon, Geometry.wall_footprints(project)["w2"])
	assert_eq(body.depth, project.get_wall("w2").height)


func test_door_is_cut_at_its_offset_and_height() -> void:
	var walls: Node3D = autofree(WallBuilder.build(Fixtures.square_room()))
	var body := walls.get_node("w1/Body") as CSGPolygon3D
	var cutter := body.get_node("Cut_o1") as CSGBox3D
	assert_eq(cutter.operation, CSGShape3D.OPERATION_SUBTRACTION)
	var world := body.transform * cutter.transform
	assert_almost_eq(world.origin, Vector3(1.0, 1.02, 0.0), Vector3(EPS, EPS, EPS))
	assert_almost_eq(cutter.size.x, 0.8, EPS)
	assert_almost_eq(cutter.size.y, 2.04, EPS)
	assert_gt(cutter.size.z, 0.2, "cutter crosses the whole wall thickness")


func test_cutter_follows_wall_direction() -> void:
	var walls: Node3D = autofree(WallBuilder.build(Fixtures.square_room()))
	var project := Fixtures.square_room()
	project.openings[0].wall_id = "w2"  # wall w2 runs along +z
	walls = autofree(WallBuilder.build(project))
	var body := walls.get_node("w2/Body") as CSGPolygon3D
	var world := body.transform * (body.get_node("Cut_o1") as CSGBox3D).transform
	assert_almost_eq(world.origin, Vector3(4.0, 1.02, 1.0), Vector3(EPS, EPS, EPS))
	assert_almost_eq(absf(world.basis.x.normalized().dot(Vector3(0, 0, 1))), 1.0, EPS,
		"opening width runs along the wall")


func test_windows_get_glass_and_doors_do_not() -> void:
	var project := Fixtures.square_room()
	project.openings.append(_window("o2", "w3"))
	var walls: Node3D = autofree(WallBuilder.build(project))
	assert_not_null(walls.get_node_or_null("w3/Glass_o2"))
	assert_null(walls.get_node_or_null("w1/Glass_o1"))


func test_every_wall_has_a_cap() -> void:
	var walls: Node3D = autofree(WallBuilder.build(Fixtures.square_room()))
	for wall in walls.get_children():
		assert_not_null(wall.get_node_or_null("Cap"), wall.name)


func test_wall_without_footprint_is_skipped() -> void:
	var project := Fixtures.square_room()
	project.walls.append(Fixtures.wall("w5", "n1", "n1"))
	var walls: Node3D = autofree(WallBuilder.build(project))
	assert_eq(walls.get_child_count(), 4)


func test_builds_one_floor_per_room() -> void:
	var floors: Node3D = autofree(FloorBuilder.build(Fixtures.square_room()))
	assert_eq(floors.get_child_count(), 1)
	var floor_mesh := floors.get_node("r1") as MeshInstance3D
	assert_eq(floor_mesh.mesh.get_surface_count(), 1)


func test_floor_color_follows_kind() -> void:
	var floors: Node3D = autofree(FloorBuilder.build(Fixtures.square_room()))
	var mat := (floors.get_node("r1") as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(mat.albedo_color, Palette.floor_color("wood"))


func test_flat_mesh_triangles_face_up() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(0, 4), Vector2(4, 4), Vector2(4, 0)])
	var arrays := FloorBuilder.flat_mesh(square, 0.5).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_eq(indices.size(), 6)
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var cross := (vertices[indices[i + 1]] - a).cross(vertices[indices[i + 2]] - a)
		assert_lt(cross.y, 0.0, "clockwise seen from above = front face in Godot")
	for v in vertices:
		assert_eq(v.y, 0.5)


func test_flat_mesh_of_degenerate_polygon_is_empty() -> void:
	var line := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0)])
	assert_eq(FloorBuilder.flat_mesh(line, 0.0).get_surface_count(), 0)


func test_unknown_floor_kind_uses_fallback_color() -> void:
	assert_eq(Palette.floor_color("marble"), Palette.FLOOR_FALLBACK)
