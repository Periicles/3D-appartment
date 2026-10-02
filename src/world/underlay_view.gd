class_name UnderlayView
extends MeshInstance3D
## The architect's plan image laid on the floor, scaled by the project's
## `underlay`, to check the modelled walls. Shown only in plan view, when the
## user has it switched on (P).

const HEIGHT := 0.01
const OPACITY := 0.6
## Bundled plans are found here when the image is not next to the project file.
const BUNDLED_DIR := "res://data"

var enabled := true
var _plan_view := false
var _has_image := false


func _init() -> void:
	name = "Underlay"
	visible = false


## Loads the project's underlay image, looked up next to the project file and
## then among the bundled plans. Returns false when there is none to show.
func show_project(project: ProjectData, project_path: String) -> bool:
	_has_image = false
	mesh = null
	if project.underlay != null:
		var texture := _load_texture(project.underlay.image, project_path)
		if texture != null:
			_build(project.underlay, texture)
			_has_image = true
	_refresh()
	return _has_image


func set_plan_view(plan_view: bool) -> void:
	_plan_view = plan_view
	_refresh()


func toggle() -> void:
	enabled = not enabled
	_refresh()


func has_image() -> bool:
	return _has_image


func _refresh() -> void:
	visible = enabled and _plan_view and _has_image


func _build(underlay: Underlay, texture: Texture2D) -> void:
	var size := Vector2(texture.get_width(), texture.get_height()) * underlay.meters_per_px
	var plane := PlaneMesh.new()
	plane.size = size
	mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = Color(1, 1, 1, OPACITY)
	material_override = material
	# PlaneMesh is centred; the underlay offset is the image's top-left corner.
	position = Vector3(underlay.offset.x + size.x / 2.0, HEIGHT, underlay.offset.y + size.y / 2.0)


static func _load_texture(image: String, project_path: String) -> Texture2D:
	var candidates := PackedStringArray()
	# Only the file name counts: a hand-edited project must not make the app
	# read images outside its own folder ("../x.png", absolute paths).
	var file_name := image.get_file()
	if file_name == "":
		return null
	if project_path != "":
		candidates.append(project_path.get_base_dir().path_join(file_name))
	candidates.append(BUNDLED_DIR.path_join(file_name))
	for path in candidates:
		if path.begins_with("res://"):
			var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
			if texture != null:
				return texture
		elif FileAccess.file_exists(path):
			var loaded := Image.load_from_file(path)
			if loaded == null:
				push_warning("Calque illisible : %s" % path)
				continue
			return ImageTexture.create_from_image(loaded)
	return null
