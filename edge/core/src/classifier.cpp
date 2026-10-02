#include "cropdx/classifier.hpp"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstring>
#include <fstream>
#include <numeric>
#include <stdexcept>

#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/interpreter_builder.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model_builder.h"

namespace cropdx {
namespace {

using Clock = std::chrono::steady_clock;

double ms_since(Clock::time_point t0) {
  return std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
}

}  // namespace

bool Result::uncertain() const {
  if (scores.empty()) return true;
  const float second = scores.size() > 1 ? scores[1].probability : 0.0f;
  return top().probability < kMinConfidence ||
         top().probability - second < kMinMargin;
}

std::vector<std::string> read_labels(const std::string& path) {
  std::ifstream in(path);
  if (!in) throw std::runtime_error("cannot open labels file '" + path + "'");
  std::vector<std::string> labels;
  for (std::string line; std::getline(in, line);) {
    line.erase(std::remove_if(line.begin(), line.end(),
                              [](unsigned char c) { return std::isspace(c); }),
               line.end());
    if (!line.empty()) labels.push_back(line);
  }
  return labels;
}

Result make_result(const std::vector<float>& probs,
                   const std::vector<std::string>& labels) {
  if (probs.size() != labels.size()) {
    throw std::runtime_error("output/label count mismatch");
  }
  float sum = 0.0f;
  for (float p : probs) sum += std::max(p, 0.0f);
  Result r;
  r.scores.reserve(probs.size());
  for (size_t i = 0; i < probs.size(); ++i) {
    r.scores.push_back({labels[i], sum > 0 ? std::max(probs[i], 0.0f) / sum : 0.0f});
  }
  std::stable_sort(r.scores.begin(), r.scores.end(),
                   [](const Score& a, const Score& b) {
                     return a.probability > b.probability;
                   });
  return r;
}

struct Classifier::Impl {
  std::unique_ptr<tflite::FlatBufferModel> model;
  std::unique_ptr<tflite::Interpreter> interpreter;
  std::vector<std::string> labels;
  std::vector<float> buffer;
  int size = 0;
};

Classifier::Classifier(const std::string& model_path,
                       const std::string& labels_path, Options options)
    : impl_(std::make_unique<Impl>()) {
  impl_->labels = read_labels(labels_path);

  impl_->model = tflite::FlatBufferModel::BuildFromFile(model_path.c_str());
  if (!impl_->model) {
    throw std::runtime_error("cannot load model '" + model_path + "'");
  }
  // The builtin resolver applies the XNNPACK delegate by default, which gives
  // fast float and int8 kernels on x86 and ARM.
  tflite::ops::builtin::BuiltinOpResolver resolver;
  tflite::InterpreterBuilder builder(*impl_->model, resolver);
  builder.SetNumThreads(std::max(1, options.threads));
  if (builder(&impl_->interpreter) != kTfLiteOk || !impl_->interpreter) {
    throw std::runtime_error("cannot build interpreter");
  }
  if (impl_->interpreter->AllocateTensors() != kTfLiteOk) {
    throw std::runtime_error("cannot allocate tensors");
  }

  const TfLiteTensor* in = impl_->interpreter->input_tensor(0);
  if (in->type != kTfLiteFloat32 || in->dims->size != 4 ||
      in->dims->data[1] != in->dims->data[2] || in->dims->data[3] != 3) {
    throw std::runtime_error("model input must be float32 [1,N,N,3]");
  }
  impl_->size = in->dims->data[1];

  const TfLiteTensor* out = impl_->interpreter->output_tensor(0);
  const int classes = out->dims->data[out->dims->size - 1];
  if (out->type != kTfLiteFloat32 ||
      classes != static_cast<int>(impl_->labels.size())) {
    throw std::runtime_error("model has " + std::to_string(classes) +
                             " float outputs but labels file has " +
                             std::to_string(impl_->labels.size()));
  }
  impl_->buffer.resize(static_cast<size_t>(impl_->size) * impl_->size * 3);
}

Classifier::~Classifier() = default;

int Classifier::input_size() const { return impl_->size; }

const std::vector<std::string>& Classifier::labels() const {
  return impl_->labels;
}

std::vector<float> Classifier::run(const float* input) {
  float* dst = impl_->interpreter->typed_input_tensor<float>(0);
  std::memcpy(dst, input, impl_->buffer.size() * sizeof(float));
  if (impl_->interpreter->Invoke() != kTfLiteOk) {
    throw std::runtime_error("inference failed");
  }
  const float* out = impl_->interpreter->typed_output_tensor<float>(0);
  return {out, out + impl_->labels.size()};
}

Result Classifier::classify(const std::uint8_t* rgb, int width, int height,
                            int stride) {
  auto t0 = Clock::now();
  preprocess(rgb, width, height, stride, impl_->size, impl_->buffer.data());
  const double pre_ms = ms_since(t0);

  t0 = Clock::now();
  std::vector<float> probs = run(impl_->buffer.data());
  const double inf_ms = ms_since(t0);

  Result r = make_result(probs, impl_->labels);
  r.preprocess_ms = pre_ms;
  r.inference_ms = inf_ms;
  return r;
}

}  // namespace cropdx
