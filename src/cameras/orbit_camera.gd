class_name OrbitCamera
extends Camera3D
## Orbit camera: right drag rotates, middle drag (or Shift + right drag) pans,
## wheel zooms, double click on a floor centres the view on that room.
## Trackpad: two-finger scroll rotates, Shift + scroll pans, pinch zooms.

const ROTATE_DEG_PER_PX := 0.3
const PAN_M_PER_PX_PER_M := 0.0015  # scaled by distance so panning feels constant
const ZOOM_STEP := 1.0
const SCROLL_ROTATE_DEG_PER_UNIT := 3.0
const SCROLL_PAN_M_PER_UNIT_PER_M := 0.02
const PINCH_ZOOM_SENSITIVITY := 10.0
const FOCUS_SECONDS := 0.4

## Receives the horizontal viewing direction every frame (WorldView.update_cutaway).
signal heading_changed(forward: Vector2)

var orbit := OrbitState.new()
var _project: ProjectData
var _focus_tween: Tween


func frame_project(project: ProjectData) -> void:
	_project = project
	var center := Cutaway.apartment_center(project)
	orbit.target = Vector3(center.x, 0, center.y)
	_apply()


func _ready() -> void:
	_apply()


func _process(_delta: float) -> void:
	heading_changed.emit(orbit.forward_2d())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var panning: bool = event.button_mask & MOUSE_BUTTON_MASK_MIDDLE \
				or (event.button_mask & MOUSE_BUTTON_MASK_RIGHT and event.shift_pressed)
		if panning:
			_pan(event.relative, PAN_M_PER_PX_PER_M)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit.rotate(-event.relative.x * ROTATE_DEG_PER_PX, -event.relative.y * ROTATE_DEG_PER_PX)
			_apply()
	elif event is InputEventPanGesture:
		if event.shift_pressed:
			_pan(event.delta, SCROLL_PAN_M_PER_UNIT_PER_M)
		else:
			orbit.rotate(-event.delta.x * SCROLL_ROTATE_DEG_PER_UNIT, -event.delta.y * SCROLL_ROTATE_DEG_PER_UNIT)
			_apply()
	elif event is InputEventMagnifyGesture:
		orbit.zoom((event.factor - 1.0) * PINCH_ZOOM_SENSITIVITY)
		_apply()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				orbit.zoom(ZOOM_STEP)
				_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				orbit.zoom(-ZOOM_STEP)
				_apply()
			MOUSE_BUTTON_LEFT:
				if event.double_click:
					_focus_room_under(event.position)


func _pan(screen_delta: Vector2, metres_per_unit_per_metre: float) -> void:
	var scale := metres_per_unit_per_metre * orbit.distance
	orbit.pan(Vector2(-screen_delta.x, screen_delta.y) * scale)
	_apply()


func _focus_room_under(screen_point: Vector2) -> void:
	if _project == null:
		return
	var hit = Plane(Vector3.UP, 0).intersects_ray(project_ray_origin(screen_point), project_ray_normal(screen_point))
	if hit == null:
		return
	var point := Vector2(hit.x, hit.z)
	for room in _project.rooms:
		var polygon := Geometry.room_polygon(_project, room)
		if Geometry2D.is_point_in_polygon(point, polygon):
			var c := Geometry.polygon_centroid(polygon)
			if _focus_tween:
				_focus_tween.kill()
			_focus_tween = create_tween()
			_focus_tween.tween_method(_set_target, orbit.target, Vector3(c.x, 0, c.y), FOCUS_SECONDS)
			return


func _set_target(value: Vector3) -> void:
	orbit.target = value
	_apply()


func _apply() -> void:
	transform = orbit.camera_transform()
