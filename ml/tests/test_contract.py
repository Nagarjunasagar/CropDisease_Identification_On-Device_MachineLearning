"""Fast checks that keep training, the exported models and both apps in sync.
Run from ml/:  python -m pytest -q
"""
import json
from pathlib import Path

import numpy as np
import pytest
import tensorflow as tf

from cropdx import data
from cropdx.labels import CLASSES, LEGACY_2018, PLANTDOC, PLANTVILLAGE

MODELS = Path(__file__).resolve().parents[2] / "models"


def test_label_maps_cover_canonical_classes():
    assert sorted(PLANTVILLAGE.values()) == sorted(CLASSES)
    assert set(PLANTDOC.values()) <= set(CLASSES)
    assert set(LEGACY_2018) <= set(CLASSES)


def test_exported_labels_match_training_order():
    assert (MODELS / "labels.txt").read_text().split() == CLASSES


def test_disease_guide_covers_every_class():
    guide = json.loads((MODELS / "disease_info.json").read_text())["classes"]
    for c in CLASSES:
        assert guide[c]["name"] and guide[c]["management"], c


def test_preprocess_center_crops_and_keeps_0_255_range():
    img = np.zeros((100, 300, 3), np.uint8)
    img[:, :100, 0] = 255   # red | green | blue thirds
    img[:, 100:200, 1] = 255
    img[:, 200:, 2] = 255
    out = data.preprocess(tf.constant(img), 32).numpy()
    assert out.shape == (32, 32, 3)
    np.testing.assert_allclose(out[16, 16], [0, 255, 0], atol=1e-3)
    assert out.min() >= 0 and out.max() <= 255


@pytest.mark.parametrize("variant", ["fp32", "fp16", "int8"])
def test_tflite_variant_contract(variant):
    from ai_edge_litert.interpreter import Interpreter
    path = MODELS / f"crop_disease_{variant}.tflite"
    if not path.exists():
        pytest.skip(f"{path.name} not exported")
    it = Interpreter(str(path))
    it.allocate_tensors()
    inp, out = it.get_input_details()[0], it.get_output_details()[0]
    assert list(inp["shape"]) == [1, 224, 224, 3] and inp["dtype"] == np.float32
    assert list(out["shape"]) == [1, len(CLASSES)] and out["dtype"] == np.float32
    it.set_tensor(inp["index"], np.full(inp["shape"], 127.0, np.float32))
    it.invoke()
    probs = it.get_tensor(out["index"])[0]
    assert abs(probs.sum() - 1) < 0.02 and (probs >= 0).all()


def test_model_info_checksums():
    import hashlib
    info = json.loads((MODELS / "model_info.json").read_text())
    assert info["labels"] == CLASSES
    for v in info["variants"].values():
        blob = (MODELS / v["file"]).read_bytes()
        assert hashlib.sha256(blob).hexdigest() == v["sha256"]
