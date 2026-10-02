"""Two-stage transfer-learning training.

    python -m cropdx.train --config configs/default.yaml
    python -m cropdx.train --set backbone=efficientnet_b0 finetune_epochs=10
"""
from __future__ import annotations

import json
import time
from pathlib import Path

import keras
import tensorflow as tf

from . import data
from .config import load_config
from .model import build_model, unfreeze_top


def main(argv=None) -> None:
    cfg, _ = load_config(argv)
    keras.utils.set_random_seed(cfg.seed)
    root, split_dir, out = Path(cfg.data_root), Path(cfg.split_dir), Path(cfg.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    if not (split_dir / "train.csv").exists():
        print(f"creating stratified splits in {split_dir}/")
        data.make_splits(root, split_dir, cfg.val_fraction, cfg.test_fraction, cfg.seed)
    train_rows, val_rows = data.read_split(split_dir, "train"), data.read_split(split_dir, "val")
    if cfg.limit:
        import random
        random.Random(cfg.seed).shuffle(train_rows)
        random.Random(cfg.seed).shuffle(val_rows)
        train_rows, val_rows = train_rows[:cfg.limit], val_rows[:max(cfg.limit // 4, 32)]
    if cfg.field_train_root:
        field = data.plantdoc_train_rows(Path(cfg.field_train_root))
        train_rows = train_rows + field * cfg.field_train_repeat
        print(f"mixed in {len(field)} field photos x{cfg.field_train_repeat}")
    print(f"train={len(train_rows)} val={len(val_rows)}")

    train_ds = data.make_dataset(train_rows, root, cfg.image_size, cfg.batch_size, True, cfg.seed)
    val_ds = data.make_dataset(val_rows, root, cfg.image_size, cfg.batch_size, False)
    cw = data.class_weights(train_rows) if cfg.class_weighting else None

    if cfg.init_from:
        model = keras.models.load_model(cfg.init_from, compile=False)
        base = next(l for l in model.layers if isinstance(l, keras.Model))
        print(f"continuing from {cfg.init_from}")
    else:
        model, base = build_model(cfg.backbone, cfg.image_size, cfg.dropout,
                                  cfg.backbone_weights or None)
    loss = keras.losses.SparseCategoricalCrossentropy()
    if cfg.label_smoothing > 0:
        # label smoothing needs one-hot targets
        n = model.output_shape[-1]
        to_onehot = lambda x, y: (x, tf.one_hot(y, n))
        train_ds, val_ds = train_ds.map(to_onehot), val_ds.map(to_onehot)
        loss = keras.losses.CategoricalCrossentropy(label_smoothing=cfg.label_smoothing)

    best = out / "best.keras"
    callbacks = [
        keras.callbacks.ModelCheckpoint(best, monitor="val_accuracy", save_best_only=True),
        keras.callbacks.CSVLogger(out / "history.csv", append=True),
    ]
    history: dict[str, list] = {}

    def run(stage: str, epochs: int, lr: float, initial_epoch: int) -> int:
        if epochs <= 0:
            return initial_epoch
        model.compile(optimizer=keras.optimizers.AdamW(lr, weight_decay=1e-4),
                      loss=loss, metrics=["accuracy"])
        print(f"\n== {stage}: {epochs} epochs @ lr={lr}")
        t0 = time.time()
        h = model.fit(train_ds, validation_data=val_ds, epochs=initial_epoch + epochs,
                      initial_epoch=initial_epoch, class_weight=cw, callbacks=callbacks)
        print(f"{stage} took {time.time() - t0:.0f}s")
        for k, v in h.history.items():
            history.setdefault(k, []).extend(float(x) for x in v)
        return initial_epoch + epochs

    epoch = run("stage 1 (head)", cfg.head_epochs, cfg.head_lr, 0)
    n = unfreeze_top(base, cfg.finetune_unfreeze_fraction)
    print(f"unfroze {n} backbone layers")
    run("stage 2 (fine-tune)", cfg.finetune_epochs, cfg.finetune_lr, epoch)

    (out / "history.json").write_text(json.dumps(history, indent=2))
    (out / "config.json").write_text(json.dumps(cfg.to_dict(), indent=2))
    print(f"best model: {best}  (val_accuracy={max(history.get('val_accuracy', [0])):.4f})")


if __name__ == "__main__":
    main()
