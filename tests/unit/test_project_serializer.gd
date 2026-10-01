extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func _load(data: Dictionary) -> ProjectLoadResult:
	return ProjectSerializer.from_json(JSON.stringify(data))


func _assert_rejected(result: ProjectLoadResult, expected_fragment: String) -> void:
	assert_false(result.is_ok(), "should be rejected")
	assert_null(result.project)
	assert_string_contains("\n".join(result.errors), expected_fragment)


func test_loads_hand_written_fixture() -> void:
	var result := _load(Fixtures.square_room_dict())
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	var project := result.project
	assert_eq(project.name, "Séjour test")
	assert_eq(project.nodes.size(), 4)
	assert_eq(project.get_plan_node("n2").pos, Vector2(4, 0))
	assert_eq(project.get_wall("w1").thickness, 0.2)
	assert_eq(project.openings[0].kind, "door")
	assert_eq(project.rooms[0].node_ids, PackedStringArray(["n1", "n2", "n3", "n4"]))
	assert_eq(project.rooms[0].floor_kind, "wood")
	assert_eq(project.underlay.meters_per_px, 0.01)


func test_wall_height_defaults_to_project_wall_height() -> void:
	var data := Fixtures.square_room_dict()
	data["wall_height"] = 2.7
	assert_almost_eq(_load(data).project.get_wall("w1").height, 2.7, 1e-6)


func test_furniture_size_is_width_depth_height_in_file() -> void:
	var sofa := _load(Fixtures.square_room_dict()).project.furniture[0]
	assert_almost_eq(sofa.size.x, 2.1, 1e-6, "width")
	assert_almost_eq(sofa.size.z, 0.9, 1e-6, "depth")
	assert_almost_eq(sofa.size.y, 0.85, 1e-6, "height")


func test_furniture_null_glb_reads_as_empty_string() -> void:
	var sofa := _load(Fixtures.square_room_dict()).project.furniture[0]
	assert_eq(sofa.glb, "")
	assert_eq(sofa.preset, "sofa_3")
	assert_eq(sofa.color, Color.html("#c9a88a"))
	assert_eq(sofa.rotation_deg, 90.0)


func test_round_trip_is_lossless() -> void:
	var json := ProjectSerializer.to_json(Fixtures.square_room())
	var reloaded := ProjectSerializer.from_json(json)
	assert_true(reloaded.is_ok(), "errors: %s" % [reloaded.errors])
	assert_eq(ProjectSerializer.to_json(reloaded.project), json)


func test_round_trip_keeps_non_ascii_names() -> void:
	var project := Fixtures.square_room()
	project.furniture[0].name = "Fauteuil « Élise »"
	var reloaded := ProjectSerializer.from_json(ProjectSerializer.to_json(project)).project
	assert_eq(reloaded.furniture[0].name, "Fauteuil « Élise »")


func test_round_trip_keeps_missing_underlay_and_empty_preset() -> void:
	var project := Fixtures.square_room()
	project.underlay = null
	project.furniture[0].preset = ""
	var reloaded := ProjectSerializer.from_json(ProjectSerializer.to_json(project)).project
	assert_null(reloaded.underlay)
	assert_eq(reloaded.furniture[0].preset, "")


func test_empty_project_round_trips() -> void:
	var reloaded := ProjectSerializer.from_json(ProjectSerializer.to_json(ProjectData.new()))
	assert_true(reloaded.is_ok(), "errors: %s" % [reloaded.errors])
	assert_eq(reloaded.project.walls.size(), 0)


func test_missing_collections_read_as_empty() -> void:
	var result := _load({"schema_version": 1, "name": "Vide"})
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	assert_eq(result.project.furniture.size(), 0)


func test_integer_numbers_are_accepted() -> void:
	var result := ProjectSerializer.from_json('{"schema_version": 1, "name": "x", "wall_height": 3}')
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	assert_eq(result.project.wall_height, 3.0)


func test_rejects_malformed_json_with_line_number() -> void:
	_assert_rejected(ProjectSerializer.from_json('{\n"name": "x",\n oops}'), "ligne 3")


func test_rejects_non_object_root() -> void:
	_assert_rejected(ProjectSerializer.from_json("[1, 2]"), "objet JSON")


func test_rejects_missing_schema_version() -> void:
	var data := Fixtures.square_room_dict()
	data.erase("schema_version")
	_assert_rejected(_load(data), "schema_version")


func test_rejects_newer_schema_version() -> void:
	var data := Fixtures.square_room_dict()
	data["schema_version"] = 2
	_assert_rejected(_load(data), "version plus récente")


func test_rejects_schema_version_zero() -> void:
	var data := Fixtures.square_room_dict()
	data["schema_version"] = 0
	_assert_rejected(_load(data), "schema_version")


func test_rejects_wrong_field_type_with_location() -> void:
	var data := Fixtures.square_room_dict()
	data["walls"][1]["thickness"] = "épais"
	_assert_rejected(_load(data), "walls[1] : « thickness » doit être un nombre")


func test_rejects_missing_required_field() -> void:
	var data := Fixtures.square_room_dict()
	data["nodes"][0].erase("x")
	_assert_rejected(_load(data), "nodes[0] : « x »")


func test_rejects_collection_that_is_not_a_list() -> void:
	var data := Fixtures.square_room_dict()
	data["walls"] = {"w1": {}}
	_assert_rejected(_load(data), "« walls » doit être une liste")


func test_rejects_list_entry_that_is_not_an_object() -> void:
	var data := Fixtures.square_room_dict()
	data["nodes"].append("n5")
	_assert_rejected(_load(data), "nodes[4] : doit être un objet")


func test_errors_keep_original_index_after_a_non_object_entry() -> void:
	var data := Fixtures.square_room_dict()
	data["nodes"].insert(1, "oops")
	data["nodes"][2].erase("x")
	var result := _load(data)
	assert_false(result.is_ok(), "should be rejected")
	assert_string_contains("\n".join(result.errors), "nodes[1] : doit être un objet")
	assert_string_contains("\n".join(result.errors), "nodes[2] : « x »")


func test_rejects_bad_vector_length() -> void:
	var data := Fixtures.square_room_dict()
	data["furniture"][0]["size"] = [2.1, 0.9]
	_assert_rejected(_load(data), "furniture[0] : « size » doit être une liste de 3 nombres")


func test_rejects_invalid_color() -> void:
	var data := Fixtures.square_room_dict()
	data["furniture"][0]["color"] = "beige"
	_assert_rejected(_load(data), "« color »")


func test_reports_every_type_error_at_once() -> void:
	var data := Fixtures.square_room_dict()
	data["walls"][0]["thickness"] = "x"
	data["nodes"][1]["z"] = null
	var result := _load(data)
	assert_eq(result.errors.size(), 2, "errors: %s" % [result.errors])


func test_rejects_invariant_violations() -> void:
	var data := Fixtures.square_room_dict()
	data["openings"][0]["offset"] = 3.9
	_assert_rejected(_load(data), "dépasse du mur")
