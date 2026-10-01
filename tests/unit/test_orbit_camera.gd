extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const FOCUS_WAIT := OrbitCamera.FOCUS_SECONDS + 0.2
const ROOM_CENTER := Vector3(2, 0, 2)
const DRAG := Vector2(40, 20)

var _camera: OrbitCamera


func before_each() -> void:
	_camera = OrbitCamera.new()
	add_child_autofree(_camera)


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _drag(mask: MouseButtonMask) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = DRAG
	event.button_mask = mask
	return event


func _double_click(at: Vector2) -> InputEventMouseButton:
	var event := _wheel(MOUSE_BUTTON_LEFT)
	event.double_click = true
	event.position = at
	return event


func test_wheel_up_zooms_in() -> void:
	var before := _camera.orbit.distance
	_camera._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_lt(_camera.orbit.distance, before)


func test_wheel_down_zooms_out() -> void:
	var before := _camera.orbit.distance
	_camera._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_gt(_camera.orbit.distance, before)


func test_right_drag_rotates() -> void:
	var before := _camera.orbit.yaw_deg
	_camera._unhandled_input(_drag(MOUSE_BUTTON_MASK_RIGHT))
	assert_ne(_camera.orbit.yaw_deg, before)


func test_middle_drag_pans() -> void:
	var before := _camera.orbit.target
	_camera._unhandled_input(_drag(MOUSE_BUTTON_MASK_MIDDLE))
	assert_ne(_camera.orbit.target, before)


func test_motion_without_button_does_nothing() -> void:
	var yaw := _camera.orbit.yaw_deg
	var target := _camera.orbit.target
	_camera._unhandled_input(_drag(0 as MouseButtonMask))
	assert_eq(_camera.orbit.yaw_deg, yaw)
	assert_eq(_camera.orbit.target, target)


func test_frame_project_centers_on_apartment() -> void:
	_camera.frame_project(Fixtures.square_room())
	assert_eq(_camera.orbit.target, ROOM_CENTER)


func test_double_click_on_floor_focuses_room() -> void:
	_camera.frame_project(Fixtures.square_room())
	_camera.orbit.target = Vector3(10, 0, 10)
	_camera._apply()
	var click_at := _camera.unproject_position(ROOM_CENTER)
	_camera._unhandled_input(_double_click(click_at))
	await wait_seconds(FOCUS_WAIT)
	assert_almost_eq(_camera.orbit.target.x, ROOM_CENTER.x, 1e-3)
	assert_almost_eq(_camera.orbit.target.z, ROOM_CENTER.z, 1e-3)


func test_double_click_without_project_does_nothing() -> void:
	var before := _camera.orbit.target
	_camera._unhandled_input(_double_click(Vector2(100, 100)))
	await wait_seconds(FOCUS_WAIT)
	assert_eq(_camera.orbit.target, before)
