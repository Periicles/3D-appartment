extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const LOOKING_NORTH := Vector2(0, -1)
const TWEEN_WAIT := 0.4

var _view: WorldView


func before_each() -> void:
	_view = WorldView.new()
	add_child_autofree(_view)
	_view.show_project(Fixtures.square_room())


func _scale_y(wall_id: String) -> float:
	return (_view.get_node("Walls/%s" % wall_id) as Node3D).scale.y


func test_builds_walls_and_floors() -> void:
	assert_not_null(_view.get_node_or_null("Walls"))
	assert_not_null(_view.get_node_or_null("Floors"))


func test_show_project_replaces_previous_content() -> void:
	_view.show_project(Fixtures.square_room())
	await wait_physics_frames(1)
	assert_eq(_view.get_child_count(), 2)


func test_auto_mode_lowers_walls_facing_camera() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3, "south wall, in front of the camera")
	assert_eq(_scale_y("w1"), 1.0, "north wall, behind the center")


func test_full_mode_keeps_every_wall_up() -> void:
	_view.cycle_cutaway_mode()
	assert_eq(_view.cutaway_mode, Cutaway.Mode.FULL)
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_eq(_scale_y("w3"), 1.0)


func test_all_lowered_mode_lowers_every_wall() -> void:
	_view.cycle_cutaway_mode()
	_view.cycle_cutaway_mode()
	assert_eq(_view.cutaway_mode, Cutaway.Mode.ALL_LOWERED)
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	for id in ["w1", "w2", "w3", "w4"]:
		assert_almost_eq(_scale_y(id), 0.08, 1e-3, id)


func test_mode_cycle_wraps_back_to_auto() -> void:
	for i in Cutaway.Mode.size():
		_view.cycle_cutaway_mode()
	assert_eq(_view.cutaway_mode, Cutaway.Mode.AUTO)


func test_update_before_any_project_is_harmless() -> void:
	var empty: WorldView = add_child_autofree(WorldView.new())
	empty.update_cutaway(LOOKING_NORTH)
	assert_eq(empty.get_child_count(), 0)
