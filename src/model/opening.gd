class_name Opening
extends RefCounted
## A door or window cut into a wall.

const KINDS: PackedStringArray = ["door", "window", "sliding_door"]
const SWINGS: PackedStringArray = ["left", "right", "none"]

var id: String
var wall_id: String
var kind: String
## Distance from the wall's start node to the opening's center, in meters.
var offset: float
var width: float
var height: float
## Height of the opening's bottom edge above the floor; 0 for doors.
var sill: float
var swing: String
