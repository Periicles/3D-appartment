class_name ShortcutsOverlay
extends Control
## Full-window help listing every control (from Shortcuts), opened with ? or F1.
## Closes with Échap, the close button or a click on the dimmed backdrop.

const BACKDROP_COLOR := Color(0, 0, 0, 0.45)
const CARD_WIDTH := 640.0
const CARD_MARGIN := 40.0
const KEYS_COLUMN_WIDTH := 260.0


func _init() -> void:
	name = "Shortcuts"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func build(mac: bool = Shortcuts.is_mac()) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", Palette.panel_style())
	# Centred horizontally, full height minus a margin, so the list rarely scrolls.
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = -CARD_WIDTH / 2.0
	card.offset_right = CARD_WIDTH / 2.0
	card.offset_top = CARD_MARGIN
	card.offset_bottom = -CARD_MARGIN
	add_child(card)
	var layout := VBoxContainer.new()
	card.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "Raccourcis"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "Fermer"
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for group in Shortcuts.groups():
		var group_title := Label.new()
		group_title.text = group.title
		group_title.add_theme_color_override("font_color", Palette.SELECTION)
		list.add_child(group_title)
		var grid := GridContainer.new()
		grid.columns = 2
		list.add_child(grid)
		for entry in group.entries:
			var keys := Label.new()
			keys.text = Shortcuts.format_keys(entry.keys, mac)
			keys.custom_minimum_size.x = KEYS_COLUMN_WIDTH
			keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grid.add_child(keys)
			var action := Label.new()
			action.text = entry.action
			action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grid.add_child(action)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
