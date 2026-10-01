extends GutTest

const CENTER := Vector2(0, 0)
# Camera south of the apartment, looking north (towards -z).
const LOOKING_NORTH := Vector2(0, -1)


func test_wall_between_camera_and_center_facing_camera_is_lowered() -> void:
	assert_true(Cutaway.is_lowered(Vector2(-2, 3), Vector2(2, 3), CENTER, LOOKING_NORTH))


func test_wall_behind_center_stays_up() -> void:
	assert_false(Cutaway.is_lowered(Vector2(-2, -3), Vector2(2, -3), CENTER, LOOKING_NORTH))


func test_side_wall_parallel_to_view_stays_up() -> void:
	assert_false(Cutaway.is_lowered(Vector2(3, -2), Vector2(3, 2), CENTER, LOOKING_NORTH))


func test_wall_direction_does_not_matter() -> void:
	assert_true(Cutaway.is_lowered(Vector2(2, 3), Vector2(-2, 3), CENTER, LOOKING_NORTH))


func test_slanted_wall_within_sixty_degrees_is_lowered() -> void:
	# Normal at 45 degrees from the camera direction.
	assert_true(Cutaway.is_lowered(Vector2(0, 4), Vector2(4, 0), CENTER, LOOKING_NORTH))


func test_slanted_wall_beyond_sixty_degrees_stays_up() -> void:
	# Normal at about 70 degrees from the camera direction.
	assert_false(Cutaway.is_lowered(Vector2(2, 0.5), Vector2(3, 3.25), CENTER, LOOKING_NORTH))


func test_target_scale_per_mode() -> void:
	assert_eq(Cutaway.target_scale(Cutaway.Mode.FULL, true, 2.5), 1.0)
	assert_almost_eq(Cutaway.target_scale(Cutaway.Mode.ALL_LOWERED, false, 2.5), 0.08, 1e-6)
	assert_almost_eq(Cutaway.target_scale(Cutaway.Mode.AUTO, true, 2.5), 0.08, 1e-6)
	assert_eq(Cutaway.target_scale(Cutaway.Mode.AUTO, false, 2.5), 1.0)


func test_low_walls_are_never_raised_above_their_height() -> void:
	assert_eq(Cutaway.target_scale(Cutaway.Mode.ALL_LOWERED, false, 0.1), 1.0)
	assert_almost_eq(Cutaway.target_scale(Cutaway.Mode.ALL_LOWERED, false, 1.0), 0.2, 1e-6)


func test_zero_height_wall_keeps_unit_scale() -> void:
	assert_eq(Cutaway.target_scale(Cutaway.Mode.ALL_LOWERED, true, 0.0), 1.0)


func test_apartment_center_is_bounding_box_center() -> void:
	var project := preload("res://tests/fixtures/project_fixtures.gd").square_room()
	assert_eq(Cutaway.apartment_center(project), Vector2(2, 2))
