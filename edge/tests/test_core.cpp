// Minimal self-contained tests (no external framework needed on the device).
//   test_core                         -> unit tests only
//   test_core MODEL LABELS GOLDEN.txt -> also checks parity with Python/LiteRT

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <functional>
#include <sstream>
#include <string>
#include <vector>

#include "cropdx/classifier.hpp"

namespace {

int g_failed = 0, g_passed = 0;

#define CHECK(cond)                                                        \
  do {                                                                     \
    if (cond) { ++g_passed; }                                              \
    else { ++g_failed; std::printf("  FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond); } \
  } while (0)

void run(const char* name, const std::function<void()>& fn) {
  std::printf("[ RUN  ] %s\n", name);
  const int before = g_failed;
  try { fn(); } catch (const std::exception& e) {
    ++g_failed;
    std::printf("  EXCEPTION %s\n", e.what());
  }
  std::printf("[ %s ] %s\n", g_failed == before ? " OK " : "FAIL", name);
}

cropdx::Image stripes(int w, int h) {
  // left third red, middle green, right blue
  cropdx::Image img{w, h, std::vector<std::uint8_t>(static_cast<size_t>(w) * h * 3, 0)};
  for (int y = 0; y < h; ++y)
    for (int x = 0; x < w; ++x)
      img.rgb[(static_cast<size_t>(y) * w + x) * 3 + (x * 3 / w)] = 255;
  return img;
}

}  // namespace

int main(int argc, char** argv) {
  run("make_result sorts and normalises", [] {
    auto r = cropdx::make_result({0.0f, 0.8f, 0.4f}, {"a", "b", "c"});
    CHECK(r.top().label == "b");
    CHECK(r.scores[1].label == "c");
    CHECK(std::fabs(r.top().probability - 0.8f / 1.2f) < 1e-6f);
  });

  run("uncertainty rule matches the mobile app", [] {
    CHECK(!cropdx::make_result({0.05f, 0.9f, 0.05f}, {"a", "b", "c"}).uncertain());
    CHECK(cropdx::make_result({0.3f, 0.4f, 0.3f}, {"a", "b", "c"}).uncertain());
    CHECK(cropdx::make_result({0.0f, 0.56f, 0.44f}, {"a", "b", "c"}).uncertain());
  });

  run("preprocess center-crops and resizes", [] {
    const auto img = stripes(300, 100);
    std::vector<float> t(32 * 32 * 3);
    cropdx::preprocess(img, 32, t.data());
    const size_t c = (16 * 32 + 16) * 3;
    CHECK(t[c] == 0.0f && t[c + 1] == 255.0f && t[c + 2] == 0.0f);  // pure green
    float lo = 255, hi = 0;
    for (float v : t) { lo = std::min(lo, v); hi = std::max(hi, v); }
    CHECK(lo >= 0.0f && hi <= 255.0f);
  });

  run("preprocess honours row stride", [] {
    const auto img = stripes(120, 90);
    const int stride = 120 * 3 + 16;  // padded rows, like QImage
    std::vector<std::uint8_t> padded(static_cast<size_t>(stride) * 90, 7);
    for (int y = 0; y < 90; ++y)
      std::copy_n(&img.rgb[static_cast<size_t>(y) * 120 * 3], 120 * 3, &padded[static_cast<size_t>(y) * stride]);
    std::vector<float> a(24 * 24 * 3), b(24 * 24 * 3);
    cropdx::preprocess(img, 24, a.data());
    cropdx::preprocess(padded.data(), 120, 90, stride, 24, b.data());
    CHECK(a == b);
  });

  run("labels file must exist", [] {
    bool threw = false;
    try { cropdx::read_labels("/nonexistent/labels.txt"); } catch (const std::runtime_error&) { threw = true; }
    CHECK(threw);
  });

  if (argc >= 4) {
    // golden file: line 1 = image path, line 2 = top-1 label, line 3 = probabilities
    run("parity with Python LiteRT reference", [&] {
      std::ifstream g(argv[3]);
      std::string image, label, probs_line;
      std::getline(g, image);
      std::getline(g, label);
      std::getline(g, probs_line);
      std::vector<float> ref;
      std::istringstream ss(probs_line);
      for (float p; ss >> p;) ref.push_back(p);

      cropdx::Classifier clf(argv[1], argv[2], {2});
      CHECK(clf.input_size() == 224);
      CHECK(clf.labels().size() == ref.size());
      auto r = clf.classify(cropdx::load_image(image));
      CHECK(r.top().label == label);

      // compare per-label probabilities (C++ uses stb's triangle filter, TF its
      // own: tiny pixel differences are expected, label and scores must agree)
      float max_diff = 0;
      for (const auto& s : r.scores) {
        for (size_t i = 0; i < clf.labels().size(); ++i)
          if (clf.labels()[i] == s.label)
            max_diff = std::max(max_diff, std::fabs(s.probability - ref[i]));
      }
      std::printf("  top-1 %s %.4f, max |p_cpp - p_python| = %.4f\n",
                  r.top().label.c_str(), r.top().probability, max_diff);
      CHECK(max_diff < 0.03f);
    });
  }

  std::printf("\n%d checks passed, %d failed\n", g_passed, g_failed);
  return g_failed ? 1 : 0;
}
