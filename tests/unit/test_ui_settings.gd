extends GutTest

const PATH := "user://test_ui_settings.cfg"
const EPS := 1e-6


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_to_full_size_without_a_file() -> void:
	assert_eq(UiSettings.load_from(PATH).zoom, 1.0)


func test_zoom_steps_by_ten_percent_within_limits() -> void:
	var settings := UiSettings.new()
	settings.zoom_in()
	assert_almost_eq(settings.zoom, 1.1, EPS)
	for i in 20:
		settings.zoom_in()
	assert_almost_eq(settings.zoom, UiSettings.MAX_ZOOM, EPS)
	for i in 30:
		settings.zoom_out()
	assert_almost_eq(settings.zoom, UiSettings.MIN_ZOOM, EPS)
	settings.reset_zoom()
	assert_eq(settings.zoom, 1.0)


func test_repeated_steps_do_not_drift() -> void:
	var settings := UiSettings.new()
	for i in 3:
		settings.zoom_in()
	for i in 3:
		settings.zoom_out()
	assert_eq(settings.zoom, 1.0)


func test_zoom_survives_save_and_load() -> void:
	var settings := UiSettings.new()
	settings.zoom_in()
	settings.zoom_in()
	assert_eq(settings.save_to(PATH), OK)
	assert_almost_eq(UiSettings.load_from(PATH).zoom, 1.2, EPS)


func test_out_of_range_file_value_is_clamped() -> void:
	var file := ConfigFile.new()
	file.set_value("interface", "zoom", 9.0)
	file.save(PATH)
	assert_almost_eq(UiSettings.load_from(PATH).zoom, UiSettings.MAX_ZOOM, EPS)


func test_non_numeric_file_value_falls_back_to_default() -> void:
	var file := ConfigFile.new()
	file.set_value("interface", "zoom", "grand")
	file.save(PATH)
	assert_eq(UiSettings.load_from(PATH).zoom, 1.0)


func test_ui_scale_combines_screen_scale_and_zoom() -> void:
	var settings := UiSettings.new()
	settings.zoom_in()
	assert_almost_eq(settings.ui_scale(2.0), 2.2, EPS)
	assert_almost_eq(settings.ui_scale(0.0), 1.1, EPS, "unknown screen scale counts as 1")


func test_remembered_projects_come_most_recent_first() -> void:
	var settings := UiSettings.new()
	settings.remember_project("/a.json", 1.0)
	settings.remember_project("/b.json", 2.0)
	assert_eq(settings.recent_projects.map(func(e: Dictionary) -> String: return e.path), ["/b.json", "/a.json"])


func test_remembering_again_moves_to_the_top_without_duplicate() -> void:
	var settings := UiSettings.new()
	settings.remember_project("/a.json", 1.0)
	settings.remember_project("/b.json", 2.0)
	settings.remember_project("/a.json", 3.0)
	assert_eq(settings.recent_projects.size(), 2)
	assert_eq(settings.recent_projects[0], {"path": "/a.json", "opened_at": 3.0})


func test_recent_list_is_capped() -> void:
	var settings := UiSettings.new()
	for i in 12:
		settings.remember_project("/p%d.json" % i, float(i))
	assert_eq(settings.recent_projects.size(), UiSettings.MAX_RECENT)
	assert_eq(settings.recent_projects[0].path, "/p11.json")


func test_forget_removes_a_project() -> void:
	var settings := UiSettings.new()
	settings.remember_project("/a.json", 1.0)
	settings.remember_project("/b.json", 2.0)
	settings.forget_project("/a.json")
	assert_eq(settings.recent_projects.size(), 1)
	assert_eq(settings.recent_projects[0].path, "/b.json")


func test_recent_projects_survive_save_and_load() -> void:
	var settings := UiSettings.new()
	settings.remember_project("/Users/me/appart.json", 1700000000.0)
	settings.save_to(PATH)
	assert_eq(UiSettings.load_from(PATH).recent_projects, [{"path": "/Users/me/appart.json", "opened_at": 1700000000.0}])


func test_malformed_recent_entries_are_skipped() -> void:
	var file := ConfigFile.new()
	file.set_value("files", "recent_projects", [{"path": 3}, "x", {"path": "/ok.json", "opened_at": 5}])
	file.save(PATH)
	assert_eq(UiSettings.load_from(PATH).recent_projects, [{"path": "/ok.json", "opened_at": 5.0}])


func test_save_leaves_no_temporary_file() -> void:
	assert_eq(UiSettings.new().save_to(PATH), OK)
	assert_true(FileAccess.file_exists(PATH))
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
