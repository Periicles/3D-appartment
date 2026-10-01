# 3D-appartment

Outil desktop d'aménagement intérieur en 2D et 3D, construit avec Godot 4 (GDScript).

## Prérequis

- [Godot 4.7.2](https://godotengine.org/) (`brew install --cask godot` sur macOS)

## Lancer le projet

```sh
godot --editor project.godot
```

## Utilisation

Au lancement, l'application ouvre le plan du log 16 (`data/log16.json`).

| Action | Contrôle |
|---|---|
| Tourner autour | Clic droit + glisser |
| Se déplacer | Clic molette + glisser, ou Maj + clic droit + glisser |
| Zoomer | Molette |
| Tourner (trackpad) | Deux doigts |
| Se déplacer (trackpad) | Maj + deux doigts |
| Zoomer (trackpad) | Pincer |
| Centrer sur une pièce | Double-clic sur son sol |
| Masquage des murs (auto / complets / tous abaissés) | H |

### Meubles

| Action | Contrôle |
|---|---|
| Ajouter un meuble | Clic sur un modèle du catalogue (à gauche), puis clic dans la pièce |
| Pivoter l'aperçu ou le meuble sélectionné | R (quart de tour) |
| Pivoter finement le meuble sélectionné | Maj + molette de la souris (±15°) |
| Placement libre, sans grille | Alt pendant le déplacement |
| Sélectionner | Clic sur le meuble |
| Déplacer | Clic sur le meuble + glisser |
| Supprimer | Suppr ou Retour arrière |
| Dupliquer | Ctrl/Cmd + D |
| Annuler / rétablir | Ctrl/Cmd + Z / Ctrl/Cmd + Maj + Z |
| Abandonner l'ajout ou désélectionner | Échap |

Un meuble approché à moins de 15 cm d'un mur s'y colle, dos au mur. Au pavé tactile, pivotez avec R ou le champ Rotation. Le panneau de droite modifie le nom, les dimensions, la couleur, la position et la rotation du meuble sélectionné.

Les meubles ne sont pas encore enregistrés : la sauvegarde arrive avec le jalon M3.

### Interface

| Action | Contrôle |
|---|---|
| Afficher ou masquer le catalogue | C (ou l'onglet « ▸ Catalogue » au bord gauche) |
| Afficher ou masquer l'inspecteur | I (ou l'onglet « Inspecteur ◂ » au bord droit) |
| Liste de tous les raccourcis | ? ou F1 (ou le bouton « ? » en bas à droite) |
| Agrandir / réduire / taille par défaut de l'interface | Ctrl/Cmd + + / Ctrl/Cmd + − / Ctrl/Cmd + 0 |

La fenêtre s'ouvre maximisée. La taille de l'interface suit le réglage d'affichage de macOS (Retina), multipliée par le zoom choisi, qui est mémorisé d'une session à l'autre dans `user://settings.cfg`.

## Tests

Les tests utilisent [GUT](https://github.com/bitwes/Gut), embarqué dans `addons/gut/`.

```sh
./scripts/test.sh                                   # toute la suite
./scripts/test.sh -gselect=test_project_serializer  # un seul fichier
```

La CI (GitHub Actions) lance la suite sur chaque pull request.

## Workflow Git

- `main` : branche de release uniquement.
- `develop` : branche d'intégration, base de tout le travail.
- Chaque changement se fait sur une branche `feat/*`, `fix/*`, `docs/*` ou `chore/*` créée depuis `develop`, puis fusionné via pull request vers `develop`.
- Les releases passent de `develop` vers `main`.
