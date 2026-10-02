// cropdx-cli: classify images or benchmark the model from the command line.
//
//   cropdx-cli --model models/crop_disease_int8.tflite --labels models/labels.txt leaf.jpg
//   cropdx-cli --model ... --labels ... --bench 200 --threads 4 leaf.jpg
//   cropdx-cli --model ... --labels ... --json dir/with/images/
//   cropdx-cli --model ... --labels ... --dump-input leaf.jpg > tensor.f32

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

#include "cropdx/classifier.hpp"

namespace fs = std::filesystem;

namespace {

void usage() {
  std::cerr <<
      "usage: cropdx-cli --model FILE --labels FILE [options] IMAGE|DIR...\n"
      "  --threads N     interpreter threads (default 2)\n"
      "  --top K         scores to print per image (default 3)\n"
      "  --bench N       time N inferences on the first image\n"
      "  --json          one JSON object per line\n"
      "  --dump-input    write the preprocessed float32 tensor to stdout\n";
}

std::string json_escape(const std::string& s) {
  std::string o;
  for (char c : s) {
    if (c == '"' || c == '\\') o += '\\';
    o += c;
  }
  return o;
}

bool is_image(const fs::path& p) {
  std::string e = p.extension().string();
  std::transform(e.begin(), e.end(), e.begin(), ::tolower);
  return e == ".jpg" || e == ".jpeg" || e == ".png" || e == ".bmp";
}

double percentile(std::vector<double> v, double q) {
  std::sort(v.begin(), v.end());
  return v[static_cast<size_t>(q * (v.size() - 1))];
}

}  // namespace

int main(int argc, char** argv) {
  std::string model, labels;
  int threads = 2, top = 3, bench = 0;
  bool json = false, dump = false;
  std::vector<fs::path> inputs;

  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    auto next = [&]() -> std::string {
      if (i + 1 >= argc) { usage(); std::exit(2); }
      return argv[++i];
    };
    if (a == "--model") model = next();
    else if (a == "--labels") labels = next();
    else if (a == "--threads") threads = std::stoi(next());
    else if (a == "--top") top = std::stoi(next());
    else if (a == "--bench") bench = std::stoi(next());
    else if (a == "--json") json = true;
    else if (a == "--dump-input") dump = true;
    else if (a == "-h" || a == "--help") { usage(); return 0; }
    else if (a.rfind("--", 0) == 0) { usage(); return 2; }
    else {
      fs::path p(a);
      if (fs::is_directory(p)) {
        std::vector<fs::path> files;
        for (auto& e : fs::recursive_directory_iterator(p))
          if (e.is_regular_file() && is_image(e.path())) files.push_back(e.path());
        std::sort(files.begin(), files.end());
        inputs.insert(inputs.end(), files.begin(), files.end());
      } else {
        inputs.push_back(p);
      }
    }
  }
  if (model.empty() || labels.empty() || inputs.empty()) { usage(); return 2; }

  try {
    cropdx::Classifier clf(model, labels, {threads});

    if (dump) {
      const int n = clf.input_size();
      std::vector<float> t(static_cast<size_t>(n) * n * 3);
      cropdx::preprocess(cropdx::load_image(inputs.front().string()), n, t.data());
      std::fwrite(t.data(), sizeof(float), t.size(), stdout);
      return 0;
    }

    if (bench > 0) {
      const auto img = cropdx::load_image(inputs.front().string());
      for (int i = 0; i < 10; ++i) clf.classify(img);  // warm-up
      std::vector<double> pre, inf;
      for (int i = 0; i < bench; ++i) {
        auto r = clf.classify(img);
        pre.push_back(r.preprocess_ms);
        inf.push_back(r.inference_ms);
      }
      const double mean = std::accumulate(inf.begin(), inf.end(), 0.0) / inf.size();
      std::printf(
          "model=%s threads=%d runs=%d input=%dx%d\n"
          "inference ms: mean %.2f  p50 %.2f  p95 %.2f  min %.2f\n"
          "preprocess ms (from %dx%d): p50 %.2f\n"
          "throughput: %.1f img/s (inference only)\n",
          fs::path(model).filename().c_str(), threads, bench, clf.input_size(),
          clf.input_size(), mean, percentile(inf, 0.5), percentile(inf, 0.95),
          percentile(inf, 0.0), img.width, img.height, percentile(pre, 0.5),
          1000.0 / mean);
      return 0;
    }

    int failures = 0;
    for (const auto& path : inputs) {
      try {
        auto r = clf.classify(cropdx::load_image(path.string()));
        const int k = std::min<int>(top, static_cast<int>(r.scores.size()));
        if (json) {
          std::cout << "{\"image\":\"" << json_escape(path.string()) << "\",\"uncertain\":"
                    << (r.uncertain() ? "true" : "false") << ",\"inference_ms\":"
                    << r.inference_ms << ",\"scores\":[";
          for (int i = 0; i < k; ++i)
            std::cout << (i ? "," : "") << "{\"label\":\"" << r.scores[i].label
                      << "\",\"p\":" << r.scores[i].probability << "}";
          std::cout << "]}\n";
        } else {
          std::printf("%s\n", path.string().c_str());
          for (int i = 0; i < k; ++i)
            std::printf("  %-24s %6.2f%%\n", r.scores[i].label.c_str(),
                        100.0 * r.scores[i].probability);
          std::printf("  %s  (%.1f ms inference, %.1f ms preprocess)\n",
                      r.uncertain() ? "UNCERTAIN" : "confident", r.inference_ms,
                      r.preprocess_ms);
        }
      } catch (const std::exception& e) {
        ++failures;
        std::cerr << path << ": " << e.what() << "\n";
      }
    }
    return failures ? 1 : 0;
  } catch (const std::exception& e) {
    std::cerr << "error: " << e.what() << "\n";
    return 1;
  }
}
