extends GutTest

const DIR := "user://test_welcome"
const EXISTING := DIR + "/appart.json"
const MISSING := DIR + "/gone.json"

var _welcome: WelcomeScreen


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var file := FileAccess.open(EXISTING, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	_welcome = WelcomeScreen.new()
	add_child_autofree(_welcome)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EXISTING))


func _recents() -> Array[Dictionary]:
	return [{"path": EXISTING, "opened_at": 1700000000.0}, {"path": MISSING, "opened_at": 1600000000.0}]


func _rows() -> Array[Node]:
	return _welcome.find_child("Recents", true, false).get_children()


func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_welcome._unhandled_key_input(event)


func test_hidden_until_presented() -> void:
	assert_false(_welcome.visible)
	_welcome.present(_recents(), "", true)
	assert_true(_welcome.visible)


func test_lists_recent_projects_with_folder_and_date() -> void:
	_welcome.present(_recents(), "", true)
	assert_eq(_rows().size(), 2)
	var first := _rows()[0].get_node("Open") as Button
	assert_string_contains(first.text, "appart.json")
	assert_string_contains(first.text, "2023")
	assert_false(first.disabled)


func test_missing_project_is_disabled_and_marked() -> void:
	_welcome.present(_recents(), "", true)
	var missing := _rows()[1].get_node("Open") as Button
	assert_true(missing.disabled)
	assert_string_contains(missing.text, "introuvable")


func test_empty_list_says_so() -> void:
	_welcome.present([] as Array[Dictionary], "", true)
	assert_eq((_rows()[0] as Label).text, "Aucun projet récent.")


func test_choosing_and_forgetting_emit_the_path() -> void:
	_welcome.present(_recents(), "", true)
	watch_signals(_welcome)
	(_rows()[0].get_node("Open") as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_welcome, "recent_chosen", [EXISTING])
	(_rows()[1].get_node("Forget") as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_welcome, "recent_forgotten", [MISSING])


func test_action_buttons_emit() -> void:
	_welcome.present(_recents(), "", true)
	watch_signals(_welcome)
	for pair in [["NewEmpty", "new_empty_chosen"], ["NewFromTemplate", "new_from_template_chosen"],
			["OpenFile", "open_file_chosen"]]:
		(_welcome.find_child(pair[0], true, false) as Button).pressed.emit()
		assert_signal_emitted(_welcome, pair[1])


func test_restore_card_only_when_there_is_unsaved_work() -> void:
	_welcome.present(_recents(), "", true)
	assert_null(_welcome.find_child("Restore", true, false))
	_welcome.present(_recents(), "appart.json", true)
	var card := _welcome.find_child("Restore", true, false)
	assert_not_null(card)
	watch_signals(_welcome)
	(card.find_child("RestoreButton", true, false) as Button).pressed.emit()
	(card.find_child("IgnoreButton", true, false) as Button).pressed.emit()
	assert_signal_emitted(_welcome, "restore_chosen")
	assert_signal_emitted(_welcome, "restore_ignored")


func test_escape_closes_only_when_allowed() -> void:
	_welcome.present(_recents(), "", false)
	_escape()
	assert_true(_welcome.visible)
	_welcome.present(_recents(), "", true)
	_escape()
	assert_false(_welcome.visible)


func test_blocks_the_scene_behind() -> void:
	_welcome.present(_recents(), "", true)
	assert_eq((_welcome.get_node("Backdrop") as Control).mouse_filter, Control.MOUSE_FILTER_STOP)


func test_home_folder_is_shortened() -> void:
	var home := OS.get_environment("HOME")
	assert_eq(WelcomeScreen._short_folder(home + "/Documents/a.json"), "~/Documents")
	assert_eq(WelcomeScreen._short_folder("/tmp/a.json"), "/tmp")


func _choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for node_name in ["NewEmpty", "NewFromTemplate", "OpenFile"]:
		buttons.append(_welcome.find_child(node_name, true, false) as Button)
	return buttons


func test_choices_wait_for_the_restore_decision() -> void:
	_welcome.present(_recents(), "appart.json", true)
	for button in _choice_buttons():
		assert_true(button.disabled, button.name)
	assert_true((_rows()[0].get_node("Open") as Button).disabled)
	assert_false((_rows()[0].get_node("Forget") as Button).disabled)
	assert_not_null(_welcome.find_child("RestoreHint", true, false))


func test_choices_are_enabled_without_a_restore_card() -> void:
	_welcome.present(_recents(), "", true)
	for button in _choice_buttons():
		assert_false(button.disabled, button.name)
	assert_false((_rows()[0].get_node("Open") as Button).disabled)
	assert_true((_rows()[1].get_node("Open") as Button).disabled, "a missing file stays disabled")
	assert_null(_welcome.find_child("RestoreHint", true, false))
