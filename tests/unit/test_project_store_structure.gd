extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())
	_store.project = Fixtures.square_room()
	_store.set_edit_mode(Store.EditMode.STRUCTURE)


func _node_pos(id: String) -> Vector2:
	return _store.project.get_plan_node(id).pos


func test_starts_in_furniture_mode() -> void:
	var fresh: Node = autofree(Store.new())
	assert_eq(fresh.edit_mode, Store.EditMode.FURNITURE)


func test_changing_mode_emits_once() -> void:
	watch_signals(_store)
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	assert_signal_emit_count(_store, "edit_mode_changed", 1)


func test_structure_edits_are_refused_in_furniture_mode() -> void:
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	assert_false(_store.move_node("n3", Vector2(5, 5)))
	assert_false(_store.update_wall("w2", {"thickness": 0.1}))
	assert_false(_store.remove_wall("w2"))
	assert_eq(_node_pos("n3"), Vector2(4, 4))
	assert_false(_store.can_undo())


func test_furniture_edits_are_refused_in_structure_mode() -> void:
	assert_false(_store.add_furniture(Fixtures.sofa("f2")))
	assert_false(_store.update_furniture("f1", {"name": "X"}))
	assert_false(_store.remove_furniture("f1"))
	assert_eq(_store.duplicate_furniture("f1"), "")
	assert_eq(_store.project.furniture.size(), 1)


func test_move_node_drags_its_walls_and_undoes_in_one_step() -> void:
	watch_signals(_store)
	assert_true(_store.move_node("n3", Vector2(5, 4.5)))
	assert_eq(_node_pos("n3"), Vector2(5, 4.5))
	assert_almost_eq(_store.project.wall_length(_store.project.get_wall("w2")), Vector2(1, 4.5).length(), EPS)
	assert_signal_emitted(_store, "structure_changed")
	_store.undo()
	assert_eq(_node_pos("n3"), Vector2(4, 4))
	_store.redo()
	assert_eq(_node_pos("n3"), Vector2(5, 4.5))


func test_move_to_the_same_place_records_nothing() -> void:
	assert_false(_store.move_node("n3", Vector2(4, 4)))
	assert_false(_store.can_undo())


func test_a_move_that_squeezes_a_door_out_of_its_wall_is_refused() -> void:
	# The door o1 spans 0.6 m to 1.4 m along w1 (n1 -> n2).
	assert_false(_store.can_move_node("n2", Vector2(1.2, 0)))
	assert_false(_store.move_node("n2", Vector2(1.2, 0)))
	assert_eq(_node_pos("n2"), Vector2(4, 0))
	assert_true(_store.can_move_node("n2", Vector2(2, 0)))


func test_a_move_that_collapses_a_wall_is_refused() -> void:
	assert_false(_store.move_node("n3", Vector2(4, 0.01)), "w2 would be 1 cm long")


func test_update_wall_thickness_and_height() -> void:
	assert_true(_store.update_wall("w2", {"thickness": 0.1, "height": 2.2}))
	var wall: Wall = _store.project.get_wall("w2")
	assert_almost_eq(wall.thickness, 0.1, EPS)
	assert_almost_eq(wall.height, 2.2, EPS)
	_store.undo()
	assert_almost_eq(_store.project.get_wall("w2").thickness, 0.2, EPS)


func test_wall_length_moves_its_end_node() -> void:
	assert_true(_store.update_wall("w2", {"length": 3.0}))  # n2 (4,0) -> n3
	assert_almost_eq(_node_pos("n3"), Vector2(4, 3), Vector2(EPS, EPS))
	assert_eq(_node_pos("n2"), Vector2(4, 0))


func test_invalid_wall_changes_are_refused() -> void:
	assert_false(_store.update_wall("w2", {"thickness": 0.0}))
	assert_false(_store.update_wall("w2", {"colour": 1}))
	assert_false(_store.update_wall("nope", {"height": 2.0}))
	assert_false(_store.update_wall("w1", {"length": 1.0}), "the door would stick out")
	assert_false(_store.can_undo())


func test_remove_wall_takes_its_openings_and_keeps_room_corners() -> void:
	assert_true(_store.remove_wall("w1"))
	assert_null(_store.project.get_wall("w1"))
	assert_eq(_store.project.openings.size(), 0, "the door went with its wall")
	assert_eq(_store.project.nodes.size(), 4, "corners still outline the room")
	_store.undo()
	assert_not_null(_store.project.get_wall("w1"))
	assert_eq(_store.project.openings.size(), 1)


func test_remove_wall_deletes_corners_left_alone() -> void:
	_store.project.nodes.append(Fixtures.plan_node("n5", 6, 0))
	_store.project.walls.append(Fixtures.wall("w5", "n2", "n5"))
	assert_true(_store.remove_wall("w5"))
	assert_null(_store.project.get_plan_node("n5"), "no wall, no room")
	assert_not_null(_store.project.get_plan_node("n2"), "still holds w1 and w2")


func test_undoing_a_structure_edit_from_furniture_mode_switches_mode() -> void:
	_store.move_node("n3", Vector2(5, 5))
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	watch_signals(_store)
	assert_true(_store.undo())
	assert_eq(_store.edit_mode, Store.EditMode.STRUCTURE)
	assert_signal_emitted_with_parameters(_store, "edit_mode_changed", [Store.EditMode.STRUCTURE])
	assert_eq(_node_pos("n3"), Vector2(4, 4))


func test_undoing_a_furniture_edit_from_structure_mode_switches_back() -> void:
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	_store.update_furniture("f1", {"name": "Banquette"})
	_store.set_edit_mode(Store.EditMode.STRUCTURE)
	_store.undo()
	assert_eq(_store.edit_mode, Store.EditMode.FURNITURE)
	assert_eq(_store.get_furniture("f1").name, "Canapé")
	_store.set_edit_mode(Store.EditMode.STRUCTURE)
	_store.redo()
	assert_eq(_store.edit_mode, Store.EditMode.FURNITURE)
	assert_eq(_store.get_furniture("f1").name, "Banquette")


func test_undo_with_empty_history_keeps_the_mode() -> void:
	assert_false(_store.undo())
	assert_false(_store.redo())
	assert_eq(_store.edit_mode, Store.EditMode.STRUCTURE)


func test_history_states_are_not_shared_with_the_project() -> void:
	_store.move_node("n3", Vector2(5, 5))
	_store.project.get_plan_node("n3").pos = Vector2(9, 9)  # outside the store, as a bug would
	_store.undo()
	_store.redo()
	assert_eq(_node_pos("n3"), Vector2(5, 5))


func test_loading_a_project_returns_to_furniture_mode() -> void:
	watch_signals(_store)
	_store.new_project()
	assert_eq(_store.edit_mode, Store.EditMode.FURNITURE)
	assert_signal_emitted(_store, "edit_mode_changed")


func test_structure_edits_make_the_project_dirty() -> void:
	_store.move_node("n3", Vector2(5, 5))
	assert_true(_store.is_dirty())
	_store.undo()
	assert_false(_store.is_dirty())


func test_non_numeric_or_non_finite_wall_values_are_refused() -> void:
	var bad_values: Array = [null, "3", INF, NAN]
	for key in Store.WALL_FIELDS:
		for value in bad_values:
			assert_false(_store.update_wall("w2", {key: value}), "%s = %s" % [key, value])
	assert_false(_store.update_wall("w2", {"length": -3.0}))
	assert_false(_store.update_wall("w2", {"length": 0.0}))
	assert_false(_store.can_undo())
	assert_eq(_node_pos("n3"), Vector2(4, 4))


func test_a_non_finite_corner_position_is_refused() -> void:
	for pos in [Vector2(NAN, 0), Vector2(INF, 1)]:
		assert_false(_store.move_node("n3", pos))
		assert_false(_store.can_move_node("n3", pos))
	assert_false(_store.can_undo())
	assert_eq(_node_pos("n3"), Vector2(4, 4))


func test_unchanged_wall_values_record_nothing() -> void:
	assert_false(_store.update_wall("w2", {"thickness": 0.2}))
	assert_false(_store.update_wall("w2", {"length": 4.0}))
	assert_false(_store.can_undo())


func test_redo_of_a_structure_edit_switches_to_structure_mode() -> void:
	_store.move_node("n3", Vector2(5, 5))
	_store.undo()
	_store.set_edit_mode(Store.EditMode.FURNITURE)
	assert_true(_store.redo())
	assert_eq(_store.edit_mode, Store.EditMode.STRUCTURE)
	assert_eq(_node_pos("n3"), Vector2(5, 5))


func test_undo_and_redo_emit_structure_changed() -> void:
	_store.move_node("n3", Vector2(5, 5))
	watch_signals(_store)
	_store.undo()
	_store.redo()
	assert_signal_emit_count(_store, "structure_changed", 2)
