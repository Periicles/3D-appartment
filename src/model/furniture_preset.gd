class_name FurniturePreset
extends Resource
## A catalogue entry: a parametric block with default dimensions and colour.

@export var id := ""
@export var name := ""
## One of FurnitureCatalog.CATEGORIES.
@export var category := ""
## Metres: x = width, y = height, z = depth (same convention as FurnitureItem.size).
@export var size := Vector3.ONE
@export var color := Color.WHITE


## A new project item made from this preset, centred at `pos` with no rotation.
func make_item(item_id: String, pos: Vector2) -> FurnitureItem:
	var item := FurnitureItem.new()
	item.id = item_id
	item.preset = id
	item.glb = ""
	item.name = name
	item.size = size
	item.color = color
	item.pos = pos
	item.rotation_deg = 0.0
	return item
