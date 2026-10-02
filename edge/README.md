# CroHeal Edge (C++17 · Qt 6 / QML · LiteRT)

The same model as the mobile app, running on a Linux edge box (Raspberry Pi 5,
Jetson, industrial PC) with a live camera feed.

```
edge/
├── core/      libcropdx_core: preprocessing + LiteRT classifier (no Qt dependency)
├── cli/       cropdx-cli: batch classification and latency benchmark
├── app/       cropdx-app: Qt 6 / QML UI, camera → worker thread → smoothed result
├── tests/     unit tests + parity test against the Python reference
└── cmake/     LiteRT.cmake: builds the LiteRT runtime from TensorFlow source
```

## Design

- **Core library without Qt.** `cropdx_core` depends only on LiteRT and stb, so it
  can be reused in a ROS 2 node, a GStreamer element or a headless service.
- **Inference off the UI thread.** `InferenceWorker` owns the interpreter on a
  dedicated `QThread`. `LeafAnalyzer` drops camera frames while one is in flight,
  which gives natural back-pressure instead of a growing queue.
- **Temporal smoothing.** In live mode the class probabilities are smoothed with an
  exponential moving average (newest frame weighted 0.35), so the label doesn't flicker.
- **What-the-model-sees overlay.** The UI draws the centre-square crop that is fed
  to the network, so users frame the leaf correctly.
- **Single preprocessing contract** (centre crop → anti-aliased resize → float
  RGB 0–255) shared with training and the Flutter app, and checked by a parity
  test against Python LiteRT output.

## Build (Ubuntu 24.04 / Raspberry Pi OS Bookworm 64-bit)

```bash
sudo apt install build-essential cmake ninja-build git \
  qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtquick-dialogs qml6-module-qtmultimedia qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript qml6-module-qtquick-templates qml6-module-qtcore

cmake -S edge -B edge/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5     # fetches LiteRT source; the flag is needed on CMake 4.x
cmake --build edge/build
ctest --test-dir edge/build --output-on-failure
```

The first build compiles LiteRT and XNNPACK from source. That takes about 15 minutes
on an 8-core PC and roughly an hour natively on a Raspberry Pi 5; later builds are
incremental. To reuse an existing TensorFlow checkout, pass
`-DCROPDX_TF_SOURCE_DIR=/path/to/tensorflow`. Without Qt, add
`-DCROPDX_BUILD_APP=OFF` to build only the core, CLI and tests.

## Run

```bash
# GUI: live camera (if present) or open a photo
edge/build/app/cropdx-app
edge/build/app/cropdx-app --image leaf.jpg --threads 4
edge/build/app/cropdx-app --model models/crop_disease_fp16.tflite   # try another variant

# CLI
edge/build/cli/cropdx-cli --model models/crop_disease_int8.tflite --labels models/labels.txt leaf.jpg
edge/build/cli/cropdx-cli --model models/crop_disease_int8.tflite --labels models/labels.txt --bench 200 leaf.jpg
edge/build/cli/cropdx-cli --model models/crop_disease_int8.tflite --labels models/labels.txt --json photos/

# headless screenshot (CI / docs)
QT_QPA_PLATFORM=offscreen edge/build/app/cropdx-app --image leaf.jpg --screenshot ui.png
```

The app looks for `models/` next to the binary, then up the directory tree, then in
`$CROPDX_MODELS`.
