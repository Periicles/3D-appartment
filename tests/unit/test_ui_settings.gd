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
