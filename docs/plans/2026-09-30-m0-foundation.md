# M0 — Socle : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mettre en place le banc de tests (GUT + CI) et la couche `src/model` : entités du projet, validation des invariants et sérialisation JSON.

**Architecture:** Des classes `RefCounted` pures dans `src/model/`, sans aucun nœud de scène :
- `ProjectData` agrège les entités ;
- `ProjectValidator` vérifie les invariants ;
- `ProjectSerializer` convertit vers et depuis le JSON du §4 de la spec, en accumulant toutes les erreurs de type puis en appelant le validateur.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, GitHub Actions.

**Spec:** `docs/specs/2026-09-30-v1-design.md` (§3 Architecture, §4 Modèle de données, §8 Erreurs, §10 Tests, §11 jalon M0).

## Global Constraints

- Godot **4.7.2**, GDScript uniquement. GUT **9.7.1** est embarqué dans `addons/gut/`.
- Indentation par **tabulations** (convention GDScript).
- Code, identifiants et commentaires en anglais. **Les messages d'erreur destinés à l'utilisateur sont en français.**
- Unités en **mètres**. Le plan du sol est en (x, z) : x vers l'est, z vers le sud. En mémoire, c'est un `Vector2(x, z)`.
- `src/model/` ne référence aucun nœud de scène : uniquement `RefCounted` et des types de base.
- Après avoir ajouté un script avec `class_name`, il faut relancer l'import (`scripts/test.sh` le fait), sinon on obtient `Identifier "X" not declared`.
- Branche `feat/m0-foundation`, PR vers `develop` assignée à `@me`.
- Messages de commit au format Conventional Commits, **sans** trailer `Co-Authored-By`, sans lien de session et sans pied de page « Generated with ».

## Review Focus

1. **Fichier édité à la main avec une valeur du mauvais type** (`"thickness": "épais"`) : message localisé (`walls[1] : « thickness » doit être un nombre`), toutes les erreurs signalées en une fois, pas de plantage. Tests : `test_rejects_wrong_field_type_with_location` et `test_reports_every_type_error_at_once` (Task 3).
2. **Nombres entiers dans le JSON** (`"wall_height": 3`) : acceptés comme 3.0. Test : `test_integer_numbers_are_accepted` (Task 3).
3. **Noms accentués et guillemets français** (`Fauteuil « Élise »`) : conservés à l'aller-retour. Test : `test_round_trip_keeps_non_ascii_names` (Task 3).
4. **Ouverture à fleur d'extrémité de mur, avec bruit flottant** (offset 3.6 + 1e-9, largeur 0.8, mur de 4 m) : acceptée. Test : `test_accepts_openings_flush_with_wall_ends_despite_float_noise` (Task 2).
5. **Projet vide ou collections absentes** (menu « Nouveau (vide) », fichier minimal) : valide. Tests : `test_empty_project_is_valid` (Task 2), `test_missing_collections_read_as_empty` et `test_empty_project_round_trips` (Task 3).

## Hors périmètre de M0

- Migrations de schéma : il n'existe qu'une version (1). La chaîne de migrations sera ajoutée avec le schéma 2. En attendant, une version supérieure ou inférieure à 1 est refusée.
- `ProjectStore`, `UndoRedo` et toute scène : jalons M1 et M2.
- `data/log16.json` : jalon M1.

## Structure des fichiers

| Fichier | Rôle |
|---|---|
| `addons/gut/` | Framework de test (copie de la version 9.7.1) |
| `.gutconfig.json` | Dossiers de tests et sortie automatique |
| `scripts/test.sh` | Import puis exécution de GUT en headless, arguments transmis à GUT |
| `src/model/plan_node.gd` | `PlanNode` : coin du graphe de murs |
| `src/model/wall.gd` | `Wall` : mur entre deux nœuds |
| `src/model/opening.gd` | `Opening` : porte ou fenêtre, `KINDS`, `SWINGS` |
| `src/model/room.gd` | `Room` : pièce (polygone de nœuds), `FLOOR_KINDS` |
| `src/model/furniture_item.gd` | `FurnitureItem` : bloc paramétrique ou GLB |
| `src/model/underlay.gd` | `Underlay` : calque du plan |
| `src/model/project_data.gd` | `ProjectData` : agrégat et recherches par id |
| `src/model/project_validator.gd` | `ProjectValidator.validate()` |
| `src/model/project_load_result.gd` | `ProjectLoadResult` : un projet ou une liste d'erreurs |
| `src/model/project_serializer.gd` | `ProjectSerializer.to_json()` et `from_json()` |
| `tests/fixtures/project_fixtures.gd` | Pièce de 4 × 4 m (objets et JSON écrit à la main) et constructeurs d'entités |
| `tests/unit/test_*.gd` | Tests GUT |
| `.github/workflows/tests.yml` | CI sur les PR |

---

### Task 1: Banc de tests et entités du modèle

**Files:**
- Create: `addons/gut/` (copie de la version), `.gutconfig.json`, `scripts/test.sh`
- Create: `src/model/plan_node.gd`, `wall.gd`, `opening.gd`, `room.gd`, `furniture_item.gd`, `underlay.gd`, `project_data.gd`
- Create: `tests/fixtures/project_fixtures.gd`
- Test: `tests/unit/test_project_data.gd`

**Interfaces:**
- Consumes: rien.
- Produces:
  - `PlanNode { id: String, pos: Vector2 }`
  - `Wall { id, a, b: String, thickness, height: float }`
  - `Opening { id, wall_id, kind: String, offset, width, height, sill: float, swing: String }`, avec `Opening.KINDS` et `Opening.SWINGS`
  - `Room { id, name: String, node_ids: PackedStringArray, floor_kind: String }`, avec `Room.FLOOR_KINDS`
  - `FurnitureItem { id, preset, glb, name: String, size: Vector3 (x = largeur, y = hauteur, z = profondeur), color: Color, pos: Vector2, rotation_deg: float }`
  - `Underlay { image: String, meters_per_px: float, offset: Vector2 }`
  - `ProjectData` : champs `name`, `wall_height`, `north_angle`, `underlay`, `nodes`, `walls`, `openings`, `rooms`, `furniture`, plus `DEFAULT_WALL_HEIGHT := 2.5`, `get_plan_node(id) -> PlanNode`, `get_wall(id) -> Wall` et `wall_length(wall) -> float` (qui vaut -1.0 si un nœud manque)
  - Fixtures (`preload("res://tests/fixtures/project_fixtures.gd")`) : `square_room()`, `square_room_dict()`, `plan_node(id, x, z)`, `wall(id, a, b)`, `door(id, wall_id, offset, width)`, `room(id, node_ids)`, `sofa(id)`

- [ ] **Step 1: Embarquer GUT 9.7.1**

```bash
cd /Users/periicles/Dev/3D-appartment
curl -sSL -o /tmp/gut.zip https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip
unzip -q /tmp/gut.zip -d /tmp/gut
cp -R /tmp/gut/Gut-9.7.1/addons/gut addons/
ls addons/gut/gut_cmdln.gd
```

Expected : le chemin `addons/gut/gut_cmdln.gd` s'affiche.

- [ ] **Step 2: Configurer GUT et le script de test**

`.gutconfig.json` :

```json
{
	"dirs": ["res://tests/"],
	"include_subdirs": true,
	"should_exit": true,
	"log_level": 1
}
```

`scripts/test.sh` (puis `chmod +x scripts/test.sh`) :

```bash
#!/usr/bin/env bash
# Runs the GUT suite headless. Extra arguments are passed to GUT
# (e.g. -gselect=test_project_data -gunit_test_name=test_wall_length).
set -euo pipefail

cd "$(dirname "$0")/.."

# Refresh Godot's global class cache so newly added `class_name` scripts resolve.
godot --headless --path . --import > /dev/null

godot --headless --path . -s addons/gut/gut_cmdln.gd "$@"
```

- [ ] **Step 3: Écrire les fixtures et le test en échec**

`tests/fixtures/project_fixtures.gd` :

```gdscript
extends RefCounted
## Shared test data: a 4 m x 4 m room with one door, one sofa and a plan underlay.


static func square_room() -> ProjectData:
	var project := ProjectData.new()
	project.name = "Séjour test"
	project.nodes.assign([
		plan_node("n1", 0, 0),
		plan_node("n2", 4, 0),
		plan_node("n3", 4, 4),
		plan_node("n4", 0, 4),
	])
	project.walls.assign([
		wall("w1", "n1", "n2"),
		wall("w2", "n2", "n3"),
		wall("w3", "n3", "n4"),
		wall("w4", "n4", "n1"),
	])
	project.openings.assign([door("o1", "w1", 1.0, 0.8)])
	project.rooms.assign([room("r1", ["n1", "n2", "n3", "n4"])])
	project.furniture.assign([sofa("f1")])
	var underlay := Underlay.new()
	underlay.image = "log16_plan.png"
	underlay.meters_per_px = 0.01
	underlay.offset = Vector2.ZERO
	project.underlay = underlay
	return project


## The JSON form of square_room(), as written by hand in a project file.
static func square_room_dict() -> Dictionary:
	return {
		"schema_version": 1,
		"name": "Séjour test",
		"wall_height": 2.5,
		"north_angle": 0,
		"underlay": {"image": "log16_plan.png", "meters_per_px": 0.01, "offset": [0, 0]},
		"nodes": [
			{"id": "n1", "x": 0, "z": 0},
			{"id": "n2", "x": 4, "z": 0},
			{"id": "n3", "x": 4, "z": 4},
			{"id": "n4", "x": 0, "z": 4},
		],
		"walls": [
			{"id": "w1", "a": "n1", "b": "n2", "thickness": 0.2},
			{"id": "w2", "a": "n2", "b": "n3", "thickness": 0.2},
			{"id": "w3", "a": "n3", "b": "n4", "thickness": 0.2},
			{"id": "w4", "a": "n4", "b": "n1", "thickness": 0.2},
		],
		"openings": [
			{
				"id": "o1", "wall": "w1", "type": "door", "offset": 1.0, "width": 0.8,
				"height": 2.04, "sill": 0, "swing": "left",
			},
		],
		"rooms": [{"id": "r1", "name": "Séjour", "nodes": ["n1", "n2", "n3", "n4"], "floor": "wood"}],
		"furniture": [
			{
				"id": "f1", "preset": "sofa_3", "glb": null, "name": "Canapé",
				"size": [2.1, 0.9, 0.85], "color": "#c9a88a", "pos": [2.0, 3.0], "rot": 90,
			},
		],
	}


static func plan_node(id: String, x: float, z: float) -> PlanNode:
	var node := PlanNode.new()
	node.id = id
	node.pos = Vector2(x, z)
	return node


static func wall(id: String, a: String, b: String) -> Wall:
	var w := Wall.new()
	w.id = id
	w.a = a
	w.b = b
	w.thickness = 0.2
	w.height = ProjectData.DEFAULT_WALL_HEIGHT
	return w


static func door(id: String, wall_id: String, offset: float, width: float) -> Opening:
	var opening := Opening.new()
	opening.id = id
	opening.wall_id = wall_id
	opening.kind = "door"
	opening.offset = offset
	opening.width = width
	opening.height = 2.04
	opening.sill = 0.0
	opening.swing = "left"
	return opening


static func room(id: String, node_ids: PackedStringArray) -> Room:
	var r := Room.new()
	r.id = id
	r.name = "Séjour"
	r.node_ids = node_ids
	r.floor_kind = "wood"
	return r


static func sofa(id: String) -> FurnitureItem:
	var item := FurnitureItem.new()
	item.id = id
	item.preset = "sofa_3"
	item.glb = ""
	item.name = "Canapé"
	item.size = Vector3(2.1, 0.85, 0.9)
	item.color = Color.html("#c9a88a")
	item.pos = Vector2(2.0, 3.0)
	item.rotation_deg = 90.0
	return item
```

`tests/unit/test_project_data.gd` :

```gdscript
extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func test_get_plan_node_returns_node_by_id() -> void:
	var project := Fixtures.square_room()
	assert_eq(project.get_plan_node("n3").pos, Vector2(4, 4))


func test_get_plan_node_returns_null_for_unknown_id() -> void:
	assert_null(Fixtures.square_room().get_plan_node("missing"))


func test_get_wall_returns_wall_by_id() -> void:
	assert_eq(Fixtures.square_room().get_wall("w2").b, "n3")


func test_get_wall_returns_null_for_unknown_id() -> void:
	assert_null(Fixtures.square_room().get_wall("missing"))


func test_wall_length_is_distance_between_nodes() -> void:
	var project := Fixtures.square_room()
	assert_almost_eq(project.wall_length(project.get_wall("w1")), 4.0, 1e-6)


func test_wall_length_handles_diagonal_walls() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 3, 4)])
	assert_almost_eq(project.wall_length(Fixtures.wall("w", "a", "b")), 5.0, 1e-6)


func test_wall_length_is_negative_when_node_missing() -> void:
	var project := Fixtures.square_room()
	assert_eq(project.wall_length(Fixtures.wall("w", "n1", "missing")), -1.0)
```

- [ ] **Step 4: Vérifier l'échec**

Run: `./scripts/test.sh`
Expected : FAIL, avec `Parse Error: Identifier "ProjectData" not declared` (ou `PlanNode`) et un code de sortie différent de 0.

- [ ] **Step 5: Écrire les entités**

`src/model/plan_node.gd` :

```gdscript
class_name PlanNode
extends RefCounted
## A corner of the wall graph.

var id: String
## Position on the floor plane in meters: x = east, y = south (world z).
var pos: Vector2
```

`src/model/wall.gd` :

```gdscript
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
```

`src/model/opening.gd` :

```gdscript
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
```

`src/model/room.gd` :

```gdscript
class_name Room
extends RefCounted
## A named floor area bounded by graph nodes.

const FLOOR_KINDS: PackedStringArray = ["wood", "tile", "outdoor"]

var id: String
var name: String
## Polygon of graph node ids, in order.
var node_ids: PackedStringArray
var floor_kind: String
```

`src/model/furniture_item.gd` :

```gdscript
class_name FurnitureItem
extends RefCounted
## A piece of furniture: a parametric block, or a GLB model scaled to `size`.

var id: String
## Catalogue preset id, or "" for a custom item.
var preset: String
## GLB path relative to the project file, or "" for a parametric block.
var glb: String
var name: String
## Bounding box in meters: x = width, y = height, z = depth.
var size: Vector3
var color: Color
## Center on the floor plane (x, world z).
var pos: Vector2
## Rotation around the vertical axis, in degrees.
var rotation_deg: float
```

`src/model/underlay.gd` :

```gdscript
class_name Underlay
extends RefCounted
## Plan image laid on the floor in plan view, used to check the modelled walls.

## Image path relative to the project file.
var image: String
var meters_per_px: float
## Position of the image's top-left corner on the floor plane, in meters.
var offset: Vector2
```

`src/model/project_data.gd` :

```gdscript
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


## Returns -1.0 when either endpoint is missing from the graph.
func wall_length(wall: Wall) -> float:
	var a := get_plan_node(wall.a)
	var b := get_plan_node(wall.b)
	if a == null or b == null:
		return -1.0
	return a.pos.distance_to(b.pos)
```

- [ ] **Step 6: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 7`, `All tests passed!`, code de sortie 0, sans aucune ligne `SCRIPT ERROR` ou `WARNING`.

- [ ] **Step 7: Commit**

```bash
git add addons/gut .gutconfig.json scripts/test.sh src/model tests
git commit -m "feat(model): add project entities and GUT test harness"
```

---

### Task 2: Validation des invariants

**Files:**
- Create: `src/model/project_validator.gd`
- Test: `tests/unit/test_project_validator.gd`

**Interfaces:**
- Consumes: les entités de la Task 1, `ProjectData.get_plan_node`, `get_wall` et `wall_length`, ainsi que les fixtures.
- Produces: `ProjectValidator.validate(project: ProjectData) -> PackedStringArray`, qui renvoie une liste vide quand le projet est valide. `ProjectValidator.LENGTH_EPSILON := 1e-4`.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_project_validator.gd` :

```gdscript
extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func _assert_single_error(project: ProjectData, expected_fragment: String) -> void:
	var errors := ProjectValidator.validate(project)
	assert_eq(errors.size(), 1, "errors: %s" % [errors])
	if errors.size() == 1:
		assert_string_contains(errors[0], expected_fragment)


func test_fixture_is_valid() -> void:
	assert_eq(ProjectValidator.validate(Fixtures.square_room()), PackedStringArray())


func test_empty_project_is_valid() -> void:
	assert_eq(ProjectValidator.validate(ProjectData.new()), PackedStringArray())


func test_rejects_non_positive_wall_height() -> void:
	var project := Fixtures.square_room()
	project.wall_height = 0.0
	_assert_single_error(project, "hauteur des murs")


func test_rejects_non_positive_underlay_scale() -> void:
	var project := Fixtures.square_room()
	project.underlay.meters_per_px = 0.0
	_assert_single_error(project, "calque")


func test_rejects_duplicate_ids() -> void:
	var project := Fixtures.square_room()
	project.furniture.append(Fixtures.sofa("f1"))
	_assert_single_error(project, "meuble « f1 » : identifiant en double")


func test_rejects_wall_with_unknown_node() -> void:
	var project := Fixtures.square_room()
	project.get_wall("w2").b = "n9"
	_assert_single_error(project, "mur « w2 » : nœud inconnu « n9 »")


func test_rejects_wall_joining_node_to_itself() -> void:
	var project := Fixtures.square_room()
	project.walls.append(Fixtures.wall("w5", "n1", "n1"))
	_assert_single_error(project, "relie un nœud à lui-même")


func test_rejects_non_positive_wall_thickness() -> void:
	var project := Fixtures.square_room()
	project.get_wall("w1").thickness = -0.1
	_assert_single_error(project, "épaisseur")


func test_rejects_opening_on_unknown_wall() -> void:
	var project := Fixtures.square_room()
	project.openings[0].wall_id = "w9"
	_assert_single_error(project, "mur inconnu « w9 »")


func test_rejects_opening_past_wall_end() -> void:
	var project := Fixtures.square_room()
	project.openings[0].offset = 3.8
	_assert_single_error(project, "dépasse du mur « w1 »")


func test_rejects_opening_before_wall_start() -> void:
	var project := Fixtures.square_room()
	project.openings[0].offset = 0.3
	_assert_single_error(project, "dépasse du mur")


func test_accepts_openings_flush_with_wall_ends_despite_float_noise() -> void:
	var project := Fixtures.square_room()
	project.openings[0].offset = 0.4 - 1e-9
	project.openings.append(Fixtures.door("o2", "w1", 3.6 + 1e-9, 0.8))
	assert_eq(ProjectValidator.validate(project), PackedStringArray())


func test_rejects_unknown_opening_kind() -> void:
	var project := Fixtures.square_room()
	project.openings[0].kind = "hatch"
	_assert_single_error(project, "type inconnu « hatch »")


func test_rejects_unknown_swing() -> void:
	var project := Fixtures.square_room()
	project.openings[0].swing = "up"
	_assert_single_error(project, "sens d'ouverture")


func test_rejects_negative_sill() -> void:
	var project := Fixtures.square_room()
	project.openings[0].sill = -0.5
	_assert_single_error(project, "allège")


func test_rejects_room_with_fewer_than_three_nodes() -> void:
	var project := Fixtures.square_room()
	project.rooms[0].node_ids = PackedStringArray(["n1", "n2"])
	_assert_single_error(project, "au moins 3 nœuds")


func test_rejects_room_with_unknown_node() -> void:
	var project := Fixtures.square_room()
	project.rooms[0].node_ids[3] = "n9"
	_assert_single_error(project, "pièce « r1 » : nœud inconnu « n9 »")


func test_rejects_unknown_floor_kind() -> void:
	var project := Fixtures.square_room()
	project.rooms[0].floor_kind = "marble"
	_assert_single_error(project, "type de sol inconnu")


func test_rejects_furniture_with_zero_dimension() -> void:
	var project := Fixtures.square_room()
	project.furniture[0].size.y = 0.0
	_assert_single_error(project, "meuble « f1 » : les dimensions")
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_project_validator`
Expected : FAIL, avec `Identifier "ProjectValidator" not declared`.

- [ ] **Step 3: Implémenter**

`src/model/project_validator.gd` :

```gdscript
class_name ProjectValidator
extends RefCounted
## Checks the invariants a loaded or edited project must satisfy.
## Messages are shown to the user as-is, so they are in French.

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
```

- [ ] **Step 4: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 26`, code de sortie 0.

- [ ] **Step 5: Commit**

```bash
git add src/model/project_validator.gd tests/unit/test_project_validator.gd
git commit -m "feat(model): validate project invariants"
```

---

### Task 3: Sérialisation JSON

**Files:**
- Create: `src/model/project_load_result.gd`, `src/model/project_serializer.gd`
- Test: `tests/unit/test_project_serializer.gd`

**Interfaces:**
- Consumes: les entités (Task 1), `ProjectValidator.validate` (Task 2) et les fixtures `square_room()` et `square_room_dict()`.
- Produces :
  - `ProjectLoadResult { project: ProjectData, errors: PackedStringArray }`, avec `is_ok() -> bool`, `ProjectLoadResult.success(project)` et `ProjectLoadResult.failure(errors)`.
  - `ProjectSerializer.SCHEMA_VERSION := 1`.
  - `ProjectSerializer.to_json(project) -> String` : indentation par tabulations, `preset` et `glb` vides écrits `null`, `size` écrit `[largeur, profondeur, hauteur]`.
  - `ProjectSerializer.from_json(text) -> ProjectLoadResult` : lit d'abord les types en accumulant les erreurs, puis appelle `ProjectValidator`.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_project_serializer.gd` :

```gdscript
extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")


func _load(data: Dictionary) -> ProjectLoadResult:
	return ProjectSerializer.from_json(JSON.stringify(data))


func _assert_rejected(result: ProjectLoadResult, expected_fragment: String) -> void:
	assert_false(result.is_ok(), "should be rejected")
	assert_null(result.project)
	assert_string_contains("\n".join(result.errors), expected_fragment)


func test_loads_hand_written_fixture() -> void:
	var result := _load(Fixtures.square_room_dict())
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	var project := result.project
	assert_eq(project.name, "Séjour test")
	assert_eq(project.nodes.size(), 4)
	assert_eq(project.get_plan_node("n2").pos, Vector2(4, 0))
	assert_eq(project.get_wall("w1").thickness, 0.2)
	assert_eq(project.openings[0].kind, "door")
	assert_eq(project.rooms[0].node_ids, PackedStringArray(["n1", "n2", "n3", "n4"]))
	assert_eq(project.rooms[0].floor_kind, "wood")
	assert_eq(project.underlay.meters_per_px, 0.01)


func test_wall_height_defaults_to_project_wall_height() -> void:
	var data := Fixtures.square_room_dict()
	data["wall_height"] = 2.7
	assert_almost_eq(_load(data).project.get_wall("w1").height, 2.7, 1e-6)


func test_furniture_size_is_width_depth_height_in_file() -> void:
	var sofa := _load(Fixtures.square_room_dict()).project.furniture[0]
	assert_almost_eq(sofa.size.x, 2.1, 1e-6, "width")
	assert_almost_eq(sofa.size.z, 0.9, 1e-6, "depth")
	assert_almost_eq(sofa.size.y, 0.85, 1e-6, "height")


func test_furniture_null_glb_reads_as_empty_string() -> void:
	var sofa := _load(Fixtures.square_room_dict()).project.furniture[0]
	assert_eq(sofa.glb, "")
	assert_eq(sofa.preset, "sofa_3")
	assert_eq(sofa.color, Color.html("#c9a88a"))
	assert_eq(sofa.rotation_deg, 90.0)


func test_round_trip_is_lossless() -> void:
	var json := ProjectSerializer.to_json(Fixtures.square_room())
	var reloaded := ProjectSerializer.from_json(json)
	assert_true(reloaded.is_ok(), "errors: %s" % [reloaded.errors])
	assert_eq(ProjectSerializer.to_json(reloaded.project), json)


func test_round_trip_keeps_non_ascii_names() -> void:
	var project := Fixtures.square_room()
	project.furniture[0].name = "Fauteuil « Élise »"
	var reloaded := ProjectSerializer.from_json(ProjectSerializer.to_json(project)).project
	assert_eq(reloaded.furniture[0].name, "Fauteuil « Élise »")


func test_round_trip_keeps_missing_underlay_and_empty_preset() -> void:
	var project := Fixtures.square_room()
	project.underlay = null
	project.furniture[0].preset = ""
	var reloaded := ProjectSerializer.from_json(ProjectSerializer.to_json(project)).project
	assert_null(reloaded.underlay)
	assert_eq(reloaded.furniture[0].preset, "")


func test_empty_project_round_trips() -> void:
	var reloaded := ProjectSerializer.from_json(ProjectSerializer.to_json(ProjectData.new()))
	assert_true(reloaded.is_ok(), "errors: %s" % [reloaded.errors])
	assert_eq(reloaded.project.walls.size(), 0)


func test_missing_collections_read_as_empty() -> void:
	var result := _load({"schema_version": 1, "name": "Vide"})
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	assert_eq(result.project.furniture.size(), 0)


func test_integer_numbers_are_accepted() -> void:
	var result := ProjectSerializer.from_json('{"schema_version": 1, "name": "x", "wall_height": 3}')
	assert_true(result.is_ok(), "errors: %s" % [result.errors])
	assert_eq(result.project.wall_height, 3.0)


func test_rejects_malformed_json_with_line_number() -> void:
	_assert_rejected(ProjectSerializer.from_json('{\n"name": "x",\n oops}'), "ligne 3")


func test_rejects_non_object_root() -> void:
	_assert_rejected(ProjectSerializer.from_json("[1, 2]"), "objet JSON")


func test_rejects_missing_schema_version() -> void:
	var data := Fixtures.square_room_dict()
	data.erase("schema_version")
	_assert_rejected(_load(data), "schema_version")


func test_rejects_newer_schema_version() -> void:
	var data := Fixtures.square_room_dict()
	data["schema_version"] = 2
	_assert_rejected(_load(data), "version plus récente")


func test_rejects_schema_version_zero() -> void:
	var data := Fixtures.square_room_dict()
	data["schema_version"] = 0
	_assert_rejected(_load(data), "schema_version")


func test_rejects_wrong_field_type_with_location() -> void:
	var data := Fixtures.square_room_dict()
	data["walls"][1]["thickness"] = "épais"
	_assert_rejected(_load(data), "walls[1] : « thickness » doit être un nombre")


func test_rejects_missing_required_field() -> void:
	var data := Fixtures.square_room_dict()
	data["nodes"][0].erase("x")
	_assert_rejected(_load(data), "nodes[0] : « x »")


func test_rejects_collection_that_is_not_a_list() -> void:
	var data := Fixtures.square_room_dict()
	data["walls"] = {"w1": {}}
	_assert_rejected(_load(data), "« walls » doit être une liste")


func test_rejects_list_entry_that_is_not_an_object() -> void:
	var data := Fixtures.square_room_dict()
	data["nodes"].append("n5")
	_assert_rejected(_load(data), "nodes[4] : doit être un objet")


func test_rejects_bad_vector_length() -> void:
	var data := Fixtures.square_room_dict()
	data["furniture"][0]["size"] = [2.1, 0.9]
	_assert_rejected(_load(data), "furniture[0] : « size » doit être une liste de 3 nombres")


func test_rejects_invalid_color() -> void:
	var data := Fixtures.square_room_dict()
	data["furniture"][0]["color"] = "beige"
	_assert_rejected(_load(data), "« color »")


func test_reports_every_type_error_at_once() -> void:
	var data := Fixtures.square_room_dict()
	data["walls"][0]["thickness"] = "x"
	data["nodes"][1]["z"] = null
	var result := _load(data)
	assert_eq(result.errors.size(), 2, "errors: %s" % [result.errors])


func test_rejects_invariant_violations() -> void:
	var data := Fixtures.square_room_dict()
	data["openings"][0]["offset"] = 3.9
	_assert_rejected(_load(data), "dépasse du mur")
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_project_serializer`
Expected : FAIL, avec `Identifier "ProjectLoadResult" not declared` (ou `ProjectSerializer`).

- [ ] **Step 3: Implémenter le résultat de chargement**

`src/model/project_load_result.gd` :

```gdscript
class_name ProjectLoadResult
extends RefCounted
## Outcome of loading a project: either a project, or the reasons it was rejected.

var project: ProjectData = null
var errors := PackedStringArray()


static func success(p_project: ProjectData) -> ProjectLoadResult:
	var result := ProjectLoadResult.new()
	result.project = p_project
	return result


static func failure(p_errors: PackedStringArray) -> ProjectLoadResult:
	var result := ProjectLoadResult.new()
	result.errors = p_errors
	return result


func is_ok() -> bool:
	return project != null
```

- [ ] **Step 4: Implémenter le sérialiseur**

`src/model/project_serializer.gd` :

```gdscript
class_name ProjectSerializer
extends RefCounted
## Converts projects to and from the JSON project file format (see docs/specs/2026-09-30-v1-design.md, §4).
## Migrations between schema versions will be added here when schema version 2 exists.

const SCHEMA_VERSION := 1
const _INDENT := "\t"


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
		var raw := r.object(data, "underlay", "projet")
		var underlay := Underlay.new()
		underlay.image = r.text(raw, "image", "underlay")
		underlay.meters_per_px = r.number(raw, "meters_per_px", "underlay")
		underlay.offset = r.vector2(raw, "offset", "underlay")
		project.underlay = underlay

	var nodes := r.objects(data, "nodes")
	for i in nodes.size():
		var ctx := "nodes[%d]" % i
		var node := PlanNode.new()
		node.id = r.text(nodes[i], "id", ctx)
		node.pos = Vector2(r.number(nodes[i], "x", ctx), r.number(nodes[i], "z", ctx))
		project.nodes.append(node)

	var walls := r.objects(data, "walls")
	for i in walls.size():
		var ctx := "walls[%d]" % i
		var wall := Wall.new()
		wall.id = r.text(walls[i], "id", ctx)
		wall.a = r.text(walls[i], "a", ctx)
		wall.b = r.text(walls[i], "b", ctx)
		wall.thickness = r.number(walls[i], "thickness", ctx)
		wall.height = r.number(walls[i], "height", ctx, project.wall_height)
		project.walls.append(wall)

	var openings := r.objects(data, "openings")
	for i in openings.size():
		var ctx := "openings[%d]" % i
		var opening := Opening.new()
		opening.id = r.text(openings[i], "id", ctx)
		opening.wall_id = r.text(openings[i], "wall", ctx)
		opening.kind = r.text(openings[i], "type", ctx)
		opening.offset = r.number(openings[i], "offset", ctx)
		opening.width = r.number(openings[i], "width", ctx)
		opening.height = r.number(openings[i], "height", ctx)
		opening.sill = r.number(openings[i], "sill", ctx, 0.0)
		opening.swing = r.text(openings[i], "swing", ctx, "none")
		project.openings.append(opening)

	var rooms := r.objects(data, "rooms")
	for i in rooms.size():
		var ctx := "rooms[%d]" % i
		var room := Room.new()
		room.id = r.text(rooms[i], "id", ctx)
		room.name = r.text(rooms[i], "name", ctx)
		room.node_ids = r.texts(rooms[i], "nodes", ctx)
		room.floor_kind = r.text(rooms[i], "floor", ctx, "wood")
		project.rooms.append(room)

	var furniture := r.objects(data, "furniture")
	for i in furniture.size():
		var ctx := "furniture[%d]" % i
		var item := FurnitureItem.new()
		item.id = r.text(furniture[i], "id", ctx)
		item.preset = r.optional_text(furniture[i], "preset", ctx)
		item.glb = r.optional_text(furniture[i], "glb", ctx)
		item.name = r.text(furniture[i], "name", ctx)
		var size := r.numbers(furniture[i], "size", ctx, 3)
		item.size = Vector3(size[0], size[2], size[1])
		item.color = r.color(furniture[i], "color", ctx)
		item.pos = r.vector2(furniture[i], "pos", ctx)
		item.rotation_deg = r.number(furniture[i], "rot", ctx, 0.0)
		project.furniture.append(item)

	if not r.errors.is_empty():
		return ProjectLoadResult.failure(r.errors)
	var invariant_errors := ProjectValidator.validate(project)
	if not invariant_errors.is_empty():
		return ProjectLoadResult.failure(invariant_errors)
	return ProjectLoadResult.success(project)


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
		if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
			return Color.html(value)
		_fail(ctx, key, "doit être une couleur hexadécimale (#rrggbb)")
		return Color.WHITE

	func object(data: Dictionary, key: String, ctx: String) -> Dictionary:
		var value = data.get(key)
		if typeof(value) == TYPE_DICTIONARY:
			return value
		_fail(ctx, key, "doit être un objet")
		return {}

	## A top-level list of objects; absent reads as an empty list.
	func objects(data: Dictionary, key: String) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var value = data.get(key, [])
		if typeof(value) != TYPE_ARRAY:
			_fail("projet", key, "doit être une liste")
			return result
		for i in value.size():
			if typeof(value[i]) == TYPE_DICTIONARY:
				result.append(value[i])
			else:
				errors.append("%s[%d] : doit être un objet" % [key, i])
		return result

	func _fail(ctx: String, key: String, expectation: String) -> void:
		errors.append("%s : « %s » %s" % [ctx, key, expectation])
```

- [ ] **Step 5: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 49`, code de sortie 0, sans `SCRIPT ERROR` ni `WARNING`.

- [ ] **Step 6: Commit**

```bash
git add src/model/project_load_result.gd src/model/project_serializer.gd tests/unit/test_project_serializer.gd
git commit -m "feat(model): serialize projects to and from JSON"
```

---

### Task 4: CI et documentation

**Files:**
- Create: `.github/workflows/tests.yml`
- Modify: `README.md` (ajout d'une section « Tests »)

**Interfaces:**
- Consumes: `scripts/test.sh` (Task 1).
- Produces: un check `tests / gut` sur chaque PR vers `develop` ou `main`.

- [ ] **Step 1: Écrire le workflow**

`.github/workflows/tests.yml` :

```yaml
name: tests

on:
  pull_request:
    branches: [develop, main]
  push:
    branches: [develop]

jobs:
  gut:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    env:
      GODOT_VERSION: 4.7.2
    steps:
      - uses: actions/checkout@v7

      - name: Install Godot
        run: |
          archive="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
          curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${archive}.zip"
          unzip -q godot.zip
          sudo mv "${archive}" /usr/local/bin/godot
          godot --version

      - name: Run tests
        run: ./scripts/test.sh
```

- [ ] **Step 2: Documenter les tests dans le README**

Insérer avant la section `## Workflow Git` :

````markdown
## Tests

Les tests utilisent [GUT](https://github.com/bitwes/Gut), embarqué dans `addons/gut/`.

```sh
./scripts/test.sh                                   # toute la suite
./scripts/test.sh -gselect=test_project_serializer  # un seul fichier
```

La CI (GitHub Actions) lance la suite sur chaque pull request.
````

- [ ] **Step 3: Vérifier localement une dernière fois**

Run: `./scripts/test.sh`
Expected : `Passing Tests 49`, code de sortie 0.

- [ ] **Step 4: Commit, push et PR**

```bash
git add .github/workflows/tests.yml README.md
git commit -m "ci: run GUT tests on pull requests"
git push -u origin feat/m0-foundation
gh pr create --base develop --assignee @me --title "feat: M0 foundation (model, validation, JSON, CI)" --body "<pourquoi et quoi, voir la spec §11 M0>"
```

- [ ] **Step 5: Vérifier la CI**

Run: `gh pr checks --watch`
Expected : le check `gut` est vert. S'il échoue au téléchargement de Godot, vérifier que l'URL de la release `4.7.2-stable` existe toujours.
