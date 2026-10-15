#!/usr/bin/env python3
"""
Fusion de datasets YOLO (SAE 501 - détection d'EPI).

Usage :
    python merge_datasets.py config.yaml

Ce que fait le script :
  1. lit chaque dataset source (format YOLO : images/ + labels/, avec ou sans splits)
  2. remappe les classes vers la liste unifiée (ou les supprime si mappées à null)
  3. renomme les fichiers avec un préfixe source (évite les collisions de noms)
  4. garde les splits d'origine, ou en crée (déterministe, seed fixe)
  5. vérifie chaque label (5 colonnes, coordonnées dans [0,1], w/h > 0)
  6. écrit data.yaml + un rapport de stats par split / classe / source
"""
import argparse, collections, json, random, shutil, sys
from pathlib import Path

import yaml

IMG_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SPLITS = ("train", "val", "test")


def find_pairs(root: Path):
    """Retourne {split|None: [(image, label|None), ...]}."""
    out = collections.defaultdict(list)
    img_root = root / "images"
    lbl_root = root / "labels"
    has_splits = any((img_root / s).is_dir() for s in SPLITS)
    for split in (SPLITS if has_splits else (None,)):
        idir = img_root / split if split else img_root
        ldir = lbl_root / split if split else lbl_root
        if not idir.is_dir():
            continue
        for img in sorted(idir.iterdir()):
            if img.suffix.lower() in IMG_EXT:
                lbl = ldir / (img.stem + ".txt")
                out[split].append((img, lbl if lbl.exists() else None))
    return out


def read_names(src_cfg, root: Path):
    if "names" in src_cfg:
        return list(src_cfg["names"])
    ct = root / "classes.txt"
    if ct.exists():
        return [l.strip() for l in ct.read_text().splitlines() if l.strip()]
    sys.exit(f"[{src_cfg['name']}] impossible de trouver les noms de classes")


def convert_label(lbl: Path, src_names, mapping, target_idx, errors, tag):
    lines_out, dropped = [], collections.Counter()
    if lbl is None:
        return lines_out, dropped  # image sans label = image de fond (background)
    for n, line in enumerate(lbl.read_text().splitlines(), 1):
        t = line.split()
        if not t:
            continue
        if len(t) != 5:
            errors.append(f"{tag}:{lbl.name}:{n} -> {len(t)} colonnes (polygone ?)")
            continue
        cid = int(t[0])
        x, y, w, h = map(float, t[1:])
        if not (0 <= x <= 1 and 0 <= y <= 1 and 0 < w <= 1 and 0 < h <= 1):
            errors.append(f"{tag}:{lbl.name}:{n} -> coordonnées hors [0,1]")
            continue
        src_name = src_names[cid]
        if src_name not in mapping:
            errors.append(f"{tag}: classe source '{src_name}' absente du mapping")
            continue
        dst = mapping[src_name]
        if dst is None:
            dropped[src_name] += 1
            continue
        lines_out.append(f"{target_idx[dst]} {x:.6f} {y:.6f} {w:.6f} {h:.6f}")
    return lines_out, dropped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("config")
    args = ap.parse_args()
    cfg_path = Path(args.config).resolve()
    cfg = yaml.safe_load(cfg_path.read_text())
    base = cfg_path.parent

    target = cfg["classes"]
    target_idx = {c: i for i, c in enumerate(target)}
    out = (base / cfg["output"]).resolve()
    if out.exists():
        shutil.rmtree(out)
    for s in SPLITS:
        (out / "images" / s).mkdir(parents=True)
        (out / "labels" / s).mkdir(parents=True)

    stats = collections.defaultdict(collections.Counter)      # split -> classe -> nb boxes
    img_count = collections.defaultdict(collections.Counter)  # source -> split -> nb images
    dropped_all = collections.defaultdict(collections.Counter)
    errors = []

    for src in cfg["sources"]:
        name, root = src["name"], (base / src["path"]).resolve()
        src_names = read_names(src, root)
        mapping = src["mapping"]
        for dst in mapping.values():
            if dst is not None and dst not in target_idx:
                sys.exit(f"[{name}] classe cible '{dst}' absente de la liste 'classes'")

        pairs = find_pairs(root)
        if None in pairs:  # pas de splits -> on les crée
            items = pairs.pop(None)
            ratios = src.get("split", {"train": 0.7, "val": 0.15, "test": 0.15})
            rnd = random.Random(cfg.get("seed", 42))
            rnd.shuffle(items)
            n = len(items)
            n_tr = round(n * ratios["train"])
            n_va = round(n * ratios["val"])
            pairs = {"train": items[:n_tr], "val": items[n_tr:n_tr + n_va], "test": items[n_tr + n_va:]}
        if src.get("force_split"):  # ex. envoyer tout un dataset en test
            merged = [p for s in pairs.values() for p in s]
            pairs = {src["force_split"]: merged}

        missing = 0
        for split, items in pairs.items():
            for img, lbl in items:
                if lbl is None:
                    missing += 1
                stem = f"{name}__{img.stem}"
                lines, dropped = convert_label(lbl, src_names, mapping, target_idx, errors, name)
                dropped_all[name].update(dropped)
                shutil.copy2(img, out / "images" / split / (stem + img.suffix.lower()))
                (out / "labels" / split / (stem + ".txt")).write_text("\n".join(lines) + ("\n" if lines else ""))
                img_count[name][split] += 1
                for l in lines:
                    stats[split][target[int(l.split()[0])]] += 1
        if missing:
            print(f"[{name}] {missing} images sans fichier label (traitées comme fond)")

    (out / "data.yaml").write_text(yaml.safe_dump({
        "path": str(out),
        "train": "images/train", "val": "images/val", "test": "images/test",
        "names": {i: c for i, c in enumerate(target)},
    }, sort_keys=False, allow_unicode=True))

    # ---- rapport ----
    rep = ["# Rapport de fusion", "", "## Images par source", "",
           "| source | train | val | test | total |", "|---|---|---|---|---|"]
    for s, c in img_count.items():
        rep.append(f"| {s} | {c['train']} | {c['val']} | {c['test']} | {sum(c.values())} |")
    rep += ["", "## Boxes par classe", "", "| classe | train | val | test | total |", "|---|---|---|---|---|"]
    for c in target:
        v = [stats[s][c] for s in SPLITS]
        flag = "  ⚠️ 0 exemple" if sum(v) == 0 else ("  ⚠️ < 100" if sum(v) < 100 else "")
        rep.append(f"| {c} | {v[0]} | {v[1]} | {v[2]} | {sum(v)}{flag} |")
    rep += ["", "## Boxes supprimées (classes mappées à null)", ""]
    for s, d in dropped_all.items():
        rep.append(f"- {s} : {dict(d) if d else 'aucune'}")
    rep += ["", f"## Erreurs de labels : {len(errors)}", ""] + [f"- {e}" for e in errors[:50]]
    (out / "rapport_fusion.md").write_text("\n".join(rep) + "\n")
    print("\n".join(rep))


if __name__ == "__main__":
    main()
