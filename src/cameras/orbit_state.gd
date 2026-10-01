class_name OrbitState
extends RefCounted
## Orbit camera parameters and their limits, independent of input and nodes.

const MIN_PITCH_DEG := 15.0
const MAX_PITCH_DEG := 85.0
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 40.0
const ZOOM_FACTOR := 1.1

var target := Vector3.ZERO
var yaw_deg := 30.0
var pitch_deg := 50.0
var distance := 11.0


func rotate(delta_yaw_deg: float, delta_pitch_deg: float) -> void:
	yaw_deg = fposmod(yaw_deg + delta_yaw_deg, 360.0)
	pitch_deg = clampf(pitch_deg + delta_pitch_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)


## Positive steps zoom in.
func zoom(steps: float) -> void:
	distance = clampf(distance / pow(ZOOM_FACTOR, steps), MIN_DISTANCE, MAX_DISTANCE)


## Moves the target in the camera's horizontal frame: x to the right, y forward.
func pan(offset: Vector2) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	target += right * offset.x + forward * offset.y


## Horizontal viewing direction on the floor plane (x, z).
func forward_2d() -> Vector2:
	var yaw := deg_to_rad(yaw_deg)
	return Vector2(-sin(yaw), -cos(yaw))


func camera_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0))
	var origin := target + basis.z * distance
	return Transform3D(basis, origin)
