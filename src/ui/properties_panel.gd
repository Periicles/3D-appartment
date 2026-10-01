class_name PropertiesPanel
extends PanelContainer
## Right-hand panel editing the selected item. Every committed field becomes
## one store edit (and one undo step). Hidden when nothing is selected.

const PANEL_WIDTH := 260.0
const CM_PER_M := 100.0
const MIN_SIZE_CM := 1.0
const MAX_SIZE_CM := 1000.0
const POSITION_LIMIT_M := 100.0
const HINT := "R : pivoter · Maj + molette : ±15°\nSuppr : supprimer · Ctrl/Cmd + D : dupliquer\nCtrl/Cmd + Z : annuler"

var store: Node
var _item_id := ""
var _filling := false
var _name: LineEdit
var _width: SpinBox
var _depth: SpinBox
var _height: SpinBox
var _color: ColorPickerButton
var _x: SpinBox
var _z: SpinBox
var _rotation: SpinBox


func _init() -> void:
	name = "Properties"
	custom_minimum_size.x = PANEL_WIDTH
	var form := VBoxContainer.new()
	add_child(form)
	var title := Label.new()
	title.text = "Propriétés"
	form.add_child(title)
	_name = LineEdit.new()
	_name.name = "Name"
	_name.text_submitted.connect(func(_text: String) -> void: _commit_name())
	_name.focus_exited.connect(_commit_name)
	_row(form, "Nom", _name)
	_width = _spin(form, "Width", "Largeur (cm)", MIN_SIZE_CM, MAX_SIZE_CM, 1.0)
	_depth = _spin(form, "Depth", "Profondeur (cm)", MIN_SIZE_CM, MAX_SIZE_CM, 1.0)
	_height = _spin(form, "Height", "Hauteur (cm)", MIN_SIZE_CM, MAX_SIZE_CM, 1.0)
	_color = ColorPickerButton.new()
	_color.name = "Color"
	_color.edit_alpha = false
	_color.custom_minimum_size.y = 28
	_color.popup_closed.connect(func() -> void: _commit({"color": _color.color}))
	_row(form, "Couleur", _color)
	_x = _spin(form, "X", "Position X (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
	_z = _spin(form, "Z", "Position Z (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
	_rotation = _spin(form, "Rotation", "Rotation (°)", 0.0, 360.0, 1.0)
	var hint := Label.new()
	hint.text = HINT
	hint.add_theme_font_size_override("font_size", 11)
	form.add_child(hint)
	for spin in [_width, _depth, _height]:
		spin.value_changed.connect(func(_v: float) -> void: _commit_size())
	_x.value_changed.connect(func(_v: float) -> void: _commit({"pos": Vector2(_x.value, _z.value)}))
	_z.value_changed.connect(func(_v: float) -> void: _commit({"pos": Vector2(_x.value, _z.value)}))
	_rotation.value_changed.connect(func(v: float) -> void: _commit({"rotation_deg": fposmod(v, 360.0)}))
	visible = false


func bind_store(p_store: Node) -> void:
	store = p_store
	store.furniture_changed.connect(_on_furniture_changed)


## Shows the item with this id, or hides the panel for "" / an unknown id.
func show_item(id: String) -> void:
	var item: FurnitureItem = store.get_furniture(id) if id != "" else null
	_item_id = item.id if item != null else ""
	visible = item != null
	if item == null:
		return
	_filling = true
	_name.text = item.name
	_width.value = item.size.x * CM_PER_M
	_depth.value = item.size.z * CM_PER_M
	_height.value = item.size.y * CM_PER_M
	_color.color = item.color
	_x.value = item.pos.x
	_z.value = item.pos.y
	_rotation.value = item.rotation_deg
	_filling = false


func shown_id() -> String:
	return _item_id


func _on_furniture_changed(id: String) -> void:
	if id == _item_id:
		show_item(id)


func _commit_name() -> void:
	if _name.text.strip_edges() != "":
		_commit({"name": _name.text.strip_edges()})


func _commit_size() -> void:
	_commit({"size": Vector3(_width.value, _height.value, _depth.value) / CM_PER_M})


## Sends the change unless the panel is being filled or nothing would change.
func _commit(changes: Dictionary) -> void:
	if _filling or _item_id == "":
		return
	var item: FurnitureItem = store.get_furniture(_item_id)
	for key in changes:
		if item.get(key) != changes[key]:
			store.update_furniture(_item_id, changes)
			return


static func _row(form: VBoxContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	form.add_child(label)
	form.add_child(control)


func _spin(form: VBoxContainer, node_name: String, label_text: String, min_value: float, max_value: float,
		step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = false
	_row(form, label_text, spin)
	return spin
