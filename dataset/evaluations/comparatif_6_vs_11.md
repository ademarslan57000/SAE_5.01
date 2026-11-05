# Comparatif 6 classes vs 11 classes

Évaluation sur le split **test**, `imgsz=640`, réglages par défaut de `val`, CPU (`device=cpu`), Ultralytics 8.4.192 pour les deux modèles.

## Runs comparés

| | run | data | epochs effectuées | Ultralytics à l'entraînement |
|---|---|---|---|---|
| 11 classes | `run_datasetV2` | `/content/dataset/data.yaml` | 90 / 100 | 8.4.183 |
| 6 classes | `run3_positives_yolo11n` | `/content/dataset_positives/data.yaml` | 70 / 100 | 8.4.192 |

Réglages d'entraînement identiques (model=yolo11n.pt, epochs=100, patience=20, imgsz=640, batch=16, seed=0). Seuls diffèrent : `data`, `name`, `save_dir`.

Remarque : version d'Ultralytics différente à l'entraînement (8.4.183 / 8.4.192), non visible dans `args.yaml`. L'évaluation ci-dessous utilise une seule version pour les deux.

## Test : 6 classes communes

| classe | P 11 classes | P 6 classes | écart | R 11 classes | R 6 classes | écart | mAP50 11 classes | mAP50 6 classes | écart | mAP50-95 11 classes | mAP50-95 6 classes | écart |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| person | 0.842 | 0.818 | -0.024 | 0.817 | 0.817 | +0.000 | 0.837 | 0.844 | +0.007 | 0.511 | 0.509 | -0.003 |
| helmet | 0.937 | 0.956 | +0.020 | 0.911 | 0.880 | -0.031 | 0.928 | 0.917 | -0.011 | 0.487 | 0.491 | +0.003 |
| vest | 0.830 | 0.880 | +0.050 | 0.876 | 0.871 | -0.006 | 0.887 | 0.904 | +0.018 | 0.576 | 0.576 | +0.001 |
| gloves | 0.875 | 0.859 | -0.016 | 0.724 | 0.724 | +0.000 | 0.771 | 0.765 | -0.006 | 0.378 | 0.376 | -0.002 |
| boots | 0.778 | 0.897 | +0.119 | 0.681 | 0.658 | -0.023 | 0.756 | 0.754 | -0.002 | 0.393 | 0.399 | +0.006 |
| goggles | 0.793 | 0.809 | +0.016 | 0.673 | 0.652 | -0.021 | 0.769 | 0.771 | +0.002 | 0.296 | 0.315 | +0.020 |
| **moyenne** | 0.842 | 0.870 | +0.027 | 0.780 | 0.767 | -0.013 | 0.825 | 0.826 | +0.001 | 0.440 | 0.444 | +0.004 |

## Validation pendant l'entraînement (`results.csv`)

| | meilleur mAP50 val | à l'epoch | epochs effectuées |
|---|---|---|---|
| 11 classes | 0.679 | 70 | 90 |
| 6 classes | 0.822 | 61 | 70 |

Ce mAP50 est la moyenne de **toutes** les classes de chaque modèle (11 contre 6) : il n'est pas directement comparable. La décision repose sur le test, classes communes.

## Faux équipements (EPI vu alors qu'il n'est pas porté)

Vérité terrain : labels `test` de `dataset/data.yaml`. Une boîte d'absence compte si au moins une prédiction de l'équipement correspondant, de confiance ≥ 0.5, la recouvre avec une IoU ≥ 0.5.

| absence → équipement prédit | boîtes | 11 classes | 6 classes |
|---|---|---|---|
| no_helmet → helmet | 55 | 0 (0.0 %) | 0 (0.0 %) |
| no_vest → vest | 77 | 0 (0.0 %) | 1 (1.3 %) |
| no_gloves → gloves | 65 | 0 (0.0 %) | 0 (0.0 %) |
| no_boots → boots | 26 | 0 (0.0 %) | 0 (0.0 %) |
| no_goggle → goggles | 38 | 0 (0.0 %) | 0 (0.0 %) |
| **total** | 261 | **0 (0.0 %)** | **1 (0.4 %)** |

## Conclusion

- Critère 1, moyenne mAP50 des classes communes ≥ celle de 11 classes − 0.01 : 0.826 contre 0.825 → **respecté**
- Critère 2, faux équipements de 6 classes ≤ ceux de 11 classes : 1 contre 0 → **non respecté** (écart : 1 boîte(s) sur 261)

**Les deux critères se contredisent** : 6 classes fait au moins aussi bien sur la précision de détection (mAP50), mais moins bien sur les faux équipements. La règle ne permet pas de trancher : c'est une décision d'équipe.
