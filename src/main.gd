extends Node3D
## Application root: lighting, camera, the 3D view of the open project, the
## furniture tool, the collapsible side panels, the shortcuts help and the
## File menu (with autosave).

const SUN_ROTATION_DEG := Vector3(-50, -40, 0)
const SUN_COLOR := Color("#ffe6c7")
const SUN_ENERGY := 1.6
const SKY_TOP := Color("#c9dcef")
const SKY_HORIZON := Color("#f6e7da")
const AMBIENT_ENERGY := 0.35
const GLOW_INTENSITY := 0.1
const SHADOW_BLUR := 0.6
const SHADOW_MAX_DISTANCE := 40.0
const HELP_BUTTON_MARGIN := 12.0
const HELP_BUTTON_SIZE := 36.0

## Where preferences and the autosave are kept; tests point them elsewhere.
var settings_path := UiSettings.DEFAULT_PATH
var autosave_project_path := Autosave.PROJECT_PATH
var autosave_meta_path := Autosave.META_PATH

var _view: WorldView
var _camera: OrbitCamera
var _furniture: FurnitureView
var _tool: FurnitureTool
var _settings: UiSettings
var _ui_root: Control
var _catalog_side: CollapsibleSide
var _inspector_side: CollapsibleSide
var _help: ShortcutsOverlay
var _autosave: Autosave
var _files: FileController
var _welcome: WelcomeScreen


func _ready() -> void:
	_settings = UiSettings.load_from(settings_path)
	# Closing the window asks first when there are unsaved changes.
	get_tree().auto_accept_quit = false
	add_child(_environment())
	add_child(_sun())
	_view = WorldView.new()
	_view.name = "World"
	add_child(_view)
	_furniture = FurnitureView.new()
	_furniture.name = "Furniture"
	add_child(_furniture)
	_camera = OrbitCamera.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.heading_changed.connect(_view.update_cutaway)
	# Added after the camera: Godot delivers unhandled input to later siblings
	# first, so the tool can claim clicks and Shift + wheel before the camera.
	_tool = FurnitureTool.new()
	_tool.name = "FurnitureTool"
	add_child(_tool)
	_furniture.bind_store(ProjectStore)
	_tool.setup(ProjectStore, _furniture, _camera)
	_autosave = Autosave.new()
	_autosave.project_path = autosave_project_path
	_autosave.meta_path = autosave_meta_path
	add_child(_autosave)
	_files = FileController.new()
	add_child(_files)
	_welcome = WelcomeScreen.new()
	_files.setup(ProjectStore, _autosave, _settings, settings_path, _welcome)
	add_child(_ui())
	_apply_ui_scale()
	get_viewport().size_changed.connect(_apply_ui_scale)
	ProjectStore.project_loaded.connect(_on_project_loaded)
	_files.startup()


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _files != null:
		_files.request_quit()


func _unhandled_key_input(event: InputEvent) -> void:
	match Shortcuts.action_for(event as InputEventKey):
		&"cutaway":
			_view.cycle_cutaway_mode()
		&"toggle_catalog":
			_catalog_side.toggle()
		&"toggle_inspector":
			_inspector_side.toggle()
		&"help":
			_help.toggle()
		&"welcome":
			_files.show_welcome()
		&"open":
			_files.open()
		&"save":
			_files.save()
		&"save_as":
			_files.save_as()
		&"zoom_in":
			_change_zoom(_settings.zoom_in)
		&"zoom_out":
			_change_zoom(_settings.zoom_out)
		&"zoom_reset":
			_change_zoom(_settings.reset_zoom)
		_:
			return
	get_viewport().set_input_as_handled()


func _change_zoom(step: Callable) -> void:
	step.call()
	_apply_ui_scale()
	var error := _settings.save_to(settings_path)
	if error != OK:
		push_warning("Préférences non enregistrées (%s) : %s" % [settings_path, error_string(error)])


## Current interface scale: the screen's backing scale (2 on Retina) times the
## user zoom, so panels keep the size of other apps whatever resolution macOS uses.
func ui_scale() -> float:
	return _settings.ui_scale(DisplayServer.screen_get_scale())


## Scales the 2D interface through the window's content scale, so Godot lays it
## out at the scaled size and rasterises fonts at full resolution (sharp text).
## The 3D view is rendered at the window's native resolution either way.
func _apply_ui_scale() -> void:
	get_window().content_scale_factor = ui_scale()
	_ui_root.size = get_viewport().get_visible_rect().size


func _on_project_loaded() -> void:
	_view.show_project(ProjectStore.project)
	_camera.frame_project(ProjectStore.project)


func _ui() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	_ui_root = Control.new()
	_ui_root.name = "Root"
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui_root)
	var catalog := CatalogPanel.new()
	catalog.populate(FurnitureCatalog.load_presets())
	catalog.preset_chosen.connect(_tool.begin_placement)
	_catalog_side = CollapsibleSide.new()
	_catalog_side.name = "CatalogSide"
	_catalog_side.setup(catalog, CollapsibleSide.Side.LEFT, "Catalogue")
	_ui_root.add_child(_catalog_side)
	var properties := PropertiesPanel.new()
	properties.bind_store(ProjectStore)
	_tool.selection_changed.connect(properties.show_item)
	_inspector_side = CollapsibleSide.new()
	_inspector_side.name = "InspectorSide"
	_inspector_side.setup(properties, CollapsibleSide.Side.RIGHT, "Inspecteur")
	_ui_root.add_child(_inspector_side)
	_ui_root.add_child(_help_button())
	_ui_root.add_child(_menu_bar())
	_ui_root.add_child(_welcome)
	_help = ShortcutsOverlay.new()
	_help.build()
	_ui_root.add_child(_help)
	return layer


## On macOS the File menu goes to the system menu bar; elsewhere it sits at the top centre.
func _menu_bar() -> MenuBar:
	var bar := _files.build_menu()
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	return bar


func _help_button() -> Button:
	var button := Button.new()
	button.name = "HelpButton"
	button.text = "?"
	button.tooltip_text = "Raccourcis (? ou F1)"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(HELP_BUTTON_SIZE, HELP_BUTTON_SIZE)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -HELP_BUTTON_MARGIN - HELP_BUTTON_SIZE
	button.offset_top = -HELP_BUTTON_MARGIN - HELP_BUTTON_SIZE
	button.offset_right = -HELP_BUTTON_MARGIN
	button.offset_bottom = -HELP_BUTTON_MARGIN
	button.pressed.connect(func() -> void: _help.open())
	return button


func _environment() -> WorldEnvironment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = SKY_HORIZON
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.7
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	return world_env


func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.shadow_blur = SHADOW_BLUR
	# The flat fits in ~15 m: keep the shadow map on it for crisp edges.
	sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE
	return sun
