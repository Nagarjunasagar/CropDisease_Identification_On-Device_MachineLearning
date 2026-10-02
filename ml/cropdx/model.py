"""Model definition: ImageNet backbone + light classification head.

Input is raw RGB in [0, 255]. Backbone-specific normalisation lives inside the
graph, so every exported .tflite has the same input contract regardless of the
backbone, and the apps never need to know which one was used.
"""
from __future__ import annotations

import keras
from keras import layers

from .labels import CLASSES


def _backbone(name: str, size: int, weights: str | None):
    shape = (size, size, 3)
    w = weights or "imagenet"
    if name == "mobilenet_v2":
        base = keras.applications.MobileNetV2(input_shape=shape, include_top=False, weights=w)
        norm = layers.Rescaling(1.0 / 127.5, offset=-1.0, name="normalize")  # -> [-1, 1]
    elif name == "mobilenet_v3_large":
        base = keras.applications.MobileNetV3Large(input_shape=shape, include_top=False, weights=w,
                                                   include_preprocessing=True)
        norm = None  # built-in preprocessing expects [0, 255]
    elif name == "mobilenet_v3_small":
        base = keras.applications.MobileNetV3Small(input_shape=shape, include_top=False, weights=w,
                                                   include_preprocessing=True)
        norm = None
    elif name == "efficientnet_b0":
        base = keras.applications.EfficientNetB0(input_shape=shape, include_top=False, weights=w)
        norm = None  # EfficientNet includes its own rescaling, expects [0, 255]
    else:
        raise ValueError(f"unknown backbone: {name}")
    return base, norm


def build_model(backbone: str, size: int, dropout: float, weights: str | None = None):
    base, norm = _backbone(backbone, size, weights)
    base.trainable = False

    inputs = keras.Input((size, size, 3), name="image")  # float32 RGB [0,255]
    x = norm(inputs) if norm is not None else inputs
    x = base(x, training=False)  # keep BatchNorm in inference mode even when fine-tuning
    x = layers.GlobalAveragePooling2D(name="pool")(x)
    x = layers.Dropout(dropout, name="dropout")(x)
    outputs = layers.Dense(len(CLASSES), activation="softmax", name="probs")(x)
    return keras.Model(inputs, outputs, name=f"cropdx_{backbone}"), base


def unfreeze_top(base: keras.Model, fraction: float) -> int:
    """Unfreeze the top `fraction` of backbone layers, keeping BatchNorm frozen."""
    base.trainable = True
    cut = int(len(base.layers) * (1.0 - fraction))
    n = 0
    for i, layer in enumerate(base.layers):
        trainable = i >= cut and not isinstance(layer, layers.BatchNormalization)
        layer.trainable = trainable
        n += int(trainable)
    return n
