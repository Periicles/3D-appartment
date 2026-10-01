extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const DIR := "user://test_file_controller"
const SETTINGS := DIR + "/settings.cfg"
const AUTOSAVE := DIR + "/autosave.json"
const AUTOSAVE_META := DIR + "/autosave.cfg"
const PROJECT_A := DIR + "/a.json"
const PROJECT_B := DIR + "/b.json"

var _store: Node
var _autosave: Autosave
var _files: FileController
var _welcome: WelcomeScreen
var _picked := ""  # what the stub picker answers; "" means the user cancelled
var _picker_modes: Array = []
var _quit_count := 0


func before_each() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_store = autofree(Store.new())
	_autosave = Autosave.new()
	_autosave.project_path = AUTOSAVE
	_autosave.meta_path = AUTOSAVE_META
	add_child_autofree(_autosave)
	_files = _controller(_store, UiSettings.new())
	_files.path_picker = _stub_picker
	_files.quit_action = func() -> void: _quit_count += 1
	_welcome = _files.welcome
	_picked = ""
	_picker_modes.clear()
	_quit_count = 0


func after_all() -> void:
	_wipe()


func _wipe() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))


## A controller with its own welcome page, as main.gd builds it.
func _controller(store: Node, settings: UiSettings) -> FileController:
	var welcome: WelcomeScreen = add_child_autofree(WelcomeScreen.new())
	var files: FileController = add_child_autofree(FileController.new())
	files.setup(store, _autosave, settings, SETTINGS, welcome)
	return files


func _stub_picker(mode: FileDialog.FileMode, done: Callable) -> void:
	_picker_modes.append(mode)
	if _picked != "":
		done.call(_picked)


## Launch, then pick "Nouveau depuis le log 16" on the welcome page.
func _start_with_template() -> void:
	_files.startup()
	_files.new_from_template()


func _dirty_edit() -> void:
	_store.add_furniture(Fixtures.sofa(_store.next_furniture_id()))


func test_startup_shows_the_welcome_page_that_cannot_be_dismissed() -> void:
	_files.startup()
	assert_true(_welcome.visible)
	assert_false(_welcome.can_close)
	assert_false(_files.is_offering_restore())


func test_choosing_the_template_closes_the_welcome_page() -> void:
	_start_with_template()
	assert_false(_welcome.visible)
	assert_eq(_store.project.rooms.size(), 7)
	assert_eq(_store.current_path, "")


func test_saved_projects_appear_in_the_recent_list() -> void:
	_start_with_template()
	_picked = PROJECT_A
	_files.save_as()
	assert_eq(UiSettings.load_from(SETTINGS).recent_projects[0].path, PROJECT_A)
	_files.show_welcome()
	assert_true(_welcome.can_close, "a project is open now")
	var first := _welcome.find_child("Recents", true, false).get_child(0).get_node("Open") as Button
	assert_string_contains(first.text, "a.json")


func test_opening_a_recent_project() -> void:
	_start_with_template()
	_picked = PROJECT_A
	_files.save_as()
	var next_store: Node = autofree(Store.new())
	var next_files := _controller(next_store, UiSettings.load_from(SETTINGS))
	next_files.startup()
	next_files.open_recent(PROJECT_A)
	assert_eq(next_store.current_path, PROJECT_A)
	assert_false(next_files.welcome.visible)


func test_forgetting_a_recent_project() -> void:
	_start_with_template()
	_picked = PROJECT_A
	_files.save_as()
	_files.forget_recent(PROJECT_A)
	assert_eq(UiSettings.load_from(SETTINGS).recent_projects.size(), 0)
	assert_true(_welcome.visible, "the page is refreshed")


func test_vanished_recent_project_reports_it_and_keeps_the_page() -> void:
	_files.startup()
	_files.open_recent(DIR + "/gone.json")
	assert_string_contains(_files.shown_error(), "introuvable")
	assert_true(_welcome.visible)


func test_startup_offers_to_restore_unsaved_work() -> void:
	_start_with_template()
	_dirty_edit()
	_autosave.flush()
	var next_store: Node = autofree(Store.new())
	var next_files := _controller(next_store, UiSettings.new())
	next_files.startup()
	assert_true(next_files.is_offering_restore())
	next_files.answer_restore(&"restore")
	assert_true(next_store.is_dirty())
	assert_eq(next_store.project.furniture.size(), 1)
	assert_false(next_files.welcome.visible)


func test_ignoring_the_restore_drops_the_copy_and_stays_on_the_page() -> void:
	_start_with_template()
	_dirty_edit()
	_autosave.flush()
	var next_files := _controller(autofree(Store.new()), UiSettings.new())
	next_files.startup()
	next_files.answer_restore(&"ignore")
	assert_false(_autosave.has_pending())
	assert_true(next_files.welcome.visible)
	assert_false(next_files.is_offering_restore())


func test_welcome_menu_entry_reopens_the_page() -> void:
	_start_with_template()
	_files.on_menu(FileController.MenuId.WELCOME)
	assert_true(_welcome.visible)


func test_save_without_path_asks_for_one_and_adds_the_extension() -> void:
	_start_with_template()
	_picked = DIR + "/mon-appart"
	_files.save()
	assert_eq(_picker_modes, [FileDialog.FILE_MODE_SAVE_FILE])
	assert_eq(_store.current_path, DIR + "/mon-appart.json")
	assert_true(FileAccess.file_exists(DIR + "/mon-appart.json"))


func test_save_with_path_writes_without_asking() -> void:
	_start_with_template()
	_picked = PROJECT_A
	_files.save_as()
	_dirty_edit()
	_picker_modes.clear()
	_files.save()
	assert_eq(_picker_modes.size(), 0)
	assert_false(_store.is_dirty())


func test_cancelled_save_dialog_changes_nothing() -> void:
	_start_with_template()
	_dirty_edit()
	_files.save()
	assert_true(_store.is_dirty())
	assert_eq(_store.current_path, "")


func test_failed_save_shows_why_and_keeps_changes() -> void:
	_start_with_template()
	_dirty_edit()
	_picked = "/no/such/directory/x.json"
	_files.save()
	assert_string_contains(_files.shown_error(), "écriture impossible")
	assert_string_contains(_files.shown_error(), "sauvegarde automatique")
	assert_true(_store.is_dirty())


func test_open_replaces_the_project_when_nothing_is_lost() -> void:
	_start_with_template()
	_picked = PROJECT_A
	_files.save_as()
	_files.new_empty()
	_files.open()
	assert_eq(_store.current_path, PROJECT_A)


func test_open_of_a_broken_file_shows_the_reason_and_keeps_the_project() -> void:
	_start_with_template()
	var file := FileAccess.open(PROJECT_B, FileAccess.WRITE)
	file.store_string("{pas du json")
	file.close()
	_picked = PROJECT_B
	_files.open()
	assert_string_contains(_files.shown_error(), "JSON invalide")
	assert_eq(_store.project.rooms.size(), 7)


func test_unsaved_changes_are_confirmed_before_new() -> void:
	_start_with_template()
	_dirty_edit()
	_files.new_empty()
	assert_true(_files.is_confirming())
	assert_eq(_store.project.rooms.size(), 7, "nothing replaced yet")


func test_cancel_keeps_everything() -> void:
	_start_with_template()
	_dirty_edit()
	_files.new_empty()
	_files.answer_confirmation(&"cancel")
	assert_true(_store.is_dirty())
	assert_eq(_store.project.rooms.size(), 7)


func test_discard_drops_changes_and_the_autosave() -> void:
	_start_with_template()
	_dirty_edit()
	_autosave.flush()
	_files.new_empty()
	_files.answer_confirmation(&"discard")
	assert_eq(_store.project.rooms.size(), 0)
	assert_false(_autosave.has_pending())


func test_discard_keeps_the_copy_when_the_open_picker_is_cancelled() -> void:
	_start_with_template()
	_dirty_edit()
	_autosave.flush()
	_files.open()
	_files.answer_confirmation(&"discard")  # _picked is "": the user cancels the picker
	assert_true(_autosave.has_pending())
	assert_true(_store.is_dirty())


func test_discard_keeps_the_copy_when_the_opened_file_is_broken() -> void:
	_start_with_template()
	_dirty_edit()
	_autosave.flush()
	var file := FileAccess.open(PROJECT_B, FileAccess.WRITE)
	file.store_string("{pas du json")
	file.close()
	_picked = PROJECT_B
	_files.open()
	_files.answer_confirmation(&"discard")
	assert_true(_autosave.has_pending())


func test_save_then_continue() -> void:
	_start_with_template()
	_dirty_edit()
	_files.new_empty()
	_picked = PROJECT_A
	_files.answer_confirmation(&"save")
	assert_true(FileAccess.file_exists(PROJECT_A))
	assert_eq(_store.project.rooms.size(), 0, "then the new project opened")


func test_save_cancelled_during_confirmation_does_not_continue() -> void:
	_start_with_template()
	_dirty_edit()
	_files.new_empty()
	_files.answer_confirmation(&"save")  # _picked is "": the user cancels the save dialog
	assert_eq(_store.project.rooms.size(), 7)
	assert_true(_store.is_dirty())


func test_quit_asks_when_dirty_and_quits_directly_otherwise() -> void:
	_start_with_template()
	_files.request_quit()
	assert_eq(_quit_count, 1)
	_dirty_edit()
	_files.request_quit()
	assert_eq(_quit_count, 1)
	assert_true(_files.is_confirming())
	_autosave.flush()
	_files.answer_confirmation(&"discard")
	assert_eq(_quit_count, 2)
	assert_false(_autosave.has_pending(), "quitting drops the copy")


func test_title_shows_file_name_and_unsaved_marker() -> void:
	_start_with_template()
	assert_eq(_files.title_text(), "Sans titre — 3D Appartment")
	_dirty_edit()
	assert_eq(_files.title_text(), "Sans titre * — 3D Appartment")
	_picked = PROJECT_A
	_files.save()
	assert_eq(_files.title_text(), "a.json — 3D Appartment")


func test_new_from_template_is_untitled() -> void:
	_start_with_template()
	_picked = PROJECT_A
	_files.save_as()
	_files.new_from_template()
	assert_eq(_store.current_path, "")
	assert_eq(_store.project.rooms.size(), 7)


func test_menu_lists_the_spec_entries_and_routes_them() -> void:
	var bar: MenuBar = add_child_autofree(_files.build_menu())
	var menu := bar.get_child(0) as PopupMenu
	var labels := []
	for i in menu.item_count:
		if not menu.is_item_separator(i):
			labels.append(menu.get_item_text(i))
	assert_eq(labels, ["Accueil…", "Nouveau (vide)", "Nouveau depuis le log 16", "Ouvrir…", "Enregistrer",
		"Enregistrer sous…"])
	_start_with_template()
	menu.id_pressed.emit(FileController.MenuId.NEW_EMPTY)
	assert_eq(_store.project.rooms.size(), 0)


func _pending_copy_and_fresh_controller() -> FileController:
	_start_with_template()
	_dirty_edit()
	_autosave.flush()
	var next_files := _controller(autofree(Store.new()), UiSettings.new())
	next_files.path_picker = _stub_picker
	next_files.quit_action = func() -> void: _quit_count += 1
	next_files.startup()
	return next_files


func test_quitting_while_a_restore_is_undecided_keeps_the_copy() -> void:
	var next_files := _pending_copy_and_fresh_controller()
	assert_true(next_files.is_offering_restore())
	next_files.request_quit()
	assert_eq(_quit_count, 1)
	assert_true(_autosave.has_pending())


func test_entry_points_do_nothing_while_the_restore_card_is_shown() -> void:
	var next_files := _pending_copy_and_fresh_controller()
	_picked = PROJECT_A
	next_files.open()
	next_files.save()
	next_files.save_as()
	next_files.new_empty()
	next_files.new_from_template()
	next_files.open_recent(PROJECT_A)
	next_files.on_menu(FileController.MenuId.OPEN)
	assert_eq(_picker_modes.size(), 0, "no picker was opened")
	assert_true(next_files.welcome.visible)
	assert_true(next_files.is_offering_restore())
	assert_true(_autosave.has_pending())
	assert_false(FileAccess.file_exists(PROJECT_A))


func test_corrupt_copy_is_set_aside_not_deleted_when_restoring_fails() -> void:
	var file := FileAccess.open(AUTOSAVE, FileAccess.WRITE)
	file.store_string("{oops")
	file.close()
	_files.startup()
	assert_true(_files.is_offering_restore())
	_files.answer_restore(&"restore")
	assert_string_contains(_files.shown_error(), "conservé")
	assert_true(FileAccess.file_exists(DIR + "/autosave.corrupt.json"))
	assert_false(_autosave.has_pending())
	assert_true(_welcome.visible)


func test_autosave_write_failure_is_shown_once() -> void:
	_autosave.write_failed.emit(ERR_FILE_CANT_WRITE)
	assert_string_contains(_files.shown_error(), "Pensez à enregistrer")
	_files.find_child("Error", true, false).hide()
	_autosave.write_failed.emit(ERR_FILE_CANT_WRITE)
	assert_eq(_files.shown_error(), "", "not shown a second time")
