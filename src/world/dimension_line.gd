class_name DimensionLine
extends Node3D
## A measurement drawn just above the floor: a thin bar between two points,
## end ticks, and its length in centimetres, always readable on screen.

const HEIGHT := 0.03
const THICKNESS := 0.012
const TICK_LENGTH := 0.12
const LABEL_PIXEL_SIZE := 0.0012
const LABEL_FONT_SIZE := 32
const LABEL_LIFT := 0.05
const COLOR := Color("#2b2b2b")
const LABEL_OUTLINE := Color("#fff8ec")

var _bar: MeshInstance3D
var _ticks: Array[MeshInstance3D] = []
var _label: Label3D
var _material := StandardMaterial3D.new()


func _init() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOR
	_material.no_depth_test = true
	_material.render_priority = 1
	_bar = _box_instance("Bar")
	for i in 2:
		_ticks.append(_box_instance("Tick%d" % i))
	_label = Label3D.new()
	_label.name = "Label"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.font_size = LABEL_FONT_SIZE
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.modulate = COLOR
	_label.outline_modulate = LABEL_OUTLINE
	_label.outline_size = 12
	add_child(_label)


## Draws from `a` to `b` on the floor plane (x, z).
func set_points(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	visible = length > 0.0
	if not visible:
		return
	var mid := (a + b) / 2.0
	var dir := (b - a) / length
	var yaw := -dir.angle()
	_place(_bar, mid, yaw, Vector3(length, THICKNESS, THICKNESS))
	var across := Vector2(-dir.y, dir.x)
	for i in 2:
		var end := a if i == 0 else b
		_place(_ticks[i], end, -across.angle(), Vector3(TICK_LENGTH, THICKNESS, THICKNESS))
	_label.text = text_for(length)
	_label.position = Vector3(mid.x, HEIGHT + LABEL_LIFT, mid.y)


func label_text() -> String:
	return _label.text


## "123 cm", rounded to the centimetre.
static func text_for(length_m: float) -> String:
	return "%d cm" % roundi(length_m * 100.0)


func _box_instance(node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = BoxMesh.new()
	instance.material_override = _material
	add_child(instance)
	return instance


static func _place(instance: MeshInstance3D, center: Vector2, yaw: float, size: Vector3) -> void:
	(instance.mesh as BoxMesh).size = size
	instance.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(center.x, HEIGHT, center.y))
