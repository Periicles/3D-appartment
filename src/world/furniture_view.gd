class_name FurnitureView
extends Node3D
## Draws furniture items as coloured blocks, the selection outline, and the
## translucent ghost used while placing a new item. Never edits the project.

## Contains a space, which ProjectValidator forbids in ids, so it never clashes with an item.
const GHOST_NAME := "Ghost preview"
## Opacity of the blocks while the structure is edited.
const DIMMED_ALPHA := 0.4

var _selected_id := ""
var _outline := Palette.outline_material()
var _store: Node
var _dimmed := false


## Keeps the blocks in sync with a ProjectStore (the autoload, or a test double).
## Bound methods (not lambdas) so the connections die with this node.
func bind_store(store: Node) -> void:
	_store = store
	store.project_loaded.connect(_on_project_loaded)
	store.furniture_added.connect(_on_furniture_added)
	store.furniture_changed.connect(_on_furniture_changed)
	store.furniture_removed.connect(remove_item)
	_on_project_loaded()


func _on_project_loaded() -> void:
	show_items(_store.project.furniture)


func _on_furniture_added(id: String) -> void:
	add_item(_store.get_furniture(id))


func _on_furniture_changed(id: String) -> void:
	update_item(_store.get_furniture(id))


func show_items(items: Array[FurnitureItem]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_selected_id = ""
	for item in items:
		add_item(item)


func add_item(item: FurnitureItem) -> void:
	var node := _block(item.size, Palette.material(item.color))
	node.name = item.id
	add_child(node)
	_place(node, item.pos, item.rotation_deg)
	_apply_dim(node, item.color)


## Rebuilds the item's block from its current data.
func update_item(item: FurnitureItem) -> void:
	var node := get_node_or_null(NodePath(item.id)) as Node3D
	if node == null:
		return
	var box := node.get_node("Box") as MeshInstance3D
	(box.mesh as BoxMesh).size = item.size
	box.position.y = item.size.y / 2.0
	_apply_dim(node, item.color)
	_place(node, item.pos, item.rotation_deg)


func remove_item(id: String) -> void:
	var node := get_node_or_null(NodePath(id))
	if node == null:
		return
	if id == _selected_id:
		_selected_id = ""
	remove_child(node)
	node.queue_free()


## Moves the item's block without touching the data (live drag feedback).
func preview_item(id: String, pos: Vector2, rotation_deg: float) -> void:
	var node := get_node_or_null(NodePath(id)) as Node3D
	if node != null:
		_place(node, pos, rotation_deg)


## Outlines the item with this id; "" or an unknown id clears the selection.
func set_selected(id: String) -> void:
	if _selected_id != "":
		_set_outline(_selected_id, false)
	_selected_id = id if has_node(NodePath(id)) and id != GHOST_NAME else ""
	if _selected_id != "":
		_set_outline(_selected_id, true)


func selected_id() -> String:
	return _selected_id


## Fades every block (Structure mode), or restores them.
func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	if _store == null:
		return
	for item in _store.project.furniture:
		var node := get_node_or_null(NodePath(item.id))
		if node != null:
			_apply_dim(node, item.color)


func is_dimmed() -> bool:
	return _dimmed


func show_ghost(size: Vector3, color: Color) -> void:
	hide_ghost()
	var ghost_color := color
	ghost_color.a = Palette.GHOST_ALPHA
	var ghost := _block(size, Palette.material(ghost_color))
	ghost.name = GHOST_NAME
	add_child(ghost)


func move_ghost(pos: Vector2, rotation_deg: float) -> void:
	var ghost := get_node_or_null(GHOST_NAME) as Node3D
	if ghost != null:
		_place(ghost, pos, rotation_deg)


func hide_ghost() -> void:
	var ghost := get_node_or_null(GHOST_NAME)
	if ghost != null:
		remove_child(ghost)
		ghost.queue_free()


func has_ghost() -> bool:
	return get_node_or_null(GHOST_NAME) != null


func _set_outline(id: String, on: bool) -> void:
	var node := get_node_or_null(NodePath(id))
	if node == null:
		return
	var mat := (node.get_node("Box") as MeshInstance3D).material_override as StandardMaterial3D
	mat.next_pass = _outline if on else null


func _apply_dim(node: Node, color: Color) -> void:
	var mat := (node.get_node("Box") as MeshInstance3D).material_override as StandardMaterial3D
	var shown := color
	shown.a = DIMMED_ALPHA if _dimmed else 1.0
	mat.albedo_color = shown
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _dimmed else BaseMaterial3D.TRANSPARENCY_DISABLED


static func _block(size: Vector3, material: StandardMaterial3D) -> Node3D:
	var node := Node3D.new()
	var box := MeshInstance3D.new()
	box.name = "Box"
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position.y = size.y / 2.0
	node.add_child(box)
	return node


static func _place(node: Node3D, pos: Vector2, rotation_deg: float) -> void:
	node.position = Vector3(pos.x, 0, pos.y)
	node.rotation = Vector3(0, deg_to_rad(rotation_deg), 0)
