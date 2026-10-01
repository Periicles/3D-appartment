extends GutTest

const EPS := 1e-4


func test_pitch_is_clamped() -> void:
	var orbit := OrbitState.new()
	orbit.rotate(0, 500)
	assert_eq(orbit.pitch_deg, OrbitState.MAX_PITCH_DEG)
	orbit.rotate(0, -500)
	assert_eq(orbit.pitch_deg, OrbitState.MIN_PITCH_DEG)


func test_yaw_wraps_around() -> void:
	var orbit := OrbitState.new()
	orbit.yaw_deg = 350.0
	orbit.rotate(20, 0)
	assert_almost_eq(orbit.yaw_deg, 10.0, EPS)


func test_zoom_is_clamped() -> void:
	var orbit := OrbitState.new()
	orbit.zoom(100)
	assert_eq(orbit.distance, OrbitState.MIN_DISTANCE)
	orbit.zoom(-100)
	assert_eq(orbit.distance, OrbitState.MAX_DISTANCE)


func test_camera_sits_at_distance_from_target_and_looks_at_it() -> void:
	var orbit := OrbitState.new()
	orbit.target = Vector3(3, 0, 2)
	var t := orbit.camera_transform()
	assert_almost_eq(t.origin.distance_to(orbit.target), orbit.distance, EPS)
	var looking := -t.basis.z
	assert_almost_eq(looking.dot((orbit.target - t.origin).normalized()), 1.0, EPS)


func test_camera_is_above_target() -> void:
	assert_gt(OrbitState.new().camera_transform().origin.y, 0.0)


func test_forward_2d_matches_camera_heading() -> void:
	var orbit := OrbitState.new()
	var look := -orbit.camera_transform().basis.z
	var flat := Vector2(look.x, look.z).normalized()
	assert_almost_eq(flat.dot(orbit.forward_2d()), 1.0, EPS)


func test_pan_forward_moves_target_along_heading() -> void:
	var orbit := OrbitState.new()
	orbit.pan(Vector2(0, 1))
	assert_almost_eq(Vector2(orbit.target.x, orbit.target.z), orbit.forward_2d(), Vector2(EPS, EPS))
