class_name MeasureSnap
extends RefCounted
## Magnetism for the free measuring tool: corners first (wall nodes, wall
## footprint corners, furniture corners), then edges (wall faces, furniture
## sides), otherwise the point itself.

const RADIUS := 0.15


static func snap(point: Vector2, project: ProjectData, radius: float = RADIUS) -> Vector2:
	var polygons: Array[PackedVector2Array] = []
	for footprint in Geometry.wall_footprints(project).values():
		polygons.append(footprint)
	for item in project.furniture:
		polygons.append(Placement.footprint(item.pos, item.size, item.rotation_deg))
	var corners := PackedVector2Array()
	for node in project.nodes:
		corners.append(node.pos)
	for polygon in polygons:
		corners.append_array(polygon)
	var best := point
	var best_distance := radius
	for corner in corners:
		var distance := point.distance_to(corner)
		if distance <= best_distance:
			best_distance = distance
			best = corner
	if best != point:
		return best
	best_distance = radius
	for polygon in polygons:
		for i in polygon.size():
			var on_edge := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
			var distance := point.distance_to(on_edge)
			if distance <= best_distance:
				best_distance = distance
				best = on_edge
	return best
