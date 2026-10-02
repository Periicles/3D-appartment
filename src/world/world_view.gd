class_name WorldView
extends Node3D
## Rebuilds walls and floors when a project is loaded or its structure changes,
## and lowers the walls that hide the inside from the orbit camera.

const CUTAWAY_TWEEN_SECONDS := 0.25

var cutaway_mode := Cutaway.Mode.AUTO
var _project: ProjectData
var _walls: Node3D
var _floors: Node3D
var _center := Vector2.ZERO
var _last_forward := Vector2.ZERO
var _lowered := {}  # wall id -> bool, to tween only on change
var _suspended := false  # plan view: every wall stands at full height
var _tweens := {}  # wall id -> Tween, so a new move replaces the running one
var _highlighted := ""  # wall drawn in the selection colour (Structure mode)
var _highlight_material := Palette.material(Palette.SELECTION)


func show_project(project: ProjectData) -> void:
	_center = Cutaway.apartment_center(project)
	_lowered.clear()
	_build(project)


## Rebuilds the walls and floors of `project` (an edit, or a preview while
## dragging) without animating the cutaway: walls already lowered stay lowered.
## The cutaway centre is kept, so editing never flips which walls are lowered.
func refresh(project: ProjectData) -> void:
	_build(project)
	for wall in project.walls:
		var node := _walls.get_node_or_null(NodePath(wall.id)) as Node3D
		if node != null and _lowered.has(wall.id):
			node.scale.y = Cutaway.target_scale(cutaway_mode, _lowered[wall.id], wall.height)


## Height of the wall as currently drawn (lowered by the cutaway or not); 0 for
## an unknown id.
func wall_display_height(wall_id: String) -> float:
	if _project == null:
		return 0.0
	var wall := _project.get_wall(wall_id)
	var node := _walls.get_node_or_null(NodePath(wall_id)) as Node3D
	if wall == null or node == null:
		return 0.0
	return wall.height * node.scale.y


## Draws the wall in the selection colour ("" for none); kept across rebuilds.
func highlight_wall(wall_id: String) -> void:
	_set_wall_material(_highlighted, null)
	_highlighted = wall_id
	_set_wall_material(_highlighted, _highlight_material)


func highlighted_wall() -> String:
	return _highlighted


func _set_wall_material(wall_id: String, material: Material) -> void:
	if _walls == null or wall_id == "":
		return
	var body := _walls.get_node_or_null("%s/Body" % wall_id) as CSGPolygon3D
	if body != null:
		body.material_override = material


func _build(project: ProjectData) -> void:
	_project = project
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_floors = FloorBuilder.build(project)
	_walls = WallBuilder.build(project)
	add_child(_floors)
	add_child(_walls)
	_set_wall_material(_highlighted, _highlight_material)
	for tween in _tweens.values():
		tween.kill()
	_tweens.clear()
	_last_forward = Vector2.ZERO


func cycle_cutaway_mode() -> void:
	cutaway_mode = (cutaway_mode + 1) % Cutaway.Mode.size() as Cutaway.Mode
	_lowered.clear()
	_last_forward = Vector2.ZERO


## While suspended (plan view), every wall stands at full height and camera
## headings are ignored; resuming recomputes the cutaway on the next heading.
func set_cutaway_suspended(suspended: bool) -> void:
	_suspended = suspended
	_lowered.clear()
	_last_forward = Vector2.ZERO
	if suspended and _project != null:
		for wall in _project.walls:
			var node := _walls.get_node_or_null(NodePath(wall.id)) as Node3D
			if node != null:
				_tween_wall(wall.id, node, 1.0)


## Called every frame by the camera rig with its horizontal viewing direction.
func update_cutaway(camera_forward: Vector2) -> void:
	if _project == null or _suspended or camera_forward.is_equal_approx(_last_forward):
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
		_tween_wall(wall.id, node, Cutaway.target_scale(cutaway_mode, lowered, wall.height))


func _tween_wall(wall_id: String, node: Node3D, target_scale: float) -> void:
	var running: Tween = _tweens.get(wall_id)
	if running:
		running.kill()
	var tween := create_tween()
	tween.tween_property(node, "scale:y", target_scale, CUTAWAY_TWEEN_SECONDS)
	_tweens[wall_id] = tween
