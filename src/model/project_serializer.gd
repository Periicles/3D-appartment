class_name ProjectSerializer
extends RefCounted
## Converts projects to and from the JSON project file format (see docs/specs/2026-09-30-v1-design.md, §4).
## Migrations between schema versions will be added here when schema version 2 exists.

const SCHEMA_VERSION := 1
const _INDENT := "\t"
## Alpha is not part of the file format, so only plain #rrggbb is accepted.
const _COLOR_PATTERN := "^#[0-9a-fA-F]{6}$"


static func to_json(project: ProjectData) -> String:
	return JSON.stringify(_project_to_dict(project), _INDENT, false)


static func from_json(text: String) -> ProjectLoadResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return ProjectLoadResult.failure(PackedStringArray([
			"JSON invalide (ligne %d) : %s" % [json.get_error_line() + 1, json.get_error_message()],
		]))
	if typeof(json.data) != TYPE_DICTIONARY:
		return ProjectLoadResult.failure(PackedStringArray(["le fichier doit contenir un objet JSON"]))
	return _project_from_dict(json.data)


static func _project_to_dict(project: ProjectData) -> Dictionary:
	var underlay = null
	if project.underlay != null:
		underlay = {
			"image": project.underlay.image,
			"meters_per_px": project.underlay.meters_per_px,
			"offset": [project.underlay.offset.x, project.underlay.offset.y],
		}
	return {
		"schema_version": SCHEMA_VERSION,
		"name": project.name,
		"wall_height": project.wall_height,
		"north_angle": project.north_angle,
		"underlay": underlay,
		"nodes": project.nodes.map(func(n: PlanNode) -> Dictionary:
			return {"id": n.id, "x": n.pos.x, "z": n.pos.y}),
		"walls": project.walls.map(func(w: Wall) -> Dictionary:
			return {"id": w.id, "a": w.a, "b": w.b, "thickness": w.thickness, "height": w.height}),
		"openings": project.openings.map(func(o: Opening) -> Dictionary:
			return {
				"id": o.id, "wall": o.wall_id, "type": o.kind, "offset": o.offset, "width": o.width,
				"height": o.height, "sill": o.sill, "swing": o.swing,
			}),
		"rooms": project.rooms.map(func(r: Room) -> Dictionary:
			return {"id": r.id, "name": r.name, "nodes": Array(r.node_ids), "floor": r.floor_kind}),
		"furniture": project.furniture.map(func(f: FurnitureItem) -> Dictionary:
			return {
				"id": f.id,
				"preset": f.preset if f.preset != "" else null,
				"glb": f.glb if f.glb != "" else null,
				"name": f.name,
				"size": [f.size.x, f.size.z, f.size.y],
				"color": "#" + f.color.to_html(false),
				"pos": [f.pos.x, f.pos.y],
				"rot": f.rotation_deg,
			}),
	}


static func _project_from_dict(data: Dictionary) -> ProjectLoadResult:
	var version = data.get("schema_version")
	if not _is_number(version):
		return ProjectLoadResult.failure(PackedStringArray(["« schema_version » manquant ou invalide"]))
	if not is_equal_approx(version, floorf(version)):
		return ProjectLoadResult.failure(PackedStringArray(["« schema_version » invalide : %s" % version]))
	if int(version) > SCHEMA_VERSION:
		return ProjectLoadResult.failure(PackedStringArray([
			"fichier créé par une version plus récente (schéma %d, supporté : %d)" % [int(version), SCHEMA_VERSION],
		]))
	if int(version) < 1:
		return ProjectLoadResult.failure(PackedStringArray(["« schema_version » invalide : %s" % version]))

	var r := _Reader.new()
	var project := ProjectData.new()
	project.name = r.text(data, "name", "projet")
	project.wall_height = r.number(data, "wall_height", "projet", ProjectData.DEFAULT_WALL_HEIGHT)
	project.north_angle = r.number(data, "north_angle", "projet", 0.0)
	if data.get("underlay") != null:
		if typeof(data["underlay"]) != TYPE_DICTIONARY:
			r.object(data, "underlay", "projet")
		else:
			var raw: Dictionary = data["underlay"]
			var underlay := Underlay.new()
			underlay.image = r.text(raw, "image", "underlay")
			underlay.meters_per_px = r.number(raw, "meters_per_px", "underlay")
			underlay.offset = r.vector2(raw, "offset", "underlay")
			project.underlay = underlay

	r.each_object(data, "nodes", func(entry: Dictionary, ctx: String) -> void:
		var node := PlanNode.new()
		node.id = r.text(entry, "id", ctx)
		node.pos = Vector2(r.number(entry, "x", ctx), r.number(entry, "z", ctx))
		project.nodes.append(node))

	r.each_object(data, "walls", func(entry: Dictionary, ctx: String) -> void:
		var wall := Wall.new()
		wall.id = r.text(entry, "id", ctx)
		wall.a = r.text(entry, "a", ctx)
		wall.b = r.text(entry, "b", ctx)
		wall.thickness = r.number(entry, "thickness", ctx)
		wall.height = r.number(entry, "height", ctx, project.wall_height)
		project.walls.append(wall))

	r.each_object(data, "openings", func(entry: Dictionary, ctx: String) -> void:
		var opening := Opening.new()
		opening.id = r.text(entry, "id", ctx)
		opening.wall_id = r.text(entry, "wall", ctx)
		opening.kind = r.text(entry, "type", ctx)
		opening.offset = r.number(entry, "offset", ctx)
		opening.width = r.number(entry, "width", ctx)
		opening.height = r.number(entry, "height", ctx)
		opening.sill = r.number(entry, "sill", ctx, 0.0)
		opening.swing = r.text(entry, "swing", ctx, "none")
		project.openings.append(opening))

	r.each_object(data, "rooms", func(entry: Dictionary, ctx: String) -> void:
		var room := Room.new()
		room.id = r.text(entry, "id", ctx)
		room.name = r.text(entry, "name", ctx)
		room.node_ids = r.texts(entry, "nodes", ctx)
		room.floor_kind = r.text(entry, "floor", ctx, "wood")
		project.rooms.append(room))

	r.each_object(data, "furniture", func(entry: Dictionary, ctx: String) -> void:
		var item := FurnitureItem.new()
		item.id = r.text(entry, "id", ctx)
		item.preset = r.optional_text(entry, "preset", ctx)
		item.glb = r.optional_text(entry, "glb", ctx)
		item.name = r.text(entry, "name", ctx)
		var size := r.numbers(entry, "size", ctx, 3)
		item.size = Vector3(size[0], size[2], size[1])
		item.color = r.color(entry, "color", ctx)
		item.pos = r.vector2(entry, "pos", ctx)
		item.rotation_deg = r.number(entry, "rot", ctx, 0.0)
		project.furniture.append(item))

	if not r.errors.is_empty():
		return ProjectLoadResult.failure(r.errors)
	var invariant_errors := ProjectValidator.validate(project)
	if not invariant_errors.is_empty():
		return ProjectLoadResult.failure(invariant_errors)
	return ProjectLoadResult.success(project)


static var _color_regex := _compile_color_regex()


static func _compile_color_regex() -> RegEx:
	var regex := RegEx.new()
	regex.compile(_COLOR_PATTERN)
	return regex


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


## Type-checked field access that collects errors instead of failing on the first one.
class _Reader:
	var errors := PackedStringArray()

	## `fallback` is used when the key is absent; null makes the key required.
	func number(data: Dictionary, key: String, ctx: String, fallback: Variant = null) -> float:
		var value = data.get(key, fallback)
		if ProjectSerializer._is_number(value):
			return float(value)
		_fail(ctx, key, "doit être un nombre")
		return 0.0

	func text(data: Dictionary, key: String, ctx: String, fallback: Variant = null) -> String:
		var value = data.get(key, fallback)
		if typeof(value) == TYPE_STRING:
			return value
		_fail(ctx, key, "doit être une chaîne")
		return ""

	## Absent or null reads as "".
	func optional_text(data: Dictionary, key: String, ctx: String) -> String:
		var value = data.get(key)
		if value == null:
			return ""
		if typeof(value) == TYPE_STRING:
			return value
		_fail(ctx, key, "doit être une chaîne ou null")
		return ""

	func texts(data: Dictionary, key: String, ctx: String) -> PackedStringArray:
		var value = data.get(key)
		if typeof(value) != TYPE_ARRAY or not value.all(func(v): return typeof(v) == TYPE_STRING):
			_fail(ctx, key, "doit être une liste de chaînes")
			return PackedStringArray()
		return PackedStringArray(value)

	func numbers(data: Dictionary, key: String, ctx: String, count: int) -> PackedFloat64Array:
		var value = data.get(key)
		if typeof(value) != TYPE_ARRAY or value.size() != count or not value.all(ProjectSerializer._is_number):
			_fail(ctx, key, "doit être une liste de %d nombres" % count)
			var zeros := PackedFloat64Array()
			zeros.resize(count)
			return zeros
		return PackedFloat64Array(value)

	func vector2(data: Dictionary, key: String, ctx: String) -> Vector2:
		var values := numbers(data, key, ctx, 2)
		return Vector2(values[0], values[1])

	func color(data: Dictionary, key: String, ctx: String) -> Color:
		var value = data.get(key)
		if typeof(value) == TYPE_STRING and ProjectSerializer._color_regex.search(value) != null:
			return Color.html(value)
		_fail(ctx, key, "doit être une couleur hexadécimale (#rrggbb)")
		return Color.WHITE

	func object(data: Dictionary, key: String, ctx: String) -> Dictionary:
		var value = data.get(key)
		if typeof(value) == TYPE_DICTIONARY:
			return value
		_fail(ctx, key, "doit être un objet")
		return {}

	## Visits each object of a top-level list with its location (e.g. "nodes[2]") built from the
	## original index; absent reads as an empty list and non-object entries are reported, not visited.
	func each_object(data: Dictionary, key: String, visit: Callable) -> void:
		var value = data.get(key, [])
		if typeof(value) != TYPE_ARRAY:
			_fail("projet", key, "doit être une liste")
			return
		for i in value.size():
			var ctx := "%s[%d]" % [key, i]
			if typeof(value[i]) == TYPE_DICTIONARY:
				visit.call(value[i], ctx)
			else:
				errors.append("%s : doit être un objet" % ctx)

	func _fail(ctx: String, key: String, expectation: String) -> void:
		errors.append("%s : « %s » %s" % [ctx, key, expectation])
