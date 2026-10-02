class_name PlanNode
extends RefCounted
## A corner of the wall graph.

var id: String
## Position on the floor plane in meters: x = east, y = south (world z).
var pos: Vector2


func copy() -> PlanNode:
	var other := PlanNode.new()
	other.id = id
	other.pos = pos
	return other
