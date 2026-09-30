class_name Underlay
extends RefCounted
## Plan image laid on the floor in plan view, used to check the modelled walls.

## Image path relative to the project file.
var image: String
var meters_per_px: float
## Position of the image's top-left corner on the floor plane, in meters.
var offset: Vector2
