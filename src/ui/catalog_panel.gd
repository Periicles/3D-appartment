class_name CatalogPanel
extends PanelContainer
## Left-hand catalogue: one button per preset, grouped by category.

signal preset_chosen(preset: FurniturePreset)

const PANEL_WIDTH := 220.0


func _init() -> void:
	name = "Catalog"
	custom_minimum_size.x = PANEL_WIDTH
	add_theme_stylebox_override("panel", Palette.panel_style())


func populate(presets: Array[FurniturePreset]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var title := Label.new()
	title.text = "Catalogue"
	list.add_child(title)
	var current_category := ""
	for preset in presets:
		if preset.category != current_category:
			current_category = preset.category
			var header := Label.new()
			header.text = current_category
			header.add_theme_color_override("font_color", Palette.SELECTION)
			list.add_child(header)
		var button := Button.new()
		button.name = preset.id
		button.text = preset.name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE  # Keeps Tab, Space and Enter for the shortcuts.
		button.tooltip_text = "%d × %d × %d cm" % [roundi(preset.size.x * 100), roundi(preset.size.z * 100),
			roundi(preset.size.y * 100)]
		button.pressed.connect(preset_chosen.emit.bind(preset))
		list.add_child(button)


func button_for(preset_id: String) -> Button:
	return find_child(preset_id, true, false) as Button
