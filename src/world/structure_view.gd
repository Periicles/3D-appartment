class_name StructureView
extends Node3D
## Structure mode overlay: a handle on every corner, the selection highlighted,
## and the length of the walls being edited. Drawn above the walls (no depth
## test) so corners hidden behind a wall can still be grabbed. Never edits data.

const HANDLE_RADIUS := 0.1
const HANDLE_HEIGHT := 0.01
const LIFT := 0.02
const HANDLE_COLOR := Color("#3d6fb6")
const WALL_HIGHLIGHT_ALPHA := 0.55

var _handle_material := _overlay_material(HANDLE_COLOR)
var _selected_material := _overlay_material(Palette.SELECTION)
var _wall_material := _overlay_material(Color(Palette.SELECTION, WALL_HIGHLIGHT_ALPHA))


func _init() -> void:
	name = "Structure"


## Redraws the overlay for `project`. `kind` is &"node", &"wall" or &"" (no
## selection): a selected corner shows the length of its walls, a selected wall
## is highlighted with its length.
func show_structure(project: ProjectData, kind: StringName, id: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for node in project.nodes:
		var selected := kind == &"node" and node.id == id
		add_child(_handle(node, _selected_material if selected else _handle_material))
	var measured: Array[Wall] = []
	if kind == &"node":
		measured = project.walls_at(id)
	elif kind == &"wall" and project.get_wall(id) != null:
		measured = [project.get_wall(id)]
		add_child(_wall_highlight(project, project.get_wall(id)))
	for wall in measured:
		var line := DimensionLine.new()
		line.name = "Length_%s" % wall.id
		add_child(line)
		line.set_points(project.get_plan_node(wall.a).pos, project.get_plan_node(wall.b).pos)


func handle(node_id: String) -> MeshInstance3D:
	return get_node_or_null("Handle_%s" % node_id) as MeshInstance3D


func is_handle_selected(node_id: String) -> bool:
	var found := handle(node_id)
	return found != null and found.material_override == _selected_material


func _handle(node: PlanNode, material: Material) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = "Handle_%s" % node.id
	var mesh := CylinderMesh.new()
	mesh.top_radius = HANDLE_RADIUS
	mesh.bottom_radius = HANDLE_RADIUS
	mesh.height = HANDLE_HEIGHT
	disc.mesh = mesh
	disc.material_override = material
	disc.position = Vector3(node.pos.x, LIFT, node.pos.y)
	return disc


func _wall_highlight(project: ProjectData, wall: Wall) -> MeshInstance3D:
	var a := project.get_plan_node(wall.a).pos
	var b := project.get_plan_node(wall.b).pos
	var bar := MeshInstance3D.new()
	bar.name = "Highlight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(a.distance_to(b), HANDLE_HEIGHT, wall.thickness)
	bar.mesh = mesh
	bar.material_override = _wall_material
	var mid := (a + b) / 2.0
	bar.transform = Transform3D(Basis(Vector3.UP, -(b - a).angle()), Vector3(mid.x, LIFT, mid.y))
	return bar


static func _overlay_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	mat.render_priority = 1
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
