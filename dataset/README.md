# Dataset v1 — détection d'EPI (format YOLO)

Fusion de **Construction-PPE** (Ultralytics) et du **dataset maison** (Label Studio), 11 classes :

| id | classe | id | classe |
|---|---|---|---|
| 0 | person | 6 | no_gloves |
| 1 | helmet | 7 | boots |
| 2 | no_helmet | 8 | no_boots |
| 3 | vest | 9 | goggles |
| 4 | no_vest | 10 | no_goggle |
| 5 | gloves | | |

- Splits : 1161 train / 149 val / 148 test (voir `rapport_fusion.md`)
- Entraînement : `yolo detect train data=dataset/data.yaml` (les chemins sont relatifs à `data.yaml`)
- Régénération : `outils/merge_datasets.py` + `outils/config.yaml` (sources `cppe/` et `raw/` non versionnées)

## Variante `dataset_positives/` — 6 classes positives

**Pourquoi.** Sur le dataset v1, les classes négatives (`no_*`) plafonnent entre **0,25 et 0,63 de mAP50**, alors que les classes positives sont entre **0,77 et 0,92**. On n'a pas besoin des négatives pour décider l'accès : la règle « item obligatoire non détecté = manquant » suffit. On entraîne donc un modèle uniquement sur les classes positives.

| id | classe |
|---|---|
| 0 | person |
| 1 | helmet |
| 2 | vest |
| 3 | gloves |
| 4 | boots |
| 5 | goggles |

- Mêmes images, mêmes noms, mêmes splits que `dataset/`. Seuls les labels changent : les lignes des 5 classes `no_*` sont supprimées et les IDs renumérotés. Les coordonnées ne changent pas.
- Une image qui n'a plus aucune boîte garde un fichier de labels vide (image de fond). Il y en a 4, toutes dans train.
- Le dossier n'est **pas versionné** (copie des images, voir `.gitignore`) : chacun le régénère depuis la racine du dépôt (en local ou sur Colab) :

```bash
python dataset/outils/derive_positives.py dataset dataset_positives --keep person helmet vest gloves boots goggles
```

Ajouter `--ecraser` pour le régénérer s'il existe déjà. Le script affiche un rapport et s'arrête si un contrôle échoue. Entraînement : `yolo detect train data=dataset_positives/data.yaml`.
