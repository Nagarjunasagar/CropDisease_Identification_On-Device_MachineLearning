#pragma once

#include <memory>
#include <string>
#include <vector>

#include "cropdx/image.hpp"

namespace cropdx {

struct Score {
  std::string label;
  float probability = 0.0f;
};

struct Result {
  std::vector<Score> scores;  // sorted, highest first
  double preprocess_ms = 0.0;
  double inference_ms = 0.0;

  /// Same rule as the mobile app: low top-1 or a close runner-up.
  static constexpr float kMinConfidence = 0.55f;
  static constexpr float kMinMargin = 0.15f;

  const Score& top() const { return scores.front(); }
  bool uncertain() const;
};

struct Options {
  int threads = 2;
};

/// LiteRT (TensorFlow Lite) image classifier. Not thread-safe: use one
/// instance per thread (the Qt app owns it on a worker thread).
class Classifier {
 public:
  /// Throws std::runtime_error if the model or labels cannot be loaded or
  /// do not match the expected input/output contract.
  Classifier(const std::string& model_path, const std::string& labels_path,
             Options options = {});
  ~Classifier();
  Classifier(const Classifier&) = delete;
  Classifier& operator=(const Classifier&) = delete;

  /// Classifies an RGB buffer of any size (see preprocess() for the contract).
  Result classify(const std::uint8_t* rgb, int width, int height, int stride);
  Result classify(const Image& img) {
    return classify(img.rgb.data(), img.width, img.height, img.width * 3);
  }

  /// Runs the model on an already-preprocessed size*size*3 float tensor.
  std::vector<float> run(const float* input);

  int input_size() const;
  const std::vector<std::string>& labels() const;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

/// Reads one label per line, ignoring blank lines.
std::vector<std::string> read_labels(const std::string& path);

/// Turns raw probabilities into a sorted Result (re-normalised).
Result make_result(const std::vector<float>& probs,
                   const std::vector<std::string>& labels);

}  // namespace cropdx
