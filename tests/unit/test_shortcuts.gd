extends GutTest


func test_mac_uses_symbols() -> void:
	assert_eq(Shortcuts.format_keys(["cmd", "shift", "Z"], true), "⌘ ⇧ Z")
	assert_eq(Shortcuts.format_keys(["alt"], true), "⌥")


func test_other_platforms_use_words() -> void:
	assert_eq(Shortcuts.format_keys(["cmd", "shift", "Z"], false), "Ctrl + Maj + Z")
	assert_eq(Shortcuts.format_keys(["alt"], false), "Alt")


func test_plain_tokens_are_kept() -> void:
	assert_eq(Shortcuts.format_keys(["Clic droit + glisser"], true), "Clic droit + glisser")


func test_groups_cover_camera_furniture_and_interface() -> void:
	var titles: Array = Shortcuts.groups().map(func(g: Dictionary) -> String: return g.title)
	assert_eq(titles, ["Caméra (souris)", "Caméra (trackpad)", "Meubles", "Interface"])


func test_every_entry_has_keys_and_action() -> void:
	for group in Shortcuts.groups():
		assert_false(group.entries.is_empty(), group.title)
		for entry in group.entries:
			assert_false(entry.keys.is_empty(), str(entry))
			assert_false(String(entry.action).is_empty(), str(entry))


func test_interface_group_lists_panel_help_and_zoom_keys() -> void:
	var interface: Dictionary = Shortcuts.groups()[3]
	var keys: Array = interface.entries.map(func(e: Dictionary) -> String: return Shortcuts.format_keys(e.keys, false))
	for expected in ["C", "I", "? / F1", "Ctrl + +", "Ctrl + −", "Ctrl + 0", "H"]:
		assert_has(keys, expected)


func test_furniture_hint_is_short_and_platform_aware() -> void:
	assert_string_contains(Shortcuts.furniture_hint(true), "⌘ D")
	assert_string_contains(Shortcuts.furniture_hint(false), "Ctrl + D")
	assert_lt(Shortcuts.furniture_hint(true).split("\n").size(), 5)


func _key(keycode: Key, unicode := 0, command := false, shift := false, physical: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = physical if physical != KEY_NONE else keycode
	event.unicode = unicode
	event.ctrl_pressed = command
	event.meta_pressed = command
	event.shift_pressed = shift
	return event


func test_panel_help_and_cutaway_keys() -> void:
	assert_eq(Shortcuts.action_for(_key(KEY_C)), &"toggle_catalog")
	assert_eq(Shortcuts.action_for(_key(KEY_I)), &"toggle_inspector")
	assert_eq(Shortcuts.action_for(_key(KEY_H)), &"cutaway")
	assert_eq(Shortcuts.action_for(_key(KEY_F1)), &"help")


func test_question_mark_on_any_layout_opens_help() -> void:
	# AZERTY Mac: Shift + comma; QWERTY: Shift + slash.
	assert_eq(Shortcuts.action_for(_key(KEY_COMMA, "?".unicode_at(0), false, true)), &"help")
	assert_eq(Shortcuts.action_for(_key(KEY_SLASH, "?".unicode_at(0), false, true)), &"help")


func test_command_letter_combinations_are_not_panel_toggles() -> void:
	assert_eq(Shortcuts.action_for(_key(KEY_C, 0, true)), &"")
	assert_eq(Shortcuts.action_for(_key(KEY_I, 0, true)), &"")


func test_zoom_keys_on_qwerty_and_azerty() -> void:
	assert_eq(Shortcuts.action_for(_key(KEY_EQUAL, 0, true)), &"zoom_in")
	assert_eq(Shortcuts.action_for(_key(KEY_EQUAL, "+".unicode_at(0), true, true)), &"zoom_in")
	assert_eq(Shortcuts.action_for(_key(KEY_PLUS, 0, true)), &"zoom_in")
	assert_eq(Shortcuts.action_for(_key(KEY_KP_ADD, 0, true)), &"zoom_in")
	assert_eq(Shortcuts.action_for(_key(KEY_MINUS, 0, true)), &"zoom_out")
	assert_eq(Shortcuts.action_for(_key(KEY_KP_SUBTRACT, 0, true)), &"zoom_out")
	assert_eq(Shortcuts.action_for(_key(KEY_0, 0, true)), &"zoom_reset")
	# AZERTY: the "à 0" key reports its own keycode but sits where 0 is physically.
	assert_eq(Shortcuts.action_for(_key(224 as Key, 0, true, false, KEY_0)), &"zoom_reset")


func test_zoom_needs_the_command_key() -> void:
	assert_eq(Shortcuts.action_for(_key(KEY_MINUS)), &"")
	assert_eq(Shortcuts.action_for(_key(KEY_0)), &"")


func test_released_and_repeated_keys_do_nothing() -> void:
	var released := _key(KEY_C)
	released.pressed = false
	assert_eq(Shortcuts.action_for(released), &"")
	var repeated := _key(KEY_C)
	repeated.echo = true
	assert_eq(Shortcuts.action_for(repeated), &"")
