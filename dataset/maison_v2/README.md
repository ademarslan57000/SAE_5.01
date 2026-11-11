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

`python dataset/outils/fusionner_run4.py` crée `dataset_run4/` à la racine du dépôt :
le train d'internet + les 36 photos (préfixe `maisonv2_`), le val et le test du run3
inchangés, et `test_maison_v2/` avec son propre `data.yaml`. Zipper ce dossier et le
dézipper dans `/content` sur Colab.

Mêmes réglages que le run3, seul `data` change :

```python
from ultralytics import YOLO
model = YOLO("yolo11n.pt")
model.train(data="/content/dataset_run4/data.yaml", patience=20, device=0,
            project="/content/drive/MyDrive/Modele_EPI", name="run4_positives_maisonV2")
```

Réglages par défaut conservés comme au run3 : `epochs=100`, `imgsz=640`, `batch=16`, `seed=0`.

## Comparer run3 et run4

1. Sur le split test d'internet (le run4 a-t-il perdu quelque chose ?) :

```
python dataset/outils/compare_runs.py \
    --run-a dataset/entrainements/run3_positives_yolo11n --data-a dataset_positives/data.yaml --nom-a "run3" \
    --run-b dataset/entrainements/run4_positives_maisonV2 --data-b dataset_run4/data.yaml --nom-b "run4 (+ maison V2)" \
    --verite dataset/data.yaml \
    --paires no_helmet:helmet no_vest:vest no_gloves:gloves no_boots:boots no_goggle:goggles \
    --sortie dataset/evaluations/comparatif_run3_vs_run4.md
```

2. Sur nos photos (le run4 reconnaît-il mieux casques et gants chez nous ?) :

```python
YOLO("dataset/entrainements/run4_positives_maisonV2/weights/best.pt").val(
    data="dataset_run4/test_maison_v2/data.yaml", split="test")
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
