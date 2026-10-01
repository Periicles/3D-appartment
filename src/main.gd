extends Node3D
## Application root: lighting, camera, the 3D view of the open project, the
## furniture tool and the side panels.

const DEFAULT_PROJECT := "res://data/log16.json"
const SUN_ROTATION_DEG := Vector3(-50, -40, 0)
const SUN_COLOR := Color("#ffe6c7")
const SUN_ENERGY := 1.6
const SKY_TOP := Color("#c9dcef")
const SKY_HORIZON := Color("#f6e7da")
const AMBIENT_ENERGY := 0.35

var _view: WorldView
var _camera: OrbitCamera
var _furniture: FurnitureView
var _tool: FurnitureTool


func _ready() -> void:
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
	add_child(_ui())
	ProjectStore.project_loaded.connect(_on_project_loaded)
	var errors := ProjectStore.load_from_file(DEFAULT_PROJECT)
	if not errors.is_empty():
		push_error("Chargement du plan impossible : %s" % "; ".join(errors))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_view.cycle_cutaway_mode()


func _on_project_loaded() -> void:
	_view.show_project(ProjectStore.project)
	_camera.frame_project(ProjectStore.project)


func _ui() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var catalog := CatalogPanel.new()
	catalog.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	catalog.populate(FurnitureCatalog.load_presets())
	catalog.preset_chosen.connect(_tool.begin_placement)
	root.add_child(catalog)
	var properties := PropertiesPanel.new()
	properties.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	properties.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	properties.bind_store(ProjectStore)
	_tool.selection_changed.connect(properties.show_item)
	root.add_child(properties)
	return layer


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
	env.glow_intensity = 0.3
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
	sun.shadow_blur = 2.0
	return sun
