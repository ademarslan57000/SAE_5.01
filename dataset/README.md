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
