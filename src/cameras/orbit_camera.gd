class_name OrbitCamera
extends Camera3D
## Orbit camera: right drag rotates, middle drag (or Shift + right drag) pans,
## wheel zooms, double click on a floor centres the view on that room.
## Trackpad: two-finger scroll rotates, Shift + scroll pans, pinch zooms.
## Plan view: orthographic, looking straight down with north (-z) up; every
## drag or scroll pans, wheel and pinch zoom.

const ROTATE_DEG_PER_PX := 0.3
const PAN_M_PER_PX_PER_M := 0.0015  # scaled by distance so panning feels constant
const ZOOM_STEP := 1.0
const SCROLL_ROTATE_DEG_PER_UNIT := 3.0
const SCROLL_PAN_M_PER_UNIT_PER_M := 0.02
const PINCH_ZOOM_SENSITIVITY := 10.0
## Trackpad scroll units converted to screen pixels when panning the plan.
const SCROLL_PLAN_PX_PER_UNIT := 12.0
const FOCUS_SECONDS := 0.4
const VIEW_TRANSITION_SECONDS := 0.4
## Height of the plan camera above the target; far above any wall.
const PLAN_HEIGHT := 60.0
## Looking down (-y) with the screen's up towards -z.
const PLAN_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

## Receives the horizontal viewing direction every frame (WorldView.update_cutaway).
signal heading_changed(forward: Vector2)
signal view_mode_changed(plan: bool)

var orbit := OrbitState.new()
var _project: ProjectData
var _focus_tween: Tween
var _plan := false
var _view_tween: Tween


func frame_project(project: ProjectData) -> void:
	_project = project
	var center := Cutaway.apartment_center(project)
	orbit.target = Vector3(center.x, 0, center.y)
	_apply()


func _ready() -> void:
	_apply()


func is_plan_mode() -> bool:
	return _plan


## Switches between the orbit view and the plan view, with a short camera move.
func set_plan_mode(plan: bool, animate: bool = true) -> void:
	if plan == _plan:
		return
	_plan = plan
	if _view_tween:
		_view_tween.kill()
	var target := _pose()
	if not animate or not is_inside_tree():
		_finish_view_change()
	else:
		# The move happens in perspective; the plan switches to orthographic on arrival.
		projection = Camera3D.PROJECTION_PERSPECTIVE
		_view_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_view_tween.tween_property(self, "transform", target, VIEW_TRANSITION_SECONDS)
		_view_tween.tween_callback(_finish_view_change)
	view_mode_changed.emit(plan)


func toggle_plan_mode() -> void:
	set_plan_mode(not _plan)


func _process(_delta: float) -> void:
	if not _plan:
		heading_changed.emit(orbit.forward_2d())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var panning: bool = event.button_mask & MOUSE_BUTTON_MASK_MIDDLE \
				or (event.button_mask & MOUSE_BUTTON_MASK_RIGHT and event.shift_pressed)
		if _plan and event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_pan_plan(event.relative)
		elif panning:
			_pan(event.relative, PAN_M_PER_PX_PER_M)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit.rotate(-event.relative.x * ROTATE_DEG_PER_PX, -event.relative.y * ROTATE_DEG_PER_PX)
			_apply()
	elif event is InputEventPanGesture:
		if _plan:
			_pan_plan(event.delta * SCROLL_PLAN_PX_PER_UNIT)
		elif event.shift_pressed:
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


## Drags the plan under the cursor: content follows the pointer.
func _pan_plan(screen_delta: Vector2) -> void:
	var metres_per_px := size / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	orbit.target += Vector3(-screen_delta.x, 0, -screen_delta.y) * metres_per_px
	_apply()


func _set_target(value: Vector3) -> void:
	orbit.target = value
	_apply()


func _apply() -> void:
	if _view_tween and _view_tween.is_running():
		return
	transform = _pose()
	if _plan:
		size = orbit.distance


func _pose() -> Transform3D:
	if _plan:
		return Transform3D(PLAN_BASIS, orbit.target + Vector3.UP * PLAN_HEIGHT)
	return orbit.camera_transform()


func _finish_view_change() -> void:
	_view_tween = null  # still "running" while its final callback executes
	projection = Camera3D.PROJECTION_ORTHOGONAL if _plan else Camera3D.PROJECTION_PERSPECTIVE
	_apply()
