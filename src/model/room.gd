class_name Room
extends RefCounted
## A named floor area bounded by graph nodes.

const FLOOR_KINDS: PackedStringArray = ["wood", "tile", "outdoor"]

var id: String
var name: String
## Polygon of graph node ids, in order.
var node_ids: PackedStringArray
var floor_kind: String


func copy() -> Room:
	var other := Room.new()
	other.id = id
	other.name = name
	other.node_ids = node_ids.duplicate()
	other.floor_kind = floor_kind
	return other
