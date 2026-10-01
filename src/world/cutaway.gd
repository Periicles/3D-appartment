class_name Cutaway
extends RefCounted
## Decides which walls drop to a low height so the orbit camera sees inside.

enum Mode { AUTO, FULL, ALL_LOWERED }

const LOWERED_HEIGHT := 0.20
## A wall facing the camera within this angle is lowered.
const MAX_FACING_ANGLE_DEG := 60.0


## `camera_forward` is the camera's horizontal viewing direction on the floor plane.
static func is_lowered(wall_start: Vector2, wall_end: Vector2, apartment_center: Vector2,
		camera_forward: Vector2) -> bool:
	var towards_camera := -camera_forward.normalized()
	var middle := (wall_start + wall_end) / 2.0
	if (middle - apartment_center).dot(towards_camera) <= 0.0:
		return false
	var along := (wall_end - wall_start).normalized()
	var normal := Vector2(-along.y, along.x)
	return absf(normal.dot(towards_camera)) >= cos(deg_to_rad(MAX_FACING_ANGLE_DEG))


## Vertical scale for a wall of `wall_height` in the given mode.
static func target_scale(mode: Mode, lowered: bool, wall_height: float) -> float:
	if mode == Mode.FULL or wall_height <= 0.0:
		return 1.0
	if mode == Mode.ALL_LOWERED or lowered:
		return minf(1.0, LOWERED_HEIGHT / wall_height)
	return 1.0


static func apartment_center(project: ProjectData) -> Vector2:
	if project.nodes.is_empty():
		return Vector2.ZERO
	var bounds := Rect2(project.nodes[0].pos, Vector2.ZERO)
	for node in project.nodes:
		bounds = bounds.expand(node.pos)
	return bounds.get_center()
