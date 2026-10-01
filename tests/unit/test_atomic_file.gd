extends GutTest

const PATH := "user://test_atomic_file.txt"
const MISSING_DIR_PATH := "/no/such/dir/file.txt"


func _remove(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func before_each() -> void:
	_remove(PATH)


func after_all() -> void:
	_remove(PATH)


func test_writes_the_content() -> void:
	assert_eq(AtomicFile.write(PATH, "abc"), OK)
	assert_eq(FileAccess.get_file_as_string(PATH), "abc")


func test_overwrites_an_existing_file() -> void:
	AtomicFile.write(PATH, "old")
	assert_eq(AtomicFile.write(PATH, "new"), OK)
	assert_eq(FileAccess.get_file_as_string(PATH), "new")


func test_leaves_no_temporary_file() -> void:
	AtomicFile.write(PATH, "abc")
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_missing_directory_returns_an_error() -> void:
	assert_ne(AtomicFile.write(MISSING_DIR_PATH, "abc"), OK)
	assert_false(FileAccess.file_exists(MISSING_DIR_PATH))
