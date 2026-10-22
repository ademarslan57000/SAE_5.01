#!/usr/bin/env python3
"""
Dérive un dataset YOLO réduit à certaines classes (SAE 501 - détection d'EPI).

Sert à créer `dataset_positives/` (6 classes positives) à partir de `dataset/`
(11 classes) SANS relancer la fusion : on repart du dataset déjà fusionné pour
garder exactement le même découpage train/val/test.

Usage (local ou Google Colab) :
    python dataset/outils/derive_positives.py dataset dataset_positives \\
        --keep person helmet vest gloves boots goggles

Ce que fait le script :
  1. lit les noms de classes et les splits dans <source>/data.yaml
  2. copie chaque image telle quelle (même nom, même split)
  3. réécrit chaque fichier de labels : supprime les lignes des classes non
     gardées, renumérote les IDs (0..N-1 dans l'ordre de --keep), recopie les
     coordonnées caractère pour caractère ; une image sans boîte garde un
     fichier de labels vide (image de fond)
  4. écrit <sortie>/data.yaml avec des chemins relatifs
  5. affiche un rapport, puis relit le résultat et vérifie qu'il est cohérent
     (s'arrête avec un message clair au premier contrôle qui échoue)
"""
import argparse, collections, shutil, sys
from pathlib import Path

import yaml

IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SPLITS = ("train", "val", "test")


def fail(msg):
    sys.exit(f"ERREUR : {msg}")


def list_images(folder):
    return sorted(p for p in folder.iterdir() if p.suffix.lower() in IMG_EXTS)


def labels_dir_for(images_dir):
    # Convention YOLO : .../images/<split> -> .../labels/<split>
    parts = list(images_dir.parts)
    if "images" not in parts:
        fail(f"{images_dir} : impossible de trouver le dossier labels (pas de 'images' dans le chemin)")
    i = len(parts) - 1 - parts[::-1].index("images")
    parts[i] = "labels"
    return Path(*parts)


def read_label_lines(path, nc, where):
    """Renvoie la liste des (id_classe, reste_de_la_ligne) d'un fichier de labels."""
    if not path.exists():
        return []
    rows = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2 or len(parts[1].split()) != 4:
            fail(f"{where}:{n} : ligne mal formée : {line!r}")
        try:
            cid = int(parts[0])
        except ValueError:
            fail(f"{where}:{n} : ID de classe non entier : {line!r}")
        if not 0 <= cid < nc:
            fail(f"{where}:{n} : ID {cid} hors de 0..{nc - 1}")
        rows.append((cid, parts[1]))
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", type=Path, help="dataset YOLO d'origine (contient data.yaml)")
    ap.add_argument("sortie", type=Path, help="dossier du nouveau dataset (ne doit pas exister, sauf --ecraser)")
    ap.add_argument("--keep", nargs="+", required=True, help="classes à garder, dans l'ordre des nouveaux IDs")
    ap.add_argument("--ecraser", action="store_true", help="supprime le dossier de sortie s'il existe déjà")
    args = ap.parse_args()
    # Accents lisibles même quand la sortie est redirigée (Windows, Colab)
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")

    src, dst = args.source.resolve(), args.sortie.resolve()

    # --- Lecture de la configuration source ---
    cfg_path = src / "data.yaml"
    if not cfg_path.exists():
        fail(f"{cfg_path} introuvable")
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8"))
    names = cfg["names"]
    if isinstance(names, dict):
        names = [names[i] for i in sorted(names)]
    nc_src = len(names)

    # --- Vérification des arguments ---
    if len(set(args.keep)) != len(args.keep):
        fail(f"--keep contient des doublons : {args.keep}")
    unknown = [c for c in args.keep if c not in names]
    if unknown:
        fail(f"classes inconnues dans {cfg_path} : {unknown} (disponibles : {names})")
    if dst == src or src in dst.parents or dst in src.parents:
        fail("le dossier de sortie ne doit pas être la source, ni dedans, ni la contenir")
    if dst.exists():
        if not args.ecraser:
            fail(f"{dst} existe déjà (ajoute --ecraser pour le régénérer)")
        shutil.rmtree(dst)

    # Ancien ID -> nouvel ID (None = classe supprimée)
    remap = {names.index(c): new for new, c in enumerate(args.keep)}
    dropped = [c for c in names if c not in args.keep]
    nc_dst = len(args.keep)

    splits = {s: cfg[s] for s in SPLITS if cfg.get(s)}
    if not splits:
        fail(f"aucun split (train/val/test) dans {cfg_path}")

    boxes_before = collections.Counter()      # par nom de classe, dans la source
    boxes_written = collections.Counter()     # par nom de classe, écrites dans la sortie
    removed_lines = 0
    stats = {}                                # par split : images, fonds avant/après
    expected_rests = {}                       # (split, stem) -> coordonnées gardées, pour le contrôle

    # --- Copie des images et réécriture des labels, split par split ---
    for split, rel in splits.items():
        img_src = src / rel
        lbl_src = labels_dir_for(img_src)
        img_dst, lbl_dst = dst / rel, labels_dir_for(dst / rel)
        img_dst.mkdir(parents=True, exist_ok=True)
        lbl_dst.mkdir(parents=True, exist_ok=True)

        images = list_images(img_src)
        stems = [p.stem for p in images]
        if len(set(stems)) != len(stems):
            fail(f"{img_src} : deux images ont le même nom sans extension (un seul fichier de labels possible)")

        bg_before = bg_after = 0
        for img in images:
            rows = read_label_lines(lbl_src / f"{img.stem}.txt", nc_src, lbl_src / f"{img.stem}.txt")
            kept = []
            for cid, rest in rows:
                boxes_before[names[cid]] += 1
                if cid in remap:
                    kept.append(f"{remap[cid]} {rest}")
                    boxes_written[names[cid]] += 1
                else:
                    removed_lines += 1
            bg_before += not rows
            bg_after += not kept
            expected_rests[(split, img.stem)] = [line.split(maxsplit=1)[1] for line in kept]

            shutil.copy2(img, img_dst / img.name)
            # write_bytes : fins de ligne "\n" même sous Windows, comme les labels d'origine
            (lbl_dst / f"{img.stem}.txt").write_bytes("".join(l + "\n" for l in kept).encode("utf-8"))

        stats[split] = (len(images), bg_before, bg_after)

    # --- Écriture du data.yaml (chemins relatifs à ce fichier, pas de 'path:') ---
    out_cfg = {s: splits[s] for s in splits}
    out_cfg["nc"] = nc_dst
    out_cfg["names"] = {i: c for i, c in enumerate(args.keep)}
    (dst / "data.yaml").write_bytes(yaml.safe_dump(out_cfg, sort_keys=False, allow_unicode=True).encode("utf-8"))

    # --- Rapport ---
    print(f"# Dérivation : {src.name} -> {dst.name}\n")
    print(f"Classes gardées ({nc_dst}) : " + ", ".join(f"{i}={c}" for i, c in enumerate(args.keep)))
    print(f"Classes supprimées ({len(dropped)}) : {', '.join(dropped) or 'aucune'}\n")
    print("## Images par split\n")
    print("| split | images | fonds avant | fonds après |\n|---|---|---|---|")
    for split, (n, b0, b1) in stats.items():
        print(f"| {split} | {n} | {b0} | {b1} |")
    print("\n## Boîtes par classe\n")
    print("| classe | avant | après |\n|---|---|---|")
    for c in names:
        print(f"| {c} | {boxes_before[c]} | {boxes_written[c]} |")
    print(f"\nLignes supprimées : {removed_lines}\n")

    # --- Contrôles : on relit ce qui a été écrit sur le disque ---
    print("## Contrôles\n")
    boxes_after = collections.Counter()
    for split, rel in splits.items():
        src_names = [p.name for p in list_images(src / rel)]
        dst_imgs = list_images(dst / rel)
        lbl_dst = labels_dir_for(dst / rel)

        # 1. Même nombre d'images et mêmes noms dans chaque split
        if [p.name for p in dst_imgs] != src_names:
            fail(f"[{split}] les images de la sortie ne correspondent pas à la source")

        # 2. Une image = un fichier de labels (et aucun label orphelin)
        lbl_stems = sorted(p.stem for p in lbl_dst.glob("*.txt"))
        if lbl_stems != sorted(p.stem for p in dst_imgs):
            fail(f"[{split}] il n'y a pas exactement un fichier de labels par image")

        for img in dst_imgs:
            # 3. Aucun ID hors de 0..N-1 (vérifié par read_label_lines avec nc_dst)
            rows = read_label_lines(lbl_dst / f"{img.stem}.txt", nc_dst, lbl_dst / f"{img.stem}.txt")
            for cid, _ in rows:
                boxes_after[args.keep[cid]] += 1
            # Bonus : coordonnées recopiées sans modification
            if [rest for _, rest in rows] != expected_rests[(split, img.stem)]:
                fail(f"[{split}] {img.stem} : coordonnées différentes de la source")
    print(f"OK  mêmes images et mêmes noms dans chaque split ({', '.join(splits)})")
    print("OK  une image = un fichier de labels")
    print(f"OK  aucun ID de classe hors de 0..{nc_dst - 1}")
    print("OK  coordonnées identiques à la source")

    # 4. Même nombre de boîtes pour chaque classe gardée
    for c in args.keep:
        if boxes_after[c] != boxes_before[c]:
            fail(f"classe {c} : {boxes_before[c]} boîtes avant, {boxes_after[c]} après")
    print("OK  nombre de boîtes identique pour chaque classe gardée")

    # 5. Lignes supprimées = total des boîtes des classes supprimées
    expected_removed = sum(boxes_before[c] for c in dropped)
    if removed_lines != expected_removed:
        fail(f"{removed_lines} lignes supprimées, mais {expected_removed} boîtes dans les classes supprimées")
    print(f"OK  lignes supprimées ({removed_lines}) = boîtes des classes supprimées ({expected_removed})")
    print(f"\nTerminé : {dst}")


if __name__ == "__main__":
    main()
