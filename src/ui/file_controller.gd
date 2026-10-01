class_name FileController
extends Node
## File menu behaviour: welcome page, new, open, save, save as, restore after
## a crash, confirmation before losing changes, window title. Talks to the
## store and the autosave; asks the user through the welcome page and dialogs.

enum MenuId { WELCOME, NEW_EMPTY, NEW_FROM_TEMPLATE, OPEN, SAVE, SAVE_AS }

const APP_NAME := "3D Appartment"
const UNTITLED := "Sans titre"
const TEMPLATE_PATH := "res://data/log16.json"
const EXTENSION := "json"
const FILE_FILTER := "*.json ; Projets 3D Appartment"
const UNSAVED_HINT := "Vos modifications restent en mémoire et dans la sauvegarde automatique."

var store: Node
var autosave: Autosave
var settings: UiSettings
var welcome: WelcomeScreen
var settings_path := UiSettings.DEFAULT_PATH
var template_path := TEMPLATE_PATH
## Asks for a file: picker.call(mode: FileDialog.FileMode, done: Callable(path)).
## Tests replace it; by default it opens the system file dialog.
var path_picker: Callable = _pick_with_dialog
## Called once the user agreed to quit; tests replace it.
var quit_action: Callable

var _confirm: ConfirmationDialog
var _error: AcceptDialog
var _file_dialog: FileDialog
var _after_confirm: Callable
## Whether a project has been opened since launch (the welcome page can be closed).
var _has_project := false


func _init() -> void:
	name = "FileController"


func setup(p_store: Node, p_autosave: Autosave, p_settings: UiSettings, p_settings_path: String,
		p_welcome: WelcomeScreen) -> void:
	store = p_store
	autosave = p_autosave
	settings = p_settings
	settings_path = p_settings_path
	welcome = p_welcome
	welcome.recent_chosen.connect(open_recent)
	welcome.recent_forgotten.connect(forget_recent)
	welcome.new_empty_chosen.connect(new_empty)
	welcome.new_from_template_chosen.connect(new_from_template)
	welcome.open_file_chosen.connect(open)
	welcome.restore_chosen.connect(answer_restore.bind(&"restore"))
	welcome.restore_ignored.connect(answer_restore.bind(&"ignore"))
	if not quit_action.is_valid():
		quit_action = get_tree().quit
	_build_dialogs()
	store.dirty_changed.connect(_on_state_changed.unbind(1))
	store.path_changed.connect(_on_state_changed.unbind(1))
	_on_state_changed()


## At launch: shows the welcome page (with the restore card when unsaved work
## was found). The autosave starts watching once a project is chosen.
func startup() -> void:
	_has_project = false
	show_welcome()


## Shows the project selection page over the current project.
func show_welcome() -> void:
	var restore_name := ""
	if not _has_project and autosave.has_pending():
		var source := autosave.pending_source_path()
		restore_name = source.get_file() if source != "" else UNTITLED
	welcome.present(settings.recent_projects, restore_name, _has_project)


func build_menu() -> MenuBar:
	var bar := MenuBar.new()
	bar.name = "MenuBar"
	var menu := PopupMenu.new()
	menu.name = "Fichier"
	menu.add_item("Accueil…", MenuId.WELCOME)
	menu.add_separator()
	menu.add_item("Nouveau (vide)", MenuId.NEW_EMPTY)
	menu.add_item("Nouveau depuis le log 16", MenuId.NEW_FROM_TEMPLATE)
	menu.add_separator()
	menu.add_item("Ouvrir…", MenuId.OPEN)
	menu.add_separator()
	menu.add_item("Enregistrer", MenuId.SAVE)
	menu.add_item("Enregistrer sous…", MenuId.SAVE_AS)
	menu.id_pressed.connect(on_menu)
	bar.add_child(menu)
	return bar


func on_menu(id: int) -> void:
	match id:
		MenuId.WELCOME:
			show_welcome()
		MenuId.NEW_EMPTY:
			new_empty()
		MenuId.NEW_FROM_TEMPLATE:
			new_from_template()
		MenuId.OPEN:
			open()
		MenuId.SAVE:
			save()
		MenuId.SAVE_AS:
			save_as()


func new_empty() -> void:
	_confirm_discard(func() -> void:
		store.new_project()
		_project_ready())


func new_from_template() -> void:
	_confirm_discard(func() -> void:
		if _report("Ouverture impossible", store.load_from_file(template_path, true)):
			_project_ready())


func open() -> void:
	_confirm_discard(func() -> void: path_picker.call(FileDialog.FILE_MODE_OPEN_FILE, _open_path))


func open_recent(path: String) -> void:
	_confirm_discard(_open_path.bind(path))


func forget_recent(path: String) -> void:
	settings.forget_project(path)
	_save_settings()
	show_welcome()


func save() -> void:
	_save_then(Callable())


func save_as() -> void:
	path_picker.call(FileDialog.FILE_MODE_SAVE_FILE, _save_to)


func request_quit() -> void:
	_confirm_discard(func() -> void:
		autosave.clear()
		quit_action.call())


func title_text() -> String:
	var file: String = store.current_path.get_file() if store.current_path != "" else UNTITLED
	return "%s%s — %s" % [file, " *" if store.is_dirty() else "", APP_NAME]


func is_confirming() -> bool:
	return _confirm.visible


func is_offering_restore() -> bool:
	return welcome.visible and welcome.find_child("Restore", true, false) != null


## The text of the last error shown, "" if none is showing.
func shown_error() -> String:
	return _error.dialog_text if _error.visible else ""


## Answers the "save changes?" question: &"save", &"discard" or &"cancel".
func answer_confirmation(choice: StringName) -> void:
	_confirm.hide()
	var then := _after_confirm
	_after_confirm = Callable()
	match choice:
		&"save":
			_save_then(then)
		&"discard":
			# The copy stays until a replacement succeeds: opening can still fail.
			then.call()


## Answers the restore card of the welcome page: &"restore" or &"ignore".
func answer_restore(choice: StringName) -> void:
	if choice == &"restore":
		if _report("Restauration impossible", autosave.restore_into(store)):
			_project_ready()
			return
	autosave.clear()
	show_welcome()


func _open_path(path: String) -> void:
	if _report("Ouverture impossible", store.load_from_file(path)):
		_remember(path)
		_project_ready()


## A project is open: close the welcome page and start the autosave.
func _project_ready() -> void:
	_has_project = true
	welcome.close()
	autosave.start(store)


## Saves to the current file, or asks for one; then runs `then` on success.
func _save_then(then: Callable) -> void:
	if store.current_path != "":
		if _save_to(store.current_path) and then.is_valid():
			then.call()
		return
	path_picker.call(FileDialog.FILE_MODE_SAVE_FILE, func(path: String) -> void:
		if _save_to(path) and then.is_valid():
			then.call())


func _save_to(path: String) -> bool:
	if path.get_extension().to_lower() != EXTENSION:
		path += "." + EXTENSION
	var errors: PackedStringArray = store.save_to_file(path)
	if not errors.is_empty():
		errors.append(UNSAVED_HINT)
		_report("Enregistrement impossible", errors)
		return false
	_remember(path)
	return true


## Runs `then` now if nothing would be lost, otherwise asks first.
func _confirm_discard(then: Callable) -> void:
	if not store.is_dirty():
		then.call()
		return
	_after_confirm = then
	var file: String = store.current_path.get_file() if store.current_path != "" else UNTITLED
	_confirm.dialog_text = "Enregistrer les modifications de « %s » ?" % file
	_confirm.popup_centered()


## Shows the errors, if any. Returns true when there were none.
func _report(title: String, errors: PackedStringArray) -> bool:
	if errors.is_empty():
		return true
	_error.title = title
	_error.dialog_text = "\n".join(errors)
	_error.popup_centered()
	return false


func _remember(path: String) -> void:
	settings.remember_project(path)
	_save_settings()


func _save_settings() -> void:
	var error := settings.save_to(settings_path)
	if error != OK:
		push_warning("Préférences non enregistrées (%s) : %s" % [settings_path, error_string(error)])


func _on_state_changed() -> void:
	if is_inside_tree():
		get_window().title = title_text()


func _pick_with_dialog(mode: FileDialog.FileMode, done: Callable) -> void:
	_file_dialog.file_mode = mode
	_file_dialog.title = "Ouvrir un projet" if mode == FileDialog.FILE_MODE_OPEN_FILE else "Enregistrer le projet"
	var folder: String = store.current_path.get_base_dir() if store.current_path.begins_with("/") else ""
	_file_dialog.current_dir = folder if folder != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_file_dialog.current_file = store.current_path.get_file() if store.current_path != "" else "appartement.json"
	for connection in _file_dialog.file_selected.get_connections():
		_file_dialog.file_selected.disconnect(connection.callable)
	_file_dialog.file_selected.connect(done, CONNECT_ONE_SHOT)
	_file_dialog.popup_centered_ratio(0.6)


func _build_dialogs() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.name = "ConfirmDiscard"
	_confirm.title = APP_NAME
	_confirm.ok_button_text = "Enregistrer"
	_confirm.cancel_button_text = "Annuler"
	_confirm.add_button("Ne pas enregistrer", true, "discard")
	_confirm.confirmed.connect(answer_confirmation.bind(&"save"))
	_confirm.canceled.connect(answer_confirmation.bind(&"cancel"))
	_confirm.custom_action.connect(func(_action: StringName) -> void: answer_confirmation(&"discard"))
	add_child(_confirm)
	_error = AcceptDialog.new()
	_error.name = "Error"
	add_child(_error)
	_file_dialog = FileDialog.new()
	_file_dialog.name = "FileDialog"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray([FILE_FILTER])
	add_child(_file_dialog)
