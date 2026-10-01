class_name ProjectData
extends RefCounted
## In-memory project: wall graph, openings, rooms and furniture. Units are meters.

const DEFAULT_WALL_HEIGHT := 2.5

var name: String = ""
var wall_height: float = DEFAULT_WALL_HEIGHT
## Reserved for the v2 sun simulation, in degrees.
var north_angle: float = 0.0
var underlay: Underlay = null
var nodes: Array[PlanNode] = []
var walls: Array[Wall] = []
var openings: Array[Opening] = []
var rooms: Array[Room] = []
var furniture: Array[FurnitureItem] = []


func get_plan_node(id: String) -> PlanNode:
	for node in nodes:
		if node.id == id:
			return node
	return null


func get_wall(id: String) -> Wall:
	for wall in walls:
		if wall.id == id:
			return wall
	return null


## The wall joining two nodes, in either direction, or null.
func find_wall_between(node_a: String, node_b: String) -> Wall:
	for wall in walls:
		if (wall.a == node_a and wall.b == node_b) or (wall.a == node_b and wall.b == node_a):
			return wall
	return null


## Returns -1.0 when either endpoint is missing from the graph.
func wall_length(wall: Wall) -> float:
	var a := get_plan_node(wall.a)
	var b := get_plan_node(wall.b)
	if a == null or b == null:
		return -1.0
	return a.pos.distance_to(b.pos)
