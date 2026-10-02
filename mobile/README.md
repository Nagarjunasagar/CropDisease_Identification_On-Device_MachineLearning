# CroHeal mobile (Flutter 3 · Dart 3 · LiteRT)

Offline tomato leaf disease identification for Android and iOS.

## Setup

```bash
cd mobile
tool/bootstrap.sh        # or tool\bootstrap.ps1 on Windows
flutter run
```

`bootstrap` runs `flutter create` to generate the `android/` and `ios/` folders for
your installed Flutter SDK (existing `lib/` and `test/` files are not touched), adds
the iOS camera/photo permission strings, and copies the INT8 model from `../models`
into `assets/models/`. Commit the generated platform folders afterwards.
Use `MODEL_VARIANT=fp16 tool/bootstrap.sh` to bundle the FP16 model instead.

## Structure

```
lib/
├── main.dart                      Material 3 app, light/dark
└── src/
    ├── inference/
    │   ├── preprocess.dart        centre crop + anti-aliased resize (pure Dart, unit-tested)
    │   ├── classifier.dart        LiteRT interpreter; decode + inference in a background isolate
    │   └── prediction.dart        top-k, re-normalisation, "Not sure" rule
    ├── data/
    │   ├── disease_catalog.dart   symptoms / what to do (assets/models/disease_info.json)
    │   └── history_repository.dart  on-device scan history (JSON index + preview JPEGs)
    ├── providers.dart             Riverpod providers
    └── features/                  home, result, history, about screens
```

## Behaviour

- Photos are picked with `image_picker` (camera or gallery), downscaled to at most
  1600 px, then decoded, EXIF-rotated, cropped and resized **off the UI thread**.
- A result is shown as **"Not sure"** when the top probability is below 55% or the
  runner-up is within 15 points. The user is asked to retake the photo and the closest
  matches are still listed.
- Nothing leaves the device. History is stored in the app's documents folder and can
  be cleared from the History screen.

## Tests

```bash
flutter test     # preprocessing, prediction rules, history storage, assets ↔ labels, widgets
```
