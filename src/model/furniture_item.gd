class_name FurnitureItem
extends RefCounted
## A piece of furniture: a parametric block, or a GLB model scaled to `size`.

var id: String
## Catalogue preset id, or "" for a custom item.
var preset: String
## GLB path relative to the project file, or "" for a parametric block.
var glb: String
var name: String
## Bounding box in meters: x = width, y = height, z = depth.
var size: Vector3
var color: Color
## Center on the floor plane (x, world z).
var pos: Vector2
## Rotation around the vertical axis, in degrees.
var rotation_deg: float
