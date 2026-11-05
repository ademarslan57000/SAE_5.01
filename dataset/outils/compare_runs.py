#!/usr/bin/env python3
"""
Compare deux entraînements YOLO sur le split test (SAE 501 - détection d'EPI).

Sert à choisir entre deux schémas de classes entraînés sur les mêmes images,
par exemple 11 classes (run A, référence) contre 6 classes positives (run B).

Usage (depuis la racine du dépôt, local ou Google Colab) :
    python dataset/outils/compare_runs.py \\
        --run-a dataset/entrainements/run_datasetV2 --data-a dataset/data.yaml --nom-a "11 classes" \\
        --run-b <dossier du run 3> --data-b dataset_positives/data.yaml --nom-b "6 classes" \\
        --verite dataset/data.yaml \\
        --paires no_helmet:helmet no_vest:vest no_gloves:gloves no_boots:boots no_goggle:goggles \\
        --sortie dataset/evaluations/comparatif_6_vs_11.md

Ce que fait le script :
  1. compare les deux args.yaml (seuls les réglages listés dans --args-attendus
     ont le droit de différer) et lit la version d'Ultralytics de chaque best.pt
  2. évalue chaque best.pt sur le split demandé avec `val` (mêmes paramètres pour
     les deux), puis compare précision, rappel, mAP50 et mAP50-95 des classes communes
  3. lit dans chaque results.csv le meilleur mAP50 de validation et le nombre d'epochs
  4. compte les « faux équipements » : boîtes d'absence de la vérité terrain
     (ex. no_helmet) recouvertes (IoU >= --iou) par une prédiction de l'équipement
     correspondant (ex. helmet) avec une confiance >= --conf
  5. applique la règle de décision et écrit le rapport Markdown

Les dossiers des runs et des datasets ne sont jamais modifiés : `val` travaille
sur une copie temporaire du split (sinon il écrirait un fichier .cache dans labels/).
"""
import argparse, csv, shutil, sys, tempfile
from pathlib import Path

import yaml


def fail(msg):
    sys.exit(f"ERREUR : {msg}")


def load_yaml(path):
    if not Path(path).exists():
        fail(f"{path} introuvable")
    return yaml.safe_load(Path(path).read_text(encoding="utf-8"))


def names_list(names):
    return [names[i] for i in sorted(names)] if isinstance(names, dict) else list(names)


def split_dirs(data_yaml, split):
    """Dossiers images/labels d'un split et noms des classes, d'après un data.yaml."""
    cfg = load_yaml(data_yaml)
    if not cfg.get(split):
        fail(f"pas de split '{split}' dans {data_yaml}")
    img = (Path(data_yaml).parent / cfg[split]).resolve()
    parts = list(img.parts)
    i = len(parts) - 1 - parts[::-1].index("images")   # convention YOLO : images/<split> -> labels/<split>
    parts[i] = "labels"
    return img, Path(*parts), names_list(cfg["names"])


def read_gt(label_file):
    """Boîtes de vérité terrain d'un fichier YOLO : liste de (classe, x1, y1, x2, y2) normalisés."""
    boxes = []
    if label_file.exists():
        for line in label_file.read_text(encoding="utf-8").splitlines():
            if line.strip():
                c, x, y, w, h = line.split()
                x, y, w, h = map(float, (x, y, w, h))
                boxes.append((int(c), x - w / 2, y - h / 2, x + w / 2, y + h / 2))
    return boxes


def iou(a, b):
    # Coordonnées normalisées : l'IoU est la même qu'en pixels (même facteur sur l'intersection et l'union)
    iw = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    ih = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = iw * ih
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def run_info(run_dir):
    """Chemins utiles d'un run et réglages d'entraînement."""
    run_dir = Path(run_dir)
    files = {"best": run_dir / "weights" / "best.pt", "args": run_dir / "args.yaml", "csv": run_dir / "results.csv"}
    for k, p in files.items():
        if not p.exists():
            fail(f"{p} introuvable")
    return files, load_yaml(files["args"])


def read_results(csv_path):
    """Nombre d'epochs et meilleur mAP50 de validation (avec son epoch) dans results.csv."""
    with open(csv_path, newline="", encoding="utf-8") as f:
        rows = [{k.strip(): v for k, v in r.items()} for r in csv.DictReader(f)]
    best = max(rows, key=lambda r: float(r["metrics/mAP50(B)"]))
    return len(rows), float(best["metrics/mAP50(B)"]), int(float(best["epoch"]))


def evaluate(model, data_yaml, split, imgsz, device, tmp, tag):
    """Lance `val` sur une copie temporaire du split ; renvoie {classe: (P, R, mAP50, mAP50-95)}."""
    img, lbl, names = split_dirs(data_yaml, split)
    if names_list(model.names) != names:
        fail(f"les classes du modèle {names_list(model.names)} ne correspondent pas à {data_yaml} {names}")
    root = tmp / tag
    shutil.copytree(img, root / "images" / split)
    shutil.copytree(lbl, root / "labels" / split)
    rel = f"images/{split}"
    cfg = {"train": rel, "val": rel, split: rel, "names": dict(enumerate(names))}
    (root / "data.yaml").write_text(yaml.safe_dump(cfg, sort_keys=False), encoding="utf-8")

    m = model.val(data=str(root / "data.yaml"), split=split, imgsz=imgsz, device=device,
                  plots=False, verbose=False, project=str(tmp / "val"), name=tag)
    per_class = {}
    for i, c in enumerate(m.box.ap_class_index):
        per_class[m.names[int(c)]] = tuple(float(v) for v in m.box.class_result(i))
    return per_class


def fake_equipment(model, gt_img, gt_lbl, gt_names, pairs, imgsz, conf, iou_min, device):
    """Pour chaque paire (absence, équipement) : [boîtes d'absence recouvertes, total]."""
    model_ids = {n: i for i, n in enumerate(names_list(model.names))}
    gt_ids = {n: i for i, n in enumerate(gt_names)}
    counts = {neg: [0, 0] for neg, _ in pairs}
    images = sorted(p for p in gt_img.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".webp"})

    # Prédiction à un seuil plus bas puis filtrage >= conf : le NMS ne laisse jamais une boîte
    # sous le seuil supprimer une boîte au-dessus, donc on garde exactement les boîtes >= conf
    for res in model.predict(source=[str(p) for p in images], imgsz=imgsz, conf=min(conf, 0.25),
                             device=device, stream=True, verbose=False):
        preds = [(int(c), *map(float, xy)) for c, xy, s in
                 zip(res.boxes.cls.tolist(), res.boxes.xyxyn.tolist(), res.boxes.conf.tolist()) if s >= conf]
        gt = read_gt(gt_lbl / f"{Path(res.path).stem}.txt")
        for neg, pos in pairs:
            for g in (b for b in gt if b[0] == gt_ids[neg]):
                counts[neg][1] += 1
                if any(p[0] == model_ids[pos] and iou(g[1:], p[1:]) >= iou_min for p in preds):
                    counts[neg][0] += 1
    return counts


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run-a", required=True, help="dossier du run de référence (weights/best.pt, args.yaml, results.csv)")
    ap.add_argument("--data-a", required=True, type=Path, help="data.yaml du dataset du run A")
    ap.add_argument("--nom-a", required=True, help="nom court du run A dans le rapport")
    ap.add_argument("--run-b", required=True, help="dossier du run comparé")
    ap.add_argument("--data-b", required=True, type=Path, help="data.yaml du dataset du run B")
    ap.add_argument("--nom-b", required=True, help="nom court du run B dans le rapport")
    ap.add_argument("--verite", required=True, type=Path, help="data.yaml dont les labels servent de vérité terrain (avec les classes d'absence)")
    ap.add_argument("--paires", nargs="+", required=True, help="paires absence:équipement, ex. no_helmet:helmet")
    ap.add_argument("--sortie", required=True, type=Path, help="fichier Markdown du rapport")
    ap.add_argument("--split", default="test", help="split évalué (défaut : test)")
    ap.add_argument("--imgsz", type=int, default=640, help="taille d'image pour val et predict (défaut : 640)")
    ap.add_argument("--conf", type=float, default=0.5, help="confiance minimale des faux équipements (défaut : 0.5)")
    ap.add_argument("--iou", type=float, default=0.5, help="IoU minimale des faux équipements (défaut : 0.5)")
    ap.add_argument("--tolerance", type=float, default=0.01, help="tolérance sur la moyenne du mAP50 (défaut : 0.01)")
    ap.add_argument("--device", default="cpu", help="cpu, 0, ... (défaut : cpu)")
    ap.add_argument("--args-attendus", nargs="*", default=["data", "name", "save_dir"],
                    help="réglages d'entraînement qui ont le droit de différer (défaut : data name save_dir)")
    args = ap.parse_args()
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")

    import ultralytics
    from ultralytics import YOLO

    pairs = []
    for p in args.paires:
        if p.count(":") != 1:
            fail(f"paire mal écrite : {p!r} (attendu absence:équipement)")
        pairs.append(tuple(p.split(":")))

    # --- 1. Réglages d'entraînement et versions ---
    files_a, cfg_a = run_info(args.run_a)
    files_b, cfg_b = run_info(args.run_b)
    diffs = [(k, cfg_a.get(k), cfg_b.get(k)) for k in dict.fromkeys([*cfg_a, *cfg_b]) if cfg_a.get(k) != cfg_b.get(k)]
    unexpected = [d for d in diffs if d[0] not in args.args_attendus]
    model_a, model_b = YOLO(str(files_a["best"])), YOLO(str(files_b["best"]))
    ver_a, ver_b = (m.ckpt.get("version", "?") for m in (model_a, model_b))

    # --- 2. Évaluation sur le split test, mêmes paramètres pour les deux modèles ---
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as t:
        tmp = Path(t)
        per_a = evaluate(model_a, args.data_a, args.split, args.imgsz, args.device, tmp, "a")
        per_b = evaluate(model_b, args.data_b, args.split, args.imgsz, args.device, tmp, "b")
    common = [c for c in names_list(model_b.names) if c in per_a and c in per_b]
    if not common:
        fail("aucune classe commune entre les deux modèles")
    mean = lambda per, k: sum(per[c][k] for c in common) / len(common)

    # --- 3. Validation pendant l'entraînement (results.csv) ---
    ep_a, val_a, best_ep_a = read_results(files_a["csv"])
    ep_b, val_b, best_ep_b = read_results(files_b["csv"])

    # --- 4. Faux équipements, vérité terrain = labels avec classes d'absence ---
    gt_img, gt_lbl, gt_names = split_dirs(args.verite, args.split)
    for neg, pos in pairs:
        if neg not in gt_names:
            fail(f"classe d'absence {neg!r} absente de {args.verite}")
        for m, nom in ((model_a, args.nom_a), (model_b, args.nom_b)):
            if pos not in names_list(m.names):
                fail(f"le modèle {nom} ne connaît pas la classe {pos!r}")
    fe_a = fake_equipment(model_a, gt_img, gt_lbl, gt_names, pairs, args.imgsz, args.conf, args.iou, args.device)
    fe_b = fake_equipment(model_b, gt_img, gt_lbl, gt_names, pairs, args.imgsz, args.conf, args.iou, args.device)
    tot_a, tot_b = sum(v[0] for v in fe_a.values()), sum(v[0] for v in fe_b.values())
    tot_n = sum(v[1] for v in fe_a.values())

    # --- 5. Règle de décision ---
    m50_a, m50_b = mean(per_a, 2), mean(per_b, 2)
    ok_map = m50_b >= m50_a - args.tolerance
    ok_fe = tot_b <= tot_a

    # --- Rapport Markdown ---
    A, B = args.nom_a, args.nom_b
    pct = lambda n, d: f"{100 * n / d:.1f} %" if d else "—"
    L = [f"# Comparatif {B} vs {A}", "",
         f"Évaluation sur le split **{args.split}**, `imgsz={args.imgsz}`, réglages par défaut de `val`, "
         f"CPU (`device={args.device}`), Ultralytics {ultralytics.__version__} pour les deux modèles.", "",
         "## Runs comparés", "",
         "| | run | data | epochs effectuées | Ultralytics à l'entraînement |", "|---|---|---|---|---|",
         f"| {A} | `{Path(args.run_a).name}` | `{cfg_a.get('data')}` | {ep_a} / {cfg_a.get('epochs')} | {ver_a} |",
         f"| {B} | `{Path(args.run_b).name}` | `{cfg_b.get('data')}` | {ep_b} / {cfg_b.get('epochs')} | {ver_b} |", ""]
    common_args = ", ".join(f"{k}={cfg_a.get(k)}" for k in ("model", "epochs", "patience", "imgsz", "batch", "seed"))
    if unexpected:
        L += ["**Attention : réglages d'entraînement différents en plus du dataset :**", ""]
        L += [f"- `{k}` : {va} ({A}) / {vb} ({B})" for k, va, vb in unexpected]
    else:
        L += [f"Réglages d'entraînement identiques ({common_args}). "
              f"Seuls diffèrent : {', '.join(f'`{k}`' for k, _, _ in diffs) or 'rien'}."]
    if ver_a != ver_b:
        L += ["", f"Remarque : version d'Ultralytics différente à l'entraînement ({ver_a} / {ver_b}), "
                  "non visible dans `args.yaml`. L'évaluation ci-dessous utilise une seule version pour les deux."]

    L += ["", f"## Test : {len(common)} classes communes", "",
          f"| classe | P {A} | P {B} | écart | R {A} | R {B} | écart | mAP50 {A} | mAP50 {B} | écart | mAP50-95 {A} | mAP50-95 {B} | écart |",
          "|---|" + "---|" * 12]
    for c in common + ["**moyenne**"]:
        vals = [(mean(per_a, k), mean(per_b, k)) if c.startswith("**") else (per_a[c][k], per_b[c][k]) for k in range(4)]
        L.append(f"| {c} | " + " | ".join(f"{a:.3f} | {b:.3f} | {b - a:+.3f}" for a, b in vals) + " |")

    L += ["", "## Validation pendant l'entraînement (`results.csv`)", "",
          "| | meilleur mAP50 val | à l'epoch | epochs effectuées |", "|---|---|---|---|",
          f"| {A} | {val_a:.3f} | {best_ep_a} | {ep_a} |", f"| {B} | {val_b:.3f} | {best_ep_b} | {ep_b} |", "",
          f"Ce mAP50 est la moyenne de **toutes** les classes de chaque modèle ({len(per_a)} contre {len(per_b)}) : "
          "il n'est pas directement comparable. La décision repose sur le test, classes communes."]

    L += ["", "## Faux équipements (EPI vu alors qu'il n'est pas porté)", "",
          f"Vérité terrain : labels `{args.split}` de `{args.verite.as_posix()}`. Une boîte d'absence compte si au moins "
          f"une prédiction de l'équipement correspondant, de confiance ≥ {args.conf}, la recouvre avec une IoU ≥ {args.iou}.", "",
          f"| absence → équipement prédit | boîtes | {A} | {B} |", "|---|---|---|---|"]
    for neg, pos in pairs:
        (na, n), nb = fe_a[neg], fe_b[neg][0]
        L.append(f"| {neg} → {pos} | {n} | {na} ({pct(na, n)}) | {nb} ({pct(nb, n)}) |")
    L.append(f"| **total** | {tot_n} | **{tot_a} ({pct(tot_a, tot_n)})** | **{tot_b} ({pct(tot_b, tot_n)})** |")

    L += ["", "## Conclusion", "",
          f"- Critère 1, moyenne mAP50 des classes communes ≥ celle de {A} − {args.tolerance} : "
          f"{m50_b:.3f} contre {m50_a:.3f} → **{'respecté' if ok_map else 'non respecté'}**",
          f"- Critère 2, faux équipements de {B} ≤ ceux de {A} : "
          f"{tot_b} contre {tot_a} → **{'respecté' if ok_fe else 'non respecté'}** "
          f"(écart : {abs(tot_b - tot_a)} boîte(s) sur {tot_n})", ""]
    if ok_map and ok_fe:
        L.append(f"**Les deux critères sont respectés : on garde le schéma {B}.**")
    elif not ok_map and not ok_fe:
        L.append(f"**Aucun des deux critères n'est respecté : on garde le schéma {A}.**")
    else:
        good, bad = ("la précision de détection (mAP50)", "les faux équipements") if ok_map else \
                    ("les faux équipements", "la précision de détection (mAP50)")
        L.append(f"**Les deux critères se contredisent** : {B} fait au moins aussi bien sur {good}, "
                 f"mais moins bien sur {bad}. La règle ne permet pas de trancher : c'est une décision d'équipe.")

    report = "\n".join(L) + "\n"
    args.sortie.parent.mkdir(parents=True, exist_ok=True)
    args.sortie.write_bytes(report.encode("utf-8"))
    print(report)
    print(f"Rapport écrit : {args.sortie}")


if __name__ == "__main__":
    main()
