from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass, fields
from pathlib import Path

import yaml


@dataclass
class Config:
    data_root: str = "data/plantvillage/raw/color"
    split_dir: str = "splits"
    val_fraction: float = 0.15
    test_fraction: float = 0.15
    seed: int = 42
    image_size: int = 224
    batch_size: int = 32
    backbone: str = "mobilenet_v2"
    backbone_weights: str = ""
    dropout: float = 0.25
    label_smoothing: float = 0.1
    head_epochs: int = 5
    head_lr: float = 1e-3
    finetune_epochs: int = 5
    finetune_lr: float = 1e-4
    finetune_unfreeze_fraction: float = 0.3
    class_weighting: bool = True
    output_dir: str = "runs/latest"
    field_train_root: str = ""  # e.g. data/plantdoc: mix PlantDoc *train* photos into training
    field_train_repeat: int = 4  # oversampling factor for the (small) field set
    init_from: str = ""  # continue from a saved .keras model (e.g. head_epochs=0)
    limit: int = 0  # >0: use only this many train/val images (quick smoke tests)

    def to_dict(self) -> dict:
        return asdict(self)


def _coerce(value: str, current):
    if isinstance(current, bool):
        return value.lower() in {"1", "true", "yes", "on"}
    return type(current)(value)


def load_config(argv: list[str] | None = None, extra_args=None) -> tuple[Config, argparse.Namespace]:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="configs/default.yaml")
    parser.add_argument("--set", nargs="*", default=[], metavar="KEY=VALUE",
                        help="override config keys")
    if extra_args:
        extra_args(parser)
    args = parser.parse_args(argv)

    cfg = Config()
    path = Path(args.config)
    if path.exists():
        for k, v in (yaml.safe_load(path.read_text()) or {}).items():
            if k not in {f.name for f in fields(Config)}:
                raise KeyError(f"unknown config key in {path}: {k}")
            setattr(cfg, k, type(getattr(cfg, k))(v) if not isinstance(getattr(cfg, k), bool) else bool(v))
    for item in args.set:
        k, v = item.split("=", 1)
        if not hasattr(cfg, k):
            raise KeyError(f"unknown config key: {k}")
        setattr(cfg, k, _coerce(v, getattr(cfg, k)))
    return cfg, args
