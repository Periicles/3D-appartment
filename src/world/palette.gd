class_name Palette
extends RefCounted
## The fixed v1 colour palette (no material system before v2).

const WALL := Color("#f2ede4")
const WALL_TOP := Color("#8f8478")
const GLASS := Color(0.75, 0.88, 0.95, 0.35)
const FLOORS := {
	"wood": Color("#c99a6b"),
	"tile": Color("#c9ccd0"),
	"outdoor": Color("#a9a39a"),
}
const FLOOR_FALLBACK := Color("#cccccc")


static func floor_color(kind: String) -> Color:
	return FLOORS.get(kind, FLOOR_FALLBACK)


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
