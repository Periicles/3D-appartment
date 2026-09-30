extends RefCounted
## Shared test data: a 4 m x 4 m room with one door, one sofa and a plan underlay.


static func square_room() -> ProjectData:
	var project := ProjectData.new()
	project.name = "Séjour test"
	project.nodes.assign([
		plan_node("n1", 0, 0),
		plan_node("n2", 4, 0),
		plan_node("n3", 4, 4),
		plan_node("n4", 0, 4),
	])
	project.walls.assign([
		wall("w1", "n1", "n2"),
		wall("w2", "n2", "n3"),
		wall("w3", "n3", "n4"),
		wall("w4", "n4", "n1"),
	])
	project.openings.assign([door("o1", "w1", 1.0, 0.8)])
	project.rooms.assign([room("r1", ["n1", "n2", "n3", "n4"])])
	project.furniture.assign([sofa("f1")])
	var underlay := Underlay.new()
	underlay.image = "log16_plan.png"
	underlay.meters_per_px = 0.01
	underlay.offset = Vector2.ZERO
	project.underlay = underlay
	return project


## The JSON form of square_room(), as written by hand in a project file.
static func square_room_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"name": "Séjour test",
		"wall_height": 2.5,
		"north_angle": 0,
		"underlay": {"image": "log16_plan.png", "meters_per_px": 0.01, "offset": [0, 0]},
		"nodes": [
			{"id": "n1", "x": 0, "z": 0},
			{"id": "n2", "x": 4, "z": 0},
			{"id": "n3", "x": 4, "z": 4},
			{"id": "n4", "x": 0, "z": 4},
		],
		"walls": [
			{"id": "w1", "a": "n1", "b": "n2", "thickness": 0.2},
			{"id": "w2", "a": "n2", "b": "n3", "thickness": 0.2},
			{"id": "w3", "a": "n3", "b": "n4", "thickness": 0.2},
			{"id": "w4", "a": "n4", "b": "n1", "thickness": 0.2},
		],
		"openings": [
			{
				"id": "o1", "wall": "w1", "type": "door", "offset": 1.0, "width": 0.8,
				"height": 2.04, "sill": 0, "swing": "left",
			},
		],
		"rooms": [{"id": "r1", "name": "Séjour", "nodes": ["n1", "n2", "n3", "n4"], "floor": "wood"}],
		"furniture": [
			{
				"id": "f1", "preset": "sofa_3", "glb": null, "name": "Canapé",
				"size": [2.1, 0.9, 0.85], "color": "#c9a88a", "pos": [2.0, 3.0], "rot": 90,
			},
		],
	}


static func plan_node(id: String, x: float, z: float) -> PlanNode:
	var node := PlanNode.new()
	node.id = id
	node.pos = Vector2(x, z)
	return node


static func wall(id: String, a: String, b: String) -> Wall:
	var w := Wall.new()
	w.id = id
	w.a = a
	w.b = b
	w.thickness = 0.2
	w.height = ProjectData.DEFAULT_WALL_HEIGHT
	return w


static func door(id: String, wall_id: String, offset: float, width: float) -> Opening:
	var opening := Opening.new()
	opening.id = id
	opening.wall_id = wall_id
	opening.kind = "door"
	opening.offset = offset
	opening.width = width
	opening.height = 2.04
	opening.sill = 0.0
	opening.swing = "left"
	return opening


static func room(id: String, node_ids: PackedStringArray) -> Room:
	var r := Room.new()
	r.id = id
	r.name = "Séjour"
	r.node_ids = node_ids
	r.floor_kind = "wood"
	return r


static func sofa(id: String) -> FurnitureItem:
	var item := FurnitureItem.new()
	item.id = id
	item.preset = "sofa_3"
	item.glb = ""
	item.name = "Canapé"
	item.size = Vector3(2.1, 0.85, 0.9)
	item.color = Color.html("#c9a88a")
	item.pos = Vector2(2.0, 3.0)
	item.rotation_deg = 90.0
	return item
