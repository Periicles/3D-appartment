extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4

var _view: FurnitureView


func before_each() -> void:
	_view = FurnitureView.new()
	add_child_autofree(_view)


func _box(id: String) -> MeshInstance3D:
	return _view.get_node("%s/Box" % id) as MeshInstance3D


func _items(ids: Array) -> Array[FurnitureItem]:
	var items: Array[FurnitureItem] = []
	for id in ids:
		items.append(Fixtures.sofa(id))
	return items


func test_show_items_builds_one_block_per_item() -> void:
	_view.show_items(_items(["f1", "f2"]))
	assert_eq(_view.get_child_count(), 2)
	assert_not_null(_view.get_node_or_null("f1"))


func test_block_matches_item_size_position_and_rotation() -> void:
	var sofa := Fixtures.sofa("f1")
	_view.add_item(sofa)
	var node := _view.get_node("f1") as Node3D
	assert_almost_eq(node.position, Vector3(2, 0, 3), Vector3(EPS, EPS, EPS))
	assert_almost_eq(node.rotation.y, deg_to_rad(90.0), EPS)
	assert_eq((_box("f1").mesh as BoxMesh).size, sofa.size)
	assert_almost_eq(_box("f1").position.y, sofa.size.y / 2.0, EPS, "block stands on the floor")


func test_update_item_follows_new_data() -> void:
	var sofa := Fixtures.sofa("f1")
	_view.add_item(sofa)
	sofa.pos = Vector2(5, 1)
	sofa.size = Vector3(1, 2, 1)
	sofa.color = Color.RED
	_view.update_item(sofa)
	assert_almost_eq((_view.get_node("f1") as Node3D).position, Vector3(5, 0, 1), Vector3(EPS, EPS, EPS))
	assert_eq((_box("f1").mesh as BoxMesh).size, Vector3(1, 2, 1))
	assert_eq((_box("f1").material_override as StandardMaterial3D).albedo_color, Color.RED)


func test_remove_item_deletes_block_and_clears_selection() -> void:
	_view.show_items(_items(["f1"]))
	_view.set_selected("f1")
	_view.remove_item("f1")
	assert_null(_view.get_node_or_null("f1"))
	assert_eq(_view.selected_id(), "")


func test_selection_outlines_only_the_selected_item() -> void:
	_view.show_items(_items(["f1", "f2"]))
	_view.set_selected("f1")
	assert_not_null((_box("f1").material_override as StandardMaterial3D).next_pass)
	_view.set_selected("f2")
	assert_null((_box("f1").material_override as StandardMaterial3D).next_pass)
	assert_not_null((_box("f2").material_override as StandardMaterial3D).next_pass)
	_view.set_selected("")
	assert_null((_box("f2").material_override as StandardMaterial3D).next_pass)


func test_preview_moves_block_only() -> void:
	var sofa := Fixtures.sofa("f1")
	_view.add_item(sofa)
	_view.preview_item("f1", Vector2(7, 7), 0.0)
	assert_almost_eq((_view.get_node("f1") as Node3D).position, Vector3(7, 0, 7), Vector3(EPS, EPS, EPS))
	assert_eq(sofa.pos, Vector2(2, 3), "data untouched")


func test_ghost_is_translucent_and_follows() -> void:
	_view.show_ghost(Vector3(1, 1, 1), Color.BLUE)
	assert_true(_view.has_ghost())
	var mat := (_view.get_node(FurnitureView.GHOST_NAME + "/Box") as MeshInstance3D).material_override as StandardMaterial3D
	assert_almost_eq(mat.albedo_color.a, Palette.GHOST_ALPHA, EPS)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	_view.move_ghost(Vector2(3, 4), 45.0)
	assert_almost_eq((_view.get_node(FurnitureView.GHOST_NAME) as Node3D).position, Vector3(3, 0, 4), Vector3(EPS, EPS, EPS))
	_view.hide_ghost()
	await wait_physics_frames(1)
	assert_false(_view.has_ghost())


func test_show_ghost_twice_keeps_a_single_ghost() -> void:
	_view.show_ghost(Vector3.ONE, Color.BLUE)
	_view.show_ghost(Vector3.ONE, Color.RED)
	await wait_physics_frames(1)
	var ghosts := _view.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Ghost"))
	assert_eq(ghosts.size(), 1)


func test_show_items_replaces_previous_blocks() -> void:
	_view.show_items(_items(["f1", "f2"]))
	_view.show_items(_items(["f3"]))
	assert_eq(_view.get_child_count(), 1)
	assert_not_null(_view.get_node_or_null("f3"))


func test_updates_for_unknown_ids_are_ignored() -> void:
	_view.update_item(Fixtures.sofa("ghost"))
	_view.remove_item("ghost")
	_view.preview_item("ghost", Vector2.ZERO, 0.0)
	_view.set_selected("ghost")
	assert_eq(_view.get_child_count(), 0)
	assert_eq(_view.selected_id(), "")


func test_bound_store_edits_are_mirrored() -> void:
	var store: Node = autofree(preload("res://src/store/project_store.gd").new())
	_view.bind_store(store)
	store.add_furniture(Fixtures.sofa("f1"))
	assert_not_null(_view.get_node_or_null("f1"))
	store.update_furniture("f1", {"pos": Vector2(1, 1)})
	assert_almost_eq((_view.get_node("f1") as Node3D).position, Vector3(1, 0, 1), Vector3(EPS, EPS, EPS))
	store.remove_furniture("f1")
	assert_null(_view.get_node_or_null("f1"))
	store.undo()
	assert_not_null(_view.get_node_or_null("f1"), "undo brings the block back")
