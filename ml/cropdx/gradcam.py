"""Grad-CAM heatmaps: shows which part of the leaf drove each prediction.

    python -m cropdx.gradcam --model runs/latest/best.keras --out reports/gradcam.png
"""
from __future__ import annotations

import argparse
import random
from pathlib import Path

import keras
import numpy as np
import tensorflow as tf

from . import data
from .labels import CLASSES, INDEX


def gradcam(model: keras.Model, image: np.ndarray) -> tuple[np.ndarray, int, float]:
    """Returns (heatmap in [0,1] at image resolution, class index, probability)."""
    base_idx = next(i for i, l in enumerate(model.layers) if isinstance(l, keras.Model))
    h = tf.convert_to_tensor(image[None, ...], tf.float32)
    for layer in model.layers[1:base_idx]:          # normalisation layers
        h = layer(h)
    with tf.GradientTape() as tape:
        feats = model.layers[base_idx](h, training=False)   # last conv feature map
        tape.watch(feats)
        out = feats
        for layer in model.layers[base_idx + 1:]:   # pool -> dropout -> dense
            out = layer(out, training=False)
        cls = int(tf.argmax(out[0]))
        score = out[0, cls]
    grads = tape.gradient(score, feats)[0]
    weights = tf.reduce_mean(grads, axis=(0, 1))
    cam = tf.nn.relu(tf.reduce_sum(feats[0] * weights, axis=-1))
    cam = cam / (tf.reduce_max(cam) + 1e-8)
    cam = tf.image.resize(cam[..., None], image.shape[:2], method="bilinear")[..., 0]
    return cam.numpy(), cls, float(out[0, cls])


def main(argv=None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--data-root", default="data/plantvillage/raw/color")
    ap.add_argument("--split-dir", default="splits")
    ap.add_argument("--out", default="reports/gradcam.png")
    ap.add_argument("--seed", type=int, default=3)
    args = ap.parse_args(argv)

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    model = keras.models.load_model(args.model, compile=False)
    size = int(model.input_shape[1])
    rows = data.read_split(Path(args.split_dir), "test")
    rng = random.Random(args.seed)
    picks = []
    for c in CLASSES:
        picks.append(rng.choice([r for r in rows if r[1] == c]))

    fig, axes = plt.subplots(2, 10, figsize=(20, 5.0), facecolor="#fcfcfb")
    for j, (path, label) in enumerate(picks):
        img = data.load_numpy(Path(args.data_root) / path, size)
        cam, cls, p = gradcam(model, img)
        axes[0, j].imshow(img.astype(np.uint8))
        axes[0, j].set_title(label.replace("_", " "), fontsize=9, color="#0b0b0b")
        axes[1, j].imshow(img.astype(np.uint8))
        axes[1, j].imshow(cam, cmap="inferno", alpha=0.5, vmin=0, vmax=1)
        ok = cls == INDEX[label]
        axes[1, j].set_title(f"{'✓' if ok else '✗'} {CLASSES[cls].replace('_', ' ')} {p:.0%}",
                             fontsize=8, color="#52514e" if ok else "#d03b3b")
        for ax in axes[:, j]:
            ax.axis("off")
    fig.suptitle("Grad-CAM: where the model looks (top: input, bottom: attention + prediction)",
                 x=0.01, ha="left", fontsize=12, color="#0b0b0b")
    fig.tight_layout()
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=110)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
