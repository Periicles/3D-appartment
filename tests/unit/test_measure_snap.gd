extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4


func _room() -> ProjectData:
	var project := Fixtures.square_room()
	project.furniture.clear()
	return project


func test_snaps_to_a_wall_corner() -> void:
	# Inner corner of the mitred joint at n1 is (0.1, 0.1).
	assert_almost_eq(MeasureSnap.snap(Vector2(0.15, 0.18), _room()), Vector2(0.1, 0.1), Vector2(EPS, EPS))


func test_snaps_to_a_wall_face_when_no_corner_is_near() -> void:
	assert_almost_eq(MeasureSnap.snap(Vector2(2.0, 0.2), _room()), Vector2(2.0, 0.1), Vector2(EPS, EPS))


func test_snaps_to_a_furniture_corner() -> void:
	var project := _room()
	var table := Fixtures.sofa("t")
	table.pos = Vector2(2, 2)
	table.rotation_deg = 0.0
	table.size = Vector3(1.0, 0.7, 0.6)  # corners at (1.5..2.5, 1.7..2.3)
	project.furniture.append(table)
	assert_almost_eq(MeasureSnap.snap(Vector2(2.55, 2.35), project), Vector2(2.5, 2.3), Vector2(EPS, EPS))


func test_corners_win_over_edges() -> void:
	# Closer to the face (0.04) than to the corner (0.07), but the corner is in reach.
	assert_almost_eq(MeasureSnap.snap(Vector2(0.16, 0.14), _room()), Vector2(0.1, 0.1), Vector2(EPS, EPS))


func test_free_point_stays_put() -> void:
	assert_eq(MeasureSnap.snap(Vector2(2, 2), _room()), Vector2(2, 2))


func test_radius_is_respected() -> void:
	assert_eq(MeasureSnap.snap(Vector2(2.0, 0.2), _room(), 0.05), Vector2(2.0, 0.2))
