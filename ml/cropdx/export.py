"""Export a trained Keras model to LiteRT (.tflite) in three precisions.

    python -m cropdx.export --model runs/latest/best.keras --out ../models

Writes:
    crop_disease_fp32.tflite   reference accuracy
    crop_disease_fp16.tflite   half-size weights, ~same accuracy  (default for mobile)
    crop_disease_int8.tflite   full-integer kernels, float I/O    (default for edge CPUs)
    labels.txt                 one class id per line, model output order
    model_info.json            input contract, variants, checksums
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import tempfile
from pathlib import Path

import keras
import numpy as np
import tensorflow as tf

from . import data
from .labels import CLASSES

NAME = "crop_disease"


def _saved_model(model: keras.Model, size: int, path: Path) -> Path:
    """Export a frozen-signature SavedModel (batch 1) for the LiteRT converter."""
    sig = [tf.TensorSpec([1, size, size, 3], tf.float32, name="image")]
    model.export(str(path), format="tf_saved_model", input_signature=sig, verbose=False)
    return path


def _converter(saved_model: Path) -> tf.lite.TFLiteConverter:
    return tf.lite.TFLiteConverter.from_saved_model(str(saved_model))


def representative_data(rows, root: Path, size: int, n: int, seed: int):
    rows = list(rows)
    random.Random(seed).shuffle(rows)
    picks = rows[:n]

    def gen():
        for path, _ in picks:
            yield [data.load_numpy(root / path, size)[None, ...]]
    return gen


def main(argv=None) -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", default="../models")
    ap.add_argument("--data-root", default="data/plantvillage/raw/color")
    ap.add_argument("--split-dir", default="splits")
    ap.add_argument("--calibration-images", type=int, default=300)
    ap.add_argument("--version", default="2.0.0")
    args = ap.parse_args(argv)

    model = keras.models.load_model(args.model, compile=False)
    size = int(model.input_shape[1])
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    variants: dict[str, bytes] = {}
    sm = _saved_model(model, size, Path(tempfile.mkdtemp()) / "saved_model")

    variants["fp32"] = _converter(sm).convert()

    c = _converter(sm)
    c.optimizations = [tf.lite.Optimize.DEFAULT]
    c.target_spec.supported_types = [tf.float16]
    variants["fp16"] = c.convert()

    c = _converter(sm)
    c.optimizations = [tf.lite.Optimize.DEFAULT]
    c.representative_dataset = representative_data(
        data.read_split(Path(args.split_dir), "train"), Path(args.data_root), size,
        args.calibration_images, seed=0)
    c.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    # keep float32 input/output so every variant shares one app-side contract
    c.inference_input_type = tf.float32
    c.inference_output_type = tf.float32
    variants["int8"] = c.convert()

    info = {
        "name": NAME,
        "version": args.version,
        "backbone": model.name.removeprefix("cropdx_"),
        "input": {
            "shape": [1, size, size, 3],
            "dtype": "float32",
            "layout": "NHWC, RGB",
            "range": [0, 255],
            "preprocessing": "center-crop to square, anti-aliased resize to "
                             f"{size}x{size}; normalisation is inside the model",
        },
        "output": {"shape": [1, len(CLASSES)], "dtype": "float32", "activation": "softmax"},
        "labels": CLASSES,
        "variants": {},
    }
    for tag, blob in variants.items():
        fname = f"{NAME}_{tag}.tflite"
        (out / fname).write_bytes(blob)
        info["variants"][tag] = {
            "file": fname,
            "bytes": len(blob),
            "sha256": hashlib.sha256(blob).hexdigest(),
        }
        print(f"{fname:32s} {len(blob) / 1e6:6.2f} MB")

    (out / "labels.txt").write_text("\n".join(CLASSES) + "\n")
    (out / "model_info.json").write_text(json.dumps(info, indent=2) + "\n")
    print(f"wrote labels.txt and model_info.json to {out}/")


if __name__ == "__main__":
    main()
