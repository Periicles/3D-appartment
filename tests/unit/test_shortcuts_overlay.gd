extends GutTest

var _overlay: ShortcutsOverlay


func before_each() -> void:
	_overlay = ShortcutsOverlay.new()
	add_child_autofree(_overlay)
	_overlay.build(true)


func _texts() -> Array:
	return _overlay.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func test_hidden_until_opened() -> void:
	assert_false(_overlay.visible)
	_overlay.toggle()
	assert_true(_overlay.visible)
	_overlay.toggle()
	assert_false(_overlay.visible)


func test_lists_every_group_and_entry() -> void:
	var texts := _texts()
	for group in Shortcuts.groups():
		assert_has(texts, group.title)
		for entry in group.entries:
			assert_has(texts, entry.action)
			assert_has(texts, Shortcuts.format_keys(entry.keys, true))


func test_escape_closes_it() -> void:
	_overlay.open()
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_overlay._unhandled_key_input(event)
	assert_false(_overlay.visible)


func test_escape_is_ignored_while_closed() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	_overlay._unhandled_key_input(event)
	assert_false(_overlay.visible)


func test_click_on_the_backdrop_closes_it() -> void:
	_overlay.open()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(_overlay.get_node("Backdrop") as Control).gui_input.emit(click)
	assert_false(_overlay.visible)


func test_close_button_closes_it() -> void:
	_overlay.open()
	(_overlay.find_child("Close", true, false) as Button).pressed.emit()
	assert_false(_overlay.visible)


func test_blocks_clicks_to_the_scene_while_open() -> void:
	assert_eq((_overlay.get_node("Backdrop") as Control).mouse_filter, Control.MOUSE_FILTER_STOP)


func test_card_uses_most_of_the_window_height() -> void:
	_overlay.open()
	await wait_physics_frames(2)
	var card := _overlay.find_child("Card", true, false) as Control
	assert_gt(card.size.y, _overlay.size.y * 0.7)


func test_card_is_padded() -> void:
	var card := _overlay.find_child("Card", true, false) as PanelContainer
	var style := card.get_theme_stylebox("panel")
	assert_gt(style.content_margin_left, 0.0)
