class_name ClearanceView
extends Node3D
## Live clearances around the focused piece of furniture: one dimension line
## per side that meets a wall or another item.

var _lines := {}  # side -> DimensionLine
var _store: Node


func _init() -> void:
	name = "Clearances"
	for side in Clearance.SIDES:
		var line := DimensionLine.new()
		line.name = side.capitalize()
		line.visible = false
		add_child(line)
		_lines[side] = line


## Shows the free space around a footprint, ignoring the item `ignore_id`.
func show_for(project: ProjectData, ignore_id: String, pos: Vector2, size: Vector3, rotation_deg: float) -> void:
	var distances := Clearance.free_distances(pos, size, rotation_deg, Clearance.obstacles_for(project, ignore_id))
	for side in Clearance.SIDES:
		var line: DimensionLine = _lines[side]
		if distances.has(side) and distances[side].distance > 0.0:
			line.set_points(distances[side].from, distances[side].to)
		else:
			line.visible = false


## Follows a FurnitureTool's focus, measuring against the store's project.
## Bound methods, so the connections end with this node.
func bind(tool: FurnitureTool, store: Node) -> void:
	_store = store
	tool.focus_changed.connect(_on_focus_changed)
	tool.focus_cleared.connect(clear)


func _on_focus_changed(ignore_id: String, pos: Vector2, size: Vector3, rotation_deg: float) -> void:
	show_for(_store.project, ignore_id, pos, size, rotation_deg)


func clear() -> void:
	for line in _lines.values():
		line.visible = false


func visible_sides() -> PackedStringArray:
	var sides := PackedStringArray()
	for side in Clearance.SIDES:
		if (_lines[side] as DimensionLine).visible:
			sides.append(side)
	return sides


func line(side: String) -> DimensionLine:
	return _lines[side]
