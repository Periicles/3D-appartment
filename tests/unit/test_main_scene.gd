extends GutTest
## Smoke tests: the application scene loads the shipped plan, builds it and
## wires the interface.

const MainScene := preload("res://src/main.tscn")
const SETTINGS_PATH := "user://test_main_settings.cfg"
const AUTOSAVE_PATH := "user://test_main_autosave.json"
const AUTOSAVE_META_PATH := "user://test_main_autosave.cfg"
const EPS := 1e-4


func _remove_test_files() -> void:
	for path in [SETTINGS_PATH, AUTOSAVE_PATH, AUTOSAVE_META_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func before_each() -> void:
	_remove_test_files()


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	_remove_test_files()


## The scene with its preferences redirected, so tests never touch the user's
## files; by default the log 16 is picked on the welcome page.
func _main(open_template := true) -> Node3D:
	var main: Node3D = MainScene.instantiate()
	main.settings_path = SETTINGS_PATH
	main.autosave_project_path = AUTOSAVE_PATH
	main.autosave_meta_path = AUTOSAVE_META_PATH
	add_child_autofree(main)
	await wait_physics_frames(1)
	if open_template:
		(main.find_child("FileController", true, false) as FileController).new_from_template()
	return main


func _press(main: Node3D, keycode: Key, command := false, unicode := 0) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = unicode
	event.ctrl_pressed = command
	event.meta_pressed = command
	main._unhandled_key_input(event)


func test_main_scene_builds_the_shipped_plan() -> void:
	var main := await _main()
	var walls := main.get_node_or_null("World/Walls")
	assert_not_null(walls)
	assert_eq(walls.get_child_count(), ProjectStore.project.walls.size())
	assert_eq(main.get_node("World/Floors").get_child_count(), ProjectStore.project.rooms.size())
	assert_not_null(main.get_node_or_null("Camera"))
	assert_not_null(main.get_node_or_null("Environment"))
	assert_not_null(main.get_node_or_null("Sun"))
	assert_not_null(main.get_node_or_null("Furniture"))
	assert_not_null(main.get_node_or_null("FurnitureTool"))
	assert_not_null(main.find_child("Catalog", true, false))
	assert_not_null(main.find_child("Properties", true, false))


func test_tool_receives_input_before_the_camera() -> void:
	var main := await _main()
	assert_gt(main.get_node("FurnitureTool").get_index(), main.get_node("Camera").get_index())


func test_choosing_a_preset_starts_placement() -> void:
	var main := await _main()
	var catalog := main.find_child("Catalog", true, false) as CatalogPanel
	catalog.button_for("sofa_3").pressed.emit()
	assert_true((main.get_node("FurnitureTool") as FurnitureTool).is_placing())


func test_panels_live_in_collapsible_sides() -> void:
	var main := await _main()
	var catalog_side := main.find_child("CatalogSide", true, false) as CollapsibleSide
	var inspector_side := main.find_child("InspectorSide", true, false) as CollapsibleSide
	assert_true(catalog_side.is_ancestor_of(main.find_child("Catalog", true, false)))
	assert_true(inspector_side.is_ancestor_of(main.find_child("Properties", true, false)))


func test_c_and_i_toggle_the_panels() -> void:
	var main := await _main()
	var catalog_side := main.find_child("CatalogSide", true, false) as CollapsibleSide
	var inspector_side := main.find_child("InspectorSide", true, false) as CollapsibleSide
	_press(main, KEY_C)
	assert_false(catalog_side.is_open())
	_press(main, KEY_C)
	assert_true(catalog_side.is_open())
	_press(main, KEY_I)
	assert_false(inspector_side.is_open())


func test_help_opens_with_f1_question_mark_and_button() -> void:
	var main := await _main()
	var help := main.find_child("Shortcuts", true, false) as ShortcutsOverlay
	_press(main, KEY_F1)
	assert_true(help.visible)
	help.close()
	_press(main, KEY_COMMA, false, "?".unicode_at(0))
	assert_true(help.visible)
	help.close()
	(main.find_child("HelpButton", true, false) as Button).pressed.emit()
	assert_true(help.visible)


## The interface is scaled through the window's content scale, which keeps fonts sharp.
func _layer_scale(_main: Node3D) -> float:
	return get_tree().root.content_scale_factor


func test_interface_covers_the_window_at_any_scale() -> void:
	var main := await _main()
	var root := main.get_node("UI/Root") as Control
	_press(main, KEY_EQUAL, true)
	assert_almost_eq(root.size, main.get_viewport().get_visible_rect().size, Vector2(EPS, EPS) * 10)


func test_command_plus_minus_zero_scale_the_interface_and_remember_it() -> void:
	var main := await _main()
	var base := _layer_scale(main)
	_press(main, KEY_EQUAL, true)
	assert_almost_eq(_layer_scale(main), base * 1.1, EPS)
	assert_almost_eq(UiSettings.load_from(SETTINGS_PATH).zoom, 1.1, EPS)
	_press(main, KEY_MINUS, true)
	_press(main, KEY_MINUS, true)
	assert_almost_eq(_layer_scale(main), base * 0.9, EPS)
	_press(main, KEY_0, true)
	assert_almost_eq(_layer_scale(main), base, EPS)
	assert_almost_eq(UiSettings.load_from(SETTINGS_PATH).zoom, 1.0, EPS)


func test_saved_zoom_is_applied_at_start() -> void:
	var saved := UiSettings.new()
	saved.zoom_in()
	saved.zoom_in()
	saved.save_to(SETTINGS_PATH)
	var main := await _main()
	assert_almost_eq(_layer_scale(main), saved.ui_scale(DisplayServer.screen_get_scale()), EPS)


func test_h_still_cycles_the_cutaway_mode() -> void:
	var main := await _main()
	var view := main.get_node("World") as WorldView
	_press(main, KEY_H)
	assert_eq(view.cutaway_mode, Cutaway.Mode.FULL)



func test_starts_on_the_welcome_page() -> void:
	var main := await _main(false)
	var welcome := main.find_child("Welcome", true, false) as WelcomeScreen
	assert_true(welcome.visible)
	assert_false(welcome.can_close)


func test_picking_the_template_shows_the_log16_untitled() -> void:
	var main := await _main()
	assert_false((main.find_child("Welcome", true, false) as WelcomeScreen).visible)
	assert_eq(ProjectStore.project.rooms.size(), 7)
	assert_eq(ProjectStore.current_path, "")


func test_command_shift_o_reopens_the_welcome_page() -> void:
	var main := await _main()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_O
	event.ctrl_pressed = true
	event.meta_pressed = true
	event.shift_pressed = true
	main._unhandled_key_input(event)
	assert_true((main.find_child("Welcome", true, false) as WelcomeScreen).visible)


func test_file_menu_and_controller_are_present() -> void:
	var main := await _main()
	assert_not_null(main.find_child("FileController", true, false))
	assert_not_null(main.find_child("MenuBar", true, false))


func test_command_s_and_o_reach_the_file_controller() -> void:
	var main := await _main()
	var files := main.find_child("FileController", true, false) as FileController
	var modes := []
	files.path_picker = func(mode: FileDialog.FileMode, _done: Callable) -> void: modes.append(mode)
	_press(main, KEY_S, true)
	_press(main, KEY_O, true)
	assert_eq(modes, [FileDialog.FILE_MODE_SAVE_FILE, FileDialog.FILE_MODE_OPEN_FILE])


func test_closing_the_window_with_unsaved_changes_asks_first() -> void:
	var main := await _main()
	var files := main.find_child("FileController", true, false) as FileController
	var quits := [0]
	files.quit_action = func() -> void: quits[0] += 1
	ProjectStore.add_furniture(preload("res://tests/fixtures/project_fixtures.gd").sofa("f1"))
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(files.is_confirming())
	assert_eq(quits[0], 0)
	files.answer_confirmation(&"discard")
	assert_eq(quits[0], 1)
