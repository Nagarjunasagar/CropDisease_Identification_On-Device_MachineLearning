"""Canonical class list shared by training, both apps and the model card.

The order here *is* the model's output order. `models/labels.txt` is generated
from it by `export.py`, and the Flutter and Qt apps read that file, so never
reorder without re-exporting.
"""

CLASSES: list[str] = [
    "bacterial_spot",
    "early_blight",
    "healthy",
    "late_blight",
    "leaf_mold",
    "mosaic_virus",
    "septoria_leaf_spot",
    "spider_mites",
    "target_spot",
    "yellow_leaf_curl_virus",
]

# PlantVillage folder name -> canonical id (training / lab-condition test set)
PLANTVILLAGE: dict[str, str] = {
    "Tomato___Bacterial_spot": "bacterial_spot",
    "Tomato___Early_blight": "early_blight",
    "Tomato___healthy": "healthy",
    "Tomato___Late_blight": "late_blight",
    "Tomato___Leaf_Mold": "leaf_mold",
    "Tomato___Tomato_mosaic_virus": "mosaic_virus",
    "Tomato___Septoria_leaf_spot": "septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite": "spider_mites",
    "Tomato___Target_Spot": "target_spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "yellow_leaf_curl_virus",
}

# PlantDoc folder name -> canonical id (field-condition test set, never trained on)
PLANTDOC: dict[str, str] = {
    "Tomato leaf bacterial spot": "bacterial_spot",
    "Tomato Early blight leaf": "early_blight",
    "Tomato leaf": "healthy",
    "Tomato leaf late blight": "late_blight",
    "Tomato mold leaf": "leaf_mold",
    "Tomato leaf mosaic virus": "mosaic_virus",
    "Tomato Septoria leaf spot": "septoria_leaf_spot",
    "Tomato two spotted spider mites leaf": "spider_mites",
    "Tomato leaf yellow virus": "yellow_leaf_curl_virus",
}

# 2018 model (Teachable Machine export, 9 classes, no bacterial spot) -> canonical id
LEGACY_2018: list[str] = [
    "healthy",
    "late_blight",
    "early_blight",
    "leaf_mold",
    "mosaic_virus",
    "septoria_leaf_spot",
    "spider_mites",
    "target_spot",
    "yellow_leaf_curl_virus",
]

INDEX = {name: i for i, name in enumerate(CLASSES)}
