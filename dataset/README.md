# Dataset v1 — détection d'EPI (format YOLO)

Fusion de **Construction-PPE** (Ultralytics) et du **dataset maison** (photos annotées sous Label Studio, export YOLO). 1 458 images, 11 classes.

## Classes

| id | classe | id | classe |
|---|---|---|---|
| 0 | person | 6 | no_gloves |
| 1 | helmet | 7 | boots |
| 2 | no_helmet | 8 | no_boots |
| 3 | vest | 9 | goggles |
| 4 | no_vest | 10 | no_goggle |
| 5 | gloves | | |

L'ordre des classes dans `data.yaml` fixe les IDs utilisés par le modèle, l'application et la logique d'accès. **Ne pas le modifier.**

## Sources

| Source | Images | Licence | Lien |
|---|---|---|---|
| Construction-PPE (Dalvi et al., Ultralytics, 2025, v1.0.0) | 1 416 (1 132 / 143 / 141) | AGPL-3.0 (attribution requise) | https://docs.ultralytics.com/datasets/detect/construction-ppe |
| Dataset maison | 42 (29 / 6 / 7) | Photos de l'équipe, usage interne au projet | — |

## Correspondance des classes Construction-PPE → v1

| Construction-PPE | → v1 |
|---|---|
| 0 helmet | 1 helmet |
| 1 gloves | 5 gloves |
| 2 vest | 3 vest |
| 3 boots | 7 boots |
| 4 goggles | 9 goggles |
| 5 none | 4 no_vest (torses sans gilet, vérifié visuellement) |
| 6 Person | 0 person |
| 7 no_helmet | 2 no_helmet |
| 8 no_goggle | 10 no_goggle |
| 9 no_gloves | 6 no_gloves |
| 10 no_boots | 8 no_boots |

## Répartition

Splits : 1 161 train / 149 val / 148 test (voir `rapport_fusion.md`). Les splits d'origine de Construction-PPE sont conservés.

Nombre de boîtes par classe (tous splits) :

| Classe | Boîtes | Classe | Boîtes |
|---|---|---|---|
| person | 2 331 | no_helmet | 561 |
| helmet | 1 734 | no_vest | 874 |
| vest | 1 618 | no_gloves | 606 |
| gloves | 1 445 | no_boots | 151 |
| boots | 1 597 | no_goggle | 437 |
| goggles | 518 | **Total** | **11 872** |

## Décisions

- **Classes négatives de Construction-PPE conservées** : elles sont natives et annotées de façon homogène sur toutes les images de la source.
- **Classes négatives du dataset maison supprimées** à la refonte du 09/10 : elles n'étaient annotées que sur nos photos, ce qui créait des signaux contradictoires avec les sources publiques.
- **`no_mask` et `no_hearing_protection` retirées de la v1** : présentes uniquement dans nos 42 photos, elles auraient été apprises comme du fond dans les 1 416 images publiques.
- **Helmet-Vest et CHV non ajoutés** : ils n'annotent ni les gants ni les bottes. Des gants visibles mais non annotés auraient été appris comme du fond.

## Limites connues

- `no_boots` est très sous-représentée (151 boîtes).
- Aucune image de protection auditive, de masque ou de harnais portés.
- La plupart des boîtes couvrent moins de 10 % de l'image : ne pas entraîner en dessous de `imgsz=640`.

## Utilisation

- Entraînement : `yolo detect train data=dataset/data.yaml` (les chemins sont relatifs à `data.yaml`).
- Régénération : `outils/merge_datasets.py` + `outils/config.yaml` (sources `cppe/` et `raw/` non versionnées).

## Variante sans classes négatives (`dataset_positives/`)

Créée le 22/10 pour comparer deux entraînements à conditions égales. Les classes négatives plafonnent entre 0,25 et 0,69 de mAP50, alors que les classes positives sont entre 0,77 et 0,92. La logique d'accès peut fonctionner avec la règle « item obligatoire non détecté = manquant ».

- 6 classes : 0 person, 1 helmet, 2 vest, 3 gloves, 4 boots, 5 goggles.
- Mêmes images et mêmes splits que la v1. 2 629 boîtes `no_*` supprimées. 4 images de train deviennent des images de fond (fichier de labels vide).
- Non versionnée : à régénérer avec `outils/derive_positives.py` (voir `--help` pour les arguments).
