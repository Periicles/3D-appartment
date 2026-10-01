class_name CollapsibleSide
extends Control
## Full-height host that slides a side panel in and out of the window. When the
## panel is hidden, a small tab stays on the window edge to bring it back.

enum Side { LEFT, RIGHT }

const SLIDE_SECONDS := 0.2
const TAB_TOP_MARGIN := 8.0

var _content: Control
var _side: CollapsibleSide.Side = Side.LEFT
var _open := true
var _tab: Button
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(content: Control, side: CollapsibleSide.Side, title: String) -> void:
	_content = content
	_side = side
	content.set_anchors_preset(Control.PRESET_LEFT_WIDE if side == Side.LEFT else Control.PRESET_RIGHT_WIDE)
	# The content's width is only final once its theme applies (fonts), so
	# re-place it whenever its minimum size changes.
	content.minimum_size_changed.connect(_on_content_resized)
	add_child(content)
	_tab = Button.new()
	_tab.name = "Tab"
	_tab.text = ("▸ %s" if side == Side.LEFT else "%s ◂") % title
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.pressed.connect(set_open.bind(true))
	_tab.set_anchors_preset(Control.PRESET_TOP_LEFT if side == Side.LEFT else Control.PRESET_TOP_RIGHT)
	_tab.grow_horizontal = Control.GROW_DIRECTION_END if side == Side.LEFT else Control.GROW_DIRECTION_BEGIN
	_tab.position.y = TAB_TOP_MARGIN
	add_child(_tab)
	_apply(_offsets(true))
	_tab.visible = false


func is_open() -> bool:
	return _open


func tab() -> Button:
	return _tab


func toggle() -> void:
	set_open(not _open)


func set_open(open: bool, animate: bool = true) -> void:
	_open = open
	if _tween:
		_tween.kill()
	if not open:
		_release_focus_inside()
	_tab.visible = not open
	var target := _offsets(open)
	if not animate or not is_inside_tree():
		_apply(target)
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_content, "offset_left", target.x, SLIDE_SECONDS)
	_tween.tween_property(_content, "offset_right", target.y, SLIDE_SECONDS)


## (offset_left, offset_right) of the content for the given state.
func _offsets(open: bool) -> Vector2:
	var width := _content.get_combined_minimum_size().x
	if _side == Side.LEFT:
		return Vector2(0, width) if open else Vector2(-width, 0)
	return Vector2(-width, 0) if open else Vector2(0, width)


func _apply(offsets: Vector2) -> void:
	_content.offset_left = offsets.x
	_content.offset_right = offsets.y


func _on_content_resized() -> void:
	if _tween == null or not _tween.is_running():
		_apply(_offsets(_open))


func _release_focus_inside() -> void:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner != null and _content.is_ancestor_of(owner):
		owner.release_focus()
