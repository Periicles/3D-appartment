class_name FloorBuilder
extends RefCounted
## Builds one flat floor mesh per room, tinted by floor kind.

## Below this area (m²) a polygon is treated as degenerate.
const MIN_AREA := 1e-6


static func build(project: ProjectData) -> Node3D:
	var root := Node3D.new()
	root.name = "Floors"
	for room in project.rooms:
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.name = room.id
		floor_mesh.mesh = flat_mesh(Geometry.room_polygon(project, room), 0.0)
		floor_mesh.material_override = Palette.material(Palette.floor_color(room.floor_kind))
		root.add_child(floor_mesh)
	return root


## Horizontal mesh of a simple polygon at `height`, facing up. Empty when the
## polygon cannot be triangulated (self-intersecting or degenerate).
static func flat_mesh(polygon: PackedVector2Array, height: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if polygon.size() < 3 or Geometry.polygon_area(polygon) < MIN_AREA:
		return mesh
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		return mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for p in polygon:
		vertices.append(Vector3(p.x, height, p.y))
		normals.append(Vector3.UP)
	# Godot treats clockwise triangles as front faces; seen from above that is a
	# negative y cross product.
	var faces := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		if (b - a).cross(c - a).y < 0.0:
			faces.append_array([indices[i], indices[i + 1], indices[i + 2]])
		else:
			faces.append_array([indices[i], indices[i + 2], indices[i + 1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = faces
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
