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
| Se déplacer | Clic molette + glisser |
| Zoomer | Molette |
| Centrer sur une pièce | Double-clic sur son sol |
| Masquage des murs (auto / complets / tous abaissés) | H |

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
