"""Evaluate exported LiteRT models on lab (PlantVillage test split) and field
(PlantDoc) images, and benchmark CPU latency.

    python -m cropdx.evaluate --models ../models --legacy ../legacy/2018-model/model_unquant.tflite

Outputs (in --report-dir): metrics.json, metrics.md, confusion_<set>.png, accuracy.png
"""
from __future__ import annotations

import argparse
import json
import statistics
import time
from pathlib import Path

import numpy as np
from ai_edge_litert.interpreter import Interpreter

from . import data
from .labels import CLASSES, INDEX, LEGACY_2018, PLANTDOC

# chart tokens (light surface)
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
BLUE, ORANGE = "#2a78d6", "#eb6834"
SEQ = ["#fcfcfb", "#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"]


class Model:
    """A .tflite classifier plus the mapping from its outputs to canonical classes."""

    def __init__(self, path: Path, name: str, out_classes: list[str], legacy: bool = False):
        self.name, self.path, self.out_classes, self.legacy = name, path, out_classes, legacy
        self.it = Interpreter(str(path), num_threads=1)
        self.it.allocate_tensors()
        self.inp = self.it.get_input_details()[0]
        self.out = self.it.get_output_details()[0]
        self.size = int(self.inp["shape"][1])
        self.supported = set(out_classes)

    def predict(self, img: np.ndarray) -> np.ndarray:
        x = img[None, ...].astype(np.float32)
        if self.legacy:  # Teachable Machine export expects [-1, 1] input
            x = x / 127.5 - 1.0
        self.it.set_tensor(self.inp["index"], x)
        self.it.invoke()
        return self.it.get_tensor(self.out["index"])[0]


def load_set(kind: str, root: Path, split_dir: Path) -> list[tuple[Path, str]]:
    if kind == "lab":
        return [(root / p, c) for p, c in data.read_split(split_dir, "test")]
    # PlantDoc's official test split: never trained on, even by the field-mixed model
    return [(Path(p), c) for p, c in data.plantdoc_rows(root, "test")]


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    """95% Wilson score interval for a proportion (honest error bars on small sets)."""
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5) / d
    return (round(c - h, 4), round(c + h, 4))


def evaluate(model: Model, rows, cache: dict) -> dict:
    rows = [(p, c) for p, c in rows if c in model.supported]
    y_true, y_pred, conf, sure = [], [], [], []
    for path, cls in rows:
        key = (str(path), model.size)
        if key not in cache:
            cache[key] = data.load_numpy(path, model.size)
        probs = model.predict(cache[key])
        k = int(np.argmax(probs))
        y_true.append(INDEX[cls])
        y_pred.append(INDEX[model.out_classes[k]])
        conf.append(float(probs[k]))
        p_sorted = np.sort(probs / max(float(probs.sum()), 1e-9))[::-1]
        # same "Not sure" rule as both apps: top-1 < 0.55 or margin < 0.15
        sure.append(bool(p_sorted[0] >= 0.55 and p_sorted[0] - p_sorted[1] >= 0.15))
    y_true, y_pred, sure = np.array(y_true), np.array(y_pred), np.array(sure)

    n = len(CLASSES)
    cm = np.zeros((n, n), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1
    per_class = {}
    f1s = []
    for i, c in enumerate(CLASSES):
        if c not in model.supported or cm[i].sum() == 0:
            continue
        tp = cm[i, i]
        prec = tp / cm[:, i].sum() if cm[:, i].sum() else 0.0
        rec = tp / cm[i].sum()
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        f1s.append(f1)
        per_class[c] = {"precision": round(prec, 4), "recall": round(rec, 4),
                        "f1": round(f1, 4), "support": int(cm[i].sum())}
    correct = int((y_true == y_pred).sum())
    return {
        "images": int(len(y_true)),
        "accuracy": round(correct / len(y_true), 4),
        "accuracy_ci95": wilson(correct, len(y_true)),
        "macro_f1": round(float(np.mean(f1s)), 4),
        "mean_confidence": round(float(np.mean(conf)), 4),
        # selective prediction: how often the app answers, and how often it's right then
        "coverage": round(float(sure.mean()), 4),
        "accuracy_when_confident": round(float((y_true == y_pred)[sure].mean()), 4) if sure.any() else 0.0,
        "per_class": per_class,
        "confusion": cm.tolist(),
    }


def latency_ms(model: Model, img: np.ndarray, runs: int = 50) -> float:
    for _ in range(5):
        model.predict(img)
    times = []
    for _ in range(runs):
        t0 = time.perf_counter()
        model.predict(img)
        times.append((time.perf_counter() - t0) * 1e3)
    return round(statistics.median(times), 2)


# ------------------------------------------------------------------- charts
def _style(plt):
    plt.rcParams.update({
        "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
        "axes.edgecolor": GRID, "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
        "text.color": INK, "font.size": 10, "axes.spines.top": False, "axes.spines.right": False,
    })


def plot_confusion(cm: list[list[int]], title: str, path: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap
    _style(plt)
    cm = np.array(cm, dtype=float)
    # keep a class if it occurs as ground truth *or* as a prediction
    keep = [i for i in range(len(CLASSES)) if cm[i].sum() > 0 or cm[:, i].sum() > 0]
    cm = cm[np.ix_(keep, keep)]
    norm = cm / np.maximum(cm.sum(axis=1, keepdims=True), 1)
    names = [CLASSES[i].replace("_", " ") for i in keep]
    fig, ax = plt.subplots(figsize=(8.2, 7))
    cmap = LinearSegmentedColormap.from_list("seq", SEQ)
    ax.imshow(norm, cmap=cmap, vmin=0, vmax=1)
    for i in range(len(keep)):
        for j in range(len(keep)):
            v = norm[i, j]
            if v >= 0.005:
                ax.text(j, i, f"{v:.0%}" if v < 0.995 else "100%", ha="center", va="center",
                        fontsize=8, color="#ffffff" if v > 0.55 else INK)
    ax.set_xticks(range(len(keep)), names, rotation=40, ha="right")
    ax.set_yticks(range(len(keep)), names)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    ax.set_title(title, loc="left", fontsize=12, color=INK, pad=12)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(length=0)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_accuracy(results: dict, path: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    _style(plt)
    names = list(results)
    lab = [results[n]["lab"]["accuracy"] * 100 for n in names]
    field = [results[n]["field"]["accuracy"] * 100 for n in names]
    x = np.arange(len(names))
    w = 0.36
    fig, ax = plt.subplots(figsize=(9, 4.4))
    b1 = ax.bar(x - w / 2 - 0.01, lab, w, color=BLUE, label="Lab images (PlantVillage test split)")
    b2 = ax.bar(x + w / 2 + 0.01, field, w, color=ORANGE, label="Field photos (PlantDoc test split, 95% CI)")
    lo = [results[n]["field"]["accuracy_ci95"][0] * 100 for n in names]
    hi = [results[n]["field"]["accuracy_ci95"][1] * 100 for n in names]
    ax.errorbar(x + w / 2 + 0.01, field, yerr=[np.subtract(field, lo), np.subtract(hi, field)],
                fmt="none", ecolor=INK2, elinewidth=1, capsize=3)
    for bars in (b1, b2):
        for b in bars:
            ax.text(b.get_x() + b.get_width() / 2, 2, f"{b.get_height():.0f}",
                    ha="center", fontsize=9, color="#ffffff", fontweight="bold")
    ax.set_xticks(x, names)
    ax.set_ylim(0, 108)
    ax.set_ylabel("Top-1 accuracy (%)")
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)
    ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.1), ncol=2)
    ax.set_title("Accuracy: lab vs. real-world field photos", loc="left", fontsize=12, pad=12)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


# --------------------------------------------------------------------- main
def main(argv=None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", default="../models")
    ap.add_argument("--legacy", default="")
    ap.add_argument("--compare", nargs="*", default=[], metavar="NAME=MODEL.tflite",
                    help="extra models with the same labels.txt, e.g. a lab-only baseline")
    ap.add_argument("--lab-root", default="data/plantvillage/raw/color")
    ap.add_argument("--field-root", default="data/plantdoc")
    ap.add_argument("--split-dir", default="splits")
    ap.add_argument("--report-dir", default="reports")
    args = ap.parse_args(argv)

    mdir, rep = Path(args.models), Path(args.report_dir)
    rep.mkdir(parents=True, exist_ok=True)
    labels = Path(mdir / "labels.txt").read_text().split()
    models = [Model(mdir / f"crop_disease_{t}.tflite", f"v2 {t.upper()}", labels)
              for t in ("fp32", "fp16", "int8") if (mdir / f"crop_disease_{t}.tflite").exists()]
    for item in reversed(args.compare):
        name, path = item.split("=", 1)
        models.insert(0, Model(Path(path), name, labels))
    if args.legacy:
        models.insert(0, Model(Path(args.legacy), "2018 model", LEGACY_2018, legacy=True))

    sets = {"lab": load_set("lab", Path(args.lab_root), Path(args.split_dir)),
            "field": load_set("field", Path(args.field_root), Path(args.split_dir))}
    sample = data.load_numpy(sets["lab"][0][0], models[-1].size)

    results, cache = {}, {}
    for m in models:
        r = {"file": m.path.name, "bytes": m.path.stat().st_size,
             "latency_ms_1thread": latency_ms(m, sample)}
        for s, rows in sets.items():
            r[s] = evaluate(m, rows, cache)
            print(f"{m.name:18s} {s:5s} acc={r[s]['accuracy']:.4f} f1={r[s]['macro_f1']:.4f} "
                  f"coverage={r[s]['coverage']:.3f} acc@conf={r[s]['accuracy_when_confident']:.4f} "
                  f"n={r[s]['images']}")
        r["supported_classes"] = len(m.supported)
        results[m.name] = r

    (rep / "metrics.json").write_text(json.dumps(results, indent=2) + "\n")

    best = next((n for n in results if n == "v2 INT8"), list(results)[-1])  # the shipped model
    for s in sets:
        plot_confusion(results[best][s]["confusion"],
                       f"Confusion matrix · {best} · {s} images (row-normalised)",
                       rep / f"confusion_{s}.png")
    plot_accuracy(results, rep / "accuracy.png")

    lines = ["| Model | Size | Latency (1 thread) | Lab accuracy | Lab macro-F1 "
             "| Field accuracy (95% CI) | Field macro-F1 | Field: answered / right when answered |",
             "|---|---|---|---|---|---|---|---|"]
    for n, r in results.items():
        lo, hi = r["field"]["accuracy_ci95"]
        lines.append(f"| {n} | {r['bytes'] / 1e6:.2f} MB | {r['latency_ms_1thread']:.1f} ms | "
                     f"{r['lab']['accuracy']:.1%} | {r['lab']['macro_f1']:.3f} | "
                     f"{r['field']['accuracy']:.1%} ({lo:.0%}–{hi:.0%}) | {r['field']['macro_f1']:.3f} | "
                     f"{r['field']['coverage']:.0%} / {r['field']['accuracy_when_confident']:.0%} |")
    (rep / "metrics.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
