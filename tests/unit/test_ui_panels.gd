extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4
const OFF_STEP_SIZE := Vector3(2.1, 0.853, 0.9047)  # finer than the SpinBox steps

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())


func test_catalog_has_a_button_per_preset_and_category_headers() -> void:
	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
	var presets := FurnitureCatalog.load_presets()
	panel.populate(presets)
	for preset in presets:
		assert_not_null(panel.button_for(preset.id), preset.id)
	var labels := panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	for category in FurnitureCatalog.CATEGORIES:
		assert_has(labels, category)


func test_catalog_button_emits_its_preset() -> void:
	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
	panel.populate(FurnitureCatalog.load_presets())
	watch_signals(panel)
	panel.button_for("bed_160").pressed.emit()
	assert_signal_emitted(panel, "preset_chosen")
	var preset: FurniturePreset = get_signal_parameters(panel, "preset_chosen")[0]
	assert_eq(preset.id, "bed_160")


func test_catalog_tooltip_shows_dimensions_in_cm() -> void:
	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
	panel.populate(FurnitureCatalog.load_presets())
	assert_eq(panel.button_for("sofa_3").tooltip_text, "210 × 90 × 85 cm")


func _properties() -> PropertiesPanel:
	var panel: PropertiesPanel = add_child_autofree(PropertiesPanel.new())
	panel.bind_store(_store)
	_store.add_furniture(Fixtures.sofa("f1"))
	return panel


func test_properties_hidden_without_selection() -> void:
	var panel := _properties()
	assert_false(panel.visible)
	panel.show_item("f1")
	assert_true(panel.visible)
	panel.show_item("")
	assert_false(panel.visible)
	panel.show_item("unknown")
	assert_false(panel.visible)


func test_properties_show_item_values_without_editing() -> void:
	var panel := _properties()
	panel.show_item("f1")
	assert_eq((panel.find_child("Name", true, false) as LineEdit).text, "Canapé")
	assert_almost_eq((panel.find_child("Width", true, false) as SpinBox).value, 210.0, EPS)
	assert_almost_eq((panel.find_child("Depth", true, false) as SpinBox).value, 90.0, EPS)
	assert_almost_eq((panel.find_child("Height", true, false) as SpinBox).value, 85.0, EPS)
	assert_almost_eq((panel.find_child("Rotation", true, false) as SpinBox).value, 90.0, EPS)
	_store.undo()  # only the add is in the history
	assert_null(_store.get_furniture("f1"))


func test_editing_width_updates_the_store_in_metres() -> void:
	var panel := _properties()
	panel.show_item("f1")
	(panel.find_child("Width", true, false) as SpinBox).value = 180.0
	assert_almost_eq(_store.get_furniture("f1").size.x, 1.8, EPS)
	assert_almost_eq(_store.get_furniture("f1").size.z, 0.9, EPS, "depth untouched")


func test_editing_position_and_rotation_updates_the_store() -> void:
	var panel := _properties()
	panel.show_item("f1")
	(panel.find_child("X", true, false) as SpinBox).value = 1.25
	(panel.find_child("Rotation", true, false) as SpinBox).value = 45.0
	assert_almost_eq(_store.get_furniture("f1").pos, Vector2(1.25, 3), Vector2(EPS, EPS))
	assert_almost_eq(_store.get_furniture("f1").rotation_deg, 45.0, EPS)


func test_renaming_on_submit() -> void:
	var panel := _properties()
	panel.show_item("f1")
	var field := panel.find_child("Name", true, false) as LineEdit
	field.text = "  Canapé du salon "
	field.text_submitted.emit(field.text)
	assert_eq(_store.get_furniture("f1").name, "Canapé du salon")


func test_blank_name_is_ignored() -> void:
	var panel := _properties()
	panel.show_item("f1")
	var field := panel.find_child("Name", true, false) as LineEdit
	field.text = "   "
	field.text_submitted.emit(field.text)
	assert_eq(_store.get_furniture("f1").name, "Canapé")


func test_panel_refreshes_when_item_changes_elsewhere() -> void:
	var panel := _properties()
	panel.show_item("f1")
	_store.update_furniture("f1", {"pos": Vector2(0.5, 0.75)})
	assert_almost_eq((panel.find_child("Z", true, false) as SpinBox).value, 0.75, EPS)


func test_refresh_does_not_create_extra_history() -> void:
	var panel := _properties()
	panel.show_item("f1")
	_store.update_furniture("f1", {"rotation_deg": 10.0})
	_store.undo()
	_store.undo()
	assert_null(_store.get_furniture("f1"), "two steps: add and rotate")


func _off_step_properties() -> PropertiesPanel:
	var panel := _properties()
	var item: FurnitureItem = _store.get_furniture("f1")
	item.pos = Vector2(2.003, 3.0047)
	item.size = OFF_STEP_SIZE
	panel.show_item("f1")
	return panel


func test_editing_x_keeps_the_exact_z() -> void:
	var panel := _off_step_properties()
	(panel.find_child("X", true, false) as SpinBox).value = 1.5
	assert_eq(_store.get_furniture("f1").pos, Vector2(1.5, 3.0047))


func test_editing_z_keeps_the_exact_x() -> void:
	var panel := _off_step_properties()
	(panel.find_child("Z", true, false) as SpinBox).value = 1.5
	assert_eq(_store.get_furniture("f1").pos, Vector2(2.003, 1.5))


func test_editing_width_keeps_the_exact_height_and_depth() -> void:
	var panel := _off_step_properties()
	(panel.find_child("Width", true, false) as SpinBox).value = 180.0
	var size: Vector3 = _store.get_furniture("f1").size
	assert_almost_eq(size.x, 1.8, EPS)
	assert_eq(size.y, OFF_STEP_SIZE.y)
	assert_eq(size.z, OFF_STEP_SIZE.z)


func test_editing_height_and_depth_keep_the_other_components() -> void:
	var panel := _off_step_properties()
	(panel.find_child("Height", true, false) as SpinBox).value = 90.0
	(panel.find_child("Depth", true, false) as SpinBox).value = 80.0
	var size: Vector3 = _store.get_furniture("f1").size
	assert_eq(size.x, OFF_STEP_SIZE.x)
	assert_almost_eq(size.y, 0.9, EPS)
	assert_almost_eq(size.z, 0.8, EPS)


func test_properties_hint_comes_from_the_shortcut_list() -> void:
	var panel := _properties()
	var texts := panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(texts, Shortcuts.furniture_hint())


func test_properties_form_scrolls_when_the_window_is_short() -> void:
	var panel := _properties()
	var scroll := panel.get_child(0) as ScrollContainer
	assert_not_null(scroll)
	assert_not_null(scroll.find_child("Width", true, false))


func test_side_panels_are_padded() -> void:
	var catalog: CatalogPanel = add_child_autofree(CatalogPanel.new())
	var properties := _properties()
	for panel in [catalog, properties]:
		assert_gt((panel as PanelContainer).get_theme_stylebox("panel").content_margin_left, 0.0)
