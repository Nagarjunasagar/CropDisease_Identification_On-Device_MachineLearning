# Legacy (2018 M.Tech version)

Kept for reference and for the before/after comparison in the main README.

- `2018-notebooks/`: the original Keras training notebooks (MobileNetV2, InceptionV3,
  ResNet50) and the augmentation script. They use TF1-era APIs (`tensorflow.compat.v1`,
  `ImageDataGenerator`) and hard-coded Windows paths, so they won't run as-is on a
  current TensorFlow. `Model_training_Mobilenetv2_colab.ipynb` is not valid JSON
  (truncated) and can't be opened.
- `2018-model/`: the model the original app shipped (`model_unquant.tflite`, 2.1 MB,
  9 classes, Teachable-Machine-style export, input scaled to [-1, 1]). It is evaluated
  next to the new models by `ml/cropdx/evaluate.py --legacy`.

The original Flutter app (Dart 2, `tflite` 1.1.2 plugin) is in the git history
before the v2 restructure.
