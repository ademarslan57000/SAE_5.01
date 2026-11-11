# Dataset maison V2

44 photos prises par l'équipe le 11/11/2026, annotées dans Label Studio en 6 classes
(`person`, `helmet`, `vest`, `gloves`, `boots`, `goggles`). Seuls le casque et les gants
apparaissent : pas de gilet, de lunettes de protection ni de chaussures de sécurité.

But de l'expérience : savoir si ajouter nos propres photos à l'entraînement améliore
la détection sur des photos comme les nôtres (intérieur, gros plans), sans dégrader le reste.

## Répartition

| Split | Photos | Contenu |
|---|---|---|
| `train` | tm_01 à tm_36 (36 photos, 3 personnes) | ajoutées au train du run4 |
| `test` | tm_37 à tm_44 (8 photos, 1 personne) | jamais vues à l'entraînement |

La séparation se fait **par personne**, pas au hasard : les photos d'une même personne
se ressemblent trop (même pièce, même pose). Mélangées, elles gonfleraient le score.

Ces photos ne remplacent pas `test_maison/`, réservé à la future séance photo avec tout le matériel.

## Refaire le rangement après un nouvel export Label Studio

```
python dataset/outils/preparer_maison_v2.py <export_yolo_dezippe> dataset/test_maison/images/val
```

Le script remet les classes dans l'ordre du modèle (Label Studio les trie par ordre
alphabétique) et refuse toute photo sans fichier de labels.

## Corrections faites après l'export Label Studio

Faites à la main dans `labels/train/` le 11/11 (vérifiées à l'œil) : un relancement de
`preparer_maison_v2.py` les efface, il faut alors les refaire dans Label Studio.

- tm_12 : ajout du casque oublié.
- tm_14 : suppression d'une boîte `gloves` posée sur des lunettes de vue.
- tm_24 : ajout du gant oublié (main tendue).
- tm_38 : pas encore annotée, donc absente du test (7 photos au lieu de 8).

## Fusionner et entraîner le run4 (Colab)

Le dataset fusionné est **déjà dans le dépôt** : `dataset/maison_v2/dataset_run4/`.

| Dossier | Images | Contenu |
|---|---|---|
| `images/train` | 1 197 | 1 161 d'internet + 36 photos maison (préfixe `maisonv2_`) |
| `images/val` | 149 | identique au run3 |
| `images/test` | 148 | identique au run3 |
| `test_maison_v2/` | 7 | la personne gardée pour le test, avec son `data.yaml` |

Il a été produit par `python dataset/outils/fusionner_run4.py` (à relancer si les
annotations changent). Les chemins du `data.yaml` sont relatifs : il marche où que
soit le dépôt. Sur Colab, après avoir cloné le dépôt dans `/content/SAE_5.01` :

```python
!ls /content/SAE_5.01/dataset/maison_v2/dataset_run4/images/train | wc -l   # doit afficher 1197

from ultralytics import YOLO
model = YOLO("yolo11n.pt")
model.train(data="/content/SAE_5.01/dataset/maison_v2/dataset_run4/data.yaml", patience=20, device=0,
            project="/content/drive/MyDrive/Modele_EPI", name="run4_positives_maisonV2")
```

Mêmes réglages que le run3, seul `data` change.

Réglages par défaut conservés comme au run3 : `epochs=100`, `imgsz=640`, `batch=16`, `seed=0`.

## Comparer run3 et run4

1. Sur le split test d'internet (le run4 a-t-il perdu quelque chose ?) :

```
python dataset/outils/compare_runs.py \
    --run-a dataset/entrainements/run3_positives_yolo11n --data-a dataset_positives/data.yaml --nom-a "run3" \
    --run-b dataset/entrainements/run4_positives_maisonV2 --data-b dataset/maison_v2/dataset_run4/data.yaml --nom-b "run4 (+ maison V2)" \
    --verite dataset/data.yaml \
    --paires no_helmet:helmet no_vest:vest no_gloves:gloves no_boots:boots no_goggle:goggles \
    --sortie dataset/evaluations/comparatif_run3_vs_run4.md
```

2. Sur nos photos (le run4 reconnaît-il mieux casques et gants chez nous ?) :

```python
YOLO("dataset/entrainements/run4_positives_maisonV2/weights/best.pt").val(
    data="dataset/maison_v2/dataset_run4/test_maison_v2/data.yaml", split="test")
```

## Référence : run3 sur le test maison V2

Mesuré le 11/11 sur 7 photos (tm_38 pas encore annotée), CPU, `imgsz=640`.

| Classe | Précision | Rappel | mAP50 |
|---|---|---|---|
| person | 0,844 | 1,000 | 0,995 |
| helmet | 1,000 | 0,509 | 0,878 |
| gloves | 0,541 | 0,200 | 0,235 |
| **toutes** | 0,795 | 0,570 | 0,703 |

Le run3 ne trouve qu'un casque sur deux et un gant sur cinq sur nos photos. C'est ce
chiffre que le run4 doit améliorer. Huit photos, c'est peu : un écart de quelques points
n'est pas une preuve.
