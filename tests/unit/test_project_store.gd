extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())


func _write_temp(text: String) -> String:
	var path := "user://test_project_store.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func test_starts_with_an_empty_project() -> void:
	assert_eq(_store.project.walls.size(), 0)


func test_loads_a_valid_file_and_emits_signal() -> void:
	watch_signals(_store)
	var errors: PackedStringArray = _store.load_from_file(_write_temp(JSON.stringify(Fixtures.square_room_dict())))
	assert_eq(errors, PackedStringArray())
	assert_eq(_store.project.walls.size(), 4)
	assert_signal_emitted(_store, "project_loaded")


func test_keeps_current_project_when_file_is_invalid() -> void:
	_store.load_from_file(_write_temp(JSON.stringify(Fixtures.square_room_dict())))
	watch_signals(_store)
	var errors: PackedStringArray = _store.load_from_file(_write_temp("{oops"))
	assert_false(errors.is_empty())
	assert_eq(_store.project.walls.size(), 4)
	assert_signal_not_emitted(_store, "project_loaded")


func test_reports_missing_file() -> void:
	var errors: PackedStringArray = _store.load_from_file("user://does_not_exist.json")
	assert_string_contains(errors[0], "introuvable")


func test_loads_shipped_log16_plan() -> void:
	assert_eq(_store.load_from_file("res://data/log16.json"), PackedStringArray())
	assert_eq(_store.project.rooms.size(), 7)
