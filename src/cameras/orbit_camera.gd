class_name OrbitCamera
extends Camera3D
## Orbit camera: right drag rotates, middle drag pans, wheel zooms,
## double click on a floor centres the view on that room.

const ROTATE_DEG_PER_PX := 0.3
const PAN_M_PER_PX_PER_M := 0.0015  # scaled by distance so panning feels constant
const ZOOM_STEP := 1.0
const FOCUS_SECONDS := 0.4

## Receives the horizontal viewing direction every frame (WorldView.update_cutaway).
signal heading_changed(forward: Vector2)

var orbit := OrbitState.new()
var _project: ProjectData


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
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit.rotate(-event.relative.x * ROTATE_DEG_PER_PX, -event.relative.y * ROTATE_DEG_PER_PX)
			_apply()
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var scale := PAN_M_PER_PX_PER_M * orbit.distance
			orbit.pan(Vector2(-event.relative.x, event.relative.y) * scale)
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
			create_tween().tween_method(_set_target, orbit.target, Vector3(c.x, 0, c.y), FOCUS_SECONDS)
			return


func _set_target(value: Vector3) -> void:
	orbit.target = value
	_apply()


func _apply() -> void:
	transform = orbit.camera_transform()
