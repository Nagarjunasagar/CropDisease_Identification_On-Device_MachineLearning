#!/usr/bin/env bash
# Copy the shared model artefacts from ../models into the Flutter asset bundle.
# Usage: tool/sync_models.sh [int8|fp16|fp32]   (default: int8)
set -euo pipefail
cd "$(dirname "$0")/.."
variant="${1:-int8}"
src=../models
dst=assets/models
mkdir -p "$dst"
cp "$src/crop_disease_${variant}.tflite" "$dst/crop_disease.tflite"
cp "$src/labels.txt" "$src/disease_info.json" "$src/model_info.json" "$dst/"
echo "synced ${variant} model -> $dst"
