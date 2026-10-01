class_name Geometry
extends RefCounted
## Pure 2D geometry on the floor plane (x, z), in meters.

## Beyond this multiple of the wall thickness a miter turns into a square cut,
## so acute corners do not grow long spikes.
const MITER_LIMIT := 2.0
const _PARALLEL_EPSILON := 1e-6


## Mitred footprint of every wall, keyed by wall id. Each footprint is a
## counter-clockwise quad: start-left, end-left, end-right, start-right.
static func wall_footprints(project: ProjectData) -> Dictionary:
	var corners := {}  # "<wall_id>:<node_id>" -> [left, right] relative to the wall's direction away from that node
	for node in project.nodes:
		_solve_node(project, node, corners)
	var footprints := {}
	for wall in project.walls:
		var at_a: Array = corners.get("%s:%s" % [wall.id, wall.a], [])
		var at_b: Array = corners.get("%s:%s" % [wall.id, wall.b], [])
		if at_a.is_empty() or at_b.is_empty():
			continue
		# Seen from b, "left" is the right-hand side of a->b.
		var quad := PackedVector2Array([at_a[0], at_b[1], at_b[0], at_a[1]])
		if Geometry2D.is_polygon_clockwise(quad):
			quad.reverse()
		footprints[wall.id] = quad
	return footprints


static func polygon_area(points: PackedVector2Array) -> float:
	var twice := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		twice += p.x * q.y - q.x * p.y
	return absf(twice) / 2.0


static func polygon_centroid(points: PackedVector2Array) -> Vector2:
	var twice_area := 0.0
	var sum := Vector2.ZERO
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var cross := p.x * q.y - q.x * p.y
		twice_area += cross
		sum += (p + q) * cross
	if absf(twice_area) < _PARALLEL_EPSILON:
		return points[0] if not points.is_empty() else Vector2.ZERO
	return sum / (3.0 * twice_area)


## The room's floor polygon, through the centres of its nodes.
static func room_polygon(project: ProjectData, room: Room) -> PackedVector2Array:
	var points := PackedVector2Array()
	for node_id in room.node_ids:
		points.append(project.get_plan_node(node_id).pos)
	return points


## Floor area inside the walls: the centre-line polygon minus the half thickness
## of every wall running along one of its edges. Corner overlaps are ignored
## (a few cm² per corner).
static func room_net_area(project: ProjectData, room: Room) -> float:
	var area := polygon_area(room_polygon(project, room))
	var count := room.node_ids.size()
	for i in count:
		var a := room.node_ids[i]
		var b := room.node_ids[(i + 1) % count]
		var wall := project.find_wall_between(a, b)
		if wall != null:
			area -= project.wall_length(wall) * wall.thickness / 2.0
	return area


static func _solve_node(project: ProjectData, node: PlanNode, corners: Dictionary) -> void:
	var ends := []  # {wall, dir, half}
	for wall in project.walls:
		if wall.a != node.id and wall.b != node.id:
			continue
		var other := project.get_plan_node(wall.b if wall.a == node.id else wall.a)
		if other == null or other.pos.is_equal_approx(node.pos):
			continue
		ends.append({"wall": wall, "dir": (other.pos - node.pos).normalized(), "half": wall.thickness / 2.0})
	ends.sort_custom(func(e1, e2): return e1.dir.angle() < e2.dir.angle())
	var count := ends.size()
	var lefts := []
	var rights := []
	for e in ends:
		lefts.append(node.pos + _left_normal(e.dir) * e.half)
		rights.append(node.pos - _left_normal(e.dir) * e.half)
	if count > 1:
		var through := _through_flags(ends)
		for i in count:
			var j := (i + 1) % count
			var e_i: Dictionary = ends[i]
			var e_j: Dictionary = ends[j]
			var hit = Geometry2D.line_intersects_line(
				node.pos + _left_normal(e_i.dir) * e_i.half, e_i.dir,
				node.pos - _left_normal(e_j.dir) * e_j.half, e_j.dir)
			if hit == null:
				continue  # Collinear neighbours keep their square ends.
			var limit := MITER_LIMIT * 2.0 * maxf(e_i.half, e_j.half)
			if node.pos.distance_to(hit) > limit:
				continue
			if not through[i]:
				lefts[i] = hit
			if not through[j]:
				rights[j] = hit
	for i in count:
		corners["%s:%s" % [ends[i].wall.id, node.id]] = [lefts[i], rights[i]]


## An end is "through" when another end at the node points the opposite way: that
## wall runs straight past the junction and must keep square ends, so branches
## stop on its face instead of slanting it.
static func _through_flags(ends: Array) -> Array[bool]:
	var flags: Array[bool] = []
	for e in ends:
		var is_through := false
		for other in ends:
			if e.dir.dot(other.dir) < -1.0 + _PARALLEL_EPSILON:
				is_through = true
		flags.append(is_through)
	return flags


## Perpendicular rotated towards increasing angle (counter-clockwise in x/z maths).
static func _left_normal(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)
