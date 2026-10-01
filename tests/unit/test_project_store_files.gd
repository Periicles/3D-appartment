extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const SAVE_PATH := "user://test_store_files.json"
const LOG16 := "res://data/log16.json"

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_new_store_is_clean_and_untitled() -> void:
	assert_false(_store.is_dirty())
	assert_eq(_store.current_path, "")


func test_edits_make_the_project_dirty_and_undo_back_cleans_it() -> void:
	watch_signals(_store)
	_store.add_furniture(Fixtures.sofa("f1"))
	assert_true(_store.is_dirty())
	assert_signal_emitted_with_parameters(_store, "dirty_changed", [true])
	assert_signal_emitted(_store, "edited")
	_store.undo()
	assert_false(_store.is_dirty())


func test_save_writes_a_reloadable_file_and_cleans_the_project() -> void:
	_store.load_from_file(LOG16)
	_store.add_furniture(Fixtures.sofa("f1"))
	watch_signals(_store)
	assert_eq(_store.save_to_file(SAVE_PATH), PackedStringArray())
	assert_false(_store.is_dirty())
	assert_eq(_store.current_path, SAVE_PATH)
	assert_signal_emitted_with_parameters(_store, "path_changed", [SAVE_PATH])
	var other: Node = autofree(Store.new())
	assert_eq(other.load_from_file(SAVE_PATH), PackedStringArray())
	assert_eq(other.project.furniture.size(), 1)
	assert_eq(other.project.walls.size(), _store.project.walls.size())


func test_edit_after_save_is_dirty_and_undo_to_save_point_is_clean() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	_store.save_to_file(SAVE_PATH)
	_store.update_furniture("f1", {"name": "Autre"})
	assert_true(_store.is_dirty())
	_store.undo()
	assert_false(_store.is_dirty())
	_store.undo()
	assert_true(_store.is_dirty(), "before the save point is dirty too")


func test_failed_write_keeps_project_dirty_and_path_unchanged() -> void:
	_store.add_furniture(Fixtures.sofa("f1"))
	var errors: PackedStringArray = _store.save_to_file("/no/such/directory/project.json")
	assert_false(errors.is_empty())
	assert_string_contains(errors[0], "écriture impossible")
	assert_true(_store.is_dirty())
	assert_eq(_store.current_path, "")


func test_invalid_project_is_not_written() -> void:
	_store.project.walls.append(Fixtures.wall("w", "ghost", "n9"))
	var errors: PackedStringArray = _store.save_to_file(SAVE_PATH)
	assert_false(errors.is_empty())
	assert_false(FileAccess.file_exists(SAVE_PATH))


func test_save_leaves_no_temporary_file() -> void:
	_store.save_to_file(SAVE_PATH)
	assert_false(FileAccess.file_exists(SAVE_PATH + ".tmp"))


func test_opening_sets_the_path_and_a_template_stays_untitled() -> void:
	_store.load_from_file(LOG16)
	assert_eq(_store.current_path, LOG16)
	_store.load_from_file(LOG16, true)
	assert_eq(_store.current_path, "")
	assert_false(_store.is_dirty())


func test_new_project_is_empty_clean_and_untitled() -> void:
	_store.load_from_file(LOG16)
	_store.add_furniture(Fixtures.sofa("f1"))
	watch_signals(_store)
	_store.new_project()
	assert_eq(_store.project.walls.size(), 0)
	assert_eq(_store.current_path, "")
	assert_false(_store.is_dirty())
	assert_false(_store.can_undo())
	assert_signal_emitted(_store, "project_loaded")


func test_restore_reopens_unsaved_work_as_dirty() -> void:
	var text := ProjectSerializer.to_json(Fixtures.square_room())
	assert_eq(_store.restore_from_text(text, "user://somewhere.json"), PackedStringArray())
	assert_true(_store.is_dirty())
	assert_eq(_store.current_path, "user://somewhere.json")
	assert_eq(_store.project.furniture.size(), 1)


func test_restore_of_broken_text_keeps_the_current_project() -> void:
	_store.load_from_file(LOG16)
	assert_false(_store.restore_from_text("{oops", "").is_empty())
	assert_eq(_store.current_path, LOG16)
