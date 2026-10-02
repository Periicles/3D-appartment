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
	# The store is a global autoload: start every test from a clean project, so
	# an edit left by a previous test never triggers the "save changes?" dialog.
	ProjectStore.new_project()


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	_remove_test_files()
	# Walls rebuilt by a test are queue_freed: let them go before GUT counts orphans.
	await wait_process_frames(1)


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


func _press(main: Node3D, keycode: Key, command := false, unicode := 0, shift := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = unicode
	event.ctrl_pressed = command
	event.meta_pressed = command
	event.shift_pressed = shift
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



func _press_key(main: Node3D, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	main._unhandled_key_input(event)


func test_tab_toggles_the_plan_view_with_its_hint_and_underlay() -> void:
	var main := await _main()
	var camera := main.get_node("Camera") as OrbitCamera
	_press_key(main, KEY_TAB)
	assert_true(camera.is_plan_mode())
	assert_true((main.get_node("Underlay") as UnderlayView).visible, "bundled log16 plan")
	var hint := main.find_child("Hint", true, false) as Label
	assert_true(hint.visible)
	assert_string_contains(hint.text, "Vue plan")
	_press_key(main, KEY_P)
	assert_false((main.get_node("Underlay") as UnderlayView).visible)
	_press_key(main, KEY_O)
	assert_false(camera.is_plan_mode())
	assert_false(hint.visible)


func test_m_toggles_measuring_with_a_hint() -> void:
	var main := await _main()
	var measure := main.get_node("MeasureTool") as MeasureTool
	_press_key(main, KEY_M)
	assert_true(measure.is_active())
	assert_string_contains((main.find_child("Hint", true, false) as Label).text, "Mesure")
	_press_key(main, KEY_M)
	assert_false(measure.is_active())


func test_measure_tool_takes_clicks_before_the_furniture_tool() -> void:
	var main := await _main()
	assert_gt(main.get_node("MeasureTool").get_index(), main.get_node("FurnitureTool").get_index())


func test_selecting_furniture_shows_its_clearances() -> void:
	var main := await _main()
	ProjectStore.add_furniture(preload("res://tests/fixtures/project_fixtures.gd").sofa("f1"))
	(main.get_node("FurnitureTool") as FurnitureTool)._select("f1")
	assert_gt((main.get_node("Clearances") as ClearanceView).visible_sides().size(), 0)


func test_clearances_follow_a_neighbour_being_added_and_undone() -> void:
	var main := await _main()
	var fixtures := preload("res://tests/fixtures/project_fixtures.gd")
	var clearances := main.get_node("Clearances") as ClearanceView
	var a := fixtures.sofa("f1")
	a.pos = Vector2(3.0, 3.0)
	a.rotation_deg = 0.0
	ProjectStore.add_furniture(a)
	(main.get_node("FurnitureTool") as FurnitureTool)._select("f1")
	var before := clearances.line("right").label_text()
	var b := fixtures.sofa("f2")
	b.rotation_deg = 0.0
	b.pos = a.pos + Vector2(a.size.x / 2.0 + 0.5 + b.size.x / 2.0, 0.0)
	ProjectStore.add_furniture(b)
	assert_eq(clearances.line("right").label_text(), "50 cm", "the side facing the new item shows its distance")
	ProjectStore.undo()
	assert_eq(clearances.line("right").label_text(), before, "undo restores the wall distance")


func test_opening_another_project_clears_measurements() -> void:
	var main := await _main()
	var measure := main.get_node("MeasureTool") as MeasureTool
	var center := Cutaway.apartment_center(ProjectStore.project)
	measure.toggle()
	var camera := main.get_node("Camera") as Camera3D
	for offset in [Vector2(-0.5, 0), Vector2(0.5, 0)]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = camera.unproject_position(Vector3(center.x + offset.x, 0, center.y + offset.y))
		measure._unhandled_input(click)
	assert_eq(measure.measurements().size(), 1, "precondition: a real measurement exists")
	assert_eq(main.get_node("Measures").get_child_count(), 2, "preview and one line")
	(main.find_child("FileController", true, false) as FileController).new_empty()
	await wait_physics_frames(1)
	assert_eq(measure.measurements().size(), 0)
	assert_eq(main.get_node("Measures").get_child_count(), 1, "only the preview remains")


func test_starting_to_measure_cancels_a_placement_in_progress() -> void:
	var main := await _main()
	var tool := main.get_node("FurnitureTool") as FurnitureTool
	tool.begin_placement(load("res://data/presets/sofa_3.tres"))
	assert_true(tool.is_placing(), "precondition")
	(main.get_node("MeasureTool") as MeasureTool).toggle()
	assert_false(tool.is_placing())


func test_leaving_the_measure_tool_keeps_a_placement_in_progress() -> void:
	var main := await _main()
	var measure := main.get_node("MeasureTool") as MeasureTool
	measure.toggle()
	var tool := main.get_node("FurnitureTool") as FurnitureTool
	tool.begin_placement(load("res://data/presets/sofa_3.tres"))
	measure.toggle()
	assert_true(tool.is_placing())


func test_the_hint_wraps_within_a_maximum_width() -> void:
	var main := await _main()
	var hint := main.find_child("Hint", true, false) as Label
	assert_eq(hint.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(hint.custom_minimum_size.x, main.HINT_MAX_WIDTH)


func test_catalogue_buttons_do_not_keep_keyboard_focus() -> void:
	var main := await _main()
	var catalog := main.find_child("Catalog", true, false)
	for button in catalog.find_children("*", "Button", true, false):
		assert_eq((button as Button).focus_mode, Control.FOCUS_NONE)


func test_opening_a_project_loads_its_underlay() -> void:
	var main := await _main()
	assert_true((main.find_child("Underlay", true, false) as UnderlayView).has_image())


func test_digit_keys_and_mode_bar_switch_the_edit_mode() -> void:
	var main := await _main()
	_press_key(main, KEY_2)
	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.STRUCTURE)
	var furniture_button := main.find_child("ModeBar", true, false).get_node("Meubles") as Button
	var structure_button := main.find_child("ModeBar", true, false).get_node("Structure") as Button
	assert_true(structure_button.button_pressed)
	assert_false(furniture_button.button_pressed)
	furniture_button.pressed.emit()
	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.FURNITURE)
	_press_key(main, KEY_1)
	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.FURNITURE)


func test_mode_and_undo_keys_do_nothing_under_the_help_overlay() -> void:
	var main := await _main()
	var help := main.find_child("Shortcuts", true, false) as ShortcutsOverlay
	var node: PlanNode = ProjectStore.project.nodes[0]
	var start := node.pos
	var moved := start + Vector2(0.1, 0)
	_press_key(main, KEY_2)
	ProjectStore.move_node(node.id, moved)
	help.open()
	_press_key(main, KEY_1)
	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.STRUCTURE, "1 is ignored")
	_press(main, KEY_Z, true)
	assert_almost_eq(ProjectStore.project.get_plan_node(node.id).pos, moved, Vector2(0.001, 0.001), "undo is ignored")
	help.close()
	_press(main, KEY_Z, true)
	assert_almost_eq(ProjectStore.project.get_plan_node(node.id).pos, start, Vector2(0.001, 0.001), "undo works again")


func test_structure_mode_dims_furniture_greys_the_catalog_and_shows_a_hint() -> void:
	var main := await _main()
	_press_key(main, KEY_2)
	assert_true((main.get_node("Furniture") as FurnitureView).is_dimmed())
	var catalog := main.find_child("Catalog", true, false) as CatalogPanel
	assert_true(catalog.button_for("sofa_3").disabled)
	var hint := main.find_child("Hint", true, false) as Label
	assert_true(hint.visible)
	assert_string_contains(hint.text, "Structure")
	_press_key(main, KEY_1)
	assert_false((main.get_node("Furniture") as FurnitureView).is_dimmed())
	assert_false(catalog.button_for("sofa_3").disabled)
	assert_false(hint.visible)


func test_selecting_a_corner_shows_the_structure_panel() -> void:
	var main := await _main()
	_press_key(main, KEY_2)
	var node_id: String = ProjectStore.project.nodes[0].id
	(main.get_node("StructureTool") as StructureTool).select(&"node", node_id)
	var panel := main.find_child("StructurePanel", true, false) as StructurePanel
	assert_true(panel.visible)
	assert_true((main.find_child("InspectorSide", true, false) as CollapsibleSide).is_ancestor_of(panel))


func test_a_structure_edit_rebuilds_the_walls() -> void:
	var main := await _main()
	_press_key(main, KEY_2)
	var wall: Wall = ProjectStore.project.walls[0]
	ProjectStore.update_wall(wall.id, {"height": 1.0})
	await wait_physics_frames(1)
	var body := main.get_node("World/Walls/%s/Body" % wall.id) as CSGPolygon3D
	assert_almost_eq(body.depth, 1.0, EPS)


func test_command_z_undoes_and_switches_back_to_the_edit_mode() -> void:
	var main := await _main()
	_press_key(main, KEY_2)
	var node: PlanNode = ProjectStore.project.nodes[0]
	var start := node.pos
	ProjectStore.move_node(node.id, start + Vector2(0.1, 0))
	_press_key(main, KEY_1)
	_press(main, KEY_Z, true)
	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.STRUCTURE, "undo goes where the edit was made")
	assert_eq(ProjectStore.project.get_plan_node(node.id).pos, start)
	var structure_button := main.find_child("ModeBar", true, false).get_node("Structure") as Button
	assert_true(structure_button.button_pressed)
	_press(main, KEY_Z, true, 0, true)
	assert_eq(ProjectStore.project.get_plan_node(node.id).pos, start + Vector2(0.1, 0), "⌘⇧Z redoes")


## Sends a left-button event at a world point, as the viewport would after the GUI passed.
func _mouse_at(main: Node3D, tool: Node, world_point: Vector3, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = (main.get_node("Camera") as Camera3D).unproject_position(world_point)
	tool._unhandled_input(event)


func test_undo_is_ignored_while_dragging_furniture() -> void:
	var main := await _main()
	var tool := main.get_node("FurnitureTool") as FurnitureTool
	var sofa_center := Vector3(2.0, 0.4, 3.0)
	ProjectStore.add_furniture(preload("res://tests/fixtures/project_fixtures.gd").sofa("f1"))
	_mouse_at(main, tool, sofa_center, true)
	assert_true(tool.is_dragging())
	_press(main, KEY_Z, true)
	assert_not_null(ProjectStore.get_furniture("f1"), "nothing undone mid-drag")
	_mouse_at(main, tool, sofa_center, false)
	assert_false(tool.is_dragging())


func test_undo_and_redo_are_ignored_while_dragging_a_corner() -> void:
	var main := await _main()
	_press_key(main, KEY_2)
	var tool := main.get_node("StructureTool") as StructureTool
	var moved: PlanNode = ProjectStore.project.nodes[0]
	var moved_to := moved.pos + Vector2(0.1, 0)
	ProjectStore.move_node(moved.id, moved_to)
	var grabbed: PlanNode = ProjectStore.project.nodes[3]
	var grab_point := Vector3(grabbed.pos.x, StructureView.LIFT, grabbed.pos.y)
	_mouse_at(main, tool, grab_point, true)
	assert_true(tool.is_dragging())
	_press(main, KEY_Z, true)
	assert_eq(ProjectStore.project.get_plan_node(moved.id).pos, moved_to, "undo ignored mid-drag")
	_press(main, KEY_Z, true, 0, true)
	assert_eq(ProjectStore.project.get_plan_node(moved.id).pos, moved_to, "redo ignored mid-drag")
	assert_true(ProjectStore.can_undo(), "the edit stays on the undo stack")
	_mouse_at(main, tool, grab_point, false)
	assert_false(tool.is_dragging())


func test_switching_mode_commits_a_field_being_edited() -> void:
	var main := await _main()
	var tool := main.get_node("FurnitureTool") as FurnitureTool
	ProjectStore.add_furniture(preload("res://tests/fixtures/project_fixtures.gd").sofa("f1"))
	tool._select("f1")
	var field := main.find_child("Name", true, false) as LineEdit
	field.grab_focus()
	field.text = "Banquette"
	_press_key(main, KEY_2)
	assert_eq(ProjectStore.get_furniture("f1").name, "Banquette")
	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.STRUCTURE)


func test_structure_tool_sits_between_furniture_and_measure_tools() -> void:
	var main := await _main()
	var index := main.get_node("StructureTool").get_index()
	assert_gt(index, main.get_node("FurnitureTool").get_index())
	assert_lt(index, main.get_node("MeasureTool").get_index())
