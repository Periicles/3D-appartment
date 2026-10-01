extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const PROJECT := "user://test_autosave.json"
const META := "user://test_autosave.cfg"
const SAVE_PATH := "user://test_autosave_saved.json"
const DELAY := 0.1

var _store: Node
var _autosave: Autosave


func _remove(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func before_each() -> void:
	for path in [PROJECT, META, SAVE_PATH]:
		_remove(path)
	_store = autofree(Store.new())
	_autosave = Autosave.new()
	_autosave.project_path = PROJECT
	_autosave.meta_path = META
	_autosave.delay = DELAY
	add_child_autofree(_autosave)
	_autosave.start(_store)


func after_all() -> void:
	for path in [PROJECT, META, SAVE_PATH]:
		_remove(path)


func test_nothing_pending_at_first() -> void:
	assert_false(_autosave.has_pending())


func test_an_edit_is_written_after_the_delay() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	assert_true(_autosave.is_scheduled())
	assert_false(_autosave.has_pending(), "not before the delay")
	await wait_seconds(DELAY + 0.15)
	assert_true(_autosave.has_pending())
	var copy := ProjectSerializer.from_json(FileAccess.get_file_as_string(PROJECT))
	assert_eq(copy.project.furniture.size(), 1)


func test_further_edits_postpone_the_write() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	await wait_seconds(DELAY * 0.6)
	_store.update_furniture("f1", {"name": "Autre"})
	await wait_seconds(DELAY * 0.6)
	assert_false(_autosave.has_pending(), "timer restarted by the second edit")
	await wait_seconds(DELAY)
	assert_true(_autosave.has_pending())


func test_saving_removes_the_copy() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	_autosave.flush()
	assert_true(_autosave.has_pending())
	_store.save_to_file(SAVE_PATH)
	assert_false(_autosave.has_pending())
	assert_false(_autosave.is_scheduled())


func test_undo_back_to_the_saved_state_removes_the_copy() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	_autosave.flush()
	_store.undo()
	assert_false(_autosave.has_pending())


func test_copy_remembers_the_source_file() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	_store.save_to_file(SAVE_PATH)
	_store.update_furniture("f1", {"name": "Autre"})
	_autosave.flush()
	assert_eq(_autosave.pending_source_path(), SAVE_PATH)


func test_restore_into_a_fresh_store_gives_dirty_work_back() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	_autosave.flush()
	var next_session: Node = autofree(Store.new())
	assert_eq(_autosave.restore_into(next_session), PackedStringArray())
	assert_true(next_session.is_dirty())
	assert_eq(next_session.project.furniture.size(), 1)


func test_restore_without_copy_reports_it() -> void:
	assert_false(_autosave.restore_into(autofree(Store.new())).is_empty())


func test_write_error_is_returned() -> void:
	_autosave.project_path = "/no/such/dir/autosave.json"
	_store.add_furniture(Fixtures.sofa("f1"))
	assert_ne(_autosave.flush(), OK)


func test_starting_twice_is_harmless() -> void:
	_autosave.start(_store)
	_store.add_furniture(Fixtures.sofa("f1"))
	assert_true(_autosave.is_scheduled())
