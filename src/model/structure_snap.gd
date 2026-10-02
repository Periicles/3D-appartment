class_name StructureSnap
extends RefCounted
## Magnetism for a dragged corner: its walls lock to 0/45/90° against the
## walls at their other end, else the corner snaps to the grid. Along a guide
## the length is snapped to the grid too, so walls keep round lengths.

const GRID := 0.05
const ANGLE_STEP_DEG := 45.0
## A guide line attracts the corner within this distance, in metres.
const GUIDE_DISTANCE := 0.1
## Guides crossing at a shallower angle are not combined (the crossing point
## would run far from the mouse).
const MIN_CROSSING_DEG := 10.0
## The crossing of two guides is used only this close to the mouse, in metres;
## farther, the nearest guide alone wins.
const MAX_CROSSING_SHIFT := 0.2


## Where the corner `node_id` lands when dragged to `raw`. With `free_move`
## (Alt held) the position is kept as is.
static func snap_node(project: ProjectData, node_id: String, raw: Vector2, free_move: bool) -> Vector2:
	if free_move:
		return raw
	var near: Array[Array] = []  # [distance, guide]
	for guide in guides(project, node_id):
		var distance := _distance_to_line(raw, guide)
		if distance <= GUIDE_DISTANCE:
			near.append([distance, guide])
	if near.is_empty():
		return raw.snapped(Vector2(GRID, GRID))
	near.sort_custom(func(x, y): return x[0] < y[0])
	var best: Dictionary = near[0][1]
	for entry in near.slice(1):
		var other: Dictionary = entry[1]
		if other.origin.is_equal_approx(best.origin):
			continue  # Two angles at the same neighbour only cross at the neighbour.
		if absf(best.dir.cross(other.dir)) < sin(deg_to_rad(MIN_CROSSING_DEG)):
			continue
		var crossing = Geometry2D.line_intersects_line(best.origin, best.dir, other.origin, other.dir)
		if crossing != null and crossing.distance_to(raw) <= MAX_CROSSING_SHIFT:
			return crossing
	return _snap_along_line(raw, best)


## Lines the corner may lock onto: through each neighbouring corner, at every
## multiple of ANGLE_STEP_DEG from the neighbour's other walls (or from the
## axes when the neighbour has no other wall). Each is {origin, dir}.
static func guides(project: ProjectData, node_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for wall in project.walls_at(node_id):
		var neighbour_id := wall.b if wall.a == node_id else wall.a
		var neighbour := project.get_plan_node(neighbour_id)
		if neighbour == null:
			continue
		var references: Array[float] = []
		for other in project.walls_at(neighbour_id):
			var far_id := other.b if other.a == neighbour_id else other.a
			var far := project.get_plan_node(far_id)
			if other == wall or far_id == node_id or far == null or far.pos.is_equal_approx(neighbour.pos):
				continue
			references.append((far.pos - neighbour.pos).angle())
		if references.is_empty():
			references.append(0.0)
		for reference in references:
			for step in int(180.0 / ANGLE_STEP_DEG):
				var angle := reference + deg_to_rad(step * ANGLE_STEP_DEG)
				found.append({"origin": neighbour.pos, "dir": Vector2.from_angle(angle)})
	return found


static func _distance_to_line(point: Vector2, guide: Dictionary) -> float:
	return absf(guide.dir.cross(point - guide.origin))


static func _snap_along_line(point: Vector2, guide: Dictionary) -> Vector2:
	return guide.origin + guide.dir * snappedf(guide.dir.dot(point - guide.origin), GRID)
