# Model card: CroHeal tomato leaf classifier v2.0.0

## Files

| File | Precision | Size | sha256 |
|---|---|---|---|
| `crop_disease_fp32.tflite` | FP32 | 8.94 MB | `926f603179a8ee36…` |
| `crop_disease_fp16.tflite` | FP16 | 4.54 MB | `8d0753d8f4a391f8…` |
| `crop_disease_int8.tflite` | INT8 | 2.75 MB | `4076a03c0a752cc1…` |

`labels.txt` lists the output order, `disease_info.json` holds the user-facing guidance, and
`model_info.json` holds the input contract and full checksums. Both apps ship **INT8**.

## Contract

- **Input:** `float32 [1, 224, 224, 3]`, RGB, values **0–255**. Centre-crop to a square, then an
  anti-aliased resize. Normalisation is inside the graph.
- **Output:** `float32 [1, 10]` softmax probabilities in `labels.txt` order.
- **"Not sure" rule** (both apps): top-1 < 0.55 or (top-1 − top-2) < 0.15.

## Training

- MobileNetV2 (ImageNet weights) + global average pooling + dropout 0.25 + dense softmax.
- Stage 1: frozen backbone, 5 epochs. Stage 2: top 30% unfrozen, 5 epochs. Stage 3: top 50%
  unfrozen, 6 epochs with PlantDoc train photos mixed in (×4). BatchNorm frozen throughout.
- AdamW, label smoothing 0.1, inverse-frequency class weights, flip/rotate/zoom/colour augmentation.
- Data: PlantVillage tomato (12,710 train / 2,725 val / 2,725 test, stratified, seed 42) and
  PlantDoc tomato *train* (672 photos after removing near-duplicates of its test split).

## Evaluation (INT8)

| | Lab (PlantVillage test) | Field (PlantDoc test) |
|---|---|---|
| Accuracy | 96.8% | 52.2% (95% CI 41%–64%) |
| Macro-F1 | 0.964 | 0.518 |
| Answers (not "Not sure") | 96% | 59% |
| Accuracy when it answers | 98.6% | 73.2% |

Per-class recall:

| Class | Lab recall | Lab n | Field recall | Field n |
|---|---|---|---|---|
| bacterial spot | 96.9% | 319 | 22% | 9 |
| early blight | 91.3% | 150 | 67% | 9 |
| healthy | 100.0% | 239 | 62% | 8 |
| late blight | 95.5% | 286 | 60% | 10 |
| leaf mold | 95.8% | 143 | 67% | 6 |
| mosaic virus | 98.2% | 56 | 20% | 10 |
| septoria leaf spot | 96.6% | 266 | 82% | 11 |
| spider mites | 98.4% | 251 | n/a | 0 |
| target spot | 97.6% | 211 | n/a | 0 |
| yellow leaf curl virus | 96.9% | 804 | 33% | 6 |

## Intended use and limitations

- A first opinion for growers and extension workers on **single tomato leaves**. It is not a
  diagnosis. The guidance text tells users to confirm with a local agricultural extension service.
- Field accuracy is far below lab accuracy. Expect errors between look-alike spot diseases, and
  for photos with several leaves, fruit, stems or heavy shadow.
- Any image produces an answer: non-tomato or non-leaf photos are only partly caught by the
  "Not sure" rule.
- Field evaluation uses 69 images, so per-class field numbers are noisy.
