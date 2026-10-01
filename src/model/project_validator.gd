class_name ProjectValidator
extends RefCounted
## Checks the invariants a loaded or edited project must satisfy.
## Messages are shown to the user as-is, so they are in French.

## Ids name scene nodes, so they must stay plain: letters, digits, "_" and "-".
const ID_PATTERN := "^[A-Za-z0-9_-]+$"

static var _id_regex := RegEx.create_from_string(ID_PATTERN)

## Tolerance for float noise when an opening sits exactly at a wall end.
const LENGTH_EPSILON := 1e-4


## Returns one message per violated invariant; empty when the project is valid.
static func validate(project: ProjectData) -> PackedStringArray:
	var errors := PackedStringArray()
	if project.wall_height <= 0.0:
		errors.append("projet : la hauteur des murs doit être positive")
	if project.underlay != null and project.underlay.meters_per_px <= 0.0:
		errors.append("calque : l'échelle doit être positive")
	_check_unique_ids("nœud", project.nodes, errors)
	_check_unique_ids("mur", project.walls, errors)
	_check_unique_ids("ouverture", project.openings, errors)
	_check_unique_ids("pièce", project.rooms, errors)
	_check_unique_ids("meuble", project.furniture, errors)
	for wall in project.walls:
		_check_wall(project, wall, errors)
	for opening in project.openings:
		_check_opening(project, opening, errors)
	for room in project.rooms:
		_check_room(project, room, errors)
	for item in project.furniture:
		_check_furniture(item, errors)
	return errors


static func _check_unique_ids(label: String, entities: Array, errors: PackedStringArray) -> void:
	var seen := {}
	for entity in entities:
		if _id_regex.search(entity.id) == null:
			errors.append("%s « %s » : identifiant invalide (lettres, chiffres, _ et - uniquement)" % [label, entity.id])
		if seen.has(entity.id):
			errors.append("%s « %s » : identifiant en double" % [label, entity.id])
		seen[entity.id] = true


static func _check_wall(project: ProjectData, wall: Wall, errors: PackedStringArray) -> void:
	var prefix := "mur « %s »" % wall.id
	for node_id in [wall.a, wall.b]:
		if project.get_plan_node(node_id) == null:
			errors.append("%s : nœud inconnu « %s »" % [prefix, node_id])
	if wall.a == wall.b:
		errors.append("%s : relie un nœud à lui-même" % prefix)
	if wall.thickness <= 0.0:
		errors.append("%s : l'épaisseur doit être positive" % prefix)
	if wall.height <= 0.0:
		errors.append("%s : la hauteur doit être positive" % prefix)


static func _check_opening(project: ProjectData, opening: Opening, errors: PackedStringArray) -> void:
	var prefix := "ouverture « %s »" % opening.id
	if not opening.kind in Opening.KINDS:
		errors.append("%s : type inconnu « %s »" % [prefix, opening.kind])
	if not opening.swing in Opening.SWINGS:
		errors.append("%s : sens d'ouverture inconnu « %s »" % [prefix, opening.swing])
	if opening.width <= 0.0 or opening.height <= 0.0:
		errors.append("%s : largeur et hauteur doivent être positives" % prefix)
	if opening.sill < 0.0:
		errors.append("%s : l'allège ne peut pas être négative" % prefix)
	var wall := project.get_wall(opening.wall_id)
	if wall == null:
		errors.append("%s : mur inconnu « %s »" % [prefix, opening.wall_id])
		return
	var length := project.wall_length(wall)
	if length < 0.0:
		return  # The wall itself is already reported as broken.
	var half_width := opening.width / 2.0
	if opening.offset - half_width < -LENGTH_EPSILON or opening.offset + half_width > length + LENGTH_EPSILON:
		errors.append("%s : dépasse du mur « %s » (longueur %.2f m)" % [prefix, wall.id, length])


static func _check_room(project: ProjectData, room: Room, errors: PackedStringArray) -> void:
	var prefix := "pièce « %s »" % room.id
	if room.node_ids.size() < 3:
		errors.append("%s : il faut au moins 3 nœuds" % prefix)
	for node_id in room.node_ids:
		if project.get_plan_node(node_id) == null:
			errors.append("%s : nœud inconnu « %s »" % [prefix, node_id])
	if not room.floor_kind in Room.FLOOR_KINDS:
		errors.append("%s : type de sol inconnu « %s »" % [prefix, room.floor_kind])


static func _check_furniture(item: FurnitureItem, errors: PackedStringArray) -> void:
	if item.size.x <= 0.0 or item.size.y <= 0.0 or item.size.z <= 0.0:
		errors.append("meuble « %s » : les dimensions doivent être positives" % item.id)
