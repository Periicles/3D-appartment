class_name Room
extends RefCounted
## A named floor area bounded by graph nodes.

const FLOOR_KINDS: PackedStringArray = ["wood", "tile", "outdoor"]

var id: String
var name: String
## Polygon of graph node ids, in order.
var node_ids: PackedStringArray
var floor_kind: String
