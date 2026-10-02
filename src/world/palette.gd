class_name Palette
extends RefCounted
## The fixed v1 colour palette (no material system before v2).

const WALL := Color("#f2ede4")
const WALL_TOP := Color("#8f8478")
const GLASS := Color(0.75, 0.88, 0.95, 0.35)
const SELECTION := Color("#ffd27a")
const GHOST_ALPHA := 0.5
const PANEL_BACKGROUND := Color(0.16, 0.15, 0.15, 0.92)
const PANEL_PADDING := 10.0
const PANEL_RADIUS := 6
## How far the selection outline grows around the item, in metres.
const OUTLINE_WIDTH := 0.03
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


## Unshaded shell drawn behind a mesh's back faces, slightly inflated, so the
## mesh appears outlined.
static func outline_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SELECTION
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = OUTLINE_WIDTH
	return mat


## Toggle button that shows clearly when it is on (the mode switch).
static func apply_toggle_style(button: Button) -> void:
	# Same margins as the theme's button, so the text keeps its room when on.
	var on := button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	on.bg_color = SELECTION
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, on)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, PANEL_BACKGROUND)


## Background shared by the interface panels: dark, slightly transparent, padded.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND
	style.set_content_margin_all(PANEL_PADDING)
	style.set_corner_radius_all(PANEL_RADIUS)
	return style
