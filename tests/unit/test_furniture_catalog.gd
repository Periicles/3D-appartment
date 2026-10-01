extends GutTest


func test_loads_every_shipped_preset() -> void:
	assert_eq(FurnitureCatalog.load_presets().size(), 15)


func test_presets_are_ordered_by_category() -> void:
	var ranks: Array[int] = []
	for preset in FurnitureCatalog.load_presets():
		ranks.append(FurnitureCatalog.CATEGORIES.find(preset.category))
	var sorted := ranks.duplicate()
	sorted.sort()
	assert_eq(ranks, sorted)


func test_every_preset_is_usable() -> void:
	var ids := {}
	for preset in FurnitureCatalog.load_presets():
		assert_false(preset.id.is_empty(), preset.resource_path)
		assert_false(ids.has(preset.id), "duplicate id %s" % preset.id)
		ids[preset.id] = true
		assert_true(preset.category in FurnitureCatalog.CATEGORIES, preset.id)
		assert_true(preset.size.x > 0 and preset.size.y > 0 and preset.size.z > 0, preset.id)


func test_spec_presets_are_present() -> void:
	var ids := FurnitureCatalog.load_presets().map(func(p: FurniturePreset) -> String: return p.id)
	for id in ["sofa_2", "sofa_3", "armchair", "coffee_table", "bed_90", "bed_140", "bed_160",
			"wardrobe", "nightstand", "dining_table", "chair", "shelf", "dresser", "garden_set", "planter"]:
		assert_has(ids, id)


func test_missing_directory_gives_empty_catalogue() -> void:
	assert_eq(FurnitureCatalog.load_presets("res://does/not/exist").size(), 0)


func test_make_item_copies_preset_defaults() -> void:
	var preset: FurniturePreset = load("res://data/presets/sofa_3.tres")
	var item := preset.make_item("f9", Vector2(1, 2))
	assert_eq(item.id, "f9")
	assert_eq(item.preset, "sofa_3")
	assert_eq(item.name, "Canapé 3 places")
	assert_eq(item.size, preset.size)
	assert_eq(item.color, preset.color)
	assert_eq(item.pos, Vector2(1, 2))
	assert_eq(item.rotation_deg, 0.0)
	assert_true(ProjectValidator.validate(_project_with(item)).is_empty())


func test_furniture_item_copy_is_independent() -> void:
	var original: FurnitureItem = load("res://data/presets/bed_160.tres").make_item("f1", Vector2.ZERO)
	var clone := original.copy()
	clone.size.x = 9.0
	clone.name = "Autre"
	assert_almost_eq(original.size.x, 1.6, 1e-6)
	assert_eq(original.name, "Lit 160")
	assert_eq(clone.id, "f1")


func _project_with(item: FurnitureItem) -> ProjectData:
	var project := ProjectData.new()
	project.furniture.append(item)
	return project
