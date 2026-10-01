class_name WelcomeScreen
extends Control
## Project selection page: recent projects, new / open buttons, and a card to
## restore unsaved work found at launch. Emits the user's choice; the
## FileController acts on it.

signal recent_chosen(path: String)
signal recent_forgotten(path: String)
signal new_empty_chosen
signal new_from_template_chosen
signal open_file_chosen
signal restore_chosen
signal restore_ignored

const BACKDROP_COLOR := Color(0.1, 0.09, 0.09, 0.75)
const CARD_WIDTH := 600.0
const ROW_HEIGHT := 58.0
const MAX_LIST_HEIGHT := 400.0
const MISSING_COLOR := Color(1, 1, 1, 0.4)
const RESTORE_BORDER := 2
const RESTORE_HINT := "Choisissez d'abord : restaurer ou ignorer."

## False while no project is open yet (first launch): the page cannot be dismissed.
var can_close := true


func _init() -> void:
	name = "Welcome"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Fills and shows the page. `recents` comes from UiSettings.recent_projects;
## `restore_name` is the file name of pending unsaved work, or "" for none.
func present(recents: Array[Dictionary], restore_name: String, closable: bool) -> void:
	can_close = closable
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", Palette.panel_style())
	# Centred, as tall as its content.
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size.x = CARD_WIDTH
	add_child(card)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	card.add_child(layout)
	var title := Label.new()
	title.text = "3D Appartment"
	title.add_theme_font_size_override("font_size", 24)
	layout.add_child(title)
	if restore_name != "":
		layout.add_child(_restore_card(restore_name))
		var hint := Label.new()
		hint.name = "RestoreHint"
		hint.text = RESTORE_HINT
		layout.add_child(hint)
	var must_decide := restore_name != ""
	var actions := HBoxContainer.new()
	layout.add_child(actions)
	_button(actions, "NewEmpty", "Nouveau projet vide", new_empty_chosen.emit).disabled = must_decide
	_button(actions, "NewFromTemplate", "Nouveau depuis le log 16", new_from_template_chosen.emit).disabled = must_decide
	_button(actions, "OpenFile", "Ouvrir un fichier…", open_file_chosen.emit).disabled = must_decide
	var heading := Label.new()
	heading.text = "Projets récents"
	heading.add_theme_color_override("font_color", Palette.SELECTION)
	layout.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = clampf(maxi(recents.size(), 1) * ROW_HEIGHT, ROW_HEIGHT, MAX_LIST_HEIGHT)
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Recents"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if recents.is_empty():
		var empty := Label.new()
		empty.text = "Aucun projet récent."
		list.add_child(empty)
	for entry in recents:
		list.add_child(_recent_row(entry, must_decide))
	visible = true


func close() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and can_close and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _restore_card(file_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Restore"
	var style := Palette.panel_style()
	style.border_color = Palette.SELECTION
	style.set_border_width_all(RESTORE_BORDER)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	card.add_child(box)
	var message := Label.new()
	message.text = "Modifications non enregistrées de « %s » retrouvées." % file_name
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_button(buttons, "RestoreButton", "Restaurer", restore_chosen.emit)
	_button(buttons, "IgnoreButton", "Ignorer", restore_ignored.emit)
	return card


func _recent_row(entry: Dictionary, must_decide: bool) -> HBoxContainer:
	var path: String = entry.path
	var exists := FileAccess.file_exists(path)
	var row := HBoxContainer.new()
	var open := Button.new()
	open.name = "Open"
	open.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.text = "%s\n%s · %s" % [path.get_file(), _short_folder(path),
		_date(entry.opened_at) if exists else "introuvable"]
	open.disabled = not exists or must_decide
	if not exists:
		open.add_theme_color_override("font_disabled_color", MISSING_COLOR)
	open.pressed.connect(recent_chosen.emit.bind(path))
	row.add_child(open)
	var forget := Button.new()
	forget.name = "Forget"
	forget.text = "×"
	forget.tooltip_text = "Retirer de la liste"
	forget.pressed.connect(recent_forgotten.emit.bind(path))
	row.add_child(forget)
	return row


static func _button(parent: Control, node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## The file's folder, with the home directory written "~".
static func _short_folder(path: String) -> String:
	var folder := path.get_base_dir()
	var home := OS.get_environment("HOME")
	if home != "" and folder.begins_with(home):
		folder = "~" + folder.substr(home.length())
	return folder


## Local date and time, e.g. "14/11/2023 22:13".
static func _date(unix_seconds: float) -> String:
	var bias_minutes: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(int(unix_seconds) + bias_minutes * 60)
	return "%02d/%02d/%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
