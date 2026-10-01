extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3

var _view: UnderlayView


func before_each() -> void:
	_view = UnderlayView.new()
	add_child_autofree(_view)


func _log16() -> ProjectData:
	return ProjectSerializer.from_json(FileAccess.get_file_as_string("res://data/log16.json")).project


func test_bundled_plan_is_found_for_the_template() -> void:
	assert_true(_view.show_project(_log16(), ""))
	assert_true(_view.has_image())


func test_quad_matches_the_scaled_image_and_offset() -> void:
	var project := _log16()
	_view.show_project(project, "")
	var plane := _view.mesh as PlaneMesh
	var texture := (_view.material_override as StandardMaterial3D).albedo_texture
	var expected := Vector2(texture.get_width(), texture.get_height()) * project.underlay.meters_per_px
	assert_almost_eq(plane.size, expected, Vector2(EPS, EPS))
	var top_left := Vector2(_view.position.x, _view.position.z) - plane.size / 2.0
	assert_almost_eq(top_left, project.underlay.offset, Vector2(EPS, EPS))


func test_visible_only_in_plan_view_and_when_enabled() -> void:
	_view.show_project(_log16(), "")
	assert_false(_view.visible)
	_view.set_plan_view(true)
	assert_true(_view.visible)
	_view.toggle()
	assert_false(_view.visible)
	_view.toggle()
	assert_true(_view.visible)
	_view.set_plan_view(false)
	assert_false(_view.visible)


func test_project_without_underlay_shows_nothing() -> void:
	var project := Fixtures.square_room()
	project.underlay = null
	assert_false(_view.show_project(project, ""))
	_view.set_plan_view(true)
	assert_false(_view.visible)


func test_missing_image_shows_nothing() -> void:
	var project := Fixtures.square_room()
	project.underlay.image = "nope.png"
	assert_false(_view.show_project(project, "/tmp/somewhere/project.json"))


func test_image_next_to_a_saved_project_is_used() -> void:
	var dir := ProjectSettings.globalize_path("user://test_underlay")
	DirAccess.make_dir_recursive_absolute(dir)
	var image := Image.create(20, 10, false, Image.FORMAT_RGB8)
	image.save_png(dir.path_join("mine.png"))
	var project := Fixtures.square_room()
	project.underlay.image = "mine.png"
	assert_true(_view.show_project(project, dir.path_join("project.json")))
	assert_almost_eq((_view.mesh as PlaneMesh).size, Vector2(20, 10) * project.underlay.meters_per_px, Vector2(EPS, EPS))
	DirAccess.remove_absolute(dir.path_join("mine.png"))
