extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4

var _store: Node
var _panel: StructurePanel


func before_each() -> void:
	_store = autofree(Store.new())
	_store.project = Fixtures.square_room()
	_store.set_edit_mode(Store.EditMode.STRUCTURE)
	_panel = add_child_autofree(StructurePanel.new())
	_panel.bind_store(_store)


func _spin(node_name: String) -> SpinBox:
	return _panel.find_child(node_name, true, false) as SpinBox


func test_hidden_without_selection() -> void:
	assert_false(_panel.visible)
	_panel.show_selection(&"node", "nope")
	assert_false(_panel.visible)


func test_shows_a_corner_position_without_editing() -> void:
	_panel.show_selection(&"node", "n3")
	assert_true(_panel.visible)
	assert_eq(_spin("X").value, 4.0)
	assert_eq(_spin("Z").value, 4.0)
	assert_false(_spin("Length").is_visible_in_tree(), "wall fields hidden")
	assert_false(_store.can_undo())


func test_editing_x_moves_the_corner_and_keeps_the_exact_z() -> void:
	_store.move_node("n3", Vector2(4, 4.1234))
	_panel.show_selection(&"node", "n3")
	_spin("X").value = 4.5
	assert_almost_eq(_store.project.get_plan_node("n3").pos, Vector2(4.5, 4.1234), Vector2(EPS, EPS))


func test_shows_a_wall_in_centimetres() -> void:
	_panel.show_selection(&"wall", "w2")
	assert_eq(_spin("Length").value, 400.0)
	assert_eq(_spin("Thickness").value, 20.0)
	assert_eq(_spin("Height").value, 250.0)
	assert_false(_spin("X").is_visible_in_tree(), "corner fields hidden")


func test_editing_wall_fields_updates_the_store_in_metres() -> void:
	_panel.show_selection(&"wall", "w2")
	_spin("Thickness").value = 10
	_spin("Height").value = 220
	_spin("Length").value = 300
	var wall: Wall = _store.project.get_wall("w2")
	assert_almost_eq(wall.thickness, 0.1, EPS)
	assert_almost_eq(wall.height, 2.2, EPS)
	assert_almost_eq(_store.project.wall_length(wall), 3.0, EPS)


func test_a_refused_value_springs_back() -> void:
	_panel.show_selection(&"wall", "w1")
	_spin("Length").value = 100  # the door on w1 would stick out
	assert_eq(_spin("Length").value, 400.0)
	assert_almost_eq(_store.project.wall_length(_store.project.get_wall("w1")), 4.0, EPS)


func test_refreshes_when_the_structure_changes_elsewhere() -> void:
	_panel.show_selection(&"node", "n3")
	_store.move_node("n3", Vector2(5, 6))
	assert_eq(_spin("X").value, 5.0)
	assert_eq(_spin("Z").value, 6.0)


func test_hides_when_the_shown_wall_is_deleted() -> void:
	_panel.show_selection(&"wall", "w2")
	(_panel.find_child("DeleteWall", true, false) as Button).pressed.emit()
	assert_null(_store.project.get_wall("w2"))
	assert_false(_panel.visible)


func test_hint_comes_from_the_shortcut_list() -> void:
	var labels := _panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(labels, Shortcuts.structure_hint())


func test_a_vanished_selection_is_forgotten() -> void:
	_panel.show_selection(&"wall", "w2")
	_store.remove_wall("w2")
	_spin("Length").value = 123.0
	_store.undo()
	assert_not_null(_store.project.get_wall("w2"))
	assert_false(_store.can_undo(), "only the delete was recorded")
