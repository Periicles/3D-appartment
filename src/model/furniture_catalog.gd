class_name FurnitureCatalog
extends RefCounted
## Loads the furniture presets shipped as .tres files.

const PRESETS_DIR := "res://data/presets"
## Display order of the catalogue sections.
const CATEGORIES: PackedStringArray = ["Salon", "Chambre", "Cuisine et repas", "Rangement", "Extérieur"]


## Every preset in `dir`, ordered by category (CATEGORIES order) then name.
## Files that are not FurniturePreset resources are skipped.
static func load_presets(dir: String = PRESETS_DIR) -> Array[FurniturePreset]:
	var presets: Array[FurniturePreset] = []
	for file in ResourceLoader.list_directory(dir):
		if not file.ends_with(".tres"):
			continue
		var preset := load(dir.path_join(file)) as FurniturePreset
		if preset != null:
			presets.append(preset)
	presets.sort_custom(_before)
	return presets


static func _before(a: FurniturePreset, b: FurniturePreset) -> bool:
	var rank_a := _rank(a.category)
	var rank_b := _rank(b.category)
	if rank_a != rank_b:
		return rank_a < rank_b
	return a.name.naturalnocasecmp_to(b.name) < 0


static func _rank(category: String) -> int:
	var index := CATEGORIES.find(category)
	return index if index >= 0 else CATEGORIES.size()
