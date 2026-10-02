extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const LOOKING_NORTH := Vector2(0, -1)
const SLIGHTLY_ROTATED := Vector2(0.1, -1.0)
const CUTAWAY_HALF := WorldView.CUTAWAY_TWEEN_SECONDS / 2.0
const TWEEN_WAIT := WorldView.CUTAWAY_TWEEN_SECONDS + 0.15

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


func test_full_mode_raises_walls_lowered_in_auto() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3, "lowered in AUTO")
	_view.cycle_cutaway_mode()
	assert_eq(_view.cutaway_mode, Cutaway.Mode.FULL)
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_eq(_scale_y("w3"), 1.0)


func test_all_lowered_mode_also_lowers_walls_left_up_in_auto() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_eq(_scale_y("w1"), 1.0, "up in AUTO")
	_view.cycle_cutaway_mode()
	_view.cycle_cutaway_mode()
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	for id in ["w1", "w2", "w3", "w4"]:
		assert_almost_eq(_scale_y(id), 0.08, 1e-3, id)


func test_unchanged_heading_starts_no_tween() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	assert_gt(get_tree().get_processed_tweens().size(), 0, "control: a change tweens")
	await wait_seconds(TWEEN_WAIT)
	_view.update_cutaway(LOOKING_NORTH)
	assert_eq(get_tree().get_processed_tweens().size(), 0)


func test_heading_change_keeping_same_walls_lowered_starts_no_tween() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	_view.update_cutaway(SLIGHTLY_ROTATED)
	assert_eq(get_tree().get_processed_tweens().size(), 0)


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


func test_quick_reversal_ends_at_last_requested_scale() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(CUTAWAY_HALF)
	var first: Tween = _view._tweens["w3"]
	_view.cycle_cutaway_mode()
	_view.update_cutaway(LOOKING_NORTH)
	assert_false(first.is_valid(), "previous tween is killed")
	await wait_seconds(TWEEN_WAIT)
	assert_eq(_scale_y("w3"), 1.0)


func test_suspended_cutaway_raises_every_wall_and_ignores_headings() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3)
	_view.set_cutaway_suspended(true)
	_view.update_cutaway(Vector2(0, 1))
	await wait_seconds(TWEEN_WAIT)
	for id in ["w1", "w2", "w3", "w4"]:
		assert_eq(_scale_y(id), 1.0, id)


func test_resuming_recomputes_the_cutaway() -> void:
	_view.set_cutaway_suspended(true)
	_view.set_cutaway_suspended(false)
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3)


func test_refresh_rebuilds_from_the_given_project() -> void:
	var moved := Fixtures.square_room()
	moved.get_plan_node("n3").pos = Vector2(5, 5)
	_view.refresh(moved)
	await wait_physics_frames(1)
	assert_eq(_view.get_node("Walls").get_child_count(), 4)
	var body := _view.get_node("Walls/w2/Body") as CSGPolygon3D
	var reaches_new_corner := false
	for p in body.polygon:
		reaches_new_corner = reaches_new_corner or p.distance_to(Vector2(5, 5)) < 0.3
	assert_true(reaches_new_corner, "w2 follows n3: %s" % [body.polygon])


func test_refresh_keeps_lowered_walls_lowered_without_a_tween() -> void:
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	_view.refresh(Fixtures.square_room())
	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3, "still lowered right away")
	assert_eq(_scale_y("w1"), 1.0)
	_view.update_cutaway(LOOKING_NORTH)
	assert_eq(get_tree().get_processed_tweens().size(), 0, "nothing left to animate")
	await wait_physics_frames(1)


func test_wall_display_height_follows_the_cutaway() -> void:
	assert_almost_eq(_view.wall_display_height("w3"), 2.5, 1e-3)
	_view.update_cutaway(LOOKING_NORTH)
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(_view.wall_display_height("w3"), 0.2, 1e-3)
	assert_eq(_view.wall_display_height("nope"), 0.0)


func test_highlighted_wall_survives_a_refresh_and_can_be_cleared() -> void:
	_view.highlight_wall("w2")
	var body := _view.get_node("Walls/w2/Body") as CSGPolygon3D
	assert_not_null(body.material_override)
	_view.refresh(Fixtures.square_room())
	assert_not_null((_view.get_node("Walls/w2/Body") as CSGPolygon3D).material_override, "kept after a rebuild")
	_view.highlight_wall("")
	assert_null((_view.get_node("Walls/w2/Body") as CSGPolygon3D).material_override)
	assert_eq(_view.highlighted_wall(), "")
	await wait_physics_frames(1)
