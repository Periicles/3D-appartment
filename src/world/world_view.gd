class_name WorldView
extends Node3D
## Rebuilds walls and floors when a project is loaded, and lowers the walls
## that hide the inside from the orbit camera.

const CUTAWAY_TWEEN_SECONDS := 0.25

var cutaway_mode := Cutaway.Mode.AUTO
var _project: ProjectData
var _walls: Node3D
var _floors: Node3D
var _center := Vector2.ZERO
var _last_forward := Vector2.ZERO
var _lowered := {}  # wall id -> bool, to tween only on change
var _tweens := {}  # wall id -> Tween, so a new move replaces the running one


func show_project(project: ProjectData) -> void:
	_project = project
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_floors = FloorBuilder.build(project)
	_walls = WallBuilder.build(project)
	add_child(_floors)
	add_child(_walls)
	_center = Cutaway.apartment_center(project)
	_lowered.clear()
	_tweens.clear()
	_last_forward = Vector2.ZERO


func cycle_cutaway_mode() -> void:
	cutaway_mode = (cutaway_mode + 1) % Cutaway.Mode.size() as Cutaway.Mode
	_lowered.clear()
	_last_forward = Vector2.ZERO


## Called every frame by the camera rig with its horizontal viewing direction.
func update_cutaway(camera_forward: Vector2) -> void:
	if _project == null or camera_forward.is_equal_approx(_last_forward):
		return
	_last_forward = camera_forward
	for wall in _project.walls:
		var node := _walls.get_node_or_null(NodePath(wall.id)) as Node3D
		if node == null:
			continue
		var lowered := Cutaway.is_lowered(_project.get_plan_node(wall.a).pos,
			_project.get_plan_node(wall.b).pos, _center, camera_forward)
		if _lowered.get(wall.id) == lowered:
			continue
		_lowered[wall.id] = lowered
		var target := Cutaway.target_scale(cutaway_mode, lowered, wall.height)
		var running: Tween = _tweens.get(wall.id)
		if running:
			running.kill()
		var tween := create_tween()
		tween.tween_property(node, "scale:y", target, CUTAWAY_TWEEN_SECONDS)
		_tweens[wall.id] = tween
