class_name MeasureTool
extends Node
## Free measuring (M): click A, then B; each pair stays drawn until Échap,
## which clears them all and leaves the tool. Points snap to corners and
## edges. Measurements are not saved in the project.

signal active_changed(active: bool)

var store: Node
var camera: Camera3D
var _active := false
var _start = null  # Vector2 of the pending first point, or null
var _measurements: Array = []  # [Vector2 a, Vector2 b] pairs
var _preview: DimensionLine
var _layer: Node3D


## `layer` receives the dimension lines (a Node3D in the 3D scene).
func setup(p_store: Node, p_camera: Camera3D, layer: Node3D) -> void:
	store = p_store
	camera = p_camera
	_layer = layer
	_preview = DimensionLine.new()
	_preview.name = "Preview"
	_preview.visible = false
	_layer.add_child(_preview)


func is_active() -> bool:
	return _active


func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	if not active:
		_start = null
		_preview.visible = false
	active_changed.emit(active)


func toggle() -> void:
	set_active(not _active)


func measurements() -> Array:
	return _measurements.duplicate()


## Removes every measurement and leaves the tool.
func clear_all() -> void:
	_measurements.clear()
	for child in _layer.get_children():
		if child != _preview:
			_layer.remove_child(child)
			child.queue_free()
	set_active(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion and _start != null:
		var point = _snapped_ground(event.position)
		if point != null:
			_preview.set_points(_start, point)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point = _snapped_ground(event.position)
		if point != null:
			_click(point)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		clear_all()
		get_viewport().set_input_as_handled()


func _click(point: Vector2) -> void:
	if _start == null:
		_start = point
		return
	if not point.is_equal_approx(_start):
		_measurements.append([_start, point])
		var line := DimensionLine.new()
		line.name = "Measure%d" % _measurements.size()
		_layer.add_child(line)
		line.set_points(_start, point)
	_start = null
	_preview.visible = false


func _snapped_ground(screen_pos: Vector2) -> Variant:
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos))
	if hit == null:
		return null
	return MeasureSnap.snap(Vector2(hit.x, hit.z), store.project)
