# M2 — Meubles : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Meubler le log 16 : choisir un bloc dans le catalogue, le poser avec un aperçu translucide qui se colle aux murs, le sélectionner, le déplacer, le pivoter, le dupliquer, le supprimer et le modifier dans un panneau, avec annuler et refaire.

**Architecture:**
- **Données** : les préréglages sont des ressources `.tres` (`FurniturePreset`), lues par `FurnitureCatalog`.
- **Calculs purs** : `Placement` regroupe la grille, le collage aux murs, l'empreinte au sol et la sélection par rayon. Ces calculs se testent sans scène.
- **Modifications** : `ProjectStore` gagne des commandes (`add`, `update`, `remove`, `duplicate`) qui passent toutes par l'`UndoRedo` natif et émettent des signaux ciblés.
- **Affichage** : `FurnitureView` dessine des blocs, le contour de sélection et l'aperçu translucide. Elle ne fait que réagir aux signaux du store.
- **Saisie** : `FurnitureTool` traduit la souris et le clavier en commandes du store. Pendant un glisser, seule la vue est déplacée, et le store n'est mis à jour qu'au relâchement.
- **Interface** : `CatalogPanel` à gauche et `PropertiesPanel` à droite, assemblés dans `main.gd`.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** `docs/specs/2026-09-30-v1-design.md` (§3, §4 `furniture`, §7 « Mode Meubles », §11 jalon M2).

## Global Constraints

- Godot **4.7.2**, GDScript uniquement. GUT **9.7.1** est déjà dans `addons/gut/`.
- Indentation par **tabulations**.
- Code et commentaires en anglais. **Libellés et messages destinés à l'utilisateur en français.**
- Unités en **mètres** dans les données. Le panneau affiche les dimensions en **cm**.
- Plan du sol en (x, z), en mémoire `Vector2(x, z)`. `FurnitureItem.size` vaut (x = largeur, y = hauteur, z = profondeur). `rotation_deg = 0` signifie que la face avant regarde vers +z (convention de l'axe Y de Godot).
- `src/model/` ne référence aucun nœud de scène.
- Les vues ne modifient jamais les données. Toute modification passe par `ProjectStore`, donc par `UndoRedo` (spec §3).
- Les connexions de signaux vers l'autoload utilisent des **méthodes liées, jamais des lambdas**, pour qu'elles disparaissent avec le nœud qui les a créées.
- Le raccourci de commande est Cmd sur macOS et Ctrl ailleurs : `InputEvent.is_command_or_control_pressed()`.
- Tests : `./scripts/test.sh`, ou `./scripts/test.sh -gselect=<fichier>` pour un seul fichier.
- Les fichiers `.uid` générés par Godot sont commités avec leur source.
- Branche `feat/m2-furniture`, PR vers `develop` assignée à `@me`.
- Commits au format Conventional Commits, **sans** trailer `Co-Authored-By`, sans lien de session et sans pied de page « Generated with ».

## Choix et écarts par rapport à la spec

1. **Pose depuis le catalogue** : un clic sur le modèle, puis un clic dans la pièce, au lieu d'un glisser-déposer. Le résultat est le même, avec moins de cas limites (relâchement au-dessus d'un panneau). Échap annule.
2. **Glisser un meuble** : seule la vue suit la souris, et le store reçoit un seul `update_furniture` au relâchement. Un glisser complet correspond donc à une seule étape d'annulation. Un simple clic n'ajoute rien à l'historique.
3. **Panneau de propriétés** : chaque valeur validée correspond à une étape d'annulation. Cliquer sur les flèches d'un champ numérique donne donc plusieurs étapes.
4. **Doublon** : décalé de 0,30 m en x et en z pour rester visible. La spec ne précise rien.
5. **Identifiants** : `f<n>`, avec n égal au plus grand numéro existant + 1.
6. **Pas encore de sauvegarde** : les meubles sont perdus à la fermeture. Les fichiers arrivent en M3. C'est indiqué dans le README.
7. **Thème de l'interface** : le thème par défaut de Godot. Le thème cozy est prévu en M6, comme le rebond à la pose, les chevauchements en rouge et l'import GLB (spec §11).

## Review Focus

1. **Annuler la création d'un meuble sélectionné** : la sélection se vide et le panneau se cache, sans erreur. Test : `test_undoing_the_selected_items_creation_clears_selection` (Task 5).
2. **Valeur invalide saisie** (dimension 0, champ inconnu) : refusée, aucune étape d'annulation ajoutée. Tests : `test_update_rejects_unknown_id_field_and_invalid_values` et `test_rejected_update_leaves_history_untouched` (Task 3).
3. **Clic sans déplacement** : pas d'étape d'annulation fantôme. Test : `test_click_without_moving_adds_no_history` (Task 5).
4. **Rechargement du projet pendant une pose** : la pose est annulée et l'historique vidé. Tests : `test_loading_a_project_cancels_placement` (Task 5) et `test_loading_a_project_clears_history` (Task 3).
5. **Mise à jour du panneau quand le meuble change ailleurs** : pas de boucle, et pas d'étape d'annulation en trop. Tests : `test_panel_refreshes_when_item_changes_elsewhere` et `test_refresh_does_not_create_extra_history` (Task 6).

## Structure des fichiers

| Fichier | Rôle |
|---|---|
| `src/model/furniture_preset.gd` | `FurniturePreset` (Resource) : id, nom, catégorie, taille, couleur, `make_item()` |
| `src/model/furniture_catalog.gd` | `FurnitureCatalog.load_presets()`, `CATEGORIES` |
| `src/model/furniture_item.gd` (modifié) | `+ copy()` |
| `data/presets/*.tres` | Les 15 blocs de la spec |
| `src/model/placement.gd` | `Placement` : grille, collage au mur, empreinte, sélection par rayon |
| `src/store/project_store.gd` (remplacé) | Commandes sur les meubles, `UndoRedo`, signaux `furniture_*` |
| `src/world/palette.gd` (modifié) | Couleur de sélection, transparence de l'aperçu, matériau de contour |
| `src/world/furniture_view.gd` | `FurnitureView` : blocs, contour de sélection, aperçu, aperçu de glisser |
| `src/tools/furniture_tool.gd` | `FurnitureTool` : souris et clavier, vers les commandes du store |
| `src/ui/catalog_panel.gd` | `CatalogPanel` : boutons par catégorie, signal `preset_chosen` |
| `src/ui/properties_panel.gd` | `PropertiesPanel` : édition du meuble sélectionné |
| `src/main.gd` (remplacé) | Assemblage de la vue, de l'outil et des panneaux |
| `README.md` (modifié) | Contrôles des meubles |

---

### Task 1: Préréglages et catalogue

**Files:**
- Create: `src/model/furniture_preset.gd`, `src/model/furniture_catalog.gd`, `data/presets/*.tres` (15 fichiers)
- Modify: `src/model/furniture_item.gd` (ajout de `copy()`)
- Test: `tests/unit/test_furniture_catalog.gd`

**Interfaces:**
- Consumes: `FurnitureItem` et `ProjectValidator` (M0).
- Produces :
  - `FurniturePreset` (Resource) : `id`, `name`, `category`, `size: Vector3`, `color: Color` ; `make_item(item_id: String, pos: Vector2) -> FurnitureItem`.
  - `FurnitureCatalog.PRESETS_DIR := "res://data/presets"`.
  - `FurnitureCatalog.CATEGORIES := ["Salon", "Chambre", "Cuisine et repas", "Rangement", "Extérieur"]`.
  - `FurnitureCatalog.load_presets(dir := PRESETS_DIR) -> Array[FurniturePreset]`, trié par catégorie puis par nom.
  - `FurnitureItem.copy() -> FurnitureItem`.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_furniture_catalog.gd` :

```gdscript
extends GutTest


func test_loads_every_shipped_preset() -> void:
	assert_eq(FurnitureCatalog.load_presets().size(), 15)


func test_presets_are_ordered_by_category() -> void:
	var ranks: Array[int] = []
	for preset in FurnitureCatalog.load_presets():
		ranks.append(FurnitureCatalog.CATEGORIES.find(preset.category))
	var sorted := ranks.duplicate()
	sorted.sort()
	assert_eq(ranks, sorted)


func test_every_preset_is_usable() -> void:
	var ids := {}
	for preset in FurnitureCatalog.load_presets():
		assert_false(preset.id.is_empty(), preset.resource_path)
		assert_false(ids.has(preset.id), "duplicate id %s" % preset.id)
		ids[preset.id] = true
		assert_true(preset.category in FurnitureCatalog.CATEGORIES, preset.id)
		assert_true(preset.size.x > 0 and preset.size.y > 0 and preset.size.z > 0, preset.id)


func test_spec_presets_are_present() -> void:
	var ids := FurnitureCatalog.load_presets().map(func(p: FurniturePreset) -> String: return p.id)
	for id in ["sofa_2", "sofa_3", "armchair", "coffee_table", "bed_90", "bed_140", "bed_160",
			"wardrobe", "nightstand", "dining_table", "chair", "shelf", "dresser", "garden_set", "planter"]:
		assert_has(ids, id)


func test_missing_directory_gives_empty_catalogue() -> void:
	assert_eq(FurnitureCatalog.load_presets("res://does/not/exist").size(), 0)


func test_make_item_copies_preset_defaults() -> void:
	var preset: FurniturePreset = load("res://data/presets/sofa_3.tres")
	var item := preset.make_item("f9", Vector2(1, 2))
	assert_eq(item.id, "f9")
	assert_eq(item.preset, "sofa_3")
	assert_eq(item.name, "Canapé 3 places")
	assert_eq(item.size, preset.size)
	assert_eq(item.color, preset.color)
	assert_eq(item.pos, Vector2(1, 2))
	assert_eq(item.rotation_deg, 0.0)
	assert_true(ProjectValidator.validate(_project_with(item)).is_empty())


func test_furniture_item_copy_is_independent() -> void:
	var original: FurnitureItem = load("res://data/presets/bed_160.tres").make_item("f1", Vector2.ZERO)
	var clone := original.copy()
	clone.size.x = 9.0
	clone.name = "Autre"
	assert_almost_eq(original.size.x, 1.6, 1e-6)
	assert_eq(original.name, "Lit 160")
	assert_eq(clone.id, "f1")


func _project_with(item: FurnitureItem) -> ProjectData:
	var project := ProjectData.new()
	project.furniture.append(item)
	return project
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_furniture_catalog`
Expected : FAIL avec `Identifier "FurnitureCatalog" not declared` (code de sortie 1).

- [ ] **Step 3: Ajouter `copy()` à `FurnitureItem`**

À la fin de `src/model/furniture_item.gd` :

```gdscript


func copy() -> FurnitureItem:
	var other := FurnitureItem.new()
	other.id = id
	other.preset = preset
	other.glb = glb
	other.name = name
	other.size = size
	other.color = color
	other.pos = pos
	other.rotation_deg = rotation_deg
	return other
```

- [ ] **Step 4: Écrire le préréglage et le catalogue**

`src/model/furniture_preset.gd` :

```gdscript
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
```

`src/model/furniture_catalog.gd` :

```gdscript
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
```

- [ ] **Step 5: Écrire les 15 préréglages**

`data/presets/armchair.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "armchair"
name = "Fauteuil"
category = "Salon"
size = Vector3(0.8, 0.85, 0.8)
color = Color(0.7255, 0.5608, 0.4549, 1)
```

`data/presets/bed_140.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "bed_140"
name = "Lit 140"
category = "Chambre"
size = Vector3(1.4, 0.5, 2.0)
color = Color(0.9098, 0.8627, 0.7961, 1)
```

`data/presets/bed_160.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "bed_160"
name = "Lit 160"
category = "Chambre"
size = Vector3(1.6, 0.5, 2.0)
color = Color(0.9098, 0.8627, 0.7961, 1)
```

`data/presets/bed_90.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "bed_90"
name = "Lit 90"
category = "Chambre"
size = Vector3(0.9, 0.5, 2.0)
color = Color(0.9098, 0.8627, 0.7961, 1)
```

`data/presets/chair.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "chair"
name = "Chaise"
category = "Cuisine et repas"
size = Vector3(0.45, 0.85, 0.5)
color = Color(0.6118, 0.4784, 0.3451, 1)
```

`data/presets/coffee_table.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "coffee_table"
name = "Table basse"
category = "Salon"
size = Vector3(1.1, 0.4, 0.6)
color = Color(0.5412, 0.4157, 0.3098, 1)
```

`data/presets/dining_table.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "dining_table"
name = "Table à manger"
category = "Cuisine et repas"
size = Vector3(1.6, 0.75, 0.9)
color = Color(0.6118, 0.4784, 0.3451, 1)
```

`data/presets/dresser.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "dresser"
name = "Commode"
category = "Rangement"
size = Vector3(1.0, 0.8, 0.5)
color = Color(0.8039, 0.7176, 0.6039, 1)
```

`data/presets/garden_set.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "garden_set"
name = "Salon de jardin"
category = "Extérieur"
size = Vector3(1.6, 0.75, 1.6)
color = Color(0.498, 0.6039, 0.4784, 1)
```

`data/presets/nightstand.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "nightstand"
name = "Table de chevet"
category = "Chambre"
size = Vector3(0.45, 0.5, 0.4)
color = Color(0.6275, 0.4863, 0.3608, 1)
```

`data/presets/planter.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "planter"
name = "Jardinière"
category = "Extérieur"
size = Vector3(0.8, 0.45, 0.35)
color = Color(0.5451, 0.4353, 0.3529, 1)
```

`data/presets/shelf.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "shelf"
name = "Étagère"
category = "Rangement"
size = Vector3(0.8, 1.8, 0.35)
color = Color(0.8039, 0.7176, 0.6039, 1)
```

`data/presets/sofa_2.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "sofa_2"
name = "Canapé 2 places"
category = "Salon"
size = Vector3(1.6, 0.85, 0.9)
color = Color(0.7882, 0.6588, 0.5412, 1)
```

`data/presets/sofa_3.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "sofa_3"
name = "Canapé 3 places"
category = "Salon"
size = Vector3(2.1, 0.85, 0.9)
color = Color(0.7882, 0.6588, 0.5412, 1)
```

`data/presets/wardrobe.tres` :

```
[gd_resource type="Resource" script_class="FurniturePreset" format=3]

[ext_resource type="Script" path="res://src/model/furniture_preset.gd" id="1"]

[resource]
script = ExtResource("1")
id = "wardrobe"
name = "Armoire"
category = "Chambre"
size = Vector3(1.0, 2.0, 0.6)
color = Color(0.8471, 0.7647, 0.6471, 1)
```

- [ ] **Step 6: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 142`, code de sortie 0, aucune ligne `SCRIPT ERROR` ni `WARNING`.

- [ ] **Step 7: Commit**

```bash
git add src/model data/presets tests/unit/test_furniture_catalog.gd tests/unit/test_furniture_catalog.gd.uid
git commit -m "feat(model): add furniture presets and catalogue"
```

---

### Task 2: Calculs de placement

**Files:**
- Create: `src/model/placement.gd`
- Test: `tests/unit/test_placement.gd`

**Interfaces:**
- Consumes: `ProjectData`, `FurnitureItem`, `Geometry.polygon_area` (dans les tests), et les fixtures (`square_room`, `sofa`, `plan_node`, `wall`).
- Produces :
  - `Placement.GRID_STEP := 0.05` et `Placement.WALL_SNAP_DISTANCE := 0.15`.
  - `snap_to_grid(pos, step := GRID_STEP) -> Vector2`.
  - `front_direction(rotation_deg) -> Vector2`.
  - `to_world(item_pos, rotation_deg, local: Vector2) -> Vector2`.
  - `footprint(pos, size: Vector3, rotation_deg) -> PackedVector2Array`, dans le sens anti-horaire.
  - `snap_to_wall(project, pos, size: Vector3) -> Dictionary`, qui renvoie `{pos, rotation_deg}` ou `{}`.
  - `ray_distance_to_item(origin, dir, item) -> float`, qui vaut -1 si le rayon manque l'objet.
  - `pick_item(origin, dir, items: Array[FurnitureItem]) -> String`, qui renvoie `""` si rien n'est touché.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_placement.gd` :

```gdscript
extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4
const SOFA := Vector3(2.0, 0.85, 0.9)


func _item(pos: Vector2, rotation_deg: float, size := SOFA) -> FurnitureItem:
	var item := Fixtures.sofa("f")
	item.pos = pos
	item.rotation_deg = rotation_deg
	item.size = size
	return item


func test_snap_to_grid_rounds_to_five_centimetres() -> void:
	assert_almost_eq(Placement.snap_to_grid(Vector2(1.023, 2.974)), Vector2(1.0, 2.95), Vector2(EPS, EPS))


func test_front_direction_matches_godot_y_rotation() -> void:
	for deg in [0.0, 90.0, 180.0, 33.0]:
		var basis := Basis(Vector3.UP, deg_to_rad(deg))
		var front_3d := basis * Vector3(0, 0, 1)
		assert_almost_eq(Placement.front_direction(deg), Vector2(front_3d.x, front_3d.z), Vector2(EPS, EPS), str(deg))


func test_to_world_matches_godot_y_rotation() -> void:
	var local := Vector2(0.7, -0.3)  # x along width, y towards the front
	var basis := Basis(Vector3.UP, deg_to_rad(40.0))
	var expected_3d := basis * Vector3(local.x, 0, local.y) + Vector3(1, 0, 2)
	assert_almost_eq(Placement.to_world(Vector2(1, 2), 40.0, local), Vector2(expected_3d.x, expected_3d.z),
		Vector2(EPS, EPS))


func test_footprint_unrotated() -> void:
	var corners := Placement.footprint(Vector2(1, 1), SOFA, 0.0)
	assert_almost_eq(Geometry.polygon_area(corners), 1.8, EPS)
	for corner in [Vector2(0, 0.55), Vector2(2, 0.55), Vector2(2, 1.45), Vector2(0, 1.45)]:
		var found := false
		for p in corners:
			found = found or p.distance_to(corner) < EPS
		assert_true(found, "missing %s in %s" % [corner, corners])


func test_footprint_rotated_quarter_turn_swaps_extent() -> void:
	var corners := Placement.footprint(Vector2.ZERO, SOFA, 90.0)
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for p in corners:
		bounds = bounds.expand(p)
	assert_almost_eq(bounds.size, Vector2(0.9, 2.0), Vector2(EPS, EPS))
	assert_false(Geometry2D.is_polygon_clockwise(corners))


func test_snaps_against_nearby_wall_facing_into_the_room() -> void:
	# Square room: wall w1 runs along z = 0 (thickness 0.2, inner face at z = 0.1).
	var project := Fixtures.square_room()
	var snap := Placement.snap_to_wall(project, Vector2(2.0, 0.65), SOFA)
	assert_false(snap.is_empty())
	assert_almost_eq(snap.pos, Vector2(2.0, 0.55), Vector2(EPS, EPS), "back flush with the inner face")
	assert_almost_eq(Placement.front_direction(snap.rotation_deg), Vector2(0, 1), Vector2(EPS, EPS),
		"front faces into the room")


func test_snaps_against_slanted_wall() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 4, 4)])
	project.walls.assign([Fixtures.wall("w", "a", "b")])
	var outward := Vector2(-1, 1).normalized()
	var near := Vector2(2, 2) + outward * (0.1 + 0.45 + 0.08)
	var snap := Placement.snap_to_wall(project, near, SOFA)
	assert_false(snap.is_empty())
	assert_almost_eq(snap.pos, Vector2(2, 2) + outward * 0.55, Vector2(EPS, EPS))
	assert_almost_eq(Placement.front_direction(snap.rotation_deg), outward, Vector2(EPS, EPS))


func test_no_snap_when_too_far_from_any_wall() -> void:
	assert_true(Placement.snap_to_wall(Fixtures.square_room(), Vector2(2, 2), SOFA).is_empty())


func test_no_snap_beyond_the_wall_ends() -> void:
	var project := ProjectData.new()
	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 2, 0)])
	project.walls.assign([Fixtures.wall("w", "a", "b")])
	assert_true(Placement.snap_to_wall(project, Vector2(3.0, 0.6), SOFA).is_empty())


func test_closest_wall_wins_in_a_corner() -> void:
	# Near the n1 corner: 0.08 m from w4's face, 0.12 m from w1's face.
	var project := Fixtures.square_room()
	var snap := Placement.snap_to_wall(project, Vector2(0.1 + 0.45 + 0.08, 0.1 + 0.45 + 0.12), SOFA)
	assert_almost_eq(Placement.front_direction(snap.rotation_deg), Vector2(1, 0), Vector2(EPS, EPS),
		"snapped to the west wall")


func test_ray_from_above_hits_item_top() -> void:
	var item := _item(Vector2(1, 1), 30.0)
	var distance := Placement.ray_distance_to_item(Vector3(1, 5, 1), Vector3.DOWN, item)
	assert_almost_eq(distance, 5.0 - SOFA.y, EPS)


func test_ray_misses_item_beside_it() -> void:
	var item := _item(Vector2(1, 1), 0.0)
	assert_eq(Placement.ray_distance_to_item(Vector3(3, 5, 1), Vector3.DOWN, item), -1.0)


func test_ray_respects_item_rotation() -> void:
	# Unrotated, the sofa spans x in [0, 2]; turned 90°, it spans x in [0.55, 1.45].
	var item := _item(Vector2(1, 1), 90.0)
	assert_eq(Placement.ray_distance_to_item(Vector3(1.8, 5, 1), Vector3.DOWN, item), -1.0)
	assert_gt(Placement.ray_distance_to_item(Vector3(1, 5, 1.8), Vector3.DOWN, item), 0.0)


func test_pick_returns_closest_item() -> void:
	var low := _item(Vector2(1, 1), 0.0, Vector3(1, 0.5, 1))
	low.id = "low"
	var tall := _item(Vector2(1, 1), 0.0, Vector3(0.5, 2.0, 0.5))
	tall.id = "tall"
	var items: Array[FurnitureItem] = [low, tall]
	assert_eq(Placement.pick_item(Vector3(1, 5, 1), Vector3.DOWN, items), "tall")


func test_pick_returns_empty_when_nothing_hit() -> void:
	var items: Array[FurnitureItem] = [_item(Vector2(1, 1), 0.0)]
	assert_eq(Placement.pick_item(Vector3(9, 5, 9), Vector3.DOWN, items), "")
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_placement`
Expected : FAIL avec `Identifier "Placement" not declared`.

- [ ] **Step 3: Implémenter**

`src/model/placement.gd` :

```gdscript
class_name Placement
extends RefCounted
## Pure placement maths for furniture on the floor plane (x, z), in metres.
## Rotation follows Godot's Y axis: rotation_deg = 0 means the item's front
## faces +z; its front direction is (sin θ, cos θ).

const GRID_STEP := 0.05
## A wall attracts an item whose back is closer than this to the wall face.
const WALL_SNAP_DISTANCE := 0.15


static func snap_to_grid(pos: Vector2, step: float = GRID_STEP) -> Vector2:
	return pos.snapped(Vector2(step, step))


## Unit vector the item's front faces on the floor plane.
static func front_direction(rotation_deg: float) -> Vector2:
	var theta := deg_to_rad(rotation_deg)
	return Vector2(sin(theta), cos(theta))


## Converts a point from the item's local frame (x = width axis, y = depth axis
## towards the front) to the floor plane.
static func to_world(item_pos: Vector2, rotation_deg: float, local: Vector2) -> Vector2:
	var theta := deg_to_rad(rotation_deg)
	var right := Vector2(cos(theta), -sin(theta))
	return item_pos + right * local.x + front_direction(rotation_deg) * local.y


## The item's rectangle on the floor, counter-clockwise.
static func footprint(pos: Vector2, size: Vector3, rotation_deg: float) -> PackedVector2Array:
	var hw := size.x / 2.0
	var hd := size.z / 2.0
	var corners := PackedVector2Array()
	for local in [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)]:
		corners.append(to_world(pos, rotation_deg, local))
	if Geometry2D.is_polygon_clockwise(corners):
		corners.reverse()
	return corners


## If the item's back is within WALL_SNAP_DISTANCE of a wall face, returns
## {"pos": Vector2, "rotation_deg": float} placing it flush against that face,
## facing away from the wall. Otherwise returns an empty dictionary.
## Only faces the item's centre stands in front of (within the wall's length)
## are considered; the closest one wins.
static func snap_to_wall(project: ProjectData, pos: Vector2, size: Vector3) -> Dictionary:
	var best := {}
	var best_gap := INF
	var half_depth := size.z / 2.0
	for wall in project.walls:
		var a := project.get_plan_node(wall.a)
		var b := project.get_plan_node(wall.b)
		if a == null or b == null or a.pos.is_equal_approx(b.pos):
			continue
		var along := (b.pos - a.pos).normalized()
		var length := a.pos.distance_to(b.pos)
		var t := (pos - a.pos).dot(along)
		if t < 0.0 or t > length:
			continue
		var on_wall := a.pos + along * t
		var offset := pos - on_wall
		if offset.length() < 1e-6:
			continue
		var outward := Vector2(-along.y, along.x)
		if offset.dot(outward) < 0.0:
			outward = -outward
		var face_distance := offset.dot(outward) - wall.thickness / 2.0
		var gap := absf(face_distance - half_depth)
		if gap <= WALL_SNAP_DISTANCE and gap < best_gap:
			best_gap = gap
			best = {
				"pos": on_wall + outward * (wall.thickness / 2.0 + half_depth),
				"rotation_deg": rad_to_deg(atan2(outward.x, outward.y)),
			}
	return best


## Distance along the ray to the item's box, or -1.0 if the ray misses it.
static func ray_distance_to_item(ray_origin: Vector3, ray_dir: Vector3, item: FurnitureItem) -> float:
	var to_local := Transform3D(Basis(Vector3.UP, deg_to_rad(item.rotation_deg)),
		Vector3(item.pos.x, 0, item.pos.y)).affine_inverse()
	var local_origin := to_local * ray_origin
	var local_dir := to_local.basis * ray_dir
	var box := AABB(Vector3(-item.size.x / 2.0, 0, -item.size.z / 2.0), item.size)
	var hit = box.intersects_ray(local_origin, local_dir)
	if hit == null:
		return -1.0
	return local_origin.distance_to(hit)


## The id of the closest item hit by the ray, or "" if none.
static func pick_item(ray_origin: Vector3, ray_dir: Vector3, items: Array[FurnitureItem]) -> String:
	var best_id := ""
	var best_distance := INF
	for item in items:
		var distance := ray_distance_to_item(ray_origin, ray_dir, item)
		if distance >= 0.0 and distance < best_distance:
			best_distance = distance
			best_id = item.id
	return best_id
```

- [ ] **Step 4: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 157`, code de sortie 0.

- [ ] **Step 5: Commit**

```bash
git add src/model/placement.gd src/model/placement.gd.uid tests/unit/test_placement.gd tests/unit/test_placement.gd.uid
git commit -m "feat(model): snap furniture to grid and walls, pick by ray"
```

---

### Task 3: Commandes annulables du store

**Files:**
- Modify (remplacement complet) : `src/store/project_store.gd`
- Test: `tests/unit/test_project_store_furniture.gd` (le fichier existant `test_project_store.gd` doit continuer à passer)

**Interfaces:**
- Consumes: `FurnitureItem.copy()` (Task 1), `ProjectValidator.validate`, `ProjectSerializer`.
- Produces (sur l'autoload `ProjectStore`) :
  - signaux `furniture_added(id)`, `furniture_changed(id)` et `furniture_removed(id)` ;
  - `EDITABLE_FIELDS := ["name", "size", "color", "pos", "rotation_deg"]` et `DUPLICATE_OFFSET := Vector2(0.3, 0.3)` ;
  - `get_furniture(id) -> FurnitureItem` et `next_furniture_id() -> String` ;
  - `add_furniture(item) -> bool`, `update_furniture(id, changes: Dictionary) -> bool`, `remove_furniture(id) -> bool` et `duplicate_furniture(id) -> String` ;
  - `undo() -> bool`, `redo() -> bool`, `can_undo() -> bool` et `can_redo() -> bool`.
  - L'historique est vidé à chaque `load_from_file` réussi.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_project_store_furniture.gd` :

```gdscript
extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())


func _sofa(id := "f1") -> FurnitureItem:
	return Fixtures.sofa(id)


func test_add_stores_a_copy_and_emits() -> void:
	watch_signals(_store)
	var item := _sofa()
	assert_true(_store.add_furniture(item))
	item.name = "changed outside"
	assert_eq(_store.get_furniture("f1").name, "Canapé")
	assert_signal_emitted_with_parameters(_store, "furniture_added", ["f1"])


func test_add_rejects_duplicate_id_and_invalid_item() -> void:
	_store.add_furniture(_sofa())
	assert_false(_store.add_furniture(_sofa()))
	var flat := _sofa("f2")
	flat.size.y = 0.0
	assert_false(_store.add_furniture(flat))
	assert_eq(_store.project.furniture.size(), 1)



func test_undo_add_removes_and_redo_restores() -> void:
	_store.add_furniture(_sofa())
	watch_signals(_store)
	assert_true(_store.undo())
	assert_null(_store.get_furniture("f1"))
	assert_signal_emitted_with_parameters(_store, "furniture_removed", ["f1"])
	assert_true(_store.redo())
	assert_not_null(_store.get_furniture("f1"))


func test_update_changes_fields_and_undo_restores_them() -> void:
	_store.add_furniture(_sofa())
	watch_signals(_store)
	assert_true(_store.update_furniture("f1", {"pos": Vector2(3, 1), "rotation_deg": 90.0}))
	assert_eq(_store.get_furniture("f1").pos, Vector2(3, 1))
	assert_eq(_store.get_furniture("f1").rotation_deg, 90.0)
	assert_signal_emitted_with_parameters(_store, "furniture_changed", ["f1"])
	_store.undo()
	assert_eq(_store.get_furniture("f1").pos, Vector2(2, 3))
	assert_eq(_store.get_furniture("f1").rotation_deg, Fixtures.sofa("x").rotation_deg)


func test_update_rejects_unknown_id_field_and_invalid_values() -> void:
	_store.add_furniture(_sofa())
	assert_false(_store.update_furniture("nope", {"name": "x"}))
	assert_false(_store.update_furniture("f1", {"id": "f2"}))
	assert_false(_store.update_furniture("f1", {"size": Vector3(1, 0, 1)}))
	assert_false(_store.update_furniture("f1", {}))
	assert_eq(_store.get_furniture("f1").size, Fixtures.sofa("x").size)


func test_rejected_update_leaves_history_untouched() -> void:
	_store.add_furniture(_sofa())
	_store.update_furniture("f1", {"size": Vector3(1, 0, 1)})
	_store.undo()
	assert_null(_store.get_furniture("f1"), "the only undo step is the add")


func test_remove_and_undo_restores_at_same_index() -> void:
	_store.add_furniture(_sofa("f1"))
	_store.add_furniture(_sofa("f2"))
	_store.add_furniture(_sofa("f3"))
	assert_true(_store.remove_furniture("f2"))
	assert_null(_store.get_furniture("f2"))
	_store.undo()
	assert_eq(_store.project.furniture[1].id, "f2")


func test_duplicate_gets_new_id_and_offset() -> void:
	_store.add_furniture(_sofa("f1"))
	var id: String = _store.duplicate_furniture("f1")
	assert_ne(id, "f1")
	assert_eq(_store.get_furniture(id).pos, Fixtures.sofa("x").pos + _store.DUPLICATE_OFFSET)
	assert_eq(_store.get_furniture(id).name, "Canapé")
	assert_eq(_store.duplicate_furniture("nope"), "")


func test_next_id_follows_the_highest_numbered_id() -> void:
	assert_eq(_store.next_furniture_id(), "f1")
	_store.add_furniture(_sofa("f2"))
	assert_eq(_store.next_furniture_id(), "f3")
	_store.add_furniture(_sofa("f1"))
	assert_eq(_store.next_furniture_id(), "f3")
	_store.add_furniture(_sofa("sofa"))
	assert_eq(_store.next_furniture_id(), "f3", "ids not shaped f<n> are ignored")


func test_loading_a_project_clears_history() -> void:
	_store.add_furniture(_sofa())
	_store.load_from_file("res://data/log16.json")
	assert_false(_store.can_undo())
	assert_false(_store.undo())


func test_undo_with_empty_history_is_harmless() -> void:
	assert_false(_store.undo())
	assert_false(_store.redo())
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_project_store_furniture`
Expected : FAIL (code de sortie 1). Les méthodes `add_furniture` et les suivantes n'existent pas : erreurs `Invalid call. Nonexistent function`.

- [ ] **Step 3: Implémenter**

Remplacer tout le contenu de `src/store/project_store.gd` par :

```gdscript
extends Node
## Autoload holding the open project. Views never edit the data directly:
## they call the store and react to its signals. Every edit goes through
## Godot's UndoRedo so it can be undone.

signal project_loaded
signal furniture_added(id: String)
signal furniture_changed(id: String)
signal furniture_removed(id: String)

## Fields of a FurnitureItem that update_furniture accepts.
const EDITABLE_FIELDS: PackedStringArray = ["name", "size", "color", "pos", "rotation_deg"]
## Offset of a duplicate from its original, so both stay visible.
const DUPLICATE_OFFSET := Vector2(0.3, 0.3)

var project: ProjectData = ProjectData.new()
var _history := UndoRedo.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_history.free()


## Replaces the open project. On failure the current project is kept and the
## reasons are returned.
func load_from_file(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray(["fichier introuvable : %s" % path])
	var result := ProjectSerializer.from_json(FileAccess.get_file_as_string(path))
	if not result.is_ok():
		return result.errors
	project = result.project
	_history.clear_history()
	project_loaded.emit()
	return PackedStringArray()


func get_furniture(id: String) -> FurnitureItem:
	for item in project.furniture:
		if item.id == id:
			return item
	return null


## "f" followed by one more than the highest numbered "f<n>" id in use.
func next_furniture_id() -> String:
	var highest := 0
	for item in project.furniture:
		var suffix := item.id.substr(1)
		if item.id.begins_with("f") and suffix.is_valid_int():
			highest = maxi(highest, suffix.to_int())
	return "f%d" % (highest + 1)


## Adds a copy of `item`. Returns false (and changes nothing) if the item is
## invalid or its id is already used.
func add_furniture(item: FurnitureItem) -> bool:
	if get_furniture(item.id) != null or not _is_valid(item):
		return false
	var stored := item.copy()
	_history.create_action("Ajouter %s" % stored.name)
	_history.add_do_method(_insert.bind(stored, project.furniture.size()))
	_history.add_undo_method(_delete.bind(stored.id))
	_history.commit_action()
	return true


## Applies `changes` (keys from EDITABLE_FIELDS) to the item. Returns false
## (and changes nothing) for an unknown id, unknown field or invalid result.
func update_furniture(id: String, changes: Dictionary) -> bool:
	var item := get_furniture(id)
	if item == null or changes.is_empty():
		return false
	var previous := {}
	var preview := item.copy()
	for key in changes:
		if not key in EDITABLE_FIELDS:
			return false
		previous[key] = item.get(key)
		preview.set(key, changes[key])
	if not _is_valid(preview):
		return false
	_history.create_action("Modifier %s" % item.name)
	_history.add_do_method(_apply.bind(id, changes))
	_history.add_undo_method(_apply.bind(id, previous))
	_history.commit_action()
	return true


func remove_furniture(id: String) -> bool:
	var item := get_furniture(id)
	if item == null:
		return false
	var index := project.furniture.find(item)
	_history.create_action("Supprimer %s" % item.name)
	_history.add_do_method(_delete.bind(id))
	_history.add_undo_method(_insert.bind(item.copy(), index))
	_history.commit_action()
	return true


## Adds a copy of the item, offset by DUPLICATE_OFFSET. Returns the new id, or
## "" for an unknown id.
func duplicate_furniture(id: String) -> String:
	var item := get_furniture(id)
	if item == null:
		return ""
	var clone := item.copy()
	clone.id = next_furniture_id()
	clone.pos += DUPLICATE_OFFSET
	add_furniture(clone)
	return clone.id


func undo() -> bool:
	return _history.undo()


func redo() -> bool:
	return _history.redo()


func can_undo() -> bool:
	return _history.has_undo()


func can_redo() -> bool:
	return _history.has_redo()


func _insert(item: FurnitureItem, index: int) -> void:
	project.furniture.insert(mini(index, project.furniture.size()), item.copy())
	furniture_added.emit(item.id)


func _delete(id: String) -> void:
	project.furniture.erase(get_furniture(id))
	furniture_removed.emit(id)


func _apply(id: String, values: Dictionary) -> void:
	var item := get_furniture(id)
	for key in values:
		item.set(key, values[key])
	furniture_changed.emit(id)


func _is_valid(item: FurnitureItem) -> bool:
	var probe := ProjectData.new()
	probe.furniture.append(item)
	return ProjectValidator.validate(probe).is_empty()
```

- [ ] **Step 4: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 168`, code de sortie 0. `test_project_store.gd`, qui existait déjà, passe toujours.

- [ ] **Step 5: Commit**

```bash
git add src/store/project_store.gd tests/unit/test_project_store_furniture.gd tests/unit/test_project_store_furniture.gd.uid
git commit -m "feat(store): add undoable furniture commands"
```

---

### Task 4: Vue des meubles

**Files:**
- Modify: `src/world/palette.gd`
- Create: `src/world/furniture_view.gd`
- Test: `tests/unit/test_furniture_view.gd`

**Interfaces:**
- Consumes: `Palette.material` (M1) et les signaux et méthodes du store (Task 3).
- Produces :
  - `Palette.SELECTION`, `GHOST_ALPHA := 0.5`, `OUTLINE_WIDTH := 0.03` et `Palette.outline_material()`.
  - `FurnitureView` (`Node3D`), dont chaque enfant est un `Node3D` nommé d'après l'id du meuble, avec un `MeshInstance3D` « Box ». L'aperçu est un enfant nommé « Ghost ». Méthodes :
    - `bind_store(store)` ;
    - `show_items(items)`, `add_item(item)`, `update_item(item)` et `remove_item(id)` ;
    - `preview_item(id, pos, rotation_deg)` ;
    - `set_selected(id)` et `selected_id() -> String` ;
    - `show_ghost(size, color)`, `move_ghost(pos, rotation_deg)`, `hide_ghost()` et `has_ghost() -> bool`.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_furniture_view.gd` :

```gdscript
extends GutTest

const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4

var _view: FurnitureView


func before_each() -> void:
	_view = FurnitureView.new()
	add_child_autofree(_view)


func _box(id: String) -> MeshInstance3D:
	return _view.get_node("%s/Box" % id) as MeshInstance3D


func _items(ids: Array) -> Array[FurnitureItem]:
	var items: Array[FurnitureItem] = []
	for id in ids:
		items.append(Fixtures.sofa(id))
	return items


func test_show_items_builds_one_block_per_item() -> void:
	_view.show_items(_items(["f1", "f2"]))
	assert_eq(_view.get_child_count(), 2)
	assert_not_null(_view.get_node_or_null("f1"))


func test_block_matches_item_size_position_and_rotation() -> void:
	var sofa := Fixtures.sofa("f1")
	_view.add_item(sofa)
	var node := _view.get_node("f1") as Node3D
	assert_almost_eq(node.position, Vector3(2, 0, 3), Vector3(EPS, EPS, EPS))
	assert_almost_eq(node.rotation.y, deg_to_rad(90.0), EPS)
	assert_eq((_box("f1").mesh as BoxMesh).size, sofa.size)
	assert_almost_eq(_box("f1").position.y, sofa.size.y / 2.0, EPS, "block stands on the floor")


func test_update_item_follows_new_data() -> void:
	var sofa := Fixtures.sofa("f1")
	_view.add_item(sofa)
	sofa.pos = Vector2(5, 1)
	sofa.size = Vector3(1, 2, 1)
	sofa.color = Color.RED
	_view.update_item(sofa)
	assert_almost_eq((_view.get_node("f1") as Node3D).position, Vector3(5, 0, 1), Vector3(EPS, EPS, EPS))
	assert_eq((_box("f1").mesh as BoxMesh).size, Vector3(1, 2, 1))
	assert_eq((_box("f1").material_override as StandardMaterial3D).albedo_color, Color.RED)


func test_remove_item_deletes_block_and_clears_selection() -> void:
	_view.show_items(_items(["f1"]))
	_view.set_selected("f1")
	_view.remove_item("f1")
	assert_null(_view.get_node_or_null("f1"))
	assert_eq(_view.selected_id(), "")


func test_selection_outlines_only_the_selected_item() -> void:
	_view.show_items(_items(["f1", "f2"]))
	_view.set_selected("f1")
	assert_not_null((_box("f1").material_override as StandardMaterial3D).next_pass)
	_view.set_selected("f2")
	assert_null((_box("f1").material_override as StandardMaterial3D).next_pass)
	assert_not_null((_box("f2").material_override as StandardMaterial3D).next_pass)
	_view.set_selected("")
	assert_null((_box("f2").material_override as StandardMaterial3D).next_pass)


func test_preview_moves_block_only() -> void:
	var sofa := Fixtures.sofa("f1")
	_view.add_item(sofa)
	_view.preview_item("f1", Vector2(7, 7), 0.0)
	assert_almost_eq((_view.get_node("f1") as Node3D).position, Vector3(7, 0, 7), Vector3(EPS, EPS, EPS))
	assert_eq(sofa.pos, Vector2(2, 3), "data untouched")


func test_ghost_is_translucent_and_follows() -> void:
	_view.show_ghost(Vector3(1, 1, 1), Color.BLUE)
	assert_true(_view.has_ghost())
	var mat := (_view.get_node("Ghost/Box") as MeshInstance3D).material_override as StandardMaterial3D
	assert_almost_eq(mat.albedo_color.a, Palette.GHOST_ALPHA, EPS)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	_view.move_ghost(Vector2(3, 4), 45.0)
	assert_almost_eq((_view.get_node("Ghost") as Node3D).position, Vector3(3, 0, 4), Vector3(EPS, EPS, EPS))
	_view.hide_ghost()
	await wait_physics_frames(1)
	assert_false(_view.has_ghost())


func test_show_ghost_twice_keeps_a_single_ghost() -> void:
	_view.show_ghost(Vector3.ONE, Color.BLUE)
	_view.show_ghost(Vector3.ONE, Color.RED)
	await wait_physics_frames(1)
	var ghosts := _view.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Ghost"))
	assert_eq(ghosts.size(), 1)


func test_show_items_replaces_previous_blocks() -> void:
	_view.show_items(_items(["f1", "f2"]))
	_view.show_items(_items(["f3"]))
	assert_eq(_view.get_child_count(), 1)
	assert_not_null(_view.get_node_or_null("f3"))


func test_updates_for_unknown_ids_are_ignored() -> void:
	_view.update_item(Fixtures.sofa("ghost"))
	_view.remove_item("ghost")
	_view.preview_item("ghost", Vector2.ZERO, 0.0)
	_view.set_selected("ghost")
	assert_eq(_view.get_child_count(), 0)
	assert_eq(_view.selected_id(), "")


func test_bound_store_edits_are_mirrored() -> void:
	var store: Node = autofree(preload("res://src/store/project_store.gd").new())
	_view.bind_store(store)
	store.add_furniture(Fixtures.sofa("f1"))
	assert_not_null(_view.get_node_or_null("f1"))
	store.update_furniture("f1", {"pos": Vector2(1, 1)})
	assert_almost_eq((_view.get_node("f1") as Node3D).position, Vector3(1, 0, 1), Vector3(EPS, EPS, EPS))
	store.remove_furniture("f1")
	assert_null(_view.get_node_or_null("f1"))
	store.undo()
	assert_not_null(_view.get_node_or_null("f1"), "undo brings the block back")
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_furniture_view`
Expected : FAIL avec `Identifier "FurnitureView" not declared`.

- [ ] **Step 3: Compléter la palette**

Remplacer tout le contenu de `src/world/palette.gd` par :

```gdscript
class_name Palette
extends RefCounted
## The fixed v1 colour palette (no material system before v2).

const WALL := Color("#f2ede4")
const WALL_TOP := Color("#8f8478")
const GLASS := Color(0.75, 0.88, 0.95, 0.35)
const SELECTION := Color("#ffd27a")
const GHOST_ALPHA := 0.5
## How far the selection outline grows around the item, in metres.
const OUTLINE_WIDTH := 0.03
const FLOORS := {
	"wood": Color("#c99a6b"),
	"tile": Color("#c9ccd0"),
	"outdoor": Color("#a9a39a"),
}
const FLOOR_FALLBACK := Color("#cccccc")


static func floor_color(kind: String) -> Color:
	return FLOORS.get(kind, FLOOR_FALLBACK)


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## Unshaded shell drawn behind a mesh's back faces, slightly inflated, so the
## mesh appears outlined.
static func outline_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = SELECTION
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = OUTLINE_WIDTH
	return mat
```

- [ ] **Step 4: Écrire la vue**

`src/world/furniture_view.gd` :

```gdscript
class_name FurnitureView
extends Node3D
## Draws furniture items as coloured blocks, the selection outline, and the
## translucent ghost used while placing a new item. Never edits the project.

const GHOST_NAME := "Ghost"

var _selected_id := ""
var _outline := Palette.outline_material()
var _store: Node


## Keeps the blocks in sync with a ProjectStore (the autoload, or a test double).
## Bound methods (not lambdas) so the connections die with this node.
func bind_store(store: Node) -> void:
	_store = store
	store.project_loaded.connect(_on_project_loaded)
	store.furniture_added.connect(_on_furniture_added)
	store.furniture_changed.connect(_on_furniture_changed)
	store.furniture_removed.connect(remove_item)
	_on_project_loaded()


func _on_project_loaded() -> void:
	show_items(_store.project.furniture)


func _on_furniture_added(id: String) -> void:
	add_item(_store.get_furniture(id))


func _on_furniture_changed(id: String) -> void:
	update_item(_store.get_furniture(id))


func show_items(items: Array[FurnitureItem]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_selected_id = ""
	for item in items:
		add_item(item)


func add_item(item: FurnitureItem) -> void:
	var node := _block(item.size, Palette.material(item.color))
	node.name = item.id
	add_child(node)
	_place(node, item.pos, item.rotation_deg)


## Rebuilds the item's block from its current data.
func update_item(item: FurnitureItem) -> void:
	var node := get_node_or_null(NodePath(item.id)) as Node3D
	if node == null:
		return
	var box := node.get_node("Box") as MeshInstance3D
	(box.mesh as BoxMesh).size = item.size
	box.position.y = item.size.y / 2.0
	(box.material_override as StandardMaterial3D).albedo_color = item.color
	_place(node, item.pos, item.rotation_deg)


func remove_item(id: String) -> void:
	var node := get_node_or_null(NodePath(id))
	if node == null:
		return
	if id == _selected_id:
		_selected_id = ""
	remove_child(node)
	node.queue_free()


## Moves the item's block without touching the data (live drag feedback).
func preview_item(id: String, pos: Vector2, rotation_deg: float) -> void:
	var node := get_node_or_null(NodePath(id)) as Node3D
	if node != null:
		_place(node, pos, rotation_deg)


## Outlines the item with this id; "" or an unknown id clears the selection.
func set_selected(id: String) -> void:
	if _selected_id != "":
		_set_outline(_selected_id, false)
	_selected_id = id if has_node(NodePath(id)) and id != GHOST_NAME else ""
	if _selected_id != "":
		_set_outline(_selected_id, true)


func selected_id() -> String:
	return _selected_id


func show_ghost(size: Vector3, color: Color) -> void:
	hide_ghost()
	var ghost_color := color
	ghost_color.a = Palette.GHOST_ALPHA
	var ghost := _block(size, Palette.material(ghost_color))
	ghost.name = GHOST_NAME
	add_child(ghost)


func move_ghost(pos: Vector2, rotation_deg: float) -> void:
	var ghost := get_node_or_null(GHOST_NAME) as Node3D
	if ghost != null:
		_place(ghost, pos, rotation_deg)


func hide_ghost() -> void:
	var ghost := get_node_or_null(GHOST_NAME)
	if ghost != null:
		remove_child(ghost)
		ghost.queue_free()


func has_ghost() -> bool:
	return get_node_or_null(GHOST_NAME) != null


func _set_outline(id: String, on: bool) -> void:
	var node := get_node_or_null(NodePath(id))
	if node == null:
		return
	var mat := (node.get_node("Box") as MeshInstance3D).material_override as StandardMaterial3D
	mat.next_pass = _outline if on else null


static func _block(size: Vector3, material: StandardMaterial3D) -> Node3D:
	var node := Node3D.new()
	var box := MeshInstance3D.new()
	box.name = "Box"
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = material
	box.position.y = size.y / 2.0
	node.add_child(box)
	return node


static func _place(node: Node3D, pos: Vector2, rotation_deg: float) -> void:
	node.position = Vector3(pos.x, 0, pos.y)
	node.rotation = Vector3(0, deg_to_rad(rotation_deg), 0)
```

- [ ] **Step 5: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 179`, code de sortie 0.

- [ ] **Step 6: Commit**

```bash
git add src/world/palette.gd src/world/furniture_view.gd src/world/furniture_view.gd.uid tests/unit/test_furniture_view.gd tests/unit/test_furniture_view.gd.uid
git commit -m "feat(world): draw furniture blocks, selection outline and ghost"
```

---

### Task 5: Outil d'édition des meubles

**Files:**
- Create: `src/tools/furniture_tool.gd`
- Test: `tests/unit/test_furniture_tool.gd`

**Interfaces:**
- Consumes: `Placement` (Task 2), les commandes du store (Task 3), `FurnitureView` (Task 4) et `FurniturePreset.make_item` (Task 1).
- Produces : `FurnitureTool` (`Node`), avec :
  - `signal selection_changed(id)` ;
  - `ROTATE_STEP_DEG := 90.0` et `FINE_ROTATE_STEP_DEG := 15.0` ;
  - `setup(store, view, camera)`, à appeler **après** `view.bind_store(store)` ;
  - `begin_placement(preset)`, `cancel_placement()`, `is_placing() -> bool` et `selected_id() -> String`.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_furniture_tool.gd` :

```gdscript
extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-3
const SOFA_PRESET := "res://data/presets/sofa_3.tres"

var _store: Node
var _view: FurnitureView
var _camera: Camera3D
var _tool: FurnitureTool


func before_each() -> void:
	_store = autofree(Store.new())
	_store.project = Fixtures.square_room()
	_store.project.furniture.clear()
	_view = FurnitureView.new()
	add_child_autofree(_view)
	_view.bind_store(_store)
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.look_at_from_position(Vector3(2, 12, 2), Vector3(2, 0, 2), Vector3(0, 0, -1))
	_camera.current = true
	_tool = FurnitureTool.new()
	add_child_autofree(_tool)
	_tool.setup(_store, _view, _camera)


func _screen(pos: Vector2, height := 0.0) -> Vector2:
	return _camera.unproject_position(Vector3(pos.x, height, pos.y))


func _move(pos: Vector2, alt := false, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _screen(pos)
	event.alt_pressed = alt
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_tool._unhandled_input(event)


func _click(pos: Vector2, pressed := true, height := 0.0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _screen(pos, height)
	_tool._unhandled_input(event)


func _key(keycode: Key, command := false, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	# Cmd on macOS, Ctrl elsewhere: set both so the test runs on any platform.
	event.ctrl_pressed = command
	event.meta_pressed = command
	event.shift_pressed = shift
	_tool._unhandled_input(event)


func _wheel(up: bool, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.shift_pressed = shift
	_tool._unhandled_input(event)


func _add_sofa(pos: Vector2, rotation_deg := 0.0) -> String:
	var item := Fixtures.sofa(_store.next_furniture_id())
	item.pos = pos
	item.rotation_deg = rotation_deg
	_store.add_furniture(item)
	return item.id


func test_placement_ghost_follows_mouse_on_the_grid() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	assert_true(_view.has_ghost())
	_move(Vector2(2.013, 2.037))
	var ghost := _view.get_node("Ghost") as Node3D
	assert_almost_eq(ghost.position, Vector3(2.0, 0, 2.05), Vector3(EPS, EPS, EPS))


func test_alt_disables_grid_snapping() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2.013, 2.037), true)
	assert_almost_eq((_view.get_node("Ghost") as Node3D).position, Vector3(2.013, 0, 2.037), Vector3(EPS, EPS, EPS))


func test_click_places_item_and_selects_it() -> void:
	watch_signals(_tool)
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 2))
	_click(Vector2(2, 2))
	assert_eq(_store.project.furniture.size(), 1)
	var item: FurnitureItem = _store.project.furniture[0]
	assert_eq(item.preset, "sofa_3")
	assert_almost_eq(item.pos, Vector2(2, 2), Vector2(EPS, EPS))
	assert_false(_tool.is_placing())
	assert_eq(_tool.selected_id(), item.id)
	assert_signal_emitted_with_parameters(_tool, "selection_changed", [item.id])
	await wait_physics_frames(1)
	assert_false(_view.has_ghost())


func test_ghost_snaps_against_a_wall() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 0.62))
	var ghost := _view.get_node("Ghost") as Node3D
	assert_almost_eq(ghost.position, Vector3(2, 0, 0.55), Vector3(EPS, EPS, EPS))


func test_escape_cancels_placement() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_key(KEY_ESCAPE)
	_click(Vector2(2, 2))
	assert_false(_tool.is_placing())
	assert_eq(_store.project.furniture.size(), 0)


func test_r_turns_the_ghost_a_quarter() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_move(Vector2(2, 2))
	_key(KEY_R)
	_click(Vector2(2, 2))
	assert_almost_eq(_store.project.furniture[0].rotation_deg, 90.0, EPS)


func test_click_on_item_selects_and_click_on_floor_deselects() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2), true, 0.85)
	_click(Vector2(2, 2), false, 0.85)
	assert_eq(_tool.selected_id(), id)
	_click(Vector2(3.5, 3.5))
	_click(Vector2(3.5, 3.5), false)
	assert_eq(_tool.selected_id(), "")


func test_drag_moves_item_in_one_undo_step() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2))
	_move(Vector2(2.5, 2.3), false, true)
	_move(Vector2(2.6, 2.4), false, true)
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS), "data waits for release")
	_click(Vector2(2.6, 2.4), false)
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2.6, 2.4), Vector2(EPS, EPS))
	_store.undo()
	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS))


func test_click_without_moving_adds_no_history() -> void:
	_add_sofa(Vector2(2, 2))
	_click(Vector2(2, 2))
	_click(Vector2(2, 2), false)
	_store.undo()
	assert_eq(_store.project.furniture.size(), 0, "the only step was the add")


func test_r_rotates_selected_item() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_key(KEY_R)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 90.0, EPS)


func test_shift_wheel_rotates_in_fine_steps() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_wheel(true, true)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 15.0, EPS)
	_wheel(false, true)
	_wheel(false, true)
	assert_almost_eq(_store.get_furniture(id).rotation_deg, 345.0, EPS)


func test_plain_wheel_is_left_to_the_camera() -> void:
	var id := _add_sofa(Vector2(2, 2), 0.0)
	_tool._select(id)
	_wheel(true, false)
	assert_eq(_store.get_furniture(id).rotation_deg, 0.0)


func test_delete_removes_selected_and_clears_selection() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_tool._select(id)
	watch_signals(_tool)
	_key(KEY_DELETE)
	assert_null(_store.get_furniture(id))
	assert_eq(_tool.selected_id(), "")
	assert_signal_emitted_with_parameters(_tool, "selection_changed", [""])


func test_command_d_duplicates_and_selects_the_copy() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_tool._select(id)
	_key(KEY_D, true)
	assert_eq(_store.project.furniture.size(), 2)
	assert_ne(_tool.selected_id(), id)


func test_command_z_undoes_and_shift_redoes() -> void:
	_add_sofa(Vector2(2, 2))
	_key(KEY_Z, true)
	assert_eq(_store.project.furniture.size(), 0)
	_key(KEY_Z, true, true)
	assert_eq(_store.project.furniture.size(), 1)


func test_undoing_the_selected_items_creation_clears_selection() -> void:
	var id := _add_sofa(Vector2(2, 2))
	_tool._select(id)
	_store.undo()
	assert_eq(_tool.selected_id(), "")


func test_loading_a_project_cancels_placement() -> void:
	_tool.begin_placement(load(SOFA_PRESET))
	_store.load_from_file("res://data/log16.json")
	assert_false(_tool.is_placing())
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_furniture_tool`
Expected : FAIL avec `Identifier "FurnitureTool" not declared`.

- [ ] **Step 3: Implémenter**

`src/tools/furniture_tool.gd` :

```gdscript
class_name FurnitureTool
extends Node
## Mouse and keyboard editing of furniture: place from the catalogue, select,
## drag, rotate, delete, duplicate, undo/redo. Changes go through the store;
## the view only shows previews while the mouse is down.
## Call setup() after the view's bind_store(), so the view has already reacted
## to a store signal when this tool reads the selection back.

signal selection_changed(id: String)

const ROTATE_STEP_DEG := 90.0
const FINE_ROTATE_STEP_DEG := 15.0

var store: Node
var view: FurnitureView
var camera: Camera3D

var _placing: FurniturePreset
var _ghost_pos := Vector2.ZERO
var _ghost_rotation := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO
var _drag_pos := Vector2.ZERO
var _drag_rotation := 0.0
var _selection := ""  # last id announced through selection_changed


func setup(p_store: Node, p_view: FurnitureView, p_camera: Camera3D) -> void:
	store = p_store
	view = p_view
	camera = p_camera
	store.furniture_removed.connect(_on_furniture_removed)
	store.project_loaded.connect(_on_project_loaded)


func is_placing() -> bool:
	return _placing != null


func selected_id() -> String:
	return view.selected_id()


## Starts placing a new item: a ghost follows the mouse until a left click.
func begin_placement(preset: FurniturePreset) -> void:
	_select("")
	_placing = preset
	_ghost_rotation = 0.0
	view.show_ghost(preset.size, preset.color)
	var mouse := camera.get_viewport().get_mouse_position()
	_update_ghost(mouse, false)


func cancel_placement() -> void:
	_placing = null
	view.hide_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if store == null:
		return
	if event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _placing != null:
		_update_ghost(event.position, event.alt_pressed)
	elif _dragging:
		var ground = _ground_point(event.position)
		if ground == null:
			return
		var item: FurnitureItem = store.get_furniture(selected_id())
		var placed := _snap(ground + _drag_offset, item.size, _drag_rotation, event.alt_pressed)
		_drag_pos = placed.pos
		_drag_rotation = placed.rotation_deg
		view.preview_item(item.id, _drag_pos, _drag_rotation)
		get_viewport().set_input_as_handled()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_press(event)
			elif _dragging:
				_finish_drag()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and event.shift_pressed and selected_id() != "":
				var step := FINE_ROTATE_STEP_DEG if event.button_index == MOUSE_BUTTON_WHEEL_UP else -FINE_ROTATE_STEP_DEG
				_rotate_selected(step)
				get_viewport().set_input_as_handled()


func _on_left_press(event: InputEventMouseButton) -> void:
	if _placing != null:
		_place_ghost()
		get_viewport().set_input_as_handled()
		return
	var id := Placement.pick_item(camera.project_ray_origin(event.position),
		camera.project_ray_normal(event.position), store.project.furniture)
	if id == "":
		_select("")  # Left unhandled so the camera still sees double clicks.
		return
	_select(id)
	var ground = _ground_point(event.position)
	var item: FurnitureItem = store.get_furniture(id)
	if ground != null:
		_dragging = true
		_drag_offset = item.pos - ground
		_drag_pos = item.pos
		_drag_rotation = item.rotation_deg
	get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	_dragging = false
	var item: FurnitureItem = store.get_furniture(selected_id())
	if item == null:
		return
	if not item.pos.is_equal_approx(_drag_pos) or not is_equal_approx(item.rotation_deg, _drag_rotation):
		store.update_furniture(item.id, {"pos": _drag_pos, "rotation_deg": _drag_rotation})
	get_viewport().set_input_as_handled()


func _on_key(event: InputEventKey) -> void:
	var command := event.is_command_or_control_pressed()
	if command and event.keycode == KEY_Z:
		if event.shift_pressed:
			store.redo()
		else:
			store.undo()
	elif command and event.keycode == KEY_D:
		if selected_id() != "":
			_select(store.duplicate_furniture(selected_id()))
	elif event.keycode == KEY_ESCAPE:
		if _placing != null:
			cancel_placement()
		else:
			_select("")
	elif event.keycode == KEY_R and _placing != null:
		_ghost_rotation = fposmod(_ghost_rotation + ROTATE_STEP_DEG, 360.0)
		view.move_ghost(_ghost_pos, _ghost_rotation)
	elif event.keycode == KEY_R and selected_id() != "":
		_rotate_selected(ROTATE_STEP_DEG)
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE] and selected_id() != "":
		store.remove_furniture(selected_id())
	else:
		return
	get_viewport().set_input_as_handled()


func _rotate_selected(step_deg: float) -> void:
	var item: FurnitureItem = store.get_furniture(selected_id())
	store.update_furniture(item.id, {"rotation_deg": fposmod(item.rotation_deg + step_deg, 360.0)})


func _update_ghost(screen_pos: Vector2, free_move: bool) -> void:
	var ground = _ground_point(screen_pos)
	if ground == null:
		return
	var placed := _snap(ground, _placing.size, _ghost_rotation, free_move)
	_ghost_pos = placed.pos
	_ghost_rotation = placed.rotation_deg
	view.move_ghost(_ghost_pos, _ghost_rotation)


func _place_ghost() -> void:
	var item := _placing.make_item(store.next_furniture_id(), _ghost_pos)
	item.rotation_deg = _ghost_rotation
	cancel_placement()
	if store.add_furniture(item):
		_select(item.id)


## Grid snapping (unless `free_move`), then wall snapping which may also turn the item.
func _snap(pos: Vector2, size: Vector3, rotation_deg: float, free_move: bool) -> Dictionary:
	var snapped := pos if free_move else Placement.snap_to_grid(pos)
	var wall := Placement.snap_to_wall(store.project, snapped, size)
	if wall.is_empty():
		return {"pos": snapped, "rotation_deg": rotation_deg}
	return wall


## Where the mouse ray meets the floor (y = 0), or null.
func _ground_point(screen_pos: Vector2) -> Variant:
	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos))
	return null if hit == null else Vector2(hit.x, hit.z)


func _select(id: String) -> void:
	view.set_selected(id)
	_sync_selection()


## Announces the view's selection if it changed (e.g. the item was deleted or undone).
func _sync_selection() -> void:
	var current := view.selected_id()
	if current == _selection:
		return
	if current == "":
		_dragging = false
	_selection = current
	selection_changed.emit(current)


func _on_furniture_removed(_id: String) -> void:
	_sync_selection()


func _on_project_loaded() -> void:
	cancel_placement()
	_sync_selection()
```

- [ ] **Step 4: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 196`, code de sortie 0.

- [ ] **Step 5: Commit**

```bash
git add src/tools tests/unit/test_furniture_tool.gd tests/unit/test_furniture_tool.gd.uid
git commit -m "feat(tools): place, select, drag, rotate and delete furniture"
```

---

### Task 6: Panneaux catalogue et propriétés

**Files:**
- Create: `src/ui/catalog_panel.gd`, `src/ui/properties_panel.gd`
- Test: `tests/unit/test_ui_panels.gd`

**Interfaces:**
- Consumes: `FurnitureCatalog.load_presets` et `CATEGORIES` (Task 1), `Palette.SELECTION` (Task 4), les commandes et le signal `furniture_changed` du store (Task 3).
- Produces :
  - `CatalogPanel` (`PanelContainer`, nommé « Catalog ») : `signal preset_chosen(preset)`, `populate(presets)` et `button_for(preset_id) -> Button`.
  - `PropertiesPanel` (`PanelContainer`, nommé « Properties ») : `bind_store(store)`, `show_item(id)` et `shown_id() -> String`. Ses champs se nomment `Name`, `Width`, `Depth`, `Height`, `Color`, `X`, `Z` et `Rotation`.

- [ ] **Step 1: Écrire le test en échec**

`tests/unit/test_ui_panels.gd` :

```gdscript
extends GutTest

const Store := preload("res://src/store/project_store.gd")
const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
const EPS := 1e-4

var _store: Node


func before_each() -> void:
	_store = autofree(Store.new())


func test_catalog_has_a_button_per_preset_and_category_headers() -> void:
	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
	var presets := FurnitureCatalog.load_presets()
	panel.populate(presets)
	for preset in presets:
		assert_not_null(panel.button_for(preset.id), preset.id)
	var labels := panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	for category in FurnitureCatalog.CATEGORIES:
		assert_has(labels, category)


func test_catalog_button_emits_its_preset() -> void:
	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
	panel.populate(FurnitureCatalog.load_presets())
	watch_signals(panel)
	panel.button_for("bed_160").pressed.emit()
	assert_signal_emitted(panel, "preset_chosen")
	var preset: FurniturePreset = get_signal_parameters(panel, "preset_chosen")[0]
	assert_eq(preset.id, "bed_160")


func test_catalog_tooltip_shows_dimensions_in_cm() -> void:
	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
	panel.populate(FurnitureCatalog.load_presets())
	assert_eq(panel.button_for("sofa_3").tooltip_text, "210 × 90 × 85 cm")


func _properties() -> PropertiesPanel:
	var panel: PropertiesPanel = add_child_autofree(PropertiesPanel.new())
	panel.bind_store(_store)
	_store.add_furniture(Fixtures.sofa("f1"))
	return panel


func test_properties_hidden_without_selection() -> void:
	var panel := _properties()
	assert_false(panel.visible)
	panel.show_item("f1")
	assert_true(panel.visible)
	panel.show_item("")
	assert_false(panel.visible)
	panel.show_item("unknown")
	assert_false(panel.visible)


func test_properties_show_item_values_without_editing() -> void:
	var panel := _properties()
	panel.show_item("f1")
	assert_eq((panel.find_child("Name", true, false) as LineEdit).text, "Canapé")
	assert_almost_eq((panel.find_child("Width", true, false) as SpinBox).value, 210.0, EPS)
	assert_almost_eq((panel.find_child("Depth", true, false) as SpinBox).value, 90.0, EPS)
	assert_almost_eq((panel.find_child("Height", true, false) as SpinBox).value, 85.0, EPS)
	assert_almost_eq((panel.find_child("Rotation", true, false) as SpinBox).value, 90.0, EPS)
	_store.undo()  # only the add is in the history
	assert_null(_store.get_furniture("f1"))


func test_editing_width_updates_the_store_in_metres() -> void:
	var panel := _properties()
	panel.show_item("f1")
	(panel.find_child("Width", true, false) as SpinBox).value = 180.0
	assert_almost_eq(_store.get_furniture("f1").size.x, 1.8, EPS)
	assert_almost_eq(_store.get_furniture("f1").size.z, 0.9, EPS, "depth untouched")


func test_editing_position_and_rotation_updates_the_store() -> void:
	var panel := _properties()
	panel.show_item("f1")
	(panel.find_child("X", true, false) as SpinBox).value = 1.25
	(panel.find_child("Rotation", true, false) as SpinBox).value = 45.0
	assert_almost_eq(_store.get_furniture("f1").pos, Vector2(1.25, 3), Vector2(EPS, EPS))
	assert_almost_eq(_store.get_furniture("f1").rotation_deg, 45.0, EPS)


func test_renaming_on_submit() -> void:
	var panel := _properties()
	panel.show_item("f1")
	var field := panel.find_child("Name", true, false) as LineEdit
	field.text = "  Canapé du salon "
	field.text_submitted.emit(field.text)
	assert_eq(_store.get_furniture("f1").name, "Canapé du salon")


func test_blank_name_is_ignored() -> void:
	var panel := _properties()
	panel.show_item("f1")
	var field := panel.find_child("Name", true, false) as LineEdit
	field.text = "   "
	field.text_submitted.emit(field.text)
	assert_eq(_store.get_furniture("f1").name, "Canapé")


func test_panel_refreshes_when_item_changes_elsewhere() -> void:
	var panel := _properties()
	panel.show_item("f1")
	_store.update_furniture("f1", {"pos": Vector2(0.5, 0.75)})
	assert_almost_eq((panel.find_child("Z", true, false) as SpinBox).value, 0.75, EPS)


func test_refresh_does_not_create_extra_history() -> void:
	var panel := _properties()
	panel.show_item("f1")
	_store.update_furniture("f1", {"rotation_deg": 10.0})
	_store.undo()
	_store.undo()
	assert_null(_store.get_furniture("f1"), "two steps: add and rotate")
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_ui_panels`
Expected : FAIL avec `Identifier "CatalogPanel" not declared`.

- [ ] **Step 3: Implémenter**

`src/ui/catalog_panel.gd` :

```gdscript
class_name CatalogPanel
extends PanelContainer
## Left-hand catalogue: one button per preset, grouped by category.

signal preset_chosen(preset: FurniturePreset)

const PANEL_WIDTH := 220.0


func _init() -> void:
	name = "Catalog"
	custom_minimum_size.x = PANEL_WIDTH


func populate(presets: Array[FurniturePreset]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var title := Label.new()
	title.text = "Catalogue"
	list.add_child(title)
	var current_category := ""
	for preset in presets:
		if preset.category != current_category:
			current_category = preset.category
			var header := Label.new()
			header.text = current_category
			header.add_theme_color_override("font_color", Palette.SELECTION)
			list.add_child(header)
		var button := Button.new()
		button.name = preset.id
		button.text = preset.name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "%d × %d × %d cm" % [roundi(preset.size.x * 100), roundi(preset.size.z * 100),
			roundi(preset.size.y * 100)]
		button.pressed.connect(preset_chosen.emit.bind(preset))
		list.add_child(button)


func button_for(preset_id: String) -> Button:
	return find_child(preset_id, true, false) as Button
```

`src/ui/properties_panel.gd` :

```gdscript
class_name PropertiesPanel
extends PanelContainer
## Right-hand panel editing the selected item. Every committed field becomes
## one store edit (and one undo step). Hidden when nothing is selected.

const PANEL_WIDTH := 260.0
const CM_PER_M := 100.0
const MIN_SIZE_CM := 1.0
const MAX_SIZE_CM := 1000.0
const POSITION_LIMIT_M := 100.0
const HINT := "R : pivoter · Maj + molette : ±15°\nSuppr : supprimer · Ctrl/Cmd + D : dupliquer\nCtrl/Cmd + Z : annuler"

var store: Node
var _item_id := ""
var _filling := false
var _name: LineEdit
var _width: SpinBox
var _depth: SpinBox
var _height: SpinBox
var _color: ColorPickerButton
var _x: SpinBox
var _z: SpinBox
var _rotation: SpinBox


func _init() -> void:
	name = "Properties"
	custom_minimum_size.x = PANEL_WIDTH
	var form := VBoxContainer.new()
	add_child(form)
	var title := Label.new()
	title.text = "Propriétés"
	form.add_child(title)
	_name = LineEdit.new()
	_name.name = "Name"
	_name.text_submitted.connect(func(_text: String) -> void: _commit_name())
	_name.focus_exited.connect(_commit_name)
	_row(form, "Nom", _name)
	_width = _spin(form, "Width", "Largeur (cm)", MIN_SIZE_CM, MAX_SIZE_CM, 1.0)
	_depth = _spin(form, "Depth", "Profondeur (cm)", MIN_SIZE_CM, MAX_SIZE_CM, 1.0)
	_height = _spin(form, "Height", "Hauteur (cm)", MIN_SIZE_CM, MAX_SIZE_CM, 1.0)
	_color = ColorPickerButton.new()
	_color.name = "Color"
	_color.edit_alpha = false
	_color.custom_minimum_size.y = 28
	_color.popup_closed.connect(func() -> void: _commit({"color": _color.color}))
	_row(form, "Couleur", _color)
	_x = _spin(form, "X", "Position X (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
	_z = _spin(form, "Z", "Position Z (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
	_rotation = _spin(form, "Rotation", "Rotation (°)", 0.0, 360.0, 1.0)
	var hint := Label.new()
	hint.text = HINT
	hint.add_theme_font_size_override("font_size", 11)
	form.add_child(hint)
	for spin in [_width, _depth, _height]:
		spin.value_changed.connect(func(_v: float) -> void: _commit_size())
	_x.value_changed.connect(func(_v: float) -> void: _commit({"pos": Vector2(_x.value, _z.value)}))
	_z.value_changed.connect(func(_v: float) -> void: _commit({"pos": Vector2(_x.value, _z.value)}))
	_rotation.value_changed.connect(func(v: float) -> void: _commit({"rotation_deg": fposmod(v, 360.0)}))
	visible = false


func bind_store(p_store: Node) -> void:
	store = p_store
	store.furniture_changed.connect(_on_furniture_changed)


## Shows the item with this id, or hides the panel for "" / an unknown id.
func show_item(id: String) -> void:
	var item: FurnitureItem = store.get_furniture(id) if id != "" else null
	_item_id = item.id if item != null else ""
	visible = item != null
	if item == null:
		return
	_filling = true
	_name.text = item.name
	_width.value = item.size.x * CM_PER_M
	_depth.value = item.size.z * CM_PER_M
	_height.value = item.size.y * CM_PER_M
	_color.color = item.color
	_x.value = item.pos.x
	_z.value = item.pos.y
	_rotation.value = item.rotation_deg
	_filling = false


func shown_id() -> String:
	return _item_id


func _on_furniture_changed(id: String) -> void:
	if id == _item_id:
		show_item(id)


func _commit_name() -> void:
	if _name.text.strip_edges() != "":
		_commit({"name": _name.text.strip_edges()})


func _commit_size() -> void:
	_commit({"size": Vector3(_width.value, _height.value, _depth.value) / CM_PER_M})


## Sends the change unless the panel is being filled or nothing would change.
func _commit(changes: Dictionary) -> void:
	if _filling or _item_id == "":
		return
	var item: FurnitureItem = store.get_furniture(_item_id)
	for key in changes:
		if item.get(key) != changes[key]:
			store.update_furniture(_item_id, changes)
			return


static func _row(form: VBoxContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	form.add_child(label)
	form.add_child(control)


func _spin(form: VBoxContainer, node_name: String, label_text: String, min_value: float, max_value: float,
		step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = false
	_row(form, label_text, spin)
	return spin
```

- [ ] **Step 4: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 207`, code de sortie 0.

- [ ] **Step 5: Commit**

```bash
git add src/ui tests/unit/test_ui_panels.gd tests/unit/test_ui_panels.gd.uid
git commit -m "feat(ui): add furniture catalogue and properties panels"
```

---

### Task 7: Assemblage dans la scène principale

**Files:**
- Modify (remplacement complet) : `src/main.gd`, `tests/unit/test_main_scene.gd`
- Modify: `README.md`

**Interfaces:**
- Consumes: tout ce qui précède, plus l'autoload `ProjectStore`.
- Produces : la scène principale, dont les enfants comprennent `Furniture` (`FurnitureView`), `Camera`, `FurnitureTool` (placé **après** `Camera`) et `UI` (`CanvasLayer` contenant `Catalog` et `Properties`).

- [ ] **Step 1: Écrire le test en échec**

Remplacer tout le contenu de `tests/unit/test_main_scene.gd` par :

```gdscript
extends GutTest
## Smoke test: the application scene loads the shipped plan and builds it.

const MainScene := preload("res://src/main.tscn")


func test_main_scene_builds_the_shipped_plan() -> void:
	var main: Node3D = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(2)
	var walls := main.get_node_or_null("World/Walls")
	assert_not_null(walls)
	assert_eq(walls.get_child_count(), ProjectStore.project.walls.size())
	assert_eq(main.get_node("World/Floors").get_child_count(), ProjectStore.project.rooms.size())
	assert_not_null(main.get_node_or_null("Camera"))
	assert_not_null(main.get_node_or_null("Environment"))
	assert_not_null(main.get_node_or_null("Sun"))
	assert_not_null(main.get_node_or_null("Furniture"))
	assert_not_null(main.get_node_or_null("FurnitureTool"))
	assert_not_null(main.find_child("Catalog", true, false))
	assert_not_null(main.find_child("Properties", true, false))


func test_tool_receives_input_before_the_camera() -> void:
	var main: Node3D = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(1)
	assert_gt(main.get_node("FurnitureTool").get_index(), main.get_node("Camera").get_index())


func test_choosing_a_preset_starts_placement() -> void:
	var main: Node3D = add_child_autofree(MainScene.instantiate())
	await wait_physics_frames(1)
	var catalog := main.find_child("Catalog", true, false) as CatalogPanel
	catalog.button_for("sofa_3").pressed.emit()
	assert_true((main.get_node("FurnitureTool") as FurnitureTool).is_placing())
```

- [ ] **Step 2: Vérifier l'échec**

Run: `./scripts/test.sh -gselect=test_main_scene`
Expected : FAIL, avec `Furniture` null et `Catalog` introuvable.

- [ ] **Step 3: Implémenter**

Remplacer tout le contenu de `src/main.gd` par :

```gdscript
extends Node3D
## Application root: lighting, camera, the 3D view of the open project, the
## furniture tool and the side panels.

const DEFAULT_PROJECT := "res://data/log16.json"
const SUN_ROTATION_DEG := Vector3(-50, -40, 0)
const SUN_COLOR := Color("#ffe6c7")
const SUN_ENERGY := 1.6
const SKY_TOP := Color("#c9dcef")
const SKY_HORIZON := Color("#f6e7da")
const AMBIENT_ENERGY := 0.35

var _view: WorldView
var _camera: OrbitCamera
var _furniture: FurnitureView
var _tool: FurnitureTool


func _ready() -> void:
	add_child(_environment())
	add_child(_sun())
	_view = WorldView.new()
	_view.name = "World"
	add_child(_view)
	_furniture = FurnitureView.new()
	_furniture.name = "Furniture"
	add_child(_furniture)
	_camera = OrbitCamera.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.heading_changed.connect(_view.update_cutaway)
	# Added after the camera: Godot delivers unhandled input to later siblings
	# first, so the tool can claim clicks and Shift + wheel before the camera.
	_tool = FurnitureTool.new()
	_tool.name = "FurnitureTool"
	add_child(_tool)
	_furniture.bind_store(ProjectStore)
	_tool.setup(ProjectStore, _furniture, _camera)
	add_child(_ui())
	ProjectStore.project_loaded.connect(_on_project_loaded)
	var errors := ProjectStore.load_from_file(DEFAULT_PROJECT)
	if not errors.is_empty():
		push_error("Chargement du plan impossible : %s" % "; ".join(errors))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_view.cycle_cutaway_mode()


func _on_project_loaded() -> void:
	_view.show_project(ProjectStore.project)
	_camera.frame_project(ProjectStore.project)


func _ui() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var catalog := CatalogPanel.new()
	catalog.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	catalog.populate(FurnitureCatalog.load_presets())
	catalog.preset_chosen.connect(_tool.begin_placement)
	root.add_child(catalog)
	var properties := PropertiesPanel.new()
	properties.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	properties.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	properties.bind_store(ProjectStore)
	_tool.selection_changed.connect(properties.show_item)
	root.add_child(properties)
	return layer


func _environment() -> WorldEnvironment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = SKY_HORIZON
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.7
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	return world_env


func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	return sun
```

- [ ] **Step 4: Vérifier le succès**

Run: `./scripts/test.sh`
Expected : `Passing Tests 209`, code de sortie 0, aucune ligne `SCRIPT ERROR` ni `WARNING`.

- [ ] **Step 5: Documenter les contrôles**

Dans `README.md`, insérer après la ligne `| Masquage des murs (auto / complets / tous abaissés) | H |` (une ligne vide, puis la section) :

````markdown
### Meubles

| Action | Contrôle |
|---|---|
| Ajouter un meuble | Clic sur un modèle du catalogue (à gauche), puis clic dans la pièce |
| Pivoter l'aperçu ou le meuble sélectionné | R (quart de tour) |
| Pivoter finement le meuble sélectionné | Maj + molette (±15°) |
| Placement libre, sans grille | Alt pendant le déplacement |
| Sélectionner | Clic sur le meuble |
| Déplacer | Clic sur le meuble + glisser |
| Supprimer | Suppr ou Retour arrière |
| Dupliquer | Ctrl/Cmd + D |
| Annuler / rétablir | Ctrl/Cmd + Z / Ctrl/Cmd + Maj + Z |
| Abandonner l'ajout ou désélectionner | Échap |

Un meuble approché à moins de 15 cm d'un mur s'y colle, dos au mur. Le panneau de droite modifie le nom, les dimensions, la couleur, la position et la rotation du meuble sélectionné.

Les meubles ne sont pas encore enregistrés : la sauvegarde arrive avec le jalon M3.
````

- [ ] **Step 6: Capture du rendu réel**

```bash
rm -rf /tmp/m2-shots && mkdir -p /tmp/m2-shots
godot --path . --write-movie /tmp/m2-shots/frame.png --fixed-fps 30 --quit-after 40
```

Expected : `/tmp/m2-shots/frame00000039.png` existe, sans `ERROR` dans la sortie. On y voit :
- le catalogue à gauche, avec les en-têtes de catégorie en jaune ;
- l'appartement au centre ;
- aucun panneau de propriétés, puisque rien n'est sélectionné.

Décrire l'image dans le rapport.

- [ ] **Step 7: Commit**

```bash
git add src/main.gd tests/unit/test_main_scene.gd README.md
git commit -m "feat: furniture catalogue, tool and properties in the main scene"
```
