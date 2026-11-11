"""Fusionne dataset_positives (internet + ancien maison, 6 classes) et maison_v2 en un seul dossier.

Résultat : dataset/maison_v2/dataset_run4/, autonome, versionné sur Git pour Colab.
  images|labels/train  = dataset_positives/train + maison_v2/train (préfixe maisonv2_)
  images|labels/val    = dataset_positives/val   (identique au run3)
  images|labels/test   = dataset_positives/test  (identique au run3)
  test_maison_v2/      = les photos de la personne gardée pour le test (+ son data.yaml)

Usage, depuis la racine du dépôt :
    python dataset/outils/fusionner_run4.py
"""
import shutil
import sys
from collections import Counter
from pathlib import Path

ORDRE = ["person", "helmet", "vest", "gloves", "boots", "goggles"]
racine = Path(__file__).resolve().parents[2]
internet, maison = racine / "dataset_positives", racine / "dataset" / "maison_v2"
sortie = maison / "dataset_run4"

if sortie.exists():
    shutil.rmtree(sortie)


def copier(src_img, src_lbl, dst_img, dst_lbl, prefixe=""):
    dst_img.mkdir(parents=True, exist_ok=True)
    dst_lbl.mkdir(parents=True, exist_ok=True)
    n, boites = 0, Counter()
    for img in sorted(src_img.iterdir()):
        lbl = src_lbl / f"{img.stem}.txt"
        if not lbl.exists():
            sys.exit(f"Image sans labels : {img}")
        shutil.copy2(img, dst_img / f"{prefixe}{img.name}")
        shutil.copy2(lbl, dst_lbl / f"{prefixe}{img.stem}.txt")
        for l in lbl.read_text(encoding="utf-8").splitlines():
            if l.strip():
                boites[ORDRE[int(l.split()[0])]] += 1
        n += 1
    return n, boites


bilan = {}
for split in ("train", "val", "test"):
    bilan[f"internet {split}"] = copier(internet / "images" / split, internet / "labels" / split,
                                        sortie / "images" / split, sortie / "labels" / split)
bilan["maison_v2 train"] = copier(maison / "images" / "train", maison / "labels" / "train",
                                  sortie / "images" / "train", sortie / "labels" / "train", "maisonv2_")
bilan["test_maison_v2"] = copier(maison / "images" / "test", maison / "labels" / "test",
                                 sortie / "test_maison_v2" / "images" / "test", sortie / "test_maison_v2" / "labels" / "test")

noms = "nc: 6\nnames:\n" + "".join(f"  {i}: {n}\n" for i, n in enumerate(ORDRE))
(sortie / "data.yaml").write_text(
    "# Run4 : train = internet + 36 photos maison V2 ; val et test identiques au run3.\n"
    "train: images/train\nval: images/val\ntest: images/test\n" + noms, encoding="utf-8")
(sortie / "test_maison_v2" / "data.yaml").write_text(
    "# Photos maison V2 d'une personne jamais vue à l'entraînement.\n"
    "train: images/test\nval: images/test\ntest: images/test\n" + noms, encoding="utf-8")
shutil.copy2(maison / "README.md", sortie / "README_maison_v2.md")

for nom, (n, b) in bilan.items():
    print(f"{nom:16s} {n:5d} images  {dict(b)}")
