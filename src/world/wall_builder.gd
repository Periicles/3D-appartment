class_name WallBuilder
extends RefCounted
## Builds one Node3D per wall: the mitred footprint extruded with CSG, openings
## subtracted, a darker cap on top and glass in the windows.

## Extra depth so opening cutters fully cross mitred wall ends.
const CUTTER_MARGIN := 0.05
const GLASS_THICKNESS := 0.02
const CAP_OFFSET := 0.002


static func build(project: ProjectData) -> Node3D:
	var root := Node3D.new()
	root.name = "Walls"
	var footprints := Geometry.wall_footprints(project)
	var wall_material := Palette.material(Palette.WALL)
	var cap_material := Palette.material(Palette.WALL_TOP)
	var glass_material := Palette.material(Palette.GLASS)
	for wall in project.walls:
		if not footprints.has(wall.id):
			continue
		var openings := project.openings.filter(func(o: Opening) -> bool: return o.wall_id == wall.id)
		root.add_child(_build_wall(project, wall, footprints[wall.id], openings,
			wall_material, cap_material, glass_material))
	return root


static func _build_wall(project: ProjectData, wall: Wall, footprint: PackedVector2Array, openings: Array,
		wall_material: Material, cap_material: Material, glass_material: Material) -> Node3D:
	var node := Node3D.new()
	node.name = wall.id
	var body := CSGPolygon3D.new()
	body.name = "Body"
	body.polygon = footprint
	body.depth = wall.height
	body.material = wall_material
	# CSGPolygon3D extrudes its XY polygon along -Z; this turns (x, y) into the
	# floor plane (x, z) and the extrusion upwards.
	body.rotation_degrees = Vector3(90, 0, 0)
	node.add_child(body)

	var start := project.get_plan_node(wall.a).pos
	var dir := (project.get_plan_node(wall.b).pos - start).normalized()
	var yaw := -dir.angle()
	for opening: Opening in openings:
		var center := start + dir * opening.offset
		var cutter := CSGBox3D.new()
		cutter.name = "Cut_%s" % opening.id
		cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
		cutter.size = Vector3(opening.width, opening.height, wall.thickness + CUTTER_MARGIN * 2.0)
		# The body is rotated, so place the cutter in world space through its transform.
		var world := Transform3D(Basis(Vector3.UP, yaw), Vector3(center.x, opening.sill + opening.height / 2.0, center.y))
		cutter.transform = body.transform.affine_inverse() * world
		body.add_child(cutter)
		if opening.kind == "window":
			node.add_child(_glass(opening, wall, world, glass_material))

	node.add_child(_cap(footprint, wall.height + CAP_OFFSET, cap_material))
	return node


static func _glass(opening: Opening, wall: Wall, world: Transform3D, glass_material: Material) -> MeshInstance3D:
	var glass := MeshInstance3D.new()
	glass.name = "Glass_%s" % opening.id
	var box := BoxMesh.new()
	box.size = Vector3(opening.width, opening.height, GLASS_THICKNESS)
	glass.mesh = box
	glass.material_override = glass_material
	glass.transform = world
	return glass


static func _cap(footprint: PackedVector2Array, height: float, cap_material: Material) -> MeshInstance3D:
	var cap := MeshInstance3D.new()
	cap.name = "Cap"
	cap.mesh = FloorBuilder.flat_mesh(footprint, height)
	cap.material_override = cap_material
	return cap
