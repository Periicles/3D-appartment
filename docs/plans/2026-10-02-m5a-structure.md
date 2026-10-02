# M5a — Mode Structure : coins et murs — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modifier la structure du plan dans un mode dédié :
- la touche 2 (ou le bouton « Structure ») passe en mode Structure, la touche 1 revient aux meubles ;
- on glisse un coin, avec aimant à 0/45/90° par rapport aux murs voisins, sinon sur une grille de 5 cm (Alt : sans aimant) ;
- on sélectionne un mur pour régler sa longueur, son épaisseur et sa hauteur, ou le supprimer.

**Architecture:**
- **Séparation stricte des modes** (demande explicite) : `ProjectStore.edit_mode` (`FURNITURE` ou `STRUCTURE`). Chaque méthode d'édition du store refuse d'agir hors de son mode. Les outils s'éteignent hors de leur mode. Annuler ou rétablir une modification bascule d'abord dans le mode où elle a été faite (nom d'action préfixé `Structure : `).
- **Historique de structure** : chaque édition de structure applique la modification à une copie du projet, la valide (`ProjectValidator` + murs d'au moins 5 cm), puis enregistre l'échange des deux états (coins, murs, ouvertures, pièces) comme une seule étape d'annulation. Le store émet `structure_changed`.
- **Calcul pur** : `StructureSnap` dans `src/model/`.
- **Affichage** : `WorldView.refresh` reconstruit murs et sols sans relancer l'animation du masquage. `StructureView` dessine les poignées des coins et les cotes des murs édités. `FurnitureView` s'estompe en mode Structure.
- **Outil et panneau** : `StructureTool` (sélection, glisser avec aperçu sur une copie, Suppr). `StructurePanel` partage le côté droit avec le panneau des meubles.
- **Assemblage** : `main.gd` route 1, 2, ⌘Z et ⌘⇧Z (l'annulation quitte le `FurnitureTool` pour devenir globale), affiche la barre de modes en haut et grise le catalogue.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** `docs/specs/2026-09-30-v1-design.md` : §3 (store et `structure_changed`), §7 (modes, mode Structure), §11 (jalon M5).

## Global Constraints

- Godot **4.7.2**, GDScript uniquement. GUT **9.7.1**.
- Indentation par **tabulations**.
- Code et commentaires en anglais. **Libellés et indications en français.**
- Unités en **mètres** dans les données ; le panneau affiche longueur, épaisseur et hauteur en **cm**, la position des coins en **m**.
- `src/model/` ne référence aucun nœud de scène.
- Les vues ne modifient jamais les données : toute édition passe par `ProjectStore`.
- Connexions de signaux vers l'autoload ou entre nœuds : des **méthodes liées**, pas des lambdas.
- Tests : `./scripts/test.sh`, ou `./scripts/test.sh -gselect=<fichier>` pour un seul fichier. Les tests qui utilisent le store global repartent d'un projet propre (`ProjectStore.new_project()`, qui remet aussi le mode Meubles).
- Les `.uid` générés sont commités avec leur source.
- Branche `feat/m5a-structure`, PR vers `develop` assignée à `@me`.
- Commits au format Conventional Commits, **sans** trailer `Co-Authored-By`, sans lien de session et sans pied de page « Generated with ».

## Choix et écarts par rapport à la spec

1. **Découpage** (validé par l'utilisateur) : M5a couvre coins et murs ; le dessin de murs (W), les ouvertures (D, N) et la suppression d'un coin (avec fusion de ses deux murs, et retrait d'une pièce sous 3 coins après confirmation) vont en M5b. Une pièce de 3 coins reste valide.
2. **Modes étanches** (demande de l'utilisateur) : le store refuse toute édition de meuble en mode Structure et toute édition de structure en mode Meubles. Annuler une étape de l'autre mode y bascule d'abord, pour que le changement se voie. Ouvrir ou créer un projet revient au mode Meubles.
3. **Mur supprimé** : ses ouvertures partent avec lui. Ses coins sont supprimés s'ils ne portent plus aucun mur **et** n'appartiennent à aucune pièce (un sol garde ses coins).
4. **Glisser invalide** : un emplacement qui ferait dépasser une ouverture de son mur, ou réduirait un mur sous 5 cm, est refusé ; le coin reste à la dernière position valide. Le même refus remet la valeur du panneau.
5. **Aimant** : des lignes guides passent par chaque coin voisin, tous les 45° à partir des autres murs de ce voisin (ou des axes s'il n'en a pas). À moins de 10 cm d'une guide, le coin s'y colle ; près de deux guides de voisins différents, il se pose à leur croisement. Sinon, grille de 5 cm.
6. **Jonction en T tolérante** (validé) : deux murs alignés à 3° près au même coin comptent comme un mur traversant, pour qu'un coin déplacé à la main ne crée pas de trou.
7. **Aperçu pendant le glisser** : les murs et sols sont reconstruits à chaque mouvement depuis une copie du projet (mesuré : ~1 ms de construction, ~14 ms par image avec le CSG sur les 36 murs du log 16). Le mur sélectionné est teinté de la couleur de sélection.
8. **Poignées** : un disque sur chaque coin, dessiné par-dessus les murs ; un clic à moins de 14 px en écran prend le coin, avant les murs. Un mur se sélectionne par lancer de rayon sur son volume, à sa hauteur affichée (un mur abaissé par le masquage se clique à sa hauteur abaissée).
9. **⌘Z / ⌘⇧Z** deviennent des raccourcis globaux (main) et restent ignorés pendant un glisser, de meuble comme de coin.

## Review Focus

1. **Porte ou fenêtre poussée hors de son mur** par un coin déplacé ou une longueur réduite : refus, rien ne change. Tests : `test_a_move_that_squeezes_a_door_out_of_its_wall_is_refused` (Task 2), `test_drag_keeps_the_last_valid_spot` (Task 4), `test_a_refused_value_springs_back` (Task 4).
2. **Annuler depuis l'autre mode** : la modification n'est jamais défaite « en douce ». Tests : `test_undoing_a_structure_edit_from_furniture_mode_switches_mode` (Task 2), `test_command_z_undoes_and_switches_back_to_the_edit_mode` (Task 5).
3. **Changer de mode au milieu d'un glisser** (meuble ou coin) : l'aperçu disparaît, rien n'est enregistré. Tests : `test_switching_mode_mid_drag_drops_the_preview` et `test_leaving_structure_mode_mid_drag_drops_the_preview`.
4. **Sélection qui disparaît** (mur supprimé, annulation qui retire un coin) : le panneau se cache, la sélection se vide. Tests : `test_delete_removes_the_selected_wall`, `test_undo_that_removes_the_selected_corner_clears_the_selection`, `test_hides_when_the_shown_wall_is_deleted`.
5. **Coin presque aligné avec un mur traversant** : pas de trou à la jonction. Test : `test_nearly_straight_wall_still_counts_as_through` (Task 1).

## Structure des fichiers

| Fichier | Rôle |
|---|---|
| `src/model/structure_snap.gd` | `StructureSnap.snap_node`, `guides` |
| `src/model/{plan_node,wall,opening,room,project_data}.gd` | `copy()` profond ; `ProjectData.walls_at` |
| `src/model/geometry.gd` | `THROUGH_TOLERANCE_DEG` |
| `src/store/project_store.gd` | `EditMode`, `set_edit_mode`, `move_node`, `can_move_node`, `update_wall`, `remove_wall`, `structure_changed`, annulation qui suit le mode |
| `src/world/world_view.gd` | `refresh`, `wall_display_height`, `highlight_wall` |
| `src/world/structure_view.gd` | `StructureView` : poignées, surlignage, cotes |
| `src/world/furniture_view.gd` | `set_dimmed`, `is_dimmed` |
| `src/world/palette.gd` | `apply_toggle_style` |
| `src/ui/catalog_panel.gd` | `set_enabled` |
| `src/tools/structure_tool.gd` | `StructureTool` |
| `src/ui/structure_panel.gd` | `StructurePanel` |
| `src/ui/shortcuts.gd` | actions `furniture_mode`, `structure_mode`, `undo`, `redo` ; groupes « Structure » et « Historique » ; `structure_hint` |
| `src/tools/furniture_tool.gd` | actif en mode Meubles seulement ; `is_dragging` ; ⌘Z retiré |
| `src/main.gd` | barre de modes, inspecteur partagé, routage 1/2/⌘Z, `structure_changed` → `refresh` |

## Comment appliquer les étapes

Chaque tâche donne son code complet sous forme de **patch unifié** (fichiers nouveaux compris), produit et vérifié sur un prototype : appliqué dans l'ordre sur `develop`, chaque patch passe toute la suite. Pour une tâche :

1. Copier le bloc `diff` de la tâche dans un fichier, par exemple `/tmp/taskN.patch`.
2. `git apply --check /tmp/taskN.patch`, puis `git apply /tmp/taskN.patch`.
3. Lancer d'abord les tests de la tâche (étape « tests ciblés »), puis toute la suite.
4. Relire le diff (`git diff`) : il doit correspondre exactement au patch.
5. `godot --headless --path . --import` génère les `.uid` des nouveaux scripts ; les ajouter au commit.

Si `git apply --check` échoue, ne pas forcer : rapporter le contexte qui diffère.

---

### Task 1: Modèle : copies profondes, jonction tolérante, aimant des coins

**Files:**
- Modify: `src/model/plan_node.gd`, `src/model/wall.gd`, `src/model/opening.gd`, `src/model/room.gd`, `src/model/project_data.gd`, `src/model/geometry.gd`
- Create: `src/model/structure_snap.gd`
- Test: `tests/unit/test_project_data.gd`, `tests/unit/test_geometry.gd`, `tests/unit/test_structure_snap.gd` (nouveau)

**Interfaces:**
- Consumes: rien de nouveau.
- Produces: `PlanNode.copy()`, `Wall.copy()`, `Opening.copy()`, `Room.copy()`, `ProjectData.copy() -> ProjectData` (profond ; l'`underlay` est partagé), `ProjectData.walls_at(node_id: String) -> Array[Wall]`, `Geometry.THROUGH_TOLERANCE_DEG := 3.0`, `StructureSnap.snap_node(project: ProjectData, node_id: String, raw: Vector2, free_move: bool) -> Vector2`, `StructureSnap.guides(project, node_id) -> Array[Dictionary]` (`{origin: Vector2, dir: Vector2}`), constantes `GRID := 0.05`, `ANGLE_STEP_DEG := 45.0`, `GUIDE_DISTANCE := 0.1`, `MIN_CROSSING_DEG := 10.0`.

- [ ] **Step 1: Appliquer le patch**

```diff
diff --git a/src/model/plan_node.gd b/src/model/plan_node.gd
index 6cc87bd..a1fe0d1 100644
--- a/src/model/plan_node.gd
+++ b/src/model/plan_node.gd
@@ -5,3 +5,10 @@ extends RefCounted
 var id: String
 ## Position on the floor plane in meters: x = east, y = south (world z).
 var pos: Vector2
+
+
+func copy() -> PlanNode:
+	var other := PlanNode.new()
+	other.id = id
+	other.pos = pos
+	return other
diff --git a/src/model/wall.gd b/src/model/wall.gd
index 969f91d..ac3bf65 100644
--- a/src/model/wall.gd
+++ b/src/model/wall.gd
@@ -9,3 +9,13 @@ var a: String
 var b: String
 var thickness: float
 var height: float
+
+
+func copy() -> Wall:
+	var other := Wall.new()
+	other.id = id
+	other.a = a
+	other.b = b
+	other.thickness = thickness
+	other.height = height
+	return other
diff --git a/src/model/opening.gd b/src/model/opening.gd
index 01790b9..ae10204 100644
--- a/src/model/opening.gd
+++ b/src/model/opening.gd
@@ -15,3 +15,16 @@ var height: float
 ## Height of the opening's bottom edge above the floor; 0 for doors.
 var sill: float
 var swing: String
+
+
+func copy() -> Opening:
+	var other := Opening.new()
+	other.id = id
+	other.wall_id = wall_id
+	other.kind = kind
+	other.offset = offset
+	other.width = width
+	other.height = height
+	other.sill = sill
+	other.swing = swing
+	return other
diff --git a/src/model/room.gd b/src/model/room.gd
index 14e30bb..0abdca9 100644
--- a/src/model/room.gd
+++ b/src/model/room.gd
@@ -9,3 +9,12 @@ var name: String
 ## Polygon of graph node ids, in order.
 var node_ids: PackedStringArray
 var floor_kind: String
+
+
+func copy() -> Room:
+	var other := Room.new()
+	other.id = id
+	other.name = name
+	other.node_ids = node_ids.duplicate()
+	other.floor_kind = floor_kind
+	return other
diff --git a/src/model/project_data.gd b/src/model/project_data.gd
index 7072dc1..abee50b 100644
--- a/src/model/project_data.gd
+++ b/src/model/project_data.gd
@@ -45,3 +45,33 @@ func wall_length(wall: Wall) -> float:
 	if a == null or b == null:
 		return -1.0
 	return a.pos.distance_to(b.pos)
+
+
+## Deep copy: editing the copy never changes this project. The underlay is
+## shared, as nothing edits it.
+func copy() -> ProjectData:
+	var other := ProjectData.new()
+	other.name = name
+	other.wall_height = wall_height
+	other.north_angle = north_angle
+	other.underlay = underlay
+	for node in nodes:
+		other.nodes.append(node.copy())
+	for wall in walls:
+		other.walls.append(wall.copy())
+	for opening in openings:
+		other.openings.append(opening.copy())
+	for room in rooms:
+		other.rooms.append(room.copy())
+	for item in furniture:
+		other.furniture.append(item.copy())
+	return other
+
+
+## Walls whose start or end is this node.
+func walls_at(node_id: String) -> Array[Wall]:
+	var found: Array[Wall] = []
+	for wall in walls:
+		if wall.a == node_id or wall.b == node_id:
+			found.append(wall)
+	return found
diff --git a/src/model/geometry.gd b/src/model/geometry.gd
index aad73ef..3b8ac07 100644
--- a/src/model/geometry.gd
+++ b/src/model/geometry.gd
@@ -5,6 +5,9 @@ extends RefCounted
 ## Beyond this multiple of the wall thickness a miter turns into a square cut,
 ## so acute corners do not grow long spikes.
 const MITER_LIMIT := 2.0
+## Two walls meeting at a node within this angle of a straight line form one
+## "through" wall: corners dragged by hand are rarely exactly aligned.
+const THROUGH_TOLERANCE_DEG := 3.0
 const _PARALLEL_EPSILON := 1e-6
 
 
@@ -117,10 +120,11 @@ static func _solve_node(project: ProjectData, node: PlanNode, corners: Dictionar
 ## stop on its face instead of slanting it.
 static func _through_flags(ends: Array) -> Array[bool]:
 	var flags: Array[bool] = []
+	var opposite := -cos(deg_to_rad(THROUGH_TOLERANCE_DEG))
 	for e in ends:
 		var is_through := false
 		for other in ends:
-			if e.dir.dot(other.dir) < -1.0 + _PARALLEL_EPSILON:
+			if e.dir.dot(other.dir) < opposite:
 				is_through = true
 		flags.append(is_through)
 	return flags
diff --git a/src/model/structure_snap.gd b/src/model/structure_snap.gd
new file mode 100644
index 0000000..476302c
--- /dev/null
+++ b/src/model/structure_snap.gd
@@ -0,0 +1,72 @@
+class_name StructureSnap
+extends RefCounted
+## Magnetism for a dragged corner: its walls lock to 0/45/90° against the
+## walls at their other end, else the corner snaps to the grid.
+
+const GRID := 0.05
+const ANGLE_STEP_DEG := 45.0
+## A guide line attracts the corner within this distance, in metres.
+const GUIDE_DISTANCE := 0.1
+## Guides crossing at a shallower angle are not combined (the crossing point
+## would run far from the mouse).
+const MIN_CROSSING_DEG := 10.0
+
+
+## Where the corner `node_id` lands when dragged to `raw`. With `free_move`
+## (Alt held) the position is kept as is.
+static func snap_node(project: ProjectData, node_id: String, raw: Vector2, free_move: bool) -> Vector2:
+	if free_move:
+		return raw
+	var near := []  # [distance, guide]
+	for guide in guides(project, node_id):
+		var distance := _distance_to_line(raw, guide)
+		if distance <= GUIDE_DISTANCE:
+			near.append([distance, guide])
+	if near.is_empty():
+		return raw.snapped(Vector2(GRID, GRID))
+	near.sort_custom(func(x, y): return x[0] < y[0])
+	var best: Dictionary = near[0][1]
+	for entry in near.slice(1):
+		var other: Dictionary = entry[1]
+		if other.origin.is_equal_approx(best.origin):
+			continue  # Two angles at the same neighbour only cross at the neighbour.
+		if absf(best.dir.cross(other.dir)) < sin(deg_to_rad(MIN_CROSSING_DEG)):
+			continue
+		var crossing = Geometry2D.line_intersects_line(best.origin, best.dir, other.origin, other.dir)
+		if crossing != null:
+			return crossing
+	return _project_on_line(raw, best)
+
+
+## Lines the corner may lock onto: through each neighbouring corner, at every
+## multiple of ANGLE_STEP_DEG from the neighbour's other walls (or from the
+## axes when the neighbour has no other wall). Each is {origin, dir}.
+static func guides(project: ProjectData, node_id: String) -> Array[Dictionary]:
+	var found: Array[Dictionary] = []
+	for wall in project.walls_at(node_id):
+		var neighbour_id := wall.b if wall.a == node_id else wall.a
+		var neighbour := project.get_plan_node(neighbour_id)
+		if neighbour == null:
+			continue
+		var references: Array[float] = []
+		for other in project.walls_at(neighbour_id):
+			var far_id := other.b if other.a == neighbour_id else other.a
+			var far := project.get_plan_node(far_id)
+			if other == wall or far_id == node_id or far == null or far.pos.is_equal_approx(neighbour.pos):
+				continue
+			references.append((far.pos - neighbour.pos).angle())
+		if references.is_empty():
+			references.append(0.0)
+		for reference in references:
+			for step in int(180.0 / ANGLE_STEP_DEG):
+				var angle := reference + deg_to_rad(step * ANGLE_STEP_DEG)
+				found.append({"origin": neighbour.pos, "dir": Vector2.from_angle(angle)})
+	return found
+
+
+static func _distance_to_line(point: Vector2, guide: Dictionary) -> float:
+	return absf(guide.dir.cross(point - guide.origin))
+
+
+static func _project_on_line(point: Vector2, guide: Dictionary) -> Vector2:
+	return guide.origin + guide.dir * guide.dir.dot(point - guide.origin)
diff --git a/tests/unit/test_project_data.gd b/tests/unit/test_project_data.gd
index e5806e6..81e833d 100644
--- a/tests/unit/test_project_data.gd
+++ b/tests/unit/test_project_data.gd
@@ -34,3 +34,25 @@ func test_wall_length_handles_diagonal_walls() -> void:
 func test_wall_length_is_negative_when_node_missing() -> void:
 	var project := Fixtures.square_room()
 	assert_eq(project.wall_length(Fixtures.wall("w", "n1", "missing")), -1.0)
+
+
+func test_copy_is_deep() -> void:
+	var original := Fixtures.square_room()
+	var clone := original.copy()
+	clone.get_plan_node("n1").pos = Vector2(9, 9)
+	clone.get_wall("w1").thickness = 0.5
+	clone.openings[0].width = 2.0
+	clone.rooms[0].node_ids[0] = "n2"
+	clone.furniture[0].name = "X"
+	assert_eq(original.get_plan_node("n1").pos, Vector2.ZERO)
+	assert_almost_eq(original.get_wall("w1").thickness, 0.2, 1e-6)
+	assert_almost_eq(original.openings[0].width, 0.8, 1e-6)
+	assert_eq(original.rooms[0].node_ids[0], "n1")
+	assert_eq(original.furniture[0].name, "Canapé")
+	assert_eq(ProjectSerializer.to_json(clone.copy()), ProjectSerializer.to_json(clone), "every field copied")
+
+
+func test_walls_at_lists_walls_on_either_end() -> void:
+	var project := Fixtures.square_room()
+	var ids := project.walls_at("n1").map(func(w: Wall) -> String: return w.id)
+	assert_eq(ids, ["w1", "w4"])
diff --git a/tests/unit/test_geometry.gd b/tests/unit/test_geometry.gd
index 790ee17..fdc16a4 100644
--- a/tests/unit/test_geometry.gd
+++ b/tests/unit/test_geometry.gd
@@ -133,3 +133,25 @@ func test_room_net_area_keeps_open_edges() -> void:
 	project.walls.erase(project.get_wall("w3"))
 	project.openings.clear()
 	assert_almost_eq(Geometry.room_net_area(project, project.rooms[0]), 14.8, EPS)
+
+
+func test_nearly_straight_wall_still_counts_as_through() -> void:
+	# The right half of the through wall is 2° off straight, as after a hand drag.
+	var tilt := 2.0 * tan(deg_to_rad(2.0))
+	var project := _project(
+		[["a", 0, 0], ["m", 2, 0], ["b", 4, tilt], ["c", 2, 3]],
+		[["w1", "a", "m", 0.2], ["w2", "m", "b", 0.2], ["p", "m", "c", 0.08]])
+	var partition: PackedVector2Array = Geometry.wall_footprints(project)["p"]
+	assert_true(_has_point(partition, Vector2(1.96, 0.1)), "partition stops on the face: %s" % [partition])
+
+
+func test_a_clear_bend_is_mitred_not_through() -> void:
+	var project := _project(
+		[["a", 0, 0], ["m", 2, 0], ["b", 4, 0.5]],
+		[["w1", "a", "m", 0.2], ["w2", "m", "b", 0.2]])
+	var footprints := Geometry.wall_footprints(project)
+	var shared := 0
+	for p in footprints["w1"]:
+		if _has_point(footprints["w2"], p):
+			shared += 1
+	assert_eq(shared, 2, "14° bend: mitred joint")
diff --git a/tests/unit/test_structure_snap.gd b/tests/unit/test_structure_snap.gd
new file mode 100644
index 0000000..996c22c
--- /dev/null
+++ b/tests/unit/test_structure_snap.gd
@@ -0,0 +1,70 @@
+extends GutTest
+
+const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
+const EPS := 1e-4
+
+
+## An L of walls: a (0,0) - b (4,0) - c (4,3); the corner c is the one dragged.
+func _l_shape() -> ProjectData:
+	var project := ProjectData.new()
+	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 4, 0),
+		Fixtures.plan_node("c", 4, 3)])
+	project.walls.assign([Fixtures.wall("w1", "a", "b"), Fixtures.wall("w2", "b", "c")])
+	return project
+
+
+func test_free_move_keeps_the_raw_position() -> void:
+	var raw := Vector2(4.03, 2.97)
+	assert_eq(StructureSnap.snap_node(_l_shape(), "c", raw, true), raw)
+
+
+func test_far_from_any_guide_snaps_to_the_grid() -> void:
+	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(5.33, 1.61), false)
+	assert_almost_eq(snapped, Vector2(5.35, 1.6), Vector2(EPS, EPS))
+
+
+func test_near_square_locks_the_wall_at_ninety_degrees() -> void:
+	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(4.07, 3.13), false)
+	assert_almost_eq(snapped.x, 4.0, EPS, "w2 stays perpendicular to w1")
+	assert_almost_eq(snapped.y, 3.13, EPS, "the length follows the mouse")
+
+
+func test_near_forty_five_degrees_locks_the_diagonal() -> void:
+	var snapped := StructureSnap.snap_node(_l_shape(), "c", Vector2(6.05, 1.95), false)
+	assert_almost_eq(snapped.x - 4.0, snapped.y, EPS, "45° from w1 at b")
+
+
+func test_angles_follow_a_slanted_neighbour() -> void:
+	var project := _l_shape()
+	project.get_plan_node("a").pos = Vector2(0, -2)  # w1 is no longer horizontal
+	var direction := (project.get_plan_node("b").pos - project.get_plan_node("a").pos).normalized()
+	var square := Vector2(-direction.y, direction.x)
+	var raw := Vector2(4, 0) + square * 3.0 + direction * 0.05
+	var snapped := StructureSnap.snap_node(project, "c", raw, false)
+	assert_almost_eq((snapped - Vector2(4, 0)).normalized().dot(direction), 0.0, EPS, "90° to the slanted wall")
+
+
+func test_two_neighbours_lock_the_corner_on_their_crossing() -> void:
+	# Square a-b-c-d with c dragged: w2 (b-c) and w3 (c-d) both lock at 90°.
+	var project := ProjectData.new()
+	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 4, 0),
+		Fixtures.plan_node("c", 4, 3), Fixtures.plan_node("d", 0, 3)])
+	project.walls.assign([Fixtures.wall("w1", "a", "b"), Fixtures.wall("w2", "b", "c"),
+		Fixtures.wall("w3", "c", "d"), Fixtures.wall("w4", "d", "a")])
+	var snapped := StructureSnap.snap_node(project, "c", Vector2(4.06, 3.08), false)
+	assert_almost_eq(snapped, Vector2(4, 3), Vector2(EPS, EPS))
+
+
+func test_a_neighbour_without_other_walls_uses_the_axes() -> void:
+	var project := ProjectData.new()
+	project.nodes.assign([Fixtures.plan_node("a", 0, 0), Fixtures.plan_node("b", 3, 0.2)])
+	project.walls.assign([Fixtures.wall("w1", "a", "b")])
+	var snapped := StructureSnap.snap_node(project, "b", Vector2(3, 0.07), false)
+	assert_almost_eq(snapped.y, 0.0, EPS, "horizontal")
+
+
+func test_a_lone_corner_only_snaps_to_the_grid() -> void:
+	var project := ProjectData.new()
+	project.nodes.assign([Fixtures.plan_node("a", 0, 0)])
+	assert_almost_eq(StructureSnap.snap_node(project, "a", Vector2(0.92, 0.07), false),
+		Vector2(0.9, 0.05), Vector2(EPS, EPS))
```

- [ ] **Step 2: Tests ciblés**

Run, un fichier à la fois (GUT ne garde qu'un seul `-gselect`) :
- `./scripts/test.sh -gselect=test_project_data`
- `./scripts/test.sh -gselect=test_geometry`
- `./scripts/test.sh -gselect=test_structure_snap`
Expected: tous passent.

- [ ] **Step 3: Suite complète**

Run: `./scripts/test.sh`
Expected: **459** tests, tous passent (un seul avertissement attendu, celui de la sauvegarde automatique, et les erreurs moteur du test d'image de calque corrompue).

- [ ] **Step 4: Commit**

```bash
godot --headless --path . --import
git add -A src tests README.md
git commit -m "feat: deep project copies, tolerant through walls and corner magnetism"
```

### Task 2: Store : modes d'édition et éditions de structure annulables

**Files:**
- Modify: `src/store/project_store.gd`
- Test: `tests/unit/test_project_store_structure.gd` (nouveau)

**Interfaces:**
- Consumes: `ProjectData.copy()`, `ProjectData.walls_at()` (Task 1).
- Produces (sur l'autoload `ProjectStore`) : `enum EditMode { FURNITURE, STRUCTURE }`, `var edit_mode`, `signal edit_mode_changed(mode: EditMode)`, `signal structure_changed`, `set_edit_mode(mode)`, `move_node(id: String, pos: Vector2) -> bool`, `can_move_node(id: String, pos: Vector2) -> bool`, `update_wall(id: String, changes: Dictionary) -> bool` (clés `length`, `thickness`, `height`, en mètres), `remove_wall(id: String) -> bool`, constantes `WALL_FIELDS`, `MIN_WALL_LENGTH := 0.05`, `STRUCTURE_ACTION_PREFIX := "Structure : "`. Les méthodes de meubles renvoient `false` (ou `""`) hors du mode Meubles. `undo()` et `redo()` basculent d'abord dans le mode de l'étape. `_replace` (ouverture, nouveau projet, restauration) remet le mode Meubles.

- [ ] **Step 1: Appliquer le patch**

```diff
diff --git a/src/store/project_store.gd b/src/store/project_store.gd
index 0c10137..7c944c8 100644
--- a/src/store/project_store.gd
+++ b/src/store/project_store.gd
@@ -11,11 +11,25 @@ signal path_changed(path: String)
 signal furniture_added(id: String)
 signal furniture_changed(id: String)
 signal furniture_removed(id: String)
+## Corners, walls, openings or rooms changed (edit, undo or redo).
+signal structure_changed
+signal edit_mode_changed(mode: EditMode)
+
+## Furniture and structure are edited in separate modes, so a stray click or
+## key in one never changes the other.
+enum EditMode { FURNITURE, STRUCTURE }
 
 ## Fields of a FurnitureItem that update_furniture accepts.
 const EDITABLE_FIELDS: PackedStringArray = ["name", "size", "color", "pos", "rotation_deg"]
 ## Offset of a duplicate from its original, so both stay visible.
 const DUPLICATE_OFFSET := Vector2(0.3, 0.3)
+## Fields of a Wall that update_wall accepts; "length" moves the end node `b`.
+const WALL_FIELDS: PackedStringArray = ["length", "thickness", "height"]
+## Shortest wall an edit may leave, in metres (shorter ones have no footprint).
+const MIN_WALL_LENGTH := 0.05
+## Undo actions named with this prefix edit the structure; undoing or redoing
+## one switches to the Structure mode, so the change happens where it is seen.
+const STRUCTURE_ACTION_PREFIX := "Structure : "
 
 var project: ProjectData = ProjectData.new()
 ## File the project was opened from or last saved to; "" for a new project.
@@ -23,6 +37,7 @@ var current_path := ""
 var _history := UndoRedo.new()
 ## History version at the last open or save; -1 when restored unsaved work.
 var _saved_version := 0
+var edit_mode := EditMode.FURNITURE
 
 
 func _init() -> void:
@@ -102,10 +117,10 @@ func next_furniture_id() -> String:
 	return "f%d" % (highest + 1)
 
 
-## Adds a copy of `item`. Returns false (and changes nothing) if the item is
-## invalid or its id is already used.
+## Adds a copy of `item`. Returns false (and changes nothing) outside the
+## Furniture mode, or if the item is invalid or its id is already used.
 func add_furniture(item: FurnitureItem) -> bool:
-	if get_furniture(item.id) != null or not _is_valid(item):
+	if edit_mode != EditMode.FURNITURE or get_furniture(item.id) != null or not _is_valid(item):
 		return false
 	var stored := item.copy()
 	_begin_action("Ajouter %s" % stored.name)
@@ -119,7 +134,7 @@ func add_furniture(item: FurnitureItem) -> bool:
 ## (and changes nothing) for an unknown id, unknown field or invalid result.
 func update_furniture(id: String, changes: Dictionary) -> bool:
 	var item := get_furniture(id)
-	if item == null or changes.is_empty():
+	if edit_mode != EditMode.FURNITURE or item == null or changes.is_empty():
 		return false
 	var previous := {}
 	var preview := item.copy()
@@ -139,7 +154,7 @@ func update_furniture(id: String, changes: Dictionary) -> bool:
 
 func remove_furniture(id: String) -> bool:
 	var item := get_furniture(id)
-	if item == null:
+	if edit_mode != EditMode.FURNITURE or item == null:
 		return false
 	var index := project.furniture.find(item)
 	_begin_action("Supprimer %s" % item.name)
@@ -153,7 +168,7 @@ func remove_furniture(id: String) -> bool:
 ## "" for an unknown id.
 func duplicate_furniture(id: String) -> String:
 	var item := get_furniture(id)
-	if item == null:
+	if edit_mode != EditMode.FURNITURE or item == null:
 		return ""
 	var clone := item.copy()
 	clone.id = next_furniture_id()
@@ -161,11 +176,60 @@ func duplicate_furniture(id: String) -> String:
 	return clone.id if add_furniture(clone) else ""
 
 
+func set_edit_mode(mode: EditMode) -> void:
+	if mode == edit_mode:
+		return
+	edit_mode = mode
+	edit_mode_changed.emit(mode)
+
+
+## Moves a corner, dragging every wall joined to it. Returns false (and changes
+## nothing) outside the Structure mode, for an unknown id, or when a wall would
+## become too short or an opening would no longer fit.
+func move_node(id: String, pos: Vector2) -> bool:
+	var node := project.get_plan_node(id)
+	if node == null or node.pos.is_equal_approx(pos):
+		return false
+	return _edit_structure("déplacer un coin", _set_node_pos.bind(id, pos))
+
+
+## True when move_node(id, pos) would be accepted (live drag feedback).
+func can_move_node(id: String, pos: Vector2) -> bool:
+	var probe := project.copy()
+	return probe.get_plan_node(id) != null and _set_node_pos(probe, id, pos) and _is_buildable(probe)
+
+
+## Applies `changes` (keys from WALL_FIELDS, in metres) to the wall. A new
+## length moves its end node `b` along the wall. Same refusals as move_node.
+func update_wall(id: String, changes: Dictionary) -> bool:
+	if project.get_wall(id) == null or changes.is_empty():
+		return false
+	for key in changes:
+		if not key in WALL_FIELDS:
+			return false
+	return _edit_structure("modifier un mur", _set_wall_fields.bind(id, changes.duplicate()))
+
+
+## Deletes the wall and the openings it carries. Corners left without any wall
+## or room are deleted too.
+func remove_wall(id: String) -> bool:
+	if project.get_wall(id) == null:
+		return false
+	return _edit_structure("supprimer un mur", _delete_wall.bind(id))
+
+
+## Undoes the last edit, first switching to the mode it was made in.
 func undo() -> bool:
+	if not _history.has_undo():
+		return false
+	_follow_action(_history.get_current_action_name())
 	return _history.undo()
 
 
 func redo() -> bool:
+	if not _history.has_redo():
+		return false
+	_follow_action(_history.get_action_name(_history.get_current_action() + 1))
 	return _history.redo()
 
 
@@ -180,6 +244,7 @@ func can_redo() -> bool:
 func _replace(new_project_data: ProjectData, path: String, dirty := false) -> void:
 	project = new_project_data
 	current_path = path
+	set_edit_mode(EditMode.FURNITURE)
 	# Without a version bump: clearing is not an edit.
 	_history.clear_history(false)
 	_saved_version = -1 if dirty else _history.get_version()
@@ -223,3 +288,81 @@ func _is_valid(item: FurnitureItem) -> bool:
 	var probe := ProjectData.new()
 	probe.furniture.append(item)
 	return ProjectValidator.validate(probe).is_empty()
+
+
+func _follow_action(action_name: String) -> void:
+	var structure := action_name.begins_with(STRUCTURE_ACTION_PREFIX)
+	set_edit_mode(EditMode.STRUCTURE if structure else EditMode.FURNITURE)
+
+
+## Applies `edit` (returns false to refuse) to a copy of the project and, if the
+## result is buildable, records the swap of structure states as one undo step.
+func _edit_structure(action_name: String, edit: Callable) -> bool:
+	if edit_mode != EditMode.STRUCTURE:
+		return false
+	var probe := project.copy()
+	if not edit.call(probe) or not _is_buildable(probe):
+		return false
+	_begin_action(STRUCTURE_ACTION_PREFIX + action_name)
+	_history.add_do_method(_restore_structure.bind(probe.copy()))
+	_history.add_undo_method(_restore_structure.bind(project.copy()))
+	_history.commit_action()
+	return true
+
+
+## Takes the corners, walls, openings and rooms of `state` (copied again, so the
+## recorded state stays untouched by later edits).
+func _restore_structure(state: ProjectData) -> void:
+	var fresh := state.copy()
+	project.nodes = fresh.nodes
+	project.walls = fresh.walls
+	project.openings = fresh.openings
+	project.rooms = fresh.rooms
+	structure_changed.emit()
+
+
+func _is_buildable(probe: ProjectData) -> bool:
+	for wall in probe.walls:
+		if probe.wall_length(wall) < MIN_WALL_LENGTH:
+			return false
+	return ProjectValidator.validate(probe).is_empty()
+
+
+static func _set_node_pos(probe: ProjectData, id: String, pos: Vector2) -> bool:
+	var node := probe.get_plan_node(id)
+	if node == null:
+		return false
+	node.pos = pos
+	return true
+
+
+static func _set_wall_fields(probe: ProjectData, id: String, changes: Dictionary) -> bool:
+	var wall := probe.get_wall(id)
+	for key in changes:
+		if key == "length":
+			var a := probe.get_plan_node(wall.a)
+			var b := probe.get_plan_node(wall.b)
+			var direction := (b.pos - a.pos).normalized()
+			if direction.is_zero_approx():
+				return false
+			b.pos = a.pos + direction * float(changes[key])
+		else:
+			wall.set(key, changes[key])
+	return true
+
+
+static func _delete_wall(probe: ProjectData, id: String) -> bool:
+	var wall := probe.get_wall(id)
+	probe.walls.erase(wall)
+	probe.openings.assign(probe.openings.filter(func(o: Opening) -> bool: return o.wall_id != id))
+	for node_id in [wall.a, wall.b]:
+		if probe.walls_at(node_id).is_empty() and not _in_a_room(probe, node_id):
+			probe.nodes.erase(probe.get_plan_node(node_id))
+	return true
+
+
+static func _in_a_room(probe: ProjectData, node_id: String) -> bool:
+	for room in probe.rooms:
+		if node_id in room.node_ids:
+			return true
+	return false
diff --git a/tests/unit/test_project_store_structure.gd b/tests/unit/test_project_store_structure.gd
new file mode 100644
index 0000000..028ae8c
--- /dev/null
+++ b/tests/unit/test_project_store_structure.gd
@@ -0,0 +1,167 @@
+extends GutTest
+
+const Store := preload("res://src/store/project_store.gd")
+const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
+const EPS := 1e-4
+
+var _store: Node
+
+
+func before_each() -> void:
+	_store = autofree(Store.new())
+	_store.project = Fixtures.square_room()
+	_store.set_edit_mode(Store.EditMode.STRUCTURE)
+
+
+func _node_pos(id: String) -> Vector2:
+	return _store.project.get_plan_node(id).pos
+
+
+func test_starts_in_furniture_mode() -> void:
+	var fresh: Node = autofree(Store.new())
+	assert_eq(fresh.edit_mode, Store.EditMode.FURNITURE)
+
+
+func test_changing_mode_emits_once() -> void:
+	watch_signals(_store)
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	assert_signal_emit_count(_store, "edit_mode_changed", 1)
+
+
+func test_structure_edits_are_refused_in_furniture_mode() -> void:
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	assert_false(_store.move_node("n3", Vector2(5, 5)))
+	assert_false(_store.update_wall("w2", {"thickness": 0.1}))
+	assert_false(_store.remove_wall("w2"))
+	assert_eq(_node_pos("n3"), Vector2(4, 4))
+	assert_false(_store.can_undo())
+
+
+func test_furniture_edits_are_refused_in_structure_mode() -> void:
+	assert_false(_store.add_furniture(Fixtures.sofa("f2")))
+	assert_false(_store.update_furniture("f1", {"name": "X"}))
+	assert_false(_store.remove_furniture("f1"))
+	assert_eq(_store.duplicate_furniture("f1"), "")
+	assert_eq(_store.project.furniture.size(), 1)
+
+
+func test_move_node_drags_its_walls_and_undoes_in_one_step() -> void:
+	watch_signals(_store)
+	assert_true(_store.move_node("n3", Vector2(5, 4.5)))
+	assert_eq(_node_pos("n3"), Vector2(5, 4.5))
+	assert_almost_eq(_store.project.wall_length(_store.project.get_wall("w2")), Vector2(1, 4.5).length(), EPS)
+	assert_signal_emitted(_store, "structure_changed")
+	_store.undo()
+	assert_eq(_node_pos("n3"), Vector2(4, 4))
+	_store.redo()
+	assert_eq(_node_pos("n3"), Vector2(5, 4.5))
+
+
+func test_move_to_the_same_place_records_nothing() -> void:
+	assert_false(_store.move_node("n3", Vector2(4, 4)))
+	assert_false(_store.can_undo())
+
+
+func test_a_move_that_squeezes_a_door_out_of_its_wall_is_refused() -> void:
+	# The door o1 spans 0.6 m to 1.4 m along w1 (n1 -> n2).
+	assert_false(_store.can_move_node("n2", Vector2(1.2, 0)))
+	assert_false(_store.move_node("n2", Vector2(1.2, 0)))
+	assert_eq(_node_pos("n2"), Vector2(4, 0))
+	assert_true(_store.can_move_node("n2", Vector2(2, 0)))
+
+
+func test_a_move_that_collapses_a_wall_is_refused() -> void:
+	assert_false(_store.move_node("n3", Vector2(4, 0.01)), "w2 would be 1 cm long")
+
+
+func test_update_wall_thickness_and_height() -> void:
+	assert_true(_store.update_wall("w2", {"thickness": 0.1, "height": 2.2}))
+	var wall: Wall = _store.project.get_wall("w2")
+	assert_almost_eq(wall.thickness, 0.1, EPS)
+	assert_almost_eq(wall.height, 2.2, EPS)
+	_store.undo()
+	assert_almost_eq(_store.project.get_wall("w2").thickness, 0.2, EPS)
+
+
+func test_wall_length_moves_its_end_node() -> void:
+	assert_true(_store.update_wall("w2", {"length": 3.0}))  # n2 (4,0) -> n3
+	assert_almost_eq(_node_pos("n3"), Vector2(4, 3), Vector2(EPS, EPS))
+	assert_eq(_node_pos("n2"), Vector2(4, 0))
+
+
+func test_invalid_wall_changes_are_refused() -> void:
+	assert_false(_store.update_wall("w2", {"thickness": 0.0}))
+	assert_false(_store.update_wall("w2", {"colour": 1}))
+	assert_false(_store.update_wall("nope", {"height": 2.0}))
+	assert_false(_store.update_wall("w1", {"length": 1.0}), "the door would stick out")
+	assert_false(_store.can_undo())
+
+
+func test_remove_wall_takes_its_openings_and_keeps_room_corners() -> void:
+	assert_true(_store.remove_wall("w1"))
+	assert_null(_store.project.get_wall("w1"))
+	assert_eq(_store.project.openings.size(), 0, "the door went with its wall")
+	assert_eq(_store.project.nodes.size(), 4, "corners still outline the room")
+	_store.undo()
+	assert_not_null(_store.project.get_wall("w1"))
+	assert_eq(_store.project.openings.size(), 1)
+
+
+func test_remove_wall_deletes_corners_left_alone() -> void:
+	_store.project.nodes.append(Fixtures.plan_node("n5", 6, 0))
+	_store.project.walls.append(Fixtures.wall("w5", "n2", "n5"))
+	assert_true(_store.remove_wall("w5"))
+	assert_null(_store.project.get_plan_node("n5"), "no wall, no room")
+	assert_not_null(_store.project.get_plan_node("n2"), "still holds w1 and w2")
+
+
+func test_undoing_a_structure_edit_from_furniture_mode_switches_mode() -> void:
+	_store.move_node("n3", Vector2(5, 5))
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	watch_signals(_store)
+	assert_true(_store.undo())
+	assert_eq(_store.edit_mode, Store.EditMode.STRUCTURE)
+	assert_signal_emitted_with_parameters(_store, "edit_mode_changed", [Store.EditMode.STRUCTURE])
+	assert_eq(_node_pos("n3"), Vector2(4, 4))
+
+
+func test_undoing_a_furniture_edit_from_structure_mode_switches_back() -> void:
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	_store.update_furniture("f1", {"name": "Banquette"})
+	_store.set_edit_mode(Store.EditMode.STRUCTURE)
+	_store.undo()
+	assert_eq(_store.edit_mode, Store.EditMode.FURNITURE)
+	assert_eq(_store.get_furniture("f1").name, "Canapé")
+	_store.set_edit_mode(Store.EditMode.STRUCTURE)
+	_store.redo()
+	assert_eq(_store.edit_mode, Store.EditMode.FURNITURE)
+	assert_eq(_store.get_furniture("f1").name, "Banquette")
+
+
+func test_undo_with_empty_history_keeps_the_mode() -> void:
+	assert_false(_store.undo())
+	assert_false(_store.redo())
+	assert_eq(_store.edit_mode, Store.EditMode.STRUCTURE)
+
+
+func test_history_states_are_not_shared_with_the_project() -> void:
+	_store.move_node("n3", Vector2(5, 5))
+	_store.project.get_plan_node("n3").pos = Vector2(9, 9)  # outside the store, as a bug would
+	_store.undo()
+	_store.redo()
+	assert_eq(_node_pos("n3"), Vector2(5, 5))
+
+
+func test_loading_a_project_returns_to_furniture_mode() -> void:
+	watch_signals(_store)
+	_store.new_project()
+	assert_eq(_store.edit_mode, Store.EditMode.FURNITURE)
+	assert_signal_emitted(_store, "edit_mode_changed")
+
+
+func test_structure_edits_make_the_project_dirty() -> void:
+	_store.move_node("n3", Vector2(5, 5))
+	assert_true(_store.is_dirty())
+	_store.undo()
+	assert_false(_store.is_dirty())
```

- [ ] **Step 2: Tests ciblés**

Run, un fichier à la fois (GUT ne garde qu'un seul `-gselect`) :
- `./scripts/test.sh -gselect=test_project_store`
Expected: tous passent.

- [ ] **Step 3: Suite complète**

Run: `./scripts/test.sh`
Expected: **478** tests, tous passent (un seul avertissement attendu, celui de la sauvegarde automatique, et les erreurs moteur du test d'image de calque corrompue).

- [ ] **Step 4: Commit**

```bash
godot --headless --path . --import
git add -A src tests README.md
git commit -m "feat: edit modes and undoable structure edits in the project store"
```

### Task 3: Vues : reconstruction en place, poignées, meubles estompés

**Files:**
- Modify: `src/world/world_view.gd`, `src/world/furniture_view.gd`, `src/world/palette.gd`, `src/ui/catalog_panel.gd`
- Create: `src/world/structure_view.gd`
- Test: `tests/unit/test_world_view.gd`, `tests/unit/test_furniture_view.gd`, `tests/unit/test_ui_panels.gd`

**Interfaces:**
- Consumes: `ProjectData.walls_at()` (Task 1), `DimensionLine` (M4).
- Produces: `WorldView.refresh(project: ProjectData)` (reconstruit sans animer ; garde les murs déjà abaissés et le centre du masquage), `WorldView.wall_display_height(wall_id: String) -> float`, `WorldView.highlight_wall(wall_id: String)` / `highlighted_wall() -> String` ; `StructureView` (nœud nommé `Structure`) avec `show_structure(project, kind: StringName, id: String)`, `handle(node_id) -> MeshInstance3D` (nœuds `Handle_<id>`), `is_handle_selected(node_id) -> bool`, cotes nommées `Length_<wall_id>`, constante `LIFT := 0.02` ; `FurnitureView.set_dimmed(dimmed: bool)`, `is_dimmed() -> bool`, `DIMMED_ALPHA := 0.4` ; `Palette.apply_toggle_style(button: Button)` ; `CatalogPanel.set_enabled(enabled: bool)`.

- [ ] **Step 1: Appliquer le patch**

```diff
diff --git a/src/world/world_view.gd b/src/world/world_view.gd
index 509621f..86cdc71 100644
--- a/src/world/world_view.gd
+++ b/src/world/world_view.gd
@@ -1,7 +1,7 @@
 class_name WorldView
 extends Node3D
-## Rebuilds walls and floors when a project is loaded, and lowers the walls
-## that hide the inside from the orbit camera.
+## Rebuilds walls and floors when a project is loaded or its structure changes,
+## and lowers the walls that hide the inside from the orbit camera.
 
 const CUTAWAY_TWEEN_SECONDS := 0.25
 
@@ -14,9 +14,59 @@ var _last_forward := Vector2.ZERO
 var _lowered := {}  # wall id -> bool, to tween only on change
 var _suspended := false  # plan view: every wall stands at full height
 var _tweens := {}  # wall id -> Tween, so a new move replaces the running one
+var _highlighted := ""  # wall drawn in the selection colour (Structure mode)
+var _highlight_material := Palette.material(Palette.SELECTION)
 
 
 func show_project(project: ProjectData) -> void:
+	_center = Cutaway.apartment_center(project)
+	_lowered.clear()
+	_build(project)
+
+
+## Rebuilds the walls and floors of `project` (an edit, or a preview while
+## dragging) without animating the cutaway: walls already lowered stay lowered.
+## The cutaway centre is kept, so editing never flips which walls are lowered.
+func refresh(project: ProjectData) -> void:
+	_build(project)
+	for wall in project.walls:
+		var node := _walls.get_node_or_null(NodePath(wall.id)) as Node3D
+		if node != null and _lowered.has(wall.id):
+			node.scale.y = Cutaway.target_scale(cutaway_mode, _lowered[wall.id], wall.height)
+
+
+## Height of the wall as currently drawn (lowered by the cutaway or not); 0 for
+## an unknown id.
+func wall_display_height(wall_id: String) -> float:
+	if _project == null:
+		return 0.0
+	var wall := _project.get_wall(wall_id)
+	var node := _walls.get_node_or_null(NodePath(wall_id)) as Node3D
+	if wall == null or node == null:
+		return 0.0
+	return wall.height * node.scale.y
+
+
+## Draws the wall in the selection colour ("" for none); kept across rebuilds.
+func highlight_wall(wall_id: String) -> void:
+	_set_wall_material(_highlighted, null)
+	_highlighted = wall_id
+	_set_wall_material(_highlighted, _highlight_material)
+
+
+func highlighted_wall() -> String:
+	return _highlighted
+
+
+func _set_wall_material(wall_id: String, material: Material) -> void:
+	if _walls == null or wall_id == "":
+		return
+	var body := _walls.get_node_or_null("%s/Body" % wall_id) as CSGPolygon3D
+	if body != null:
+		body.material_override = material
+
+
+func _build(project: ProjectData) -> void:
 	_project = project
 	for child in get_children():
 		remove_child(child)
@@ -25,8 +75,9 @@ func show_project(project: ProjectData) -> void:
 	_walls = WallBuilder.build(project)
 	add_child(_floors)
 	add_child(_walls)
-	_center = Cutaway.apartment_center(project)
-	_lowered.clear()
+	_set_wall_material(_highlighted, _highlight_material)
+	for tween in _tweens.values():
+		tween.kill()
 	_tweens.clear()
 	_last_forward = Vector2.ZERO
 
diff --git a/src/world/furniture_view.gd b/src/world/furniture_view.gd
index e5bdfec..ca28d5e 100644
--- a/src/world/furniture_view.gd
+++ b/src/world/furniture_view.gd
@@ -5,10 +5,13 @@ extends Node3D
 
 ## Contains a space, which ProjectValidator forbids in ids, so it never clashes with an item.
 const GHOST_NAME := "Ghost preview"
+## Opacity of the blocks while the structure is edited.
+const DIMMED_ALPHA := 0.4
 
 var _selected_id := ""
 var _outline := Palette.outline_material()
 var _store: Node
+var _dimmed := false
 
 
 ## Keeps the blocks in sync with a ProjectStore (the autoload, or a test double).
@@ -48,6 +51,7 @@ func add_item(item: FurnitureItem) -> void:
 	node.name = item.id
 	add_child(node)
 	_place(node, item.pos, item.rotation_deg)
+	_apply_dim(node, item.color)
 
 
 ## Rebuilds the item's block from its current data.
@@ -58,7 +62,7 @@ func update_item(item: FurnitureItem) -> void:
 	var box := node.get_node("Box") as MeshInstance3D
 	(box.mesh as BoxMesh).size = item.size
 	box.position.y = item.size.y / 2.0
-	(box.material_override as StandardMaterial3D).albedo_color = item.color
+	_apply_dim(node, item.color)
 	_place(node, item.pos, item.rotation_deg)
 
 
@@ -92,6 +96,21 @@ func selected_id() -> String:
 	return _selected_id
 
 
+## Fades every block (Structure mode), or restores them.
+func set_dimmed(dimmed: bool) -> void:
+	_dimmed = dimmed
+	if _store == null:
+		return
+	for item in _store.project.furniture:
+		var node := get_node_or_null(NodePath(item.id))
+		if node != null:
+			_apply_dim(node, item.color)
+
+
+func is_dimmed() -> bool:
+	return _dimmed
+
+
 func show_ghost(size: Vector3, color: Color) -> void:
 	hide_ghost()
 	var ghost_color := color
@@ -126,6 +145,14 @@ func _set_outline(id: String, on: bool) -> void:
 	mat.next_pass = _outline if on else null
 
 
+func _apply_dim(node: Node, color: Color) -> void:
+	var mat := (node.get_node("Box") as MeshInstance3D).material_override as StandardMaterial3D
+	var shown := color
+	shown.a = DIMMED_ALPHA if _dimmed else 1.0
+	mat.albedo_color = shown
+	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _dimmed else BaseMaterial3D.TRANSPARENCY_DISABLED
+
+
 static func _block(size: Vector3, material: StandardMaterial3D) -> Node3D:
 	var node := Node3D.new()
 	var box := MeshInstance3D.new()
diff --git a/src/world/structure_view.gd b/src/world/structure_view.gd
new file mode 100644
index 0000000..aae1827
--- /dev/null
+++ b/src/world/structure_view.gd
@@ -0,0 +1,89 @@
+class_name StructureView
+extends Node3D
+## Structure mode overlay: a handle on every corner, the selection highlighted,
+## and the length of the walls being edited. Drawn above the walls (no depth
+## test) so corners hidden behind a wall can still be grabbed. Never edits data.
+
+const HANDLE_RADIUS := 0.1
+const HANDLE_HEIGHT := 0.01
+const LIFT := 0.02
+const HANDLE_COLOR := Color("#3d6fb6")
+const WALL_HIGHLIGHT_ALPHA := 0.55
+
+var _handle_material := _overlay_material(HANDLE_COLOR)
+var _selected_material := _overlay_material(Palette.SELECTION)
+var _wall_material := _overlay_material(Color(Palette.SELECTION, WALL_HIGHLIGHT_ALPHA))
+
+
+func _init() -> void:
+	name = "Structure"
+
+
+## Redraws the overlay for `project`. `kind` is &"node", &"wall" or &"" (no
+## selection): a selected corner shows the length of its walls, a selected wall
+## is highlighted with its length.
+func show_structure(project: ProjectData, kind: StringName, id: String) -> void:
+	for child in get_children():
+		remove_child(child)
+		child.queue_free()
+	for node in project.nodes:
+		var selected := kind == &"node" and node.id == id
+		add_child(_handle(node, _selected_material if selected else _handle_material))
+	var measured: Array[Wall] = []
+	if kind == &"node":
+		measured = project.walls_at(id)
+	elif kind == &"wall" and project.get_wall(id) != null:
+		measured = [project.get_wall(id)]
+		add_child(_wall_highlight(project, project.get_wall(id)))
+	for wall in measured:
+		var line := DimensionLine.new()
+		line.name = "Length_%s" % wall.id
+		add_child(line)
+		line.set_points(project.get_plan_node(wall.a).pos, project.get_plan_node(wall.b).pos)
+
+
+func handle(node_id: String) -> MeshInstance3D:
+	return get_node_or_null("Handle_%s" % node_id) as MeshInstance3D
+
+
+func is_handle_selected(node_id: String) -> bool:
+	var found := handle(node_id)
+	return found != null and found.material_override == _selected_material
+
+
+func _handle(node: PlanNode, material: Material) -> MeshInstance3D:
+	var disc := MeshInstance3D.new()
+	disc.name = "Handle_%s" % node.id
+	var mesh := CylinderMesh.new()
+	mesh.top_radius = HANDLE_RADIUS
+	mesh.bottom_radius = HANDLE_RADIUS
+	mesh.height = HANDLE_HEIGHT
+	disc.mesh = mesh
+	disc.material_override = material
+	disc.position = Vector3(node.pos.x, LIFT, node.pos.y)
+	return disc
+
+
+func _wall_highlight(project: ProjectData, wall: Wall) -> MeshInstance3D:
+	var a := project.get_plan_node(wall.a).pos
+	var b := project.get_plan_node(wall.b).pos
+	var bar := MeshInstance3D.new()
+	bar.name = "Highlight"
+	var mesh := BoxMesh.new()
+	mesh.size = Vector3(a.distance_to(b), HANDLE_HEIGHT, wall.thickness)
+	bar.mesh = mesh
+	bar.material_override = _wall_material
+	var mid := (a + b) / 2.0
+	bar.transform = Transform3D(Basis(Vector3.UP, -(b - a).angle()), Vector3(mid.x, LIFT, mid.y))
+	return bar
+
+
+static func _overlay_material(color: Color) -> StandardMaterial3D:
+	var mat := StandardMaterial3D.new()
+	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
+	mat.albedo_color = color
+	mat.no_depth_test = true
+	mat.render_priority = 1
+	if color.a < 1.0:
+		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
+	return mat
diff --git a/src/world/palette.gd b/src/world/palette.gd
index b816565..54e65e4 100644
--- a/src/world/palette.gd
+++ b/src/world/palette.gd
@@ -45,6 +45,17 @@ static func outline_material() -> StandardMaterial3D:
 	return mat
 
 
+## Toggle button that shows clearly when it is on (the mode switch).
+static func apply_toggle_style(button: Button) -> void:
+	# Same margins as the theme's button, so the text keeps its room when on.
+	var on := button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
+	on.bg_color = SELECTION
+	for state in ["pressed", "hover_pressed"]:
+		button.add_theme_stylebox_override(state, on)
+	for state in ["font_pressed_color", "font_hover_pressed_color"]:
+		button.add_theme_color_override(state, PANEL_BACKGROUND)
+
+
 ## Background shared by the interface panels: dark, slightly transparent, padded.
 static func panel_style() -> StyleBoxFlat:
 	var style := StyleBoxFlat.new()
diff --git a/src/ui/catalog_panel.gd b/src/ui/catalog_panel.gd
index b4dae8f..14cbbae 100644
--- a/src/ui/catalog_panel.gd
+++ b/src/ui/catalog_panel.gd
@@ -46,5 +46,11 @@ func populate(presets: Array[FurniturePreset]) -> void:
 		list.add_child(button)
 
 
+## Greys out every preset (Structure mode), or enables them again.
+func set_enabled(enabled: bool) -> void:
+	for button in find_children("*", "Button", true, false):
+		(button as Button).disabled = not enabled
+
+
 func button_for(preset_id: String) -> Button:
 	return find_child(preset_id, true, false) as Button
diff --git a/tests/unit/test_world_view.gd b/tests/unit/test_world_view.gd
index 6c34eaf..e4bb570 100644
--- a/tests/unit/test_world_view.gd
+++ b/tests/unit/test_world_view.gd
@@ -125,3 +125,45 @@ func test_resuming_recomputes_the_cutaway() -> void:
 	_view.update_cutaway(LOOKING_NORTH)
 	await wait_seconds(TWEEN_WAIT)
 	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3)
+
+
+func test_refresh_rebuilds_from_the_given_project() -> void:
+	var moved := Fixtures.square_room()
+	moved.get_plan_node("n3").pos = Vector2(5, 5)
+	_view.refresh(moved)
+	await wait_physics_frames(1)
+	assert_eq(_view.get_node("Walls").get_child_count(), 4)
+	var body := _view.get_node("Walls/w2/Body") as CSGPolygon3D
+	var reaches_new_corner := false
+	for p in body.polygon:
+		reaches_new_corner = reaches_new_corner or p.distance_to(Vector2(5, 5)) < 0.3
+	assert_true(reaches_new_corner, "w2 follows n3: %s" % [body.polygon])
+
+
+func test_refresh_keeps_lowered_walls_lowered_without_a_tween() -> void:
+	_view.update_cutaway(LOOKING_NORTH)
+	await wait_seconds(TWEEN_WAIT)
+	_view.refresh(Fixtures.square_room())
+	assert_almost_eq(_scale_y("w3"), 0.08, 1e-3, "still lowered right away")
+	assert_eq(_scale_y("w1"), 1.0)
+	_view.update_cutaway(LOOKING_NORTH)
+	assert_eq(get_tree().get_processed_tweens().size(), 0, "nothing left to animate")
+
+
+func test_wall_display_height_follows_the_cutaway() -> void:
+	assert_almost_eq(_view.wall_display_height("w3"), 2.5, 1e-3)
+	_view.update_cutaway(LOOKING_NORTH)
+	await wait_seconds(TWEEN_WAIT)
+	assert_almost_eq(_view.wall_display_height("w3"), 0.2, 1e-3)
+	assert_eq(_view.wall_display_height("nope"), 0.0)
+
+
+func test_highlighted_wall_survives_a_refresh_and_can_be_cleared() -> void:
+	_view.highlight_wall("w2")
+	var body := _view.get_node("Walls/w2/Body") as CSGPolygon3D
+	assert_not_null(body.material_override)
+	_view.refresh(Fixtures.square_room())
+	assert_not_null((_view.get_node("Walls/w2/Body") as CSGPolygon3D).material_override, "kept after a rebuild")
+	_view.highlight_wall("")
+	assert_null((_view.get_node("Walls/w2/Body") as CSGPolygon3D).material_override)
+	assert_eq(_view.highlighted_wall(), "")
diff --git a/tests/unit/test_furniture_view.gd b/tests/unit/test_furniture_view.gd
index 37f5bd6..e3ef1f8 100644
--- a/tests/unit/test_furniture_view.gd
+++ b/tests/unit/test_furniture_view.gd
@@ -125,3 +125,18 @@ func test_bound_store_edits_are_mirrored() -> void:
 	assert_null(_view.get_node_or_null("f1"))
 	store.undo()
 	assert_not_null(_view.get_node_or_null("f1"), "undo brings the block back")
+
+
+func test_dimming_fades_every_block_and_survives_updates() -> void:
+	var store: Node = autofree(preload("res://src/store/project_store.gd").new())
+	store.project = Fixtures.square_room()
+	_view.bind_store(store)
+	_view.set_dimmed(true)
+	var mat := _box("f1").material_override as StandardMaterial3D
+	assert_almost_eq(mat.albedo_color.a, FurnitureView.DIMMED_ALPHA, EPS)
+	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
+	_view.update_item(store.get_furniture("f1"))
+	assert_almost_eq(mat.albedo_color.a, FurnitureView.DIMMED_ALPHA, EPS, "an update keeps the fade")
+	_view.set_dimmed(false)
+	assert_eq(mat.albedo_color, store.get_furniture("f1").color)
+	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
diff --git a/tests/unit/test_ui_panels.gd b/tests/unit/test_ui_panels.gd
index 17df24d..c3e7ce5 100644
--- a/tests/unit/test_ui_panels.gd
+++ b/tests/unit/test_ui_panels.gd
@@ -178,3 +178,21 @@ func test_side_panels_are_padded() -> void:
 	var properties := _properties()
 	for panel in [catalog, properties]:
 		assert_gt((panel as PanelContainer).get_theme_stylebox("panel").content_margin_left, 0.0)
+
+
+func test_catalog_can_be_greyed_out() -> void:
+	var panel: CatalogPanel = add_child_autofree(CatalogPanel.new())
+	panel.populate(FurnitureCatalog.load_presets())
+	panel.set_enabled(false)
+	assert_true(panel.button_for("bed_160").disabled)
+	panel.set_enabled(true)
+	assert_false(panel.button_for("bed_160").disabled)
+
+
+func test_toggle_style_marks_the_on_state() -> void:
+	var button: Button = add_child_autofree(Button.new())
+	button.toggle_mode = true
+	Palette.apply_toggle_style(button)
+	var on := button.get_theme_stylebox("pressed") as StyleBoxFlat
+	assert_eq(on.bg_color, Palette.SELECTION)
+	assert_eq(on.get_margin(SIDE_LEFT), button.get_theme_stylebox("normal").get_margin(SIDE_LEFT))
```

- [ ] **Step 2: Tests ciblés**

Run, un fichier à la fois (GUT ne garde qu'un seul `-gselect`) :
- `./scripts/test.sh -gselect=test_world_view`
- `./scripts/test.sh -gselect=test_furniture_view`
- `./scripts/test.sh -gselect=test_ui_panels`
Expected: tous passent.

- [ ] **Step 3: Suite complète**

Run: `./scripts/test.sh`
Expected: **485** tests, tous passent (un seul avertissement attendu, celui de la sauvegarde automatique, et les erreurs moteur du test d'image de calque corrompue).

- [ ] **Step 4: Commit**

```bash
godot --headless --path . --import
git add -A src tests README.md
git commit -m "feat: in-place wall rebuild, corner handles and dimmed furniture"
```

### Task 4: Outil Structure, panneau et raccourcis

**Files:**
- Create: `src/tools/structure_tool.gd`, `src/ui/structure_panel.gd`
- Modify: `src/ui/shortcuts.gd`
- Test: `tests/unit/test_structure_tool.gd` (nouveau), `tests/unit/test_structure_panel.gd` (nouveau), `tests/unit/test_shortcuts.gd`

**Interfaces:**
- Consumes: tout le store de la Task 2, `StructureSnap` (Task 1), `WorldView.refresh/wall_display_height/highlight_wall` et `StructureView` (Task 3).
- Produces: `StructureTool` avec `setup(store, camera: Camera3D, world: WorldView, overlay: StructureView)`, `signal selection_changed(kind: StringName, id: String)`, `is_active()`, `is_dragging()`, `selected_kind()`, `selected_id()`, `select(kind, id)`, constante `PICK_RADIUS_PX := 14.0` ; `StructurePanel` (nommé `StructurePanel`) avec `bind_store(store)`, `show_selection(kind, id)`, champs `X`, `Z`, `Length`, `Thickness`, `Height`, bouton `DeleteWall` ; `Shortcuts.action_for` renvoie aussi `&"furniture_mode"` (1, AZERTY &, pavé 1), `&"structure_mode"` (2, AZERTY é, pavé 2), `&"undo"` (⌘Z), `&"redo"` (⌘⇧Z) ; groupes d'aide « Structure » et « Historique » ; `Shortcuts.structure_hint(mac)`.
- Note : à la fin de cette tâche, ⌘Z est encore traité par le `FurnitureTool` (`main` ignore `&"undo"` jusqu'à la Task 5) ; c'est voulu.
- Les tests de l'outil utilisent un `SubViewport` de 1000 × 1000 px : la fenêtre racine des tests sans écran ne fait que 64 px, trop peu pour un rayon de sélection en pixels.

- [ ] **Step 1: Appliquer le patch**

```diff
diff --git a/src/tools/structure_tool.gd b/src/tools/structure_tool.gd
new file mode 100644
index 0000000..6f80fb9
--- /dev/null
+++ b/src/tools/structure_tool.gd
@@ -0,0 +1,226 @@
+class_name StructureTool
+extends Node
+## Structure mode editing: click a corner or a wall to select it, drag a corner
+## (with magnetism, Alt for a free move), Suppr deletes the selected wall. Only
+## active while the store is in the Structure mode. Changes go through the
+## store; while dragging, the walls are previewed from a copy of the project.
+
+## `kind` is &"node", &"wall" or &"" when nothing is selected.
+signal selection_changed(kind: StringName, id: String)
+
+## A click this close to a corner (in screen pixels) grabs it.
+const PICK_RADIUS_PX := 14.0
+const RAY_LENGTH := 1000.0
+
+var store: Node
+var camera: Camera3D
+var world: WorldView
+var overlay: StructureView
+
+var _kind: StringName = &""
+var _id := ""
+var _dragging := false
+var _drag_offset := Vector2.ZERO
+var _drag_pos := Vector2.ZERO
+
+
+func setup(p_store: Node, p_camera: Camera3D, p_world: WorldView, p_overlay: StructureView) -> void:
+	store = p_store
+	camera = p_camera
+	world = p_world
+	overlay = p_overlay
+	store.structure_changed.connect(_on_structure_changed)
+	store.project_loaded.connect(_on_project_loaded)
+	store.edit_mode_changed.connect(_on_edit_mode_changed)
+	_on_edit_mode_changed(store.edit_mode)
+
+
+func is_active() -> bool:
+	return store != null and store.edit_mode == store.EditMode.STRUCTURE
+
+
+func is_dragging() -> bool:
+	return _dragging
+
+
+func selected_kind() -> StringName:
+	return _kind
+
+
+func selected_id() -> String:
+	return _id
+
+
+func select(kind: StringName, id: String) -> void:
+	if kind == _kind and id == _id:
+		return
+	_kind = kind
+	_id = id
+	world.highlight_wall(id if kind == &"wall" else "")
+	_redraw(store.project)
+	selection_changed.emit(kind, id)
+
+
+func _unhandled_input(event: InputEvent) -> void:
+	if not is_active():
+		return
+	if event is InputEventMouseMotion and _dragging:
+		_on_drag(event)
+	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
+		if event.pressed:
+			_on_left_press(event)
+		elif _dragging:
+			_finish_drag()
+	elif event is InputEventKey and event.pressed and not event.echo:
+		_on_key(event)
+
+
+func _on_left_press(event: InputEventMouseButton) -> void:
+	# Lets a focused panel field commit before the selection changes.
+	get_viewport().gui_release_focus()
+	var node_id := _pick_node(event.position)
+	if node_id != "":
+		select(&"node", node_id)
+		var ground = _ground_point(event.position)
+		if ground != null:
+			_dragging = true
+			_drag_pos = store.project.get_plan_node(node_id).pos
+			_drag_offset = _drag_pos - ground
+		get_viewport().set_input_as_handled()
+		return
+	var wall_id := _pick_wall(event.position)
+	if wall_id != "":
+		select(&"wall", wall_id)
+		get_viewport().set_input_as_handled()
+		return
+	select(&"", "")  # Left unhandled so the camera still sees double clicks.
+
+
+func _on_drag(event: InputEventMouseMotion) -> void:
+	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
+		_finish_drag()  # The release went to a GUI control.
+		return
+	var ground = _ground_point(event.position)
+	if ground == null:
+		return
+	var target := StructureSnap.snap_node(store.project, _id, ground + _drag_offset, event.alt_pressed)
+	# An invalid spot (a door squeezed out, a wall collapsed) keeps the last valid one.
+	if store.can_move_node(_id, target):
+		_drag_pos = target
+		var preview: ProjectData = store.project.copy()
+		preview.get_plan_node(_id).pos = target
+		world.refresh(preview)
+		_redraw(preview)
+	get_viewport().set_input_as_handled()
+
+
+func _finish_drag() -> void:
+	_dragging = false
+	var moved: bool = not store.project.get_plan_node(_id).pos.is_equal_approx(_drag_pos)
+	if moved and not store.move_node(_id, _drag_pos):
+		_show_stored()  # Refused after all: drop the preview.
+	get_viewport().set_input_as_handled()
+
+
+func _cancel_drag() -> void:
+	if _dragging:
+		_dragging = false
+		_show_stored()
+
+
+func _on_key(event: InputEventKey) -> void:
+	if event.keycode == KEY_ESCAPE:
+		if _dragging:
+			_cancel_drag()
+		elif _kind != &"":
+			select(&"", "")
+		else:
+			return
+	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE] and _kind == &"wall" and not _dragging:
+		store.remove_wall(_id)
+	else:
+		return
+	get_viewport().set_input_as_handled()
+
+
+## Nearest corner within PICK_RADIUS_PX of the screen point, or "".
+func _pick_node(screen_pos: Vector2) -> String:
+	var best := ""
+	var best_distance := PICK_RADIUS_PX
+	for node in store.project.nodes:
+		var world_pos := Vector3(node.pos.x, StructureView.LIFT, node.pos.y)
+		if camera.is_position_behind(world_pos):
+			continue
+		var distance := camera.unproject_position(world_pos).distance_to(screen_pos)
+		if distance <= best_distance:
+			best = node.id
+			best_distance = distance
+	return best
+
+
+## Nearest wall the mouse ray hits, at its displayed height (lowered walls are
+## picked at their lowered height), or "".
+func _pick_wall(screen_pos: Vector2) -> String:
+	var from := camera.project_ray_origin(screen_pos)
+	var to := from + camera.project_ray_normal(screen_pos) * RAY_LENGTH
+	var footprints := Geometry.wall_footprints(store.project)
+	var best := ""
+	var best_distance := INF
+	for wall_id in footprints:
+		var hit := Geometry3D.segment_intersects_convex(from, to,
+			_prism_planes(footprints[wall_id], world.wall_display_height(wall_id)))
+		if not hit.is_empty() and from.distance_to(hit[0]) < best_distance:
+			best = wall_id
+			best_distance = from.distance_to(hit[0])
+	return best
+
+
+## Outward planes of a footprint (counter-clockwise in x/z) extruded to `height`.
+static func _prism_planes(footprint: PackedVector2Array, height: float) -> Array[Plane]:
+	var planes: Array[Plane] = [Plane(Vector3.DOWN, 0.0), Plane(Vector3.UP, height)]
+	for i in footprint.size():
+		var p := footprint[i]
+		var q := footprint[(i + 1) % footprint.size()]
+		var outward := Vector3(q.y - p.y, 0.0, -(q.x - p.x)).normalized()
+		planes.append(Plane(outward, Vector3(p.x, 0.0, p.y)))
+	return planes
+
+
+func _ground_point(screen_pos: Vector2) -> Variant:
+	var hit = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen_pos),
+		camera.project_ray_normal(screen_pos))
+	return null if hit == null else Vector2(hit.x, hit.z)
+
+
+func _show_stored() -> void:
+	world.refresh(store.project)
+	_redraw(store.project)
+
+
+func _redraw(project: ProjectData) -> void:
+	if overlay.visible:
+		overlay.show_structure(project, _kind, _id)
+
+
+func _on_structure_changed() -> void:
+	_cancel_drag()
+	var project: ProjectData = store.project
+	var gone := (_kind == &"node" and project.get_plan_node(_id) == null) \
+			or (_kind == &"wall" and project.get_wall(_id) == null)
+	if gone:
+		select(&"", "")
+	else:
+		_redraw(project)
+
+
+func _on_project_loaded() -> void:
+	_cancel_drag()
+	select(&"", "")
+	_redraw(store.project)
+
+
+func _on_edit_mode_changed(_mode: int) -> void:
+	_cancel_drag()
+	select(&"", "")
+	overlay.visible = is_active()
+	_redraw(store.project)
diff --git a/src/ui/structure_panel.gd b/src/ui/structure_panel.gd
new file mode 100644
index 0000000..94b490f
--- /dev/null
+++ b/src/ui/structure_panel.gd
@@ -0,0 +1,134 @@
+class_name StructurePanel
+extends PanelContainer
+## Right-hand panel of the Structure mode: position of the selected corner, or
+## length, thickness and height of the selected wall. Every committed field is
+## one store edit; a refused value springs back. Hidden when nothing is selected.
+
+const PANEL_WIDTH := 260.0
+const CM_PER_M := 100.0
+const POSITION_LIMIT_M := 100.0
+const MIN_LENGTH_CM := 5.0
+const MAX_LENGTH_CM := 5000.0
+const MIN_THICKNESS_CM := 2.0
+const MAX_THICKNESS_CM := 100.0
+const MIN_HEIGHT_CM := 10.0
+const MAX_HEIGHT_CM := 500.0
+
+var store: Node
+var _kind: StringName = &""
+var _id := ""
+var _filling := false
+var _title: Label
+var _node_fields: VBoxContainer
+var _wall_fields: VBoxContainer
+var _x: SpinBox
+var _z: SpinBox
+var _length: SpinBox
+var _thickness: SpinBox
+var _height: SpinBox
+
+
+func _init() -> void:
+	name = "StructurePanel"
+	custom_minimum_size.x = PANEL_WIDTH
+	size_flags_vertical = Control.SIZE_EXPAND_FILL
+	add_theme_stylebox_override("panel", Palette.panel_style())
+	var form := VBoxContainer.new()
+	add_child(form)
+	_title = Label.new()
+	form.add_child(_title)
+	_node_fields = VBoxContainer.new()
+	form.add_child(_node_fields)
+	_x = _spin(_node_fields, "X", "Position X (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
+	_z = _spin(_node_fields, "Z", "Position Z (m)", -POSITION_LIMIT_M, POSITION_LIMIT_M, 0.01)
+	_wall_fields = VBoxContainer.new()
+	form.add_child(_wall_fields)
+	_length = _spin(_wall_fields, "Length", "Longueur (cm)", MIN_LENGTH_CM, MAX_LENGTH_CM, 1.0)
+	_thickness = _spin(_wall_fields, "Thickness", "Épaisseur (cm)", MIN_THICKNESS_CM, MAX_THICKNESS_CM, 1.0)
+	_height = _spin(_wall_fields, "Height", "Hauteur (cm)", MIN_HEIGHT_CM, MAX_HEIGHT_CM, 1.0)
+	var delete := Button.new()
+	delete.name = "DeleteWall"
+	delete.text = "Supprimer le mur"
+	delete.focus_mode = Control.FOCUS_NONE
+	delete.pressed.connect(_delete_wall)
+	_wall_fields.add_child(delete)
+	var hint := Label.new()
+	hint.text = Shortcuts.structure_hint()
+	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
+	hint.add_theme_font_size_override("font_size", 11)
+	form.add_child(hint)
+	_x.value_changed.connect(_commit_node.bind(Vector2.AXIS_X))
+	_z.value_changed.connect(_commit_node.bind(Vector2.AXIS_Y))
+	_length.value_changed.connect(_commit_wall.bind("length", _length))
+	_thickness.value_changed.connect(_commit_wall.bind("thickness", _thickness))
+	_height.value_changed.connect(_commit_wall.bind("height", _height))
+	visible = false
+
+
+## Bound methods (not lambdas) so the connection dies with the panel.
+func bind_store(p_store: Node) -> void:
+	store = p_store
+	store.structure_changed.connect(_refill)
+
+
+## Shows the corner or wall with this id; hides the panel for &"" or an unknown id.
+func show_selection(kind: StringName, id: String) -> void:
+	_kind = kind
+	_id = id
+	_refill()
+
+
+func _refill() -> void:
+	var node: PlanNode = store.project.get_plan_node(_id) if _kind == &"node" else null
+	var wall: Wall = store.project.get_wall(_id) if _kind == &"wall" else null
+	visible = node != null or wall != null
+	_node_fields.visible = node != null
+	_wall_fields.visible = wall != null
+	_filling = true
+	if node != null:
+		_title.text = "Coin"
+		_x.value = node.pos.x
+		_z.value = node.pos.y
+	elif wall != null:
+		_title.text = "Mur"
+		_length.value = store.project.wall_length(wall) * CM_PER_M
+		_thickness.value = wall.thickness * CM_PER_M
+		_height.value = wall.height * CM_PER_M
+	_filling = false
+
+
+## Changes one coordinate; the other keeps its exact value instead of the
+## SpinBox-rounded one.
+func _commit_node(value: float, axis: Vector2.Axis) -> void:
+	if _filling or _kind != &"node":
+		return
+	var pos: Vector2 = store.project.get_plan_node(_id).pos
+	pos[axis] = value
+	if not store.move_node(_id, pos):
+		_refill()
+
+
+func _commit_wall(_value: float, field: String, spin: SpinBox) -> void:
+	if _filling or _kind != &"wall":
+		return
+	if not store.update_wall(_id, {field: spin.value / CM_PER_M}):
+		_refill()
+
+
+func _delete_wall() -> void:
+	if _kind == &"wall":
+		store.remove_wall(_id)
+
+
+static func _spin(form: VBoxContainer, node_name: String, label_text: String, min_value: float,
+		max_value: float, step: float) -> SpinBox:
+	var label := Label.new()
+	label.text = label_text
+	form.add_child(label)
+	var spin := SpinBox.new()
+	spin.name = node_name
+	spin.min_value = min_value
+	spin.max_value = max_value
+	spin.step = step
+	form.add_child(spin)
+	return spin
diff --git a/src/ui/shortcuts.gd b/src/ui/shortcuts.gd
index eb5fad9..df7ca97 100644
--- a/src/ui/shortcuts.gd
+++ b/src/ui/shortcuts.gd
@@ -43,10 +43,17 @@ static func groups() -> Array[Dictionary]:
 			_entry(["shift", "Molette (souris)"], "Pivoter de ±15°"),
 			_entry(["Suppr / ⌫"], "Supprimer"),
 			_entry(["cmd", "D"], "Dupliquer"),
-			_entry(["cmd", "Z"], "Annuler"),
-			_entry(["cmd", "shift", "Z"], "Rétablir"),
 			_entry(["Échap"], "Abandonner l'ajout ou désélectionner"),
 		]),
+		_group("Structure", [
+			_entry(["1"], "Mode Meubles"),
+			_entry(["2"], "Mode Structure : coins et murs"),
+			_entry(["Clic sur un coin + glisser"], "Déplacer le coin et ses murs"),
+			_entry(["alt"], "Déplacement libre, sans aimant (en glissant)"),
+			_entry(["Clic sur un mur"], "Sélectionner le mur"),
+			_entry(["Suppr / ⌫"], "Supprimer le mur sélectionné"),
+			_entry(["Échap"], "Désélectionner"),
+		]),
 		_group("Vue et mesures", [
 			_entry(["Tab"], "Vue plan, ou retour à la vue orbitale"),
 			_entry(["O"], "Vue orbitale"),
@@ -54,6 +61,10 @@ static func groups() -> Array[Dictionary]:
 			_entry(["M"], "Mesurer : cliquer deux points"),
 			_entry(["Échap"], "Effacer toutes les mesures"),
 		]),
+		_group("Historique", [
+			_entry(["cmd", "Z"], "Annuler (passe dans le mode de la modification)"),
+			_entry(["cmd", "shift", "Z"], "Rétablir"),
+		]),
 		_group("Fichier", [
 			_entry(["cmd", "shift", "O"], "Accueil : choisir un projet"),
 			_entry(["cmd", "O"], "Ouvrir un projet"),
@@ -75,12 +86,15 @@ static func groups() -> Array[Dictionary]:
 ## The interface action a key press triggers: &"toggle_catalog",
 ## &"toggle_inspector", &"help", &"cutaway", &"zoom_in", &"zoom_out",
 ## &"zoom_reset", &"welcome", &"open", &"save", &"save_as", &"plan_view",
-## &"orbit_view", &"underlay", &"measure", or &"" for none. Accepts the QWERTY and AZERTY variants.
+## &"orbit_view", &"underlay", &"measure", &"furniture_mode", &"structure_mode",
+## &"undo", &"redo", or &"" for none. Accepts the QWERTY and AZERTY variants.
 static func action_for(event: InputEventKey) -> StringName:
 	if not event.pressed or event.echo:
 		return &""
 	var character := char(event.unicode) if event.unicode > 0 else ""
 	if event.is_command_or_control_pressed():
+		if event.keycode == KEY_Z:
+			return &"redo" if event.shift_pressed else &"undo"
 		if event.keycode == KEY_O:
 			return &"welcome" if event.shift_pressed else &"open"
 		if event.keycode == KEY_S:
@@ -96,6 +110,11 @@ static func action_for(event: InputEventKey) -> StringName:
 		return &""
 	if character == "?" or event.keycode == KEY_F1:
 		return &"help"
+	# AZERTY types "&" and "é" on the digit keys: the physical key decides.
+	if event.physical_keycode == KEY_1 or event.keycode in [KEY_1, KEY_KP_1]:
+		return &"furniture_mode"
+	if event.physical_keycode == KEY_2 or event.keycode in [KEY_2, KEY_KP_2]:
+		return &"structure_mode"
 	match event.keycode:
 		KEY_TAB:
 			# Shift + Tab is reverse focus traversal.
@@ -121,6 +140,12 @@ static func furniture_hint(mac: bool = is_mac()) -> String:
 		format_keys(["shift", "Molette"], mac), format_keys(["cmd", "D"], mac), format_keys(["cmd", "Z"], mac)]
 
 
+## Short reminder shown under the structure panel.
+static func structure_hint(mac: bool = is_mac()) -> String:
+	return "Glisser un coin pour le déplacer · %s : sans aimant\nSuppr : supprimer le mur · 1 : meubles\n%s : annuler · ? : tous les raccourcis" % [
+		format_keys(["alt"], mac), format_keys(["cmd", "Z"], mac)]
+
+
 static func _group(title: String, entries: Array) -> Dictionary:
 	return {"title": title, "entries": entries}
 
diff --git a/tests/unit/test_structure_tool.gd b/tests/unit/test_structure_tool.gd
new file mode 100644
index 0000000..95047cf
--- /dev/null
+++ b/tests/unit/test_structure_tool.gd
@@ -0,0 +1,198 @@
+extends GutTest
+
+const Store := preload("res://src/store/project_store.gd")
+const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
+const EPS := 1e-3
+## The headless root viewport is 64 px wide, too small for pixel pick radii.
+const SCREEN_SIZE := Vector2i(1000, 1000)
+
+var _store: Node
+var _world: WorldView
+var _overlay: StructureView
+var _camera: Camera3D
+var _tool: StructureTool
+
+
+func before_each() -> void:
+	_store = autofree(Store.new())
+	_store.project = Fixtures.square_room()
+	_world = WorldView.new()
+	add_child_autofree(_world)
+	_world.show_project(_store.project)
+	_overlay = StructureView.new()
+	add_child_autofree(_overlay)
+	var screen := SubViewport.new()
+	screen.size = SCREEN_SIZE
+	add_child_autofree(screen)
+	_camera = Camera3D.new()
+	screen.add_child(_camera)
+	_camera.look_at_from_position(Vector3(2, 12, 2), Vector3(2, 0, 2), Vector3(0, 0, -1))
+	_camera.current = true
+	_tool = StructureTool.new()
+	add_child_autofree(_tool)
+	_tool.setup(_store, _camera, _world, _overlay)
+	_store.set_edit_mode(Store.EditMode.STRUCTURE)
+	# The handled flag is per viewport and only the engine clears it, between events.
+	get_viewport().push_input(InputEventJoypadMotion.new())
+
+
+func _screen(pos: Vector2, height := 0.0) -> Vector2:
+	return _camera.unproject_position(Vector3(pos.x, height, pos.y))
+
+
+func _click(pos: Vector2, pressed := true, height := 0.0) -> void:
+	var event := InputEventMouseButton.new()
+	event.button_index = MOUSE_BUTTON_LEFT
+	event.pressed = pressed
+	event.position = _screen(pos, height)
+	_tool._unhandled_input(event)
+
+
+func _move(pos: Vector2, alt := false, held := true) -> void:
+	var event := InputEventMouseMotion.new()
+	event.position = _screen(pos)
+	event.alt_pressed = alt
+	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
+	_tool._unhandled_input(event)
+
+
+func _key(keycode: Key) -> void:
+	var event := InputEventKey.new()
+	event.keycode = keycode
+	event.pressed = true
+	_tool._unhandled_input(event)
+
+
+func _node_pos(id: String) -> Vector2:
+	return _store.project.get_plan_node(id).pos
+
+
+func test_overlay_shows_a_handle_per_corner_only_in_structure_mode() -> void:
+	assert_true(_overlay.visible)
+	for id in ["n1", "n2", "n3", "n4"]:
+		assert_not_null(_overlay.handle(id), id)
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	assert_false(_overlay.visible)
+
+
+func test_click_near_a_corner_selects_it() -> void:
+	watch_signals(_tool)
+	_click(Vector2(4.03, 3.98))
+	assert_eq(_tool.selected_kind(), &"node")
+	assert_eq(_tool.selected_id(), "n3")
+	assert_signal_emitted_with_parameters(_tool, "selection_changed", [&"node", "n3"])
+	assert_true(_overlay.is_handle_selected("n3"))
+	assert_true(get_viewport().is_input_handled())
+
+
+func test_click_on_a_wall_selects_it_and_shows_its_length() -> void:
+	_click(Vector2(2, 4), true, 2.5)  # top of the south wall w3
+	assert_eq(_tool.selected_kind(), &"wall")
+	assert_eq(_tool.selected_id(), "w3")
+	var line := _overlay.get_node_or_null("Length_w3") as DimensionLine
+	assert_not_null(line)
+	assert_eq(line.label_text(), "400 cm")
+
+
+func test_click_on_the_floor_clears_the_selection_and_leaves_it_to_the_camera() -> void:
+	_tool.select(&"node", "n3")
+	_click(Vector2(2, 2))
+	assert_eq(_tool.selected_kind(), &"")
+	assert_false(get_viewport().is_input_handled(), "double clicks still reach the camera")
+
+
+func test_dragging_a_corner_previews_then_commits_one_step() -> void:
+	_click(Vector2(4, 4))
+	_move(Vector2(5.02, 4.51), true)
+	assert_eq(_node_pos("n3"), Vector2(4, 4), "nothing stored while dragging")
+	assert_not_null(_overlay.get_node_or_null("Length_w2"), "lengths of the corner's walls")
+	_click(Vector2(5.02, 4.51), false)
+	assert_almost_eq(_node_pos("n3"), Vector2(5.02, 4.51), Vector2(EPS, EPS))
+	_store.undo()
+	assert_eq(_node_pos("n3"), Vector2(4, 4))
+
+
+func test_drag_snaps_unless_alt_is_held() -> void:
+	_click(Vector2(4, 4))
+	_move(Vector2(4.06, 5.13))
+	_click(Vector2(4.06, 5.13), false)
+	assert_almost_eq(_node_pos("n3").x, 4.0, EPS, "w2 locked square to w1")
+
+
+func test_drag_keeps_the_last_valid_spot() -> void:
+	# Squeezing w1 below its door (0.6 m to 1.4 m from n1) is refused.
+	_click(Vector2(4, 0))
+	_move(Vector2(2.0, 0), true)
+	_move(Vector2(1.2, 0), true)
+	_click(Vector2(1.2, 0), false)
+	assert_almost_eq(_node_pos("n2"), Vector2(2, 0), Vector2(EPS, EPS))
+
+
+func test_click_on_a_corner_without_moving_records_nothing() -> void:
+	_click(Vector2(4, 4))
+	_click(Vector2(4, 4), false)
+	assert_false(_store.can_undo())
+
+
+func test_escape_cancels_a_drag_then_clears_the_selection() -> void:
+	_click(Vector2(4, 4))
+	_move(Vector2(5, 5), true)
+	_key(KEY_ESCAPE)
+	assert_false(_tool.is_dragging())
+	assert_eq(_tool.selected_id(), "n3")
+	_click(Vector2(5, 5), false)
+	assert_eq(_node_pos("n3"), Vector2(4, 4), "the release after a cancel moves nothing")
+	_key(KEY_ESCAPE)
+	assert_eq(_tool.selected_kind(), &"")
+
+
+func test_delete_removes_the_selected_wall() -> void:
+	_click(Vector2(2, 4), true, 2.5)
+	_key(KEY_DELETE)
+	assert_null(_store.project.get_wall("w3"))
+	assert_eq(_tool.selected_kind(), &"", "a deleted wall is no longer selected")
+
+
+func test_delete_ignores_a_selected_corner() -> void:
+	_click(Vector2(4, 4))
+	_click(Vector2(4, 4), false)
+	_key(KEY_BACKSPACE)
+	assert_eq(_store.project.walls.size(), 4)
+
+
+func test_tool_is_off_in_furniture_mode() -> void:
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	_click(Vector2(4, 4))
+	assert_eq(_tool.selected_kind(), &"")
+	assert_false(get_viewport().is_input_handled())
+
+
+func test_leaving_structure_mode_mid_drag_drops_the_preview() -> void:
+	_click(Vector2(4, 4))
+	_move(Vector2(5, 5), true)
+	_store.set_edit_mode(Store.EditMode.FURNITURE)
+	assert_false(_tool.is_dragging())
+	assert_eq(_tool.selected_kind(), &"")
+	assert_eq(_node_pos("n3"), Vector2(4, 4))
+
+
+func test_undo_that_removes_the_selected_corner_clears_the_selection() -> void:
+	_store.project.nodes.append(Fixtures.plan_node("n5", 6, 0))
+	_store.project.walls.append(Fixtures.wall("w5", "n2", "n5"))
+	_store.remove_wall("w5")
+	_store.undo()  # n5 is back
+	_tool.select(&"node", "n5")
+	_store.redo()  # n5 is gone again
+	assert_eq(_tool.selected_kind(), &"")
+
+
+func test_corner_hidden_by_a_lowered_wall_is_still_picked_before_the_wall() -> void:
+	_click(Vector2(0, 4))
+	assert_eq(_tool.selected_id(), "n4")
+
+
+func test_selected_wall_is_highlighted_in_the_view() -> void:
+	_tool.select(&"wall", "w3")
+	assert_eq(_world.highlighted_wall(), "w3")
+	_tool.select(&"node", "n3")
+	assert_eq(_world.highlighted_wall(), "")
diff --git a/tests/unit/test_structure_panel.gd b/tests/unit/test_structure_panel.gd
new file mode 100644
index 0000000..b72cae7
--- /dev/null
+++ b/tests/unit/test_structure_panel.gd
@@ -0,0 +1,87 @@
+extends GutTest
+
+const Store := preload("res://src/store/project_store.gd")
+const Fixtures := preload("res://tests/fixtures/project_fixtures.gd")
+const EPS := 1e-4
+
+var _store: Node
+var _panel: StructurePanel
+
+
+func before_each() -> void:
+	_store = autofree(Store.new())
+	_store.project = Fixtures.square_room()
+	_store.set_edit_mode(Store.EditMode.STRUCTURE)
+	_panel = add_child_autofree(StructurePanel.new())
+	_panel.bind_store(_store)
+
+
+func _spin(node_name: String) -> SpinBox:
+	return _panel.find_child(node_name, true, false) as SpinBox
+
+
+func test_hidden_without_selection() -> void:
+	assert_false(_panel.visible)
+	_panel.show_selection(&"node", "nope")
+	assert_false(_panel.visible)
+
+
+func test_shows_a_corner_position_without_editing() -> void:
+	_panel.show_selection(&"node", "n3")
+	assert_true(_panel.visible)
+	assert_eq(_spin("X").value, 4.0)
+	assert_eq(_spin("Z").value, 4.0)
+	assert_false(_spin("Length").is_visible_in_tree(), "wall fields hidden")
+	assert_false(_store.can_undo())
+
+
+func test_editing_x_moves_the_corner_and_keeps_the_exact_z() -> void:
+	_store.move_node("n3", Vector2(4, 4.1234))
+	_panel.show_selection(&"node", "n3")
+	_spin("X").value = 4.5
+	assert_almost_eq(_store.project.get_plan_node("n3").pos, Vector2(4.5, 4.1234), Vector2(EPS, EPS))
+
+
+func test_shows_a_wall_in_centimetres() -> void:
+	_panel.show_selection(&"wall", "w2")
+	assert_eq(_spin("Length").value, 400.0)
+	assert_eq(_spin("Thickness").value, 20.0)
+	assert_eq(_spin("Height").value, 250.0)
+	assert_false(_spin("X").is_visible_in_tree(), "corner fields hidden")
+
+
+func test_editing_wall_fields_updates_the_store_in_metres() -> void:
+	_panel.show_selection(&"wall", "w2")
+	_spin("Thickness").value = 10
+	_spin("Height").value = 220
+	_spin("Length").value = 300
+	var wall: Wall = _store.project.get_wall("w2")
+	assert_almost_eq(wall.thickness, 0.1, EPS)
+	assert_almost_eq(wall.height, 2.2, EPS)
+	assert_almost_eq(_store.project.wall_length(wall), 3.0, EPS)
+
+
+func test_a_refused_value_springs_back() -> void:
+	_panel.show_selection(&"wall", "w1")
+	_spin("Length").value = 100  # the door on w1 would stick out
+	assert_eq(_spin("Length").value, 400.0)
+	assert_almost_eq(_store.project.wall_length(_store.project.get_wall("w1")), 4.0, EPS)
+
+
+func test_refreshes_when_the_structure_changes_elsewhere() -> void:
+	_panel.show_selection(&"node", "n3")
+	_store.move_node("n3", Vector2(5, 6))
+	assert_eq(_spin("X").value, 5.0)
+	assert_eq(_spin("Z").value, 6.0)
+
+
+func test_hides_when_the_shown_wall_is_deleted() -> void:
+	_panel.show_selection(&"wall", "w2")
+	(_panel.find_child("DeleteWall", true, false) as Button).pressed.emit()
+	assert_null(_store.project.get_wall("w2"))
+	assert_false(_panel.visible)
+
+
+func test_hint_comes_from_the_shortcut_list() -> void:
+	var labels := _panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
+	assert_has(labels, Shortcuts.structure_hint())
diff --git a/tests/unit/test_shortcuts.gd b/tests/unit/test_shortcuts.gd
index fc59586..ab2eeb5 100644
--- a/tests/unit/test_shortcuts.gd
+++ b/tests/unit/test_shortcuts.gd
@@ -1,5 +1,8 @@
 extends GutTest
 
+## The keycode AZERTY reports for its unshifted "2" key ("é", Latin-1).
+const E_ACUTE := 0xE9 as Key
+
 
 func test_mac_uses_symbols() -> void:
 	assert_eq(Shortcuts.format_keys(["cmd", "shift", "Z"], true), "⌘ ⇧ Z")
@@ -17,7 +20,8 @@ func test_plain_tokens_are_kept() -> void:
 
 func test_groups_cover_camera_furniture_and_interface() -> void:
 	var titles: Array = Shortcuts.groups().map(func(g: Dictionary) -> String: return g.title)
-	assert_eq(titles, ["Caméra (souris)", "Caméra (trackpad)", "Meubles", "Vue et mesures", "Fichier", "Interface"])
+	assert_eq(titles, ["Caméra (souris)", "Caméra (trackpad)", "Meubles", "Structure", "Vue et mesures",
+		"Historique", "Fichier", "Interface"])
 
 
 func test_every_entry_has_keys_and_action() -> void:
@@ -29,7 +33,7 @@ func test_every_entry_has_keys_and_action() -> void:
 
 
 func test_interface_group_lists_panel_help_and_zoom_keys() -> void:
-	var interface: Dictionary = Shortcuts.groups()[5]
+	var interface: Dictionary = _group("Interface")
 	var keys: Array = interface.entries.map(func(e: Dictionary) -> String: return Shortcuts.format_keys(e.keys, false))
 	for expected in ["C", "I", "? / F1", "Ctrl + +", "Ctrl + −", "Ctrl + 0", "H"]:
 		assert_has(keys, expected)
@@ -123,3 +127,40 @@ func test_command_view_keys_are_ignored() -> void:
 
 func test_shift_tab_is_not_the_plan_view() -> void:
 	assert_eq(Shortcuts.action_for(_key(KEY_TAB, 0, false, true)), &"")
+
+
+func _group(title: String) -> Dictionary:
+	for group in Shortcuts.groups():
+		if group.title == title:
+			return group
+	return {}
+
+
+func _action(keycode: Key, command := false, shift := false, physical := KEY_NONE) -> StringName:
+	var event := InputEventKey.new()
+	event.pressed = true
+	event.keycode = keycode
+	event.physical_keycode = physical if physical != KEY_NONE else keycode
+	event.ctrl_pressed = command
+	event.meta_pressed = command
+	event.shift_pressed = shift
+	return Shortcuts.action_for(event)
+
+
+func test_digit_keys_switch_mode_on_qwerty_azerty_and_keypad() -> void:
+	assert_eq(_action(KEY_1), &"furniture_mode")
+	assert_eq(_action(KEY_2), &"structure_mode")
+	assert_eq(_action(KEY_AMPERSAND, false, false, KEY_1), &"furniture_mode", "AZERTY &")
+	assert_eq(_action(E_ACUTE, false, false, KEY_2), &"structure_mode", "AZERTY é")
+	assert_eq(_action(KEY_KP_2), &"structure_mode")
+
+
+func test_command_z_undoes_and_shift_redoes() -> void:
+	assert_eq(_action(KEY_Z, true), &"undo")
+	assert_eq(_action(KEY_Z, true, true), &"redo")
+	assert_eq(_action(KEY_Z), &"", "plain Z does nothing")
+
+
+func test_structure_hint_is_platform_aware() -> void:
+	assert_string_contains(Shortcuts.structure_hint(true), "⌥")
+	assert_string_contains(Shortcuts.structure_hint(false), "Alt")
```

- [ ] **Step 2: Tests ciblés**

Run, un fichier à la fois (GUT ne garde qu'un seul `-gselect`) :
- `./scripts/test.sh -gselect=test_structure_tool`
- `./scripts/test.sh -gselect=test_structure_panel`
- `./scripts/test.sh -gselect=test_shortcuts`
Expected: tous passent.

- [ ] **Step 3: Suite complète**

Run: `./scripts/test.sh`
Expected: **513** tests, tous passent (un seul avertissement attendu, celui de la sauvegarde automatique, et les erreurs moteur du test d'image de calque corrompue).

- [ ] **Step 4: Commit**

```bash
godot --headless --path . --import
git add -A src tests README.md
git commit -m "feat: structure tool and panel for corners and walls"
```

### Task 5: Assemblage : barre de modes, annulation globale, README

**Files:**
- Modify: `src/tools/furniture_tool.gd`, `src/main.gd`, `README.md`
- Test: `tests/unit/test_furniture_tool.gd`, `tests/unit/test_main_scene.gd`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: `FurnitureTool.is_active()`, `is_dragging()` ; le `FurnitureTool` ne traite plus ⌘Z ; il s'éteint hors du mode Meubles (pose annulée, aperçu de glisser retiré, sélection vidée) et `begin_placement` y est sans effet. Dans `main` : nœuds `StructureTool` (entre `FurnitureTool` et `MeasureTool`) et `Structure` (overlay) ; `TopBar` (menu Fichier + `ModeBar` avec les boutons `Meubles` et `Structure`) ; conteneur `Inspector` qui porte `Properties` et `StructurePanel` ; constante `HINT_STRUCTURE` ; `structure_changed` → `WorldView.refresh`.

- [ ] **Step 1: Appliquer le patch**

```diff
diff --git a/src/tools/furniture_tool.gd b/src/tools/furniture_tool.gd
index 4253d92..ea7837b 100644
--- a/src/tools/furniture_tool.gd
+++ b/src/tools/furniture_tool.gd
@@ -1,8 +1,8 @@
 class_name FurnitureTool
 extends Node
 ## Mouse and keyboard editing of furniture: place from the catalogue, select,
-## drag, rotate, delete, duplicate, undo/redo. Changes go through the store;
-## the view only shows previews while the mouse is down.
+## drag, rotate, delete, duplicate. Only active in the Furniture mode. Changes
+## go through the store; the view only shows previews while the mouse is down.
 ## Call setup() after the view's bind_store(), so the view has already reacted
 ## to a store signal when this tool reads the selection back.
 
@@ -41,6 +41,15 @@ func setup(p_store: Node, p_view: FurnitureView, p_camera: Camera3D) -> void:
 	store.furniture_removed.connect(_on_furniture_removed)
 	store.furniture_changed.connect(_on_furniture_changed)
 	store.project_loaded.connect(_on_project_loaded)
+	store.edit_mode_changed.connect(_on_edit_mode_changed)
+
+
+func is_active() -> bool:
+	return store != null and store.edit_mode == store.EditMode.FURNITURE
+
+
+func is_dragging() -> bool:
+	return _dragging
 
 
 func is_placing() -> bool:
@@ -53,6 +62,8 @@ func selected_id() -> String:
 
 ## Starts placing a new item: a ghost follows the mouse until a left click.
 func begin_placement(preset: FurniturePreset) -> void:
+	if not is_active():
+		return
 	_select("")
 	_placing = preset
 	_ghost_rotation = 0.0
@@ -69,7 +80,7 @@ func cancel_placement() -> void:
 
 
 func _unhandled_input(event: InputEvent) -> void:
-	if store == null:
+	if not is_active():
 		return
 	if event is InputEventMouseMotion:
 		_on_mouse_motion(event)
@@ -150,14 +161,7 @@ func _finish_drag() -> void:
 
 func _on_key(event: InputEventKey) -> void:
 	var command := event.is_command_or_control_pressed()
-	if command and event.keycode == KEY_Z:
-		if _dragging:
-			return  # The release would overwrite whatever the undo reverted.
-		if event.shift_pressed:
-			store.redo()
-		else:
-			store.undo()
-	elif command and event.keycode == KEY_D:
+	if command and event.keycode == KEY_D:
 		if selected_id() != "" and not _dragging:
 			_select(store.duplicate_furniture(selected_id()))
 	elif event.keycode == KEY_ESCAPE:
@@ -269,3 +273,13 @@ func _refresh_focus() -> void:
 func _on_project_loaded() -> void:
 	cancel_placement()
 	_sync_selection()
+
+
+func _on_edit_mode_changed(_mode: int) -> void:
+	if is_active():
+		return
+	cancel_placement()
+	if _dragging:
+		_dragging = false
+		view.update_item(store.get_furniture(selected_id()))  # Drops the drag preview.
+	_select("")
diff --git a/src/main.gd b/src/main.gd
index 2e17749..d68adbd 100644
--- a/src/main.gd
+++ b/src/main.gd
@@ -1,8 +1,8 @@
 extends Node3D
 ## Application root: lighting, camera, the 3D view of the open project, the
-## furniture tool, measurements (live clearances, free measuring), plan view
-## with the architect's underlay, the collapsible side panels, the shortcuts
-## help and the File menu (with autosave).
+## Furniture and Structure modes with their tools, measurements (live
+## clearances, free measuring), plan view with the architect's underlay, the
+## collapsible side panels, the shortcuts help and the File menu (with autosave).
 
 const SUN_ROTATION_DEG := Vector3(-50, -40, 0)
 const SUN_COLOR := Color("#ffe6c7")
@@ -20,6 +20,8 @@ const HINT_MARGIN := 16.0
 const HINT_MAX_WIDTH := 460.0
 const HINT_MEASURE := "Mesure : cliquez deux points · M pour quitter · Échap pour tout effacer"
 const HINT_PLAN := "Vue plan · P : calque · Tab : vue orbitale"
+const HINT_STRUCTURE := "Structure : glissez un coin ou cliquez un mur · 1 : retour aux meubles"
+const TOP_BAR_MARGIN := 8.0
 
 ## Where preferences and the autosave are kept; tests point them elsewhere.
 var settings_path := UiSettings.DEFAULT_PATH
@@ -42,6 +44,9 @@ var _clearances: ClearanceView
 var _underlay: UnderlayView
 var _measure: MeasureTool
 var _hint: Label
+var _structure_tool: StructureTool
+var _catalog: CatalogPanel
+var _mode_buttons := {}  # ProjectStore.EditMode -> Button
 
 
 func _ready() -> void:
@@ -67,6 +72,12 @@ func _ready() -> void:
 	add_child(_tool)
 	_furniture.bind_store(ProjectStore)
 	_tool.setup(ProjectStore, _furniture, _camera)
+	var overlay := StructureView.new()
+	add_child(overlay)
+	_structure_tool = StructureTool.new()
+	_structure_tool.name = "StructureTool"
+	add_child(_structure_tool)
+	_structure_tool.setup(ProjectStore, _camera, _view, overlay)
 	_clearances = ClearanceView.new()
 	add_child(_clearances)
 	_clearances.bind(_tool, ProjectStore)
@@ -95,6 +106,9 @@ func _ready() -> void:
 	get_viewport().size_changed.connect(_apply_ui_scale)
 	ProjectStore.project_loaded.connect(_on_project_loaded)
 	ProjectStore.path_changed.connect(_on_path_changed)
+	ProjectStore.structure_changed.connect(_on_structure_changed)
+	ProjectStore.edit_mode_changed.connect(_on_edit_mode_changed)
+	_on_edit_mode_changed(ProjectStore.edit_mode)
 	_files.startup()
 
 
@@ -133,6 +147,16 @@ func _unhandled_key_input(event: InputEvent) -> void:
 			_underlay.toggle()
 		&"measure":
 			_measure.toggle()
+		&"furniture_mode":
+			_set_mode(ProjectStore.EditMode.FURNITURE)
+		&"structure_mode":
+			_set_mode(ProjectStore.EditMode.STRUCTURE)
+		&"undo":
+			if not _is_dragging():
+				ProjectStore.undo()
+		&"redo":
+			if not _is_dragging():
+				ProjectStore.redo()
 		&"zoom_in":
 			_change_zoom(_settings.zoom_in)
 		&"zoom_out":
@@ -144,6 +168,17 @@ func _unhandled_key_input(event: InputEvent) -> void:
 	get_viewport().set_input_as_handled()
 
 
+## A drag's release would overwrite whatever an undo reverted.
+func _is_dragging() -> bool:
+	return _tool.is_dragging() or _structure_tool.is_dragging()
+
+
+## A focused panel field commits before the mode (and its panel) changes.
+func _set_mode(mode: ProjectStore.EditMode) -> void:
+	get_viewport().gui_release_focus()
+	ProjectStore.set_edit_mode(mode)
+
+
 func _change_zoom(step: Callable) -> void:
 	step.call()
 	_apply_ui_scale()
@@ -180,6 +215,19 @@ func _on_path_changed(_path: String) -> void:
 	_underlay.show_project(ProjectStore.project, ProjectStore.current_path)
 
 
+func _on_structure_changed() -> void:
+	_view.refresh(ProjectStore.project)
+
+
+func _on_edit_mode_changed(mode: ProjectStore.EditMode) -> void:
+	var structure := mode == ProjectStore.EditMode.STRUCTURE
+	_furniture.set_dimmed(structure)
+	_catalog.set_enabled(not structure)
+	for key in _mode_buttons:
+		(_mode_buttons[key] as Button).set_pressed_no_signal(key == mode)
+	_refresh_hint()
+
+
 func _on_measure_active_changed(active: bool) -> void:
 	if active:
 		# A ghost would keep following the mouse while clicks go to measuring.
@@ -196,6 +244,8 @@ func _on_view_mode_changed(plan: bool) -> void:
 ## Bottom hint describing the active mode(s); hidden in the default view.
 func _refresh_hint() -> void:
 	var lines := PackedStringArray()
+	if ProjectStore.edit_mode == ProjectStore.EditMode.STRUCTURE:
+		lines.append(HINT_STRUCTURE)
 	if _camera.is_plan_mode():
 		lines.append(HINT_PLAN)
 	if _measure.is_active():
@@ -211,23 +261,20 @@ func _ui() -> CanvasLayer:
 	_ui_root.name = "Root"
 	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 	layer.add_child(_ui_root)
-	var catalog := CatalogPanel.new()
-	catalog.populate(FurnitureCatalog.load_presets())
-	catalog.preset_chosen.connect(_tool.begin_placement)
+	_catalog = CatalogPanel.new()
+	_catalog.populate(FurnitureCatalog.load_presets())
+	_catalog.preset_chosen.connect(_tool.begin_placement)
 	_catalog_side = CollapsibleSide.new()
 	_catalog_side.name = "CatalogSide"
-	_catalog_side.setup(catalog, CollapsibleSide.Side.LEFT, "Catalogue")
+	_catalog_side.setup(_catalog, CollapsibleSide.Side.LEFT, "Catalogue")
 	_ui_root.add_child(_catalog_side)
-	var properties := PropertiesPanel.new()
-	properties.bind_store(ProjectStore)
-	_tool.selection_changed.connect(properties.show_item)
 	_inspector_side = CollapsibleSide.new()
 	_inspector_side.name = "InspectorSide"
-	_inspector_side.setup(properties, CollapsibleSide.Side.RIGHT, "Inspecteur")
+	_inspector_side.setup(_inspector(), CollapsibleSide.Side.RIGHT, "Inspecteur")
 	_ui_root.add_child(_inspector_side)
 	_ui_root.add_child(_help_button())
 	_ui_root.add_child(_hint_label())
-	_ui_root.add_child(_menu_bar())
+	_ui_root.add_child(_top_bar())
 	_ui_root.add_child(_welcome)
 	_help = ShortcutsOverlay.new()
 	_help.build()
@@ -235,11 +282,49 @@ func _ui() -> CanvasLayer:
 	return layer
 
 
-## On macOS the File menu goes to the system menu bar; elsewhere it sits at the top centre.
-func _menu_bar() -> MenuBar:
-	var bar := _files.build_menu()
+## The furniture properties and the structure panel share the right side; at
+## most one shows, depending on the mode's selection.
+func _inspector() -> VBoxContainer:
+	var stack := VBoxContainer.new()
+	stack.name = "Inspector"
+	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
+	var properties := PropertiesPanel.new()
+	properties.size_flags_vertical = Control.SIZE_EXPAND_FILL
+	properties.bind_store(ProjectStore)
+	_tool.selection_changed.connect(properties.show_item)
+	stack.add_child(properties)
+	var structure := StructurePanel.new()
+	structure.bind_store(ProjectStore)
+	_structure_tool.selection_changed.connect(structure.show_selection)
+	stack.add_child(structure)
+	return stack
+
+
+## Top centre: the File menu (on macOS it goes to the system menu bar instead)
+## above the mode switch.
+func _top_bar() -> VBoxContainer:
+	var bar := VBoxContainer.new()
+	bar.name = "TopBar"
+	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
 	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
+	bar.offset_top = TOP_BAR_MARGIN
+	bar.add_child(_files.build_menu())
+	var modes := HBoxContainer.new()
+	modes.name = "ModeBar"
+	var group := ButtonGroup.new()
+	for entry in [[ProjectStore.EditMode.FURNITURE, "Meubles", "1"], [ProjectStore.EditMode.STRUCTURE, "Structure", "2"]]:
+		var button := Button.new()
+		button.name = entry[1]
+		button.text = "%s  %s" % [entry[1], entry[2]]
+		button.toggle_mode = true
+		button.button_group = group
+		button.focus_mode = Control.FOCUS_NONE
+		Palette.apply_toggle_style(button)
+		button.pressed.connect(_set_mode.bind(entry[0]))
+		modes.add_child(button)
+		_mode_buttons[entry[0]] = button
+	bar.add_child(modes)
 	return bar
 
 
diff --git a/README.md b/README.md
index 37c1abd..b039397 100644
--- a/README.md
+++ b/README.md
@@ -46,6 +46,26 @@ Un meuble approché à moins de 15 cm d'un mur s'y colle, dos au mur. Au pavé t
 
 Les meubles sont enregistrés avec le projet (voir « Fichiers »).
 
+### Structure
+
+Les meubles et la structure (coins et murs) se modifient dans deux modes séparés : un clic ou une touche dans un mode ne change jamais l'autre. Le mode actif est affiché en haut de la fenêtre.
+
+| Action | Contrôle |
+|---|---|
+| Mode Meubles | 1 (ou le bouton « Meubles ») |
+| Mode Structure | 2 (ou le bouton « Structure ») |
+| Déplacer un coin et ses murs | Clic sur le coin + glisser |
+| Déplacer sans aimant | Alt pendant le déplacement |
+| Sélectionner un mur | Clic sur le mur |
+| Supprimer le mur sélectionné | Suppr ou Retour arrière, ou le bouton du panneau |
+| Désélectionner, ou abandonner le déplacement | Échap |
+
+- **Aimant** : un coin déplacé aligne ses murs à 0, 45 ou 90° par rapport aux murs voisins, sinon il se cale sur une grille de 5 cm.
+- **Panneau** : position x/z du coin ; longueur, épaisseur et hauteur du mur. Changer la longueur déplace le coin de fin du mur.
+- **Refus** : un déplacement qui ferait dépasser une porte ou une fenêtre de son mur, ou réduirait un mur à moins de 5 cm, est refusé ; le coin s'arrête à la dernière position valide.
+- En mode Structure, les meubles sont estompés et le catalogue est grisé.
+- **Annuler (Ctrl/Cmd + Z)** repasse dans le mode où la modification a été faite.
+
 ### Vue plan et mesures
 
 | Action | Contrôle |
diff --git a/tests/unit/test_furniture_tool.gd b/tests/unit/test_furniture_tool.gd
index 05e4a7f..d9f129a 100644
--- a/tests/unit/test_furniture_tool.gd
+++ b/tests/unit/test_furniture_tool.gd
@@ -219,12 +219,10 @@ func test_command_d_duplicates_and_selects_the_copy() -> void:
 	assert_ne(_tool.selected_id(), id)
 
 
-func test_command_z_undoes_and_shift_redoes() -> void:
+func test_command_z_is_left_to_the_shortcuts() -> void:
 	_add_sofa(Vector2(2, 2))
 	_key(KEY_Z, true)
-	assert_eq(_store.project.furniture.size(), 0)
-	_key(KEY_Z, true, true)
-	assert_eq(_store.project.furniture.size(), 1)
+	assert_eq(_store.project.furniture.size(), 1, "undo is a global shortcut (main scene)")
 
 
 func test_undoing_the_selected_items_creation_clears_selection() -> void:
@@ -287,19 +285,43 @@ func test_rotating_during_a_drag_is_ignored() -> void:
 	assert_eq(_store.get_furniture(id).rotation_deg, 0.0)
 
 
-func test_undo_redo_during_a_drag_are_ignored() -> void:
+func test_is_dragging_reports_a_drag_in_progress() -> void:
+	_add_sofa(Vector2(2, 2))
+	_click(Vector2(2, 2))
+	assert_true(_tool.is_dragging())
+	_click(Vector2(2, 2), false)
+	assert_false(_tool.is_dragging())
+
+
+func test_structure_mode_switches_the_tool_off() -> void:
 	var id := _add_sofa(Vector2(2, 2))
-	_store.update_furniture(id, {"name": "Renamed"})
+	_tool._select(id)
+	_store.set_edit_mode(_store.EditMode.STRUCTURE)
+	assert_eq(_tool.selected_id(), "", "selection dropped")
 	_click(Vector2(2, 2))
-	_move(Vector2(2.5, 2.3), false, true)
-	_key(KEY_Z, true)
-	assert_eq(_store.get_furniture(id).name, "Renamed", "nothing undone while dragging")
-	_key(KEY_Z, true, true)
-	_click(Vector2(2.5, 2.3), false)
-	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2.5, 2.3), Vector2(EPS, EPS))
-	_store.undo()
-	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS), "release is one update step")
-	assert_eq(_store.get_furniture(id).name, "Renamed")
+	assert_eq(_tool.selected_id(), "", "clicks ignored")
+	_tool.begin_placement(load(SOFA_PRESET))
+	assert_false(_tool.is_placing())
+	_store.set_edit_mode(_store.EditMode.FURNITURE)
+	_click(Vector2(2, 2))
+	assert_eq(_tool.selected_id(), id)
+
+
+func test_switching_mode_mid_drag_drops_the_preview() -> void:
+	var id := _add_sofa(Vector2(2, 2))
+	_click(Vector2(2, 2))
+	_move(Vector2(3, 3), false, true)
+	_store.set_edit_mode(_store.EditMode.STRUCTURE)
+	assert_false(_tool.is_dragging())
+	assert_almost_eq((_view.get_node(id) as Node3D).position, Vector3(2, 0, 2), Vector3(EPS, EPS, EPS))
+	assert_almost_eq(_store.get_furniture(id).pos, Vector2(2, 2), Vector2(EPS, EPS))
+
+
+func test_switching_mode_cancels_placement() -> void:
+	_tool.begin_placement(load(SOFA_PRESET))
+	_store.set_edit_mode(_store.EditMode.STRUCTURE)
+	assert_false(_tool.is_placing())
+	assert_false(_view.has_ghost())
 
 
 func test_scene_click_releases_gui_focus() -> void:
diff --git a/tests/unit/test_main_scene.gd b/tests/unit/test_main_scene.gd
index 2751f73..4e06228 100644
--- a/tests/unit/test_main_scene.gd
+++ b/tests/unit/test_main_scene.gd
@@ -40,7 +40,7 @@ func _main(open_template := true) -> Node3D:
 	return main
 
 
-func _press(main: Node3D, keycode: Key, command := false, unicode := 0) -> void:
+func _press(main: Node3D, keycode: Key, command := false, unicode := 0, shift := false) -> void:
 	var event := InputEventKey.new()
 	event.pressed = true
 	event.keycode = keycode
@@ -48,6 +48,7 @@ func _press(main: Node3D, keycode: Key, command := false, unicode := 0) -> void:
 	event.unicode = unicode
 	event.ctrl_pressed = command
 	event.meta_pressed = command
+	event.shift_pressed = shift
 	main._unhandled_key_input(event)
 
 
@@ -330,3 +331,86 @@ func test_catalogue_buttons_do_not_keep_keyboard_focus() -> void:
 func test_opening_a_project_loads_its_underlay() -> void:
 	var main := await _main()
 	assert_true((main.find_child("Underlay", true, false) as UnderlayView).has_image())
+
+
+func test_digit_keys_and_mode_bar_switch_the_edit_mode() -> void:
+	var main := await _main()
+	_press_key(main, KEY_2)
+	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.STRUCTURE)
+	var furniture_button := main.find_child("ModeBar", true, false).get_node("Meubles") as Button
+	var structure_button := main.find_child("ModeBar", true, false).get_node("Structure") as Button
+	assert_true(structure_button.button_pressed)
+	assert_false(furniture_button.button_pressed)
+	furniture_button.pressed.emit()
+	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.FURNITURE)
+	_press_key(main, KEY_1)
+	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.FURNITURE)
+
+
+func test_structure_mode_dims_furniture_greys_the_catalog_and_shows_a_hint() -> void:
+	var main := await _main()
+	_press_key(main, KEY_2)
+	assert_true((main.get_node("Furniture") as FurnitureView).is_dimmed())
+	var catalog := main.find_child("Catalog", true, false) as CatalogPanel
+	assert_true(catalog.button_for("sofa_3").disabled)
+	var hint := main.find_child("Hint", true, false) as Label
+	assert_true(hint.visible)
+	assert_string_contains(hint.text, "Structure")
+	_press_key(main, KEY_1)
+	assert_false((main.get_node("Furniture") as FurnitureView).is_dimmed())
+	assert_false(catalog.button_for("sofa_3").disabled)
+	assert_false(hint.visible)
+
+
+func test_selecting_a_corner_shows_the_structure_panel() -> void:
+	var main := await _main()
+	_press_key(main, KEY_2)
+	var node_id: String = ProjectStore.project.nodes[0].id
+	(main.get_node("StructureTool") as StructureTool).select(&"node", node_id)
+	var panel := main.find_child("StructurePanel", true, false) as StructurePanel
+	assert_true(panel.visible)
+	assert_true((main.find_child("InspectorSide", true, false) as CollapsibleSide).is_ancestor_of(panel))
+
+
+func test_a_structure_edit_rebuilds_the_walls() -> void:
+	var main := await _main()
+	_press_key(main, KEY_2)
+	var wall: Wall = ProjectStore.project.walls[0]
+	ProjectStore.update_wall(wall.id, {"height": 1.0})
+	await wait_physics_frames(1)
+	var body := main.get_node("World/Walls/%s/Body" % wall.id) as CSGPolygon3D
+	assert_almost_eq(body.depth, 1.0, EPS)
+
+
+func test_command_z_undoes_and_switches_back_to_the_edit_mode() -> void:
+	var main := await _main()
+	_press_key(main, KEY_2)
+	var node: PlanNode = ProjectStore.project.nodes[0]
+	var start := node.pos
+	ProjectStore.move_node(node.id, start + Vector2(0.1, 0))
+	_press_key(main, KEY_1)
+	_press(main, KEY_Z, true)
+	assert_eq(ProjectStore.edit_mode, ProjectStore.EditMode.STRUCTURE, "undo goes where the edit was made")
+	assert_eq(ProjectStore.project.get_plan_node(node.id).pos, start)
+	var structure_button := main.find_child("ModeBar", true, false).get_node("Structure") as Button
+	assert_true(structure_button.button_pressed)
+	_press(main, KEY_Z, true, 0, true)
+	assert_eq(ProjectStore.project.get_plan_node(node.id).pos, start + Vector2(0.1, 0), "⌘⇧Z redoes")
+
+
+func test_undo_is_ignored_while_dragging_furniture() -> void:
+	var main := await _main()
+	var tool := main.get_node("FurnitureTool") as FurnitureTool
+	ProjectStore.add_furniture(preload("res://tests/fixtures/project_fixtures.gd").sofa("f1"))
+	tool._select("f1")
+	tool._dragging = true
+	_press(main, KEY_Z, true)
+	assert_not_null(ProjectStore.get_furniture("f1"), "nothing undone mid-drag")
+	tool._dragging = false
+
+
+func test_structure_tool_sits_between_furniture_and_measure_tools() -> void:
+	var main := await _main()
+	var index := main.get_node("StructureTool").get_index()
+	assert_gt(index, main.get_node("FurnitureTool").get_index())
+	assert_lt(index, main.get_node("MeasureTool").get_index())
```

- [ ] **Step 2: Tests ciblés**

Run, un fichier à la fois (GUT ne garde qu'un seul `-gselect`) :
- `./scripts/test.sh -gselect=test_furniture_tool`
- `./scripts/test.sh -gselect=test_main_scene`
Expected: tous passent.

- [ ] **Step 3: Suite complète**

Run: `./scripts/test.sh`
Expected: **523** tests, tous passent (un seul avertissement attendu, celui de la sauvegarde automatique, et les erreurs moteur du test d'image de calque corrompue).

- [ ] **Step 4: Commit**

```bash
godot --headless --path . --import
git add -A src tests README.md
git commit -m "feat: structure mode in the main scene with global undo"
```
