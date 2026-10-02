"""Dataset splitting and tf.data input pipelines.

Preprocessing contract (must match the Flutter and Qt apps exactly):
    1. decode as RGB
    2. center-crop to a square
    3. anti-aliased resize to image_size x image_size
    4. float32 pixel values in [0, 255]  (normalisation happens *inside* the model)
"""
from __future__ import annotations

import csv
import random
from collections import Counter
from pathlib import Path

import numpy as np
import tensorflow as tf

from .labels import CLASSES, INDEX, PLANTDOC, PLANTVILLAGE

AUTOTUNE = tf.data.AUTOTUNE
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp"}


# --------------------------------------------------------------------------- splits
def scan_folder(root: Path, folder_map: dict[str, str]) -> list[tuple[str, str]]:
    """Return (relative_path, class_id) for every image under the mapped folders."""
    items = []
    for folder, cls in folder_map.items():
        d = root / folder
        if not d.is_dir():
            continue
        for p in sorted(d.iterdir()):
            if p.suffix.lower() in IMAGE_EXTS:
                items.append((str(p.relative_to(root)), cls))
    return items


def make_splits(root: Path, out_dir: Path, val_frac: float, test_frac: float, seed: int) -> None:
    """Stratified train/val/test split written as CSVs (path,label)."""
    items = scan_folder(root, PLANTVILLAGE)
    if not items:
        raise FileNotFoundError(f"no PlantVillage tomato folders found under {root}")
    by_class: dict[str, list[str]] = {c: [] for c in CLASSES}
    for path, cls in items:
        by_class[cls].append(path)

    rng = random.Random(seed)
    splits = {"train": [], "val": [], "test": []}
    for cls, paths in by_class.items():
        rng.shuffle(paths)
        n_test = round(len(paths) * test_frac)
        n_val = round(len(paths) * val_frac)
        splits["test"] += [(p, cls) for p in paths[:n_test]]
        splits["val"] += [(p, cls) for p in paths[n_test:n_test + n_val]]
        splits["train"] += [(p, cls) for p in paths[n_test + n_val:]]

    out_dir.mkdir(parents=True, exist_ok=True)
    for name, rows in splits.items():
        with open(out_dir / f"{name}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["path", "label"])
            w.writerows(sorted(rows))


def read_split(split_dir: Path, name: str) -> list[tuple[str, str]]:
    with open(split_dir / f"{name}.csv", newline="") as f:
        return [(r["path"], r["label"]) for r in csv.DictReader(f)]


def class_weights(rows: list[tuple[str, str]]) -> dict[int, float]:
    counts = Counter(lbl for _, lbl in rows)
    total, k = sum(counts.values()), len(CLASSES)
    return {INDEX[c]: total / (k * counts[c]) for c in CLASSES}


# --------------------------------------------------------- field data (PlantDoc)
def dhash(path: Path, size: int = 8) -> int:
    """64-bit difference hash, used to find near-duplicate photos."""
    from PIL import Image
    with Image.open(path) as im:
        g = np.asarray(im.convert("L").resize((size + 1, size), Image.BILINEAR), dtype=np.int16)
    bits = (g[:, 1:] > g[:, :-1]).flatten()
    return int("".join("1" if b else "0" for b in bits), 2)


def plantdoc_rows(root: Path, split: str) -> list[tuple[str, str]]:
    """(absolute path, class) for PlantDoc tomato images of one split (train/test)."""
    return [(str((root / split / p).resolve()), c) for p, c in scan_folder(root / split, PLANTDOC)]


def plantdoc_train_rows(root: Path, max_hamming: int = 6) -> list[tuple[str, str]]:
    """PlantDoc train images minus near-duplicates of any PlantDoc *test* image
    (the dataset was scraped from the web and contains re-posted photos)."""
    test_hashes = []
    for p, _ in plantdoc_rows(root, "test"):
        try:
            test_hashes.append(dhash(Path(p)))
        except OSError:
            pass
    keep, dropped = [], 0
    for p, c in plantdoc_rows(root, "train"):
        try:
            h = dhash(Path(p))
        except OSError:
            dropped += 1  # unreadable file
            continue
        if any(bin(h ^ t).count("1") <= max_hamming for t in test_hashes):
            dropped += 1
            continue
        keep.append((p, c))
    print(f"PlantDoc train: kept {len(keep)}, dropped {dropped} (near-duplicates of test or unreadable)")
    return keep


# ---------------------------------------------------------------- preprocessing
def load_image(path: tf.Tensor, size: int) -> tf.Tensor:
    img = tf.io.decode_image(tf.io.read_file(path), channels=3, expand_animations=False)
    return preprocess(img, size)


def preprocess(img: tf.Tensor, size: int) -> tf.Tensor:
    """uint8 HxWx3 -> float32 size x size x 3 in [0,255] (center crop + AA resize)."""
    h, w = tf.shape(img)[0], tf.shape(img)[1]
    s = tf.minimum(h, w)
    img = tf.image.crop_to_bounding_box(img, (h - s) // 2, (w - s) // 2, s, s)
    img = tf.image.resize(img, (size, size), method="bilinear", antialias=True)
    return tf.clip_by_value(img, 0.0, 255.0)


def augment(img: tf.Tensor, size: int) -> tf.Tensor:
    """Geometric + photometric augmentation that roughly simulates phone captures."""
    img = tf.image.random_flip_left_right(img)
    img = tf.image.random_flip_up_down(img)
    img = tf.image.rot90(img, k=tf.random.uniform([], 0, 4, dtype=tf.int32))
    # random zoom: crop 75–100% of the side and resize back
    scale = tf.random.uniform([], 0.75, 1.0)
    crop = tf.cast(tf.cast(size, tf.float32) * scale, tf.int32)
    img = tf.image.random_crop(img, (crop, crop, 3))
    img = tf.image.resize(img, (size, size), method="bilinear")
    # lighting / white-balance variation
    img = img / 255.0
    img = tf.image.random_brightness(img, 0.2)
    img = tf.image.random_contrast(img, 0.75, 1.25)
    img = tf.image.random_saturation(img, 0.75, 1.25)
    img = tf.image.random_hue(img, 0.04)
    return tf.clip_by_value(img, 0.0, 1.0) * 255.0


def make_dataset(rows, root: Path, size: int, batch: int, training: bool, seed: int = 0) -> tf.data.Dataset:
    paths = [str(root / p) for p, _ in rows]
    labels = [INDEX[l] for _, l in rows]
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if training:
        ds = ds.shuffle(len(paths), seed=seed, reshuffle_each_iteration=True)
    ds = ds.map(lambda p, y: (load_image(p, size), y), num_parallel_calls=AUTOTUNE)
    if training:
        ds = ds.map(lambda x, y: (augment(x, size), y), num_parallel_calls=AUTOTUNE)
    return ds.batch(batch).prefetch(AUTOTUNE)


def load_numpy(path: str | Path, size: int) -> np.ndarray:
    """Single image -> (size,size,3) float32, same contract as the pipeline."""
    return load_image(tf.constant(str(path)), size).numpy().astype(np.float32)
