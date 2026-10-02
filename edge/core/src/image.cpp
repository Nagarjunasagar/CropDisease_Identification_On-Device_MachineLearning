#include "cropdx/image.hpp"

#include <algorithm>
#include <stdexcept>

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_JPEG
#define STBI_ONLY_PNG
#define STBI_ONLY_BMP
#include "stb_image.h"

#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize2.h"

namespace cropdx {

Image load_image(const std::string& path) {
  int w = 0, h = 0, channels = 0;
  stbi_uc* data = stbi_load(path.c_str(), &w, &h, &channels, 3);
  if (!data) {
    throw std::runtime_error("cannot decode image '" + path +
                             "': " + stbi_failure_reason());
  }
  Image img;
  img.width = w;
  img.height = h;
  img.rgb.assign(data, data + static_cast<size_t>(w) * h * 3);
  stbi_image_free(data);
  return img;
}

void preprocess(const std::uint8_t* rgb, int width, int height, int stride,
                int size, float* out) {
  if (!rgb || width <= 0 || height <= 0 || size <= 0) {
    throw std::invalid_argument("preprocess: empty input");
  }
  // 1. center crop to a square (no copy: offset the pointer, keep the stride)
  const int side = std::min(width, height);
  const std::uint8_t* crop =
      rgb + static_cast<size_t>((height - side) / 2) * stride +
      static_cast<size_t>((width - side) / 2) * 3;

  // 2. anti-aliased resize. A triangle filter scaled to the downsampling
  //    factor is what tf.image.resize(bilinear, antialias=True) uses.
  std::vector<std::uint8_t> resized(static_cast<size_t>(size) * size * 3);
  STBIR_RESIZE r;
  stbir_resize_init(&r, crop, side, side, stride, resized.data(), size, size,
                    size * 3, STBIR_RGB, STBIR_TYPE_UINT8);
  stbir_set_filters(&r, STBIR_FILTER_TRIANGLE, STBIR_FILTER_TRIANGLE);
  stbir_set_edgemodes(&r, STBIR_EDGE_CLAMP, STBIR_EDGE_CLAMP);
  if (!stbir_resize_extended(&r)) {
    throw std::runtime_error("preprocess: resize failed");
  }

  // 3. float32 [0, 255]; normalisation is part of the model graph
  std::transform(resized.begin(), resized.end(), out,
                 [](std::uint8_t v) { return static_cast<float>(v); });
}

}  // namespace cropdx
