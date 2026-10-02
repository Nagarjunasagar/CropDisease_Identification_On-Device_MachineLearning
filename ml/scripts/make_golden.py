"""Regenerate the C++ parity reference after re-exporting the models.

    python scripts/make_golden.py --models ../models --image ../edge/tests/data/leaf.jpg

Writes edge/tests/data/golden_int8.txt: image name, top-1 label, probabilities
(label order) computed with the Python LiteRT interpreter.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from ai_edge_litert.interpreter import Interpreter

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cropdx import data  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--models", default="../models")
ap.add_argument("--image", default="../edge/tests/data/leaf.jpg")
ap.add_argument("--variant", default="int8")
args = ap.parse_args()

models = Path(args.models)
labels = (models / "labels.txt").read_text().split()
it = Interpreter(str(models / f"crop_disease_{args.variant}.tflite"))
it.allocate_tensors()
x = data.load_numpy(args.image, 224)[None]
it.set_tensor(it.get_input_details()[0]["index"], x)
it.invoke()
probs = it.get_tensor(it.get_output_details()[0]["index"])[0]
out = Path(args.image).parent / f"golden_{args.variant}.txt"
out.write_text(f"{Path(args.image).name}\n{labels[int(np.argmax(probs))]}\n"
               + " ".join(f"{p:.6f}" for p in probs) + "\n")
print(out.read_text())
