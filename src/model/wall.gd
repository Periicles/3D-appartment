class_name Wall
extends RefCounted
## A straight wall between two graph nodes.

var id: String
## Id of the start node.
var a: String
## Id of the end node.
var b: String
var thickness: float
var height: float


func copy() -> Wall:
	var other := Wall.new()
	other.id = id
	other.a = a
	other.b = b
	other.thickness = thickness
	other.height = height
	return other
