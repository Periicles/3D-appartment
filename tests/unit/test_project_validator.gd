extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func _assert_single_error(project: ProjectData, expected_fragment: String) -> void:
	var errors := ProjectValidator.validate(project)
	assert_eq(errors.size(), 1, "errors: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], expected_fragment)


func test_fixture_is_valid() -> void:
	assert_eq(ProjectValidator.validate(Fixtures.square_room()), PackedStringArray())


func test_empty_project_is_valid() -> void:
	assert_eq(ProjectValidator.validate(ProjectData.new()), PackedStringArray())


func test_rejects_non_positive_wall_height() -> void:
	var project := Fixtures.square_room()
	project.wall_height = 0.0
	_assert_single_error(project, "hauteur des murs")


func test_rejects_non_positive_underlay_scale() -> void:
	var project := Fixtures.square_room()
	project.underlay.meters_per_px = 0.0
	_assert_single_error(project, "calque")


func test_rejects_duplicate_ids() -> void:
	var project := Fixtures.square_room()
	project.furniture.append(Fixtures.sofa("f1"))
	_assert_single_error(project, "meuble « f1 » : identifiant en double")


func test_rejects_wall_with_unknown_node() -> void:
	var project := Fixtures.square_room()
	project.get_wall("w2").b = "n9"
	_assert_single_error(project, "mur « w2 » : nœud inconnu « n9 »")


func test_rejects_wall_joining_node_to_itself() -> void:
	var project := Fixtures.square_room()
	project.walls.append(Fixtures.wall("w5", "n1", "n1"))
	_assert_single_error(project, "relie un nœud à lui-même")


func test_rejects_non_positive_wall_thickness() -> void:
	var project := Fixtures.square_room()
	project.get_wall("w1").thickness = -0.1
	_assert_single_error(project, "épaisseur")


func test_rejects_opening_on_unknown_wall() -> void:
	var project := Fixtures.square_room()
	project.openings[0].wall_id = "w9"
	_assert_single_error(project, "mur inconnu « w9 »")


func test_rejects_opening_past_wall_end() -> void:
	var project := Fixtures.square_room()
	project.openings[0].offset = 3.8
	_assert_single_error(project, "dépasse du mur « w1 »")


func test_rejects_opening_before_wall_start() -> void:
	var project := Fixtures.square_room()
	project.openings[0].offset = 0.3
	_assert_single_error(project, "dépasse du mur")


func test_accepts_openings_flush_with_wall_ends_despite_float_noise() -> void:
	var project := Fixtures.square_room()
	project.openings[0].offset = 0.4 - 1e-9
	project.openings.append(Fixtures.door("o2", "w1", 3.6 + 1e-9, 0.8))
	assert_eq(ProjectValidator.validate(project), PackedStringArray())


func test_rejects_unknown_opening_kind() -> void:
	var project := Fixtures.square_room()
	project.openings[0].kind = "hatch"
	_assert_single_error(project, "type inconnu « hatch »")


func test_rejects_unknown_swing() -> void:
	var project := Fixtures.square_room()
	project.openings[0].swing = "up"
	_assert_single_error(project, "sens d'ouverture")


func test_rejects_negative_sill() -> void:
	var project := Fixtures.square_room()
	project.openings[0].sill = -0.5
	_assert_single_error(project, "allège")


func test_rejects_room_with_fewer_than_three_nodes() -> void:
	var project := Fixtures.square_room()
	project.rooms[0].node_ids = PackedStringArray(["n1", "n2"])
	_assert_single_error(project, "au moins 3 nœuds")


func test_rejects_room_with_unknown_node() -> void:
	var project := Fixtures.square_room()
	project.rooms[0].node_ids[3] = "n9"
	_assert_single_error(project, "pièce « r1 » : nœud inconnu « n9 »")


func test_rejects_unknown_floor_kind() -> void:
	var project := Fixtures.square_room()
	project.rooms[0].floor_kind = "marble"
	_assert_single_error(project, "type de sol inconnu")


func test_rejects_furniture_with_zero_dimension() -> void:
	var project := Fixtures.square_room()
	project.furniture[0].size.y = 0.0
	_assert_single_error(project, "meuble « f1 » : les dimensions")


func test_rejects_ids_that_are_not_plain_names() -> void:
	for bad in ["", "a b", "f/1", "x:y", "Ghost preview", "é1"]:
		var project := Fixtures.square_room()
		project.furniture[0].id = bad
		var errors := ProjectValidator.validate(project)
		assert_eq(errors.size(), 1, "%s → %s" % [bad, errors])
		if errors.size() == 1:
			assert_string_contains(errors[0], "identifiant invalide")


func test_accepts_plain_ids() -> void:
	var project := Fixtures.square_room()
	project.furniture[0].id = "Sofa_2-b"
	assert_eq(ProjectValidator.validate(project), PackedStringArray())
