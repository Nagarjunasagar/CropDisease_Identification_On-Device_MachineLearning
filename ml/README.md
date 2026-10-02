# CroHeal ML pipeline (Keras 3 → LiteRT)

```
cropdx/
├── labels.py     canonical class order + dataset folder mappings
├── config.py     dataclass config, YAML + `--set key=value` overrides
├── data.py       stratified splits, tf.data pipeline, preprocessing contract, augmentation
├── model.py      backbone (MobileNetV2 / V3 / EfficientNet-B0) + GAP/dropout/softmax head
├── train.py      stage 1: frozen backbone · stage 2: fine-tune top 30% (BatchNorm frozen)
├── export.py     LiteRT FP32 / FP16 / INT8 (+ labels.txt, model_info.json with sha256)
├── evaluate.py   lab + field accuracy, macro-F1, confusion matrices, latency, 2018 baseline
└── gradcam.py    attention heatmaps per class
splits/           committed train/val/test CSVs (stratified, seed 42) for reproducibility
tests/            contract tests: labels, preprocessing, exported model I/O, checksums
```

## Run

```bash
pip install -r requirements.txt
scripts/fetch_data.sh                                   # ~650 MB, tomato folders only
python -m cropdx.train                                  # configs/default.yaml
python -m cropdx.train --set backbone=efficientnet_b0 finetune_epochs=10 output_dir=runs/effb0
python -m cropdx.export --model runs/latest/best.keras --out ../models
python -m cropdx.evaluate --models ../models --legacy ../legacy/2018-model/model_unquant.tflite
python -m cropdx.gradcam --model runs/latest/best.keras --out reports/gradcam.png
python -m pytest -q
```

Or open [`notebooks/train_colab.ipynb`](notebooks/train_colab.ipynb) on a free Colab GPU.

## Design notes

- **Normalisation inside the model.** Every exported model takes raw RGB in [0, 255],
  so the apps never need to know which backbone was used.
- **Augmentation simulates phone captures:** flips, 90° rotations, 75–100% random zoom,
  brightness, contrast, saturation and a small hue jitter.
- **Imbalance** (mosaic virus has 373 images, yellow leaf curl 5,357) is handled with
  inverse-frequency class weights.
- **INT8** uses full-integer kernels calibrated on 300 training images, with float32
  input/output so all three variants share one app-side contract.
- **Two test sets.** The PlantVillage test split measures in-distribution accuracy.
  PlantDoc's official *test* split (cluttered field photos, never trained on) measures
  real-world accuracy, reported with 95% Wilson intervals because it has only 69 images.
- **Field mixing.** `field_train_root=data/plantdoc` adds PlantDoc's *train* split
  (oversampled ×4). Train images whose perceptual hash (dHash) is within 6 bits of any
  test image are dropped first: PlantDoc was scraped from the web and contains re-posts.
- **Selective prediction.** `evaluate.py` also reports coverage (how often the "Not sure"
  rule lets the app answer) and accuracy when it does answer.

## Reproducing the shipped model

The shipped `models/` came from two runs (about 2 h in total on a 2-core CPU; much faster on a Colab GPU):

```bash
python -m cropdx.train --set output_dir=runs/lab        # 5 head + 5 fine-tune epochs (top 30%)
python -m cropdx.train --set init_from=runs/lab/best.keras head_epochs=0 finetune_epochs=6 \
    finetune_unfreeze_fraction=0.5 field_train_root=data/plantdoc output_dir=runs/field
python -m cropdx.export --model runs/field/best.keras --out ../models
python scripts/make_golden.py --models ../models        # refresh the C++ parity reference
python -m cropdx.evaluate --models ../models --legacy ../legacy/2018-model/model_unquant.tflite
```

Training logs and configs for both runs are in [`reports/training/`](reports/training/).
