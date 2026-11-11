"""Range le dataset maison V2 (export YOLO de Label Studio) pour l'entraînement run4.

Ce que fait le script :
  1. relit classes.txt de l'export (Label Studio range les classes par ordre
     alphabétique) et renumérote chaque boîte dans l'ordre du modèle 6 classes ;
  2. sépare les photos par personne : celles de TEST (une personne jamais vue
     à l'entraînement) et les autres en TRAIN ;
  3. écrit dataset/maison_v2/{images,labels}/{train,test} et data_test.yaml.

Une photo sans fichier de labels est REFUSÉE (pas copiée) : elle serait apprise
comme une image sans aucun objet, ce qui est faux.

Usage, depuis la racine du dépôt :
    python dataset/outils/preparer_maison_v2.py <export_label_studio_dezippe> <dossier_photos_tm>
"""
import shutil
import sys
from collections import Counter
from pathlib import Path

ORDRE = ["person", "helmet", "vest", "gloves", "boots", "goggles"]
# Personne gardée pour le test (maillot de foot, autre pièce) : tm_37 à tm_44.
TEST = {f"tm_{i:02d}" for i in range(37, 45)}

export, photos = Path(sys.argv[1]), Path(sys.argv[2])
racine = Path(__file__).resolve().parent.parent / "maison_v2"

classes_ls = [l.strip() for l in (export / "classes.txt").read_text(encoding="utf-8").splitlines() if l.strip()]
inconnues = set(classes_ls) - set(ORDRE)
if inconnues:
    sys.exit(f"Classes inconnues dans l'export : {inconnues}")
vers_ordre = {i: ORDRE.index(n) for i, n in enumerate(classes_ls)}

for split in ("train", "test"):
    for sous in ("images", "labels"):
        d = racine / sous / split
        if d.exists():
            shutil.rmtree(d)  # on repart de zéro à chaque lancement : le script est rejouable
        d.mkdir(parents=True)

comptes = {"train": Counter(), "test": Counter()}
nb_images = Counter()
refusees = []
for img in sorted(photos.glob("tm_*.jpg")):
    lbl = export / "labels" / f"{img.stem}.txt"
    if not lbl.exists():
        refusees.append(img.stem)
        continue
    split = "test" if img.stem in TEST else "train"
    lignes = []
    for l in lbl.read_text(encoding="utf-8").splitlines():
        if l.strip():
            c, *coords = l.split()
            nc = vers_ordre[int(c)]
            lignes.append(" ".join([str(nc), *coords]))
            comptes[split][ORDRE[nc]] += 1
    shutil.copy2(img, racine / "images" / split / img.name)
    (racine / "labels" / split / f"{img.stem}.txt").write_text("\n".join(lignes) + "\n", encoding="utf-8")
    nb_images[split] += 1

(racine / "data_test.yaml").write_text(
    "# Test maison V2 : la personne tm_37 à tm_44, jamais vue à l'entraînement.\n"
    "# Évaluation : YOLO('best.pt').val(data='dataset/maison_v2/data_test.yaml', split='test')\n"
    "train: images/train\nval: images/test\ntest: images/test\nnc: 6\nnames:\n"
    + "".join(f"  {i}: {n}\n" for i, n in enumerate(ORDRE)),
    encoding="utf-8",
)

print("Ordre Label Studio :", classes_ls, "-> remis dans l'ordre", ORDRE)
for split in ("train", "test"):
    print(f"{split:5s} {nb_images[split]:2d} images  {dict(comptes[split])}")
if refusees:
    print("ATTENTION, photos sans labels, NON copiées :", refusees)
