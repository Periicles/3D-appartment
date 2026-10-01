extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())


func _sofa(id := "f1") -> FurnitureItem:
	return Fixtures.sofa(id)


func test_add_stores_a_copy_and_emits() -> void:
	watch_signals(_store)
	var item := _sofa()
	assert_true(_store.add_furniture(item))
	item.name = "changed outside"
	assert_eq(_store.get_furniture("f1").name, "Canapé")
	assert_signal_emitted_with_parameters(_store, "furniture_added", ["f1"])


func test_add_rejects_duplicate_id_and_invalid_item() -> void:
	_store.add_furniture(_sofa())
	assert_false(_store.add_furniture(_sofa()))
	var flat := _sofa("f2")
	flat.size.y = 0.0
	assert_false(_store.add_furniture(flat))
	assert_eq(_store.project.furniture.size(), 1)



func test_undo_add_removes_and_redo_restores() -> void:
	_store.add_furniture(_sofa())
	watch_signals(_store)
	assert_true(_store.undo())
	assert_null(_store.get_furniture("f1"))
	assert_signal_emitted_with_parameters(_store, "furniture_removed", ["f1"])
	assert_true(_store.redo())
	assert_not_null(_store.get_furniture("f1"))


func test_update_changes_fields_and_undo_restores_them() -> void:
	_store.add_furniture(_sofa())
	watch_signals(_store)
	assert_true(_store.update_furniture("f1", {"pos": Vector2(3, 1), "rotation_deg": 90.0}))
	assert_eq(_store.get_furniture("f1").pos, Vector2(3, 1))
	assert_eq(_store.get_furniture("f1").rotation_deg, 90.0)
	assert_signal_emitted_with_parameters(_store, "furniture_changed", ["f1"])
	_store.undo()
	assert_eq(_store.get_furniture("f1").pos, Vector2(2, 3))
	assert_eq(_store.get_furniture("f1").rotation_deg, Fixtures.sofa("x").rotation_deg)


func test_update_rejects_unknown_id_field_and_invalid_values() -> void:
	_store.add_furniture(_sofa())
	assert_false(_store.update_furniture("nope", {"name": "x"}))
	assert_false(_store.update_furniture("f1", {"id": "f2"}))
	assert_false(_store.update_furniture("f1", {"size": Vector3(1, 0, 1)}))
	assert_false(_store.update_furniture("f1", {}))
	assert_eq(_store.get_furniture("f1").size, Fixtures.sofa("x").size)


func test_rejected_update_leaves_history_untouched() -> void:
	_store.add_furniture(_sofa())
	_store.update_furniture("f1", {"size": Vector3(1, 0, 1)})
	_store.undo()
	assert_null(_store.get_furniture("f1"), "the only undo step is the add")


func test_remove_and_undo_restores_at_same_index() -> void:
	_store.add_furniture(_sofa("f1"))
	_store.add_furniture(_sofa("f2"))
	_store.add_furniture(_sofa("f3"))
	assert_true(_store.remove_furniture("f2"))
	assert_null(_store.get_furniture("f2"))
	_store.undo()
	assert_eq(_store.project.furniture[1].id, "f2")


func test_duplicate_gets_new_id_and_offset() -> void:
	_store.add_furniture(_sofa("f1"))
	var id: String = _store.duplicate_furniture("f1")
	assert_ne(id, "f1")
	assert_eq(_store.get_furniture(id).pos, Fixtures.sofa("x").pos + _store.DUPLICATE_OFFSET)
	assert_eq(_store.get_furniture(id).name, "Canapé")
	assert_eq(_store.duplicate_furniture("nope"), "")


func test_next_id_follows_the_highest_numbered_id() -> void:
	assert_eq(_store.next_furniture_id(), "f1")
	_store.add_furniture(_sofa("f2"))
	assert_eq(_store.next_furniture_id(), "f3")
	_store.add_furniture(_sofa("f1"))
	assert_eq(_store.next_furniture_id(), "f3")
	_store.add_furniture(_sofa("sofa"))
	assert_eq(_store.next_furniture_id(), "f3", "ids not shaped f<n> are ignored")


func test_loading_a_project_clears_history() -> void:
	_store.add_furniture(_sofa())
	_store.load_from_file("res://data/log16.json")
	assert_false(_store.can_undo())
	assert_false(_store.undo())


func test_undo_with_empty_history_is_harmless() -> void:
	assert_false(_store.undo())
	assert_false(_store.redo())
