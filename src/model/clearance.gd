class_name Clearance
extends RefCounted
## Free space around a furniture footprint: for each of its four sides, the
## distance to the first wall or other piece of furniture, found by casting 2D
## rays from the side outwards.

const SIDES: PackedStringArray = ["front", "back", "left", "right"]
## Rays further than this report nothing (open space).
const MAX_RANGE := 10.0
## Rays start this far inside the side's ends, so touching neighbours at a
## corner do not count as zero clearance.
const CORNER_INSET := 0.02
## Rays along a side are at most this far apart, so a narrow neighbour cannot
## slip between two of them.
const RAY_SPACING := 0.2
## Per side, in the item's local frame (x = width axis, y = towards the front):
## [outward normal, direction along the side].
const _SIDE_FRAMES := {
	"front": [Vector2(0, 1), Vector2(1, 0)],
	"back": [Vector2(0, -1), Vector2(1, 0)],
	"left": [Vector2(-1, 0), Vector2(0, 1)],
	"right": [Vector2(1, 0), Vector2(0, 1)],
}


## Returns {side: {"distance": float, "from": Vector2, "to": Vector2}} for each
## side that meets something within MAX_RANGE. `obstacles` are footprints
## (walls and other furniture) as PackedVector2Array polygons.
static func free_distances(pos: Vector2, size: Vector3, rotation_deg: float,
		obstacles: Array[PackedVector2Array]) -> Dictionary:
	var result := {}
	var hw := size.x / 2.0
	var hd := size.z / 2.0
	for side in SIDES:
		var normal_local: Vector2 = _SIDE_FRAMES[side][0]
		var along_local: Vector2 = _SIDE_FRAMES[side][1]
		var across_x := absf(normal_local.x) > 0.0
		var half_length := hd if across_x else hw
		var offset := hw if across_x else hd
		var outward := Placement.to_world(Vector2.ZERO, rotation_deg, normal_local)
		var best := {}
		var inset := maxf(half_length - CORNER_INSET, 0.0)
		for t in _ray_offsets(inset):
			var origin := Placement.to_world(pos, rotation_deg, normal_local * offset + along_local * t)
			var hit := _cast(origin, outward, obstacles)
			if hit.is_empty():
				continue
			if best.is_empty() or hit.distance < best.distance:
				best = hit
		if not best.is_empty():
			result[side] = best
	return result


## Evenly spaced positions along a side, from -inset to +inset.
static func _ray_offsets(inset: float) -> PackedFloat32Array:
	if inset <= 0.0:
		return PackedFloat32Array([0.0])
	var count := ceili(2.0 * inset / RAY_SPACING) + 1
	var offsets := PackedFloat32Array()
	for i in count:
		offsets.append(lerpf(-inset, inset, float(i) / (count - 1)))
	return offsets


## The obstacles around an item: every wall footprint and every other item's footprint.
static func obstacles_for(project: ProjectData, ignore_id: String) -> Array[PackedVector2Array]:
	var obstacles: Array[PackedVector2Array] = []
	for footprint in Geometry.wall_footprints(project).values():
		obstacles.append(footprint)
	for item in project.furniture:
		if item.id != ignore_id:
			obstacles.append(Placement.footprint(item.pos, item.size, item.rotation_deg))
	return obstacles


static func _cast(origin: Vector2, direction: Vector2, obstacles: Array[PackedVector2Array]) -> Dictionary:
	var far := origin + direction * MAX_RANGE
	var best_distance := INF
	var best_point := Vector2.ZERO
	for polygon in obstacles:
		if Geometry2D.is_point_in_polygon(origin, polygon):
			return {"distance": 0.0, "from": origin, "to": origin}
		for i in polygon.size():
			var hit = Geometry2D.segment_intersects_segment(origin, far, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null and origin.distance_to(hit) < best_distance:
				best_distance = origin.distance_to(hit)
				best_point = hit
	if best_distance == INF:
		return {}
	return {"distance": best_distance, "from": origin, "to": best_point}
