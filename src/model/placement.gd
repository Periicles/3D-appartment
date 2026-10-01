class_name Placement
extends RefCounted
## Pure placement maths for furniture on the floor plane (x, z), in metres.
## Rotation follows Godot's Y axis: rotation_deg = 0 means the item's front
## faces +z; its front direction is (sin θ, cos θ).

const GRID_STEP := 0.05
## A wall attracts an item whose back is closer than this to the wall face.
const WALL_SNAP_DISTANCE := 0.15


static func snap_to_grid(pos: Vector2, step: float = GRID_STEP) -> Vector2:
	return pos.snapped(Vector2(step, step))


## Unit vector the item's front faces on the floor plane.
static func front_direction(rotation_deg: float) -> Vector2:
	var theta := deg_to_rad(rotation_deg)
	return Vector2(sin(theta), cos(theta))


## Converts a point from the item's local frame (x = width axis, y = depth axis
## towards the front) to the floor plane.
static func to_world(item_pos: Vector2, rotation_deg: float, local: Vector2) -> Vector2:
	var theta := deg_to_rad(rotation_deg)
	var right := Vector2(cos(theta), -sin(theta))
	return item_pos + right * local.x + front_direction(rotation_deg) * local.y


## The item's rectangle on the floor, counter-clockwise.
static func footprint(pos: Vector2, size: Vector3, rotation_deg: float) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hd := size.z / 2.0
	var corners := PackedVector2Array()
	for local in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
		corners.append(to_world(pos, rotation_deg, local))
	if Geometry2D.is_polygon_clockwise(corners):
		corners.reverse()
	return corners


## If the item's back is within WALL_SNAP_DISTANCE of a wall face, returns
## {"pos": Vector2, "rotation_deg": float} placing it flush against that face,
## facing away from the wall. Otherwise returns an empty dictionary.
## Only faces the item's centre stands in front of (within the wall's length)
## are considered; the closest one wins.
static func snap_to_wall(project: ProjectData, pos: Vector2, size: Vector3) -> Dictionary:
	var best := {}
	var best_gap := INF
	var half_depth := size.z / 2.0
	for wall in project.walls:
		var a := project.get_plan_node(wall.a)
		var b := project.get_plan_node(wall.b)
		if a == null or b == null or a.pos.is_equal_approx(b.pos):
			continue
		var along := (b.pos - a.pos).normalized()
		var length := a.pos.distance_to(b.pos)
		var t := (pos - a.pos).dot(along)
		if t < 0.0 or t > length:
			continue
		var on_wall := a.pos + along * t
		var offset := pos - on_wall
		if offset.length() < 1e-6:
			continue
		var outward := Vector2(-along.y, along.x)
		if offset.dot(outward) < 0.0:
			outward = -outward
		var face_distance := offset.dot(outward) - wall.thickness / 2.0
		var gap := absf(face_distance - half_depth)
		if gap <= WALL_SNAP_DISTANCE and gap < best_gap:
			best_gap = gap
			best = {
				"pos": on_wall + outward * (wall.thickness / 2.0 + half_depth),
				"rotation_deg": rad_to_deg(atan2(outward.x, outward.y)),
			}
	return best


## Distance along the ray to the item's box, or -1.0 if the ray misses it.
static func ray_distance_to_item(ray_origin: Vector3, ray_dir: Vector3, item: FurnitureItem) -> float:
	var to_local := Transform3D(Basis(Vector3.UP, deg_to_rad(item.rotation_deg)),
		Vector3(item.pos.x, 0, item.pos.y)).affine_inverse()
	var local_origin := to_local * ray_origin
	var local_dir := to_local.basis * ray_dir
	var box := AABB(Vector3(-item.size.x / 2.0, 0, -item.size.z / 2.0), item.size)
	var hit = box.intersects_ray(local_origin, local_dir)
	if hit == null:
		return -1.0
	return local_origin.distance_to(hit)


## The id of the closest item hit by the ray, or "" if none.
static func pick_item(ray_origin: Vector3, ray_dir: Vector3, items: Array[FurnitureItem]) -> String:
	var best_id := ""
	var best_distance := INF
	for item in items:
		var distance := ray_distance_to_item(ray_origin, ray_dir, item)
		if distance >= 0.0 and distance < best_distance:
			best_distance = distance
			best_id = item.id
	return best_id
