extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3
const WAIT := OrbitCamera.VIEW_TRANSITION_SECONDS + 0.2

var _camera: OrbitCamera


func before_each() -> void:
	_camera = OrbitCamera.new()
	add_child_autofree(_camera)
	_camera.frame_project(Fixtures.square_room())


func _drag(relative: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.button_mask = mask
	_camera._unhandled_input(event)


func test_starts_in_orbit_perspective() -> void:
	assert_false(_camera.is_plan_mode())
	assert_eq(_camera.projection, Camera3D.PROJECTION_PERSPECTIVE)


func test_plan_mode_looks_straight_down_orthographic_with_north_up() -> void:
	watch_signals(_camera)
	_camera.set_plan_mode(true)
	assert_signal_emitted_with_parameters(_camera, "view_mode_changed", [true])
	await wait_seconds(WAIT)
	assert_eq(_camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_almost_eq(-_camera.global_transform.basis.z, Vector3.DOWN, Vector3(EPS, EPS, EPS))
	assert_almost_eq(_camera.global_transform.basis.y, Vector3(0, 0, -1), Vector3(EPS, EPS, EPS))
	assert_almost_eq(_camera.size, _camera.orbit.distance, EPS)


func test_plan_is_centred_on_the_target() -> void:
	_camera.set_plan_mode(true, false)
	assert_almost_eq(Vector2(_camera.position.x, _camera.position.z), Vector2(2, 2), Vector2(EPS, EPS))


func test_right_drag_pans_in_plan_instead_of_rotating() -> void:
	_camera.set_plan_mode(true, false)
	var yaw := _camera.orbit.yaw_deg
	var before := _camera.orbit.target
	_drag(Vector2(50, 0), MOUSE_BUTTON_MASK_RIGHT)
	assert_eq(_camera.orbit.yaw_deg, yaw)
	assert_lt(_camera.orbit.target.x, before.x, "content follows the pointer to the right")


func test_two_finger_scroll_pans_in_plan() -> void:
	_camera.set_plan_mode(true, false)
	var before := _camera.orbit.target
	var gesture := InputEventPanGesture.new()
	gesture.delta = Vector2(0, 3)
	_camera._unhandled_input(gesture)
	assert_ne(_camera.orbit.target, before)


func test_wheel_zoom_changes_the_plan_scale() -> void:
	_camera.set_plan_mode(true, false)
	var before := _camera.size
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_camera._unhandled_input(wheel)
	assert_lt(_camera.size, before)


func test_no_heading_is_sent_in_plan() -> void:
	_camera.set_plan_mode(true, false)
	watch_signals(_camera)
	await wait_physics_frames(2)
	assert_signal_not_emitted(_camera, "heading_changed")


func test_back_to_orbit_restores_perspective_and_heading() -> void:
	_camera.set_plan_mode(true, false)
	_camera.set_plan_mode(false)
	await wait_seconds(WAIT)
	assert_eq(_camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(_camera.transform.origin, _camera.orbit.camera_transform().origin, Vector3(EPS, EPS, EPS))


func test_transition_height_matches_the_orthographic_scale() -> void:
	assert_almost_eq(OrbitCamera.plan_transition_height(10.0, 90.0), 5.0, EPS)


func test_transition_height_is_clamped_above_the_walls() -> void:
	assert_eq(OrbitCamera.plan_transition_height(0.5, 75.0), OrbitCamera.MIN_TRANSITION_HEIGHT)


func test_leaving_plan_starts_from_the_matching_height() -> void:
	_camera.set_plan_mode(true, false)
	_camera.set_plan_mode(false)
	assert_eq(_camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_almost_eq(_camera.position.y, OrbitCamera.plan_transition_height(_camera.orbit.distance, _camera.fov), EPS)


func test_entering_plan_ends_orthographic_at_plan_height() -> void:
	_camera.set_plan_mode(true)
	await wait_seconds(WAIT)
	assert_almost_eq(_camera.position.y, OrbitCamera.PLAN_HEIGHT, EPS)
	assert_almost_eq(_camera.size, _camera.orbit.distance, EPS)


func test_input_is_ignored_during_the_transition() -> void:
	_camera.set_plan_mode(true)
	var before := _camera.orbit.distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_camera._unhandled_input(wheel)
	assert_eq(_camera.orbit.distance, before)


func test_framing_a_project_during_the_transition_lands_on_the_new_centre() -> void:
	_camera.set_plan_mode(true)
	var moved := Fixtures.square_room()
	for node in moved.nodes:
		node.pos += Vector2(10, 0)
	_camera.frame_project(moved)
	var center := Cutaway.apartment_center(moved)
	assert_almost_eq(Vector2(_camera.position.x, _camera.position.z), center, Vector2(EPS, EPS))
	assert_eq(_camera.projection, Camera3D.PROJECTION_ORTHOGONAL)


func test_any_mouse_press_releases_gui_focus_even_during_the_transition() -> void:
	var field: LineEdit = add_child_autofree(LineEdit.new())
	field.grab_focus()
	_camera.set_plan_mode(true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	_camera._unhandled_input(press)
	assert_null(get_viewport().gui_get_focus_owner())
