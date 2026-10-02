#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace cropdx {

/// Tightly packed 8-bit RGB image.
struct Image {
  int width = 0;
  int height = 0;
  std::vector<std::uint8_t> rgb;  // width * height * 3

  bool empty() const { return width <= 0 || height <= 0 || rgb.empty(); }
};

/// Decodes JPEG/PNG/BMP from disk. Throws std::runtime_error on failure.
Image load_image(const std::string& path);

/// Preprocessing contract shared with training (ml/cropdx/data.py) and the
/// Flutter app (mobile/lib/src/inference/preprocess.dart):
///
///   center-crop to a square -> anti-aliased (triangle-filter) resize to
///   size x size -> float32 RGB in [0, 255], NHWC.
///
/// `stride` is the number of bytes per input row (supports padded buffers such
/// as QImage scanlines). `out` must hold size * size * 3 floats.
void preprocess(const std::uint8_t* rgb, int width, int height, int stride,
                int size, float* out);

inline void preprocess(const Image& img, int size, float* out) {
  preprocess(img.rgb.data(), img.width, img.height, img.width * 3, size, out);
}

}  // namespace cropdx
