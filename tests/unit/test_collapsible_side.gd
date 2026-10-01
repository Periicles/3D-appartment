extends GutTest

const EPS := 0.5
const WAIT := CollapsibleSide.SLIDE_SECONDS + 0.15

var _content: PanelContainer


func _host(side: CollapsibleSide.Side) -> CollapsibleSide:
	_content = PanelContainer.new()
	_content.custom_minimum_size.x = 200
	var host: CollapsibleSide = add_child_autofree(CollapsibleSide.new())
	host.setup(_content, side, "Catalogue")
	return host


func test_starts_open_with_content_on_screen_and_tab_hidden() -> void:
	var host := _host(CollapsibleSide.Side.LEFT)
	assert_true(host.is_open())
	assert_almost_eq(_content.offset_left, 0.0, EPS)
	assert_almost_eq(_content.offset_right, 200.0, EPS)
	assert_false(host.tab().visible)


func test_closing_left_slides_content_off_screen_and_shows_tab() -> void:
	var host := _host(CollapsibleSide.Side.LEFT)
	host.toggle()
	assert_false(host.is_open())
	await wait_seconds(WAIT)
	assert_almost_eq(_content.offset_right, 0.0, EPS)
	assert_true(host.tab().visible)


func test_closing_right_slides_content_off_screen() -> void:
	var host := _host(CollapsibleSide.Side.RIGHT)
	host.set_open(false, false)
	assert_almost_eq(_content.offset_left, 0.0, EPS)
	assert_almost_eq(_content.offset_right, 200.0, EPS)


func test_tab_reopens_the_panel() -> void:
	var host := _host(CollapsibleSide.Side.RIGHT)
	host.set_open(false, false)
	host.tab().pressed.emit()
	assert_true(host.is_open())
	await wait_seconds(WAIT)
	assert_almost_eq(_content.offset_left, -200.0, EPS)
	assert_false(host.tab().visible)


func test_tab_label_points_towards_the_panel() -> void:
	assert_string_contains(_host(CollapsibleSide.Side.LEFT).tab().text, "Catalogue")
	assert_true(_host(CollapsibleSide.Side.LEFT).tab().text.begins_with("▸"))
	assert_true(_host(CollapsibleSide.Side.RIGHT).tab().text.ends_with("◂"))


func test_closing_releases_focus_held_inside_the_panel() -> void:
	var host := _host(CollapsibleSide.Side.LEFT)
	var field := LineEdit.new()
	_content.add_child(field)
	field.grab_focus()
	assert_true(field.has_focus())
	host.set_open(false, false)
	assert_false(field.has_focus())


func test_host_lets_clicks_through_outside_the_panel() -> void:
	assert_eq(_host(CollapsibleSide.Side.LEFT).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_fast_toggles_end_in_the_last_state() -> void:
	var host := _host(CollapsibleSide.Side.LEFT)
	host.toggle()
	host.toggle()
	await wait_seconds(WAIT)
	assert_true(host.is_open())
	assert_almost_eq(_content.offset_left, 0.0, EPS)


func test_offsets_follow_content_that_grows_after_setup() -> void:
	var host := _host(CollapsibleSide.Side.LEFT)
	_content.custom_minimum_size.x = 300
	await wait_physics_frames(1)
	assert_almost_eq(_content.offset_left, 0.0, EPS)
	assert_almost_eq(_content.offset_right, 300.0, EPS)
	host.set_open(false, false)
	assert_almost_eq(_content.offset_left, -300.0, EPS)
