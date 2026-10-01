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

Les meubles sont enregistrés avec le projet (voir « Fichiers »).

### Vue plan et mesures

| Action | Contrôle |
|---|---|
| Vue plan (de dessus), ou retour à la vue orbitale | Tab |
| Vue orbitale | O |
| Afficher ou masquer le calque du plan d'architecte (en vue plan) | P |
| Se déplacer en vue plan | Clic droit ou clic molette + glisser, ou deux doigts |
| Mesurer | M, puis clic sur deux points |
| Effacer toutes les mesures | Échap |

- **Cotes en direct** : autour du meuble sélectionné, déplacé ou en cours de pose, les distances libres jusqu'au mur ou au meuble le plus proche s'affichent en cm, de chaque côté.
- **Mesure** : les points s'aimantent sur les coins et les faces des murs et des meubles. Les mesures restent affichées jusqu'à Échap, et ne sont pas enregistrées dans le projet.
- **Calque** : il est cherché à côté du fichier projet, puis parmi les plans livrés avec l'application.

### Fichiers

Au lancement, une **page d'accueil** permet de choisir le projet :
- les 8 projets récents (un projet introuvable apparaît grisé, et la croix le retire de la liste) ;
- « Nouveau projet vide », « Nouveau depuis le log 16 » ou « Ouvrir un fichier… ».

Elle reste accessible ensuite par Fichier › Accueil… ou ⌘/Ctrl + Maj + O. Échap la referme dès qu'un projet est ouvert.

| Action | Contrôle |
|---|---|
| Page d'accueil (choisir un projet) | ⌘/Ctrl + Maj + O |
| Ouvrir un projet | ⌘/Ctrl + O |
| Enregistrer | ⌘/Ctrl + S (le premier enregistrement demande un emplacement) |
| Enregistrer sous | ⌘/Ctrl + Maj + S |

Sur macOS, le menu Fichier se trouve dans la barre de menus du système. Un projet est un fichier `.json`, lisible et modifiable à la main.

- Le titre de la fenêtre affiche `*` tant qu'il reste des modifications non enregistrées. Fermer la fenêtre ou changer de projet demande alors s'il faut enregistrer.
- Une **sauvegarde automatique** est écrite 2 s après chaque modification. Après un plantage ou une fermeture forcée, la page d'accueil propose de restaurer ce travail. Elle est supprimée dès que le projet est enregistré.

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
