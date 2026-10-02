#!/usr/bin/env bash
# Downloads only the tomato folders of both datasets (sparse git checkout):
#   PlantVillage (lab photos, ~18k images, training)
#   PlantDoc     (field photos, ~750 images, test only)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data && cd data

if [ ! -d plantvillage ]; then
  git clone --depth 1 --filter=blob:none --sparse https://github.com/spMohanty/PlantVillage-Dataset.git plantvillage
  git -C plantvillage sparse-checkout set --no-cone '/raw/color/Tomato*'
fi
if [ ! -d plantdoc ]; then
  git clone --depth 1 --filter=blob:none --sparse https://github.com/pratikkayal/PlantDoc-Dataset.git plantdoc
  git -C plantdoc sparse-checkout set --no-cone '/train/Tomato*' '/test/Tomato*'
fi
echo "PlantVillage tomato images: $(find plantvillage/raw/color -type f | wc -l)"
echo "PlantDoc tomato images:     $(find plantdoc -path '*Tomato*' -type f | wc -l)"
