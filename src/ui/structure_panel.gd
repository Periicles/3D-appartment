class_name StructurePanel
extends PanelContainer
## Right-hand panel of the Structure mode: position of the selected corner, or
## length, thickness and height of the selected wall. Every committed field is
## one store edit; a refused value springs back. Hidden when nothing is selected.

const PANEL_WIDTH := 260.0
const CM_PER_M := 100.0
const POSITION_LIMIT_M := 100.0
const MIN_LENGTH_CM := 5.0
const MAX_LENGTH_CM := 5000.0
const MIN_THICKNESS_CM := 2.0
const MAX_THICKNESS_CM := 100.0
const MIN_HEIGHT_CM := 10.0
const MAX_HEIGHT_CM := 500.0

var store: Node
var _kind: StringName = &""
var _id := ""
var _filling := false
var _title: Label
var _node_fields: VBoxContainer
var _wall_fields: VBoxContainer
var _x: SpinBox
var _z: SpinBox
var _length: SpinBox
var _thickness: SpinBox
var _height: SpinBox


func _init() -> void:
	name = "StructurePanel"
	custom_minimum_size.x = PANEL_WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", Palette.panel_style())
	var form := VBoxContainer.new()
	add_child(form)
	_title = Label.new()
	form.add_child(_title)
	_node_fields = VBoxContainer.new()
	form.add_child(_node_fields)
	_x = _spin(_node_fields, "X", "Position X (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
	_z = _spin(_node_fields, "Z", "Position Z (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
	_wall_fields = VBoxContainer.new()
	form.add_child(_wall_fields)
	_length = _spin(_wall_fields, "Length", "Longueur (cm)", MIN_LENGTH_CM, MAX_LENGTH_CM, 1.0)
	_thickness = _spin(_wall_fields, "Thickness", "Épaisseur (cm)", MIN_THICKNESS_CM, MAX_THICKNESS_CM, 1.0)
	_height = _spin(_wall_fields, "Height", "Hauteur (cm)", MIN_HEIGHT_CM, MAX_HEIGHT_CM, 1.0)
	var delete := Button.new()
	delete.name = "DeleteWall"
	delete.text = "Supprimer le mur"
	delete.focus_mode = Control.FOCUS_NONE
	delete.pressed.connect(_delete_wall)
	_wall_fields.add_child(delete)
	var hint := Label.new()
	hint.text = Shortcuts.structure_hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	form.add_child(hint)
	_x.value_changed.connect(_commit_node.bind(Vector2.AXIS_X))
	_z.value_changed.connect(_commit_node.bind(Vector2.AXIS_Y))
	_length.value_changed.connect(_commit_wall.bind("length", _length))
	_thickness.value_changed.connect(_commit_wall.bind("thickness", _thickness))
	_height.value_changed.connect(_commit_wall.bind("height", _height))
	visible = false


## Bound methods (not lambdas) so the connection dies with the panel.
func bind_store(p_store: Node) -> void:
	store = p_store
	store.structure_changed.connect(_refill)


## Shows the corner or wall with this id; hides the panel for &"" or an unknown id.
func show_selection(kind: StringName, id: String) -> void:
	_kind = kind
	_id = id
	_refill()


func _refill() -> void:
	var node: PlanNode = store.project.get_plan_node(_id) if _kind == &"node" else null
	var wall: Wall = store.project.get_wall(_id) if _kind == &"wall" else null
	visible = node != null or wall != null
	_node_fields.visible = node != null
	_wall_fields.visible = wall != null
	_filling = true
	if node != null:
		_title.text = "Coin"
		_x.value = node.pos.x
		_z.value = node.pos.y
	elif wall != null:
		_title.text = "Mur"
		_length.value = store.project.wall_length(wall) * CM_PER_M
		_thickness.value = wall.thickness * CM_PER_M
		_height.value = wall.height * CM_PER_M
	_filling = false


## Changes one coordinate; the other keeps its exact value instead of the
## SpinBox-rounded one.
func _commit_node(value: float, axis: Vector2.Axis) -> void:
	if _filling or _kind != &"node":
		return
	var pos: Vector2 = store.project.get_plan_node(_id).pos
	pos[axis] = value
	if not store.move_node(_id, pos):
		_refill()


func _commit_wall(_value: float, field: String, spin: SpinBox) -> void:
	if _filling or _kind != &"wall":
		return
	if not store.update_wall(_id, {field: spin.value / CM_PER_M}):
		_refill()


func _delete_wall() -> void:
	if _kind == &"wall":
		store.remove_wall(_id)


static func _spin(form: VBoxContainer, node_name: String, label_text: String, min_value: float,
		max_value: float, step: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	form.add_child(label)
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	form.add_child(spin)
	return spin
