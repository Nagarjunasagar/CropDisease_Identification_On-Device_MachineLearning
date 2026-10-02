#!/usr/bin/env bash
# One-time setup: generates the android/ and ios/ platform folders with the
# current Flutter SDK (they are not committed by hand), adds the photo/camera
# permission strings, and syncs the model. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --platforms=android,ios --org com.nagarjunasagar --project-name croheal \
  --description "On-device tomato leaf disease identification" >/dev/null

# iOS: image_picker needs usage descriptions
plist=ios/Runner/Info.plist
if [ -f "$plist" ] && ! grep -q NSCameraUsageDescription "$plist"; then
  perl -0pi -e 's#</dict>\s*</plist>#\t<key>NSCameraUsageDescription</key>\n\t<string>Take a photo of a leaf to check it for disease.</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>Choose a leaf photo to check it for disease.</string>\n</dict>\n</plist>#' "$plist"
fi

# Android: friendly app label
manifest=android/app/src/main/AndroidManifest.xml
[ -f "$manifest" ] && sed -i.bak 's/android:label="croheal"/android:label="CroHeal"/' "$manifest" && rm -f "$manifest.bak"

# Android: LiteRT (tflite_flutter) needs API 26+ (Android 8.0)
for g in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$g" ] && sed -i.bak -E 's/minSdk(Version)? *=? *flutter\.minSdkVersion/minSdk = 26/' "$g" && rm -f "$g.bak"
done

# Android: some plugins (tflite_flutter) target Java 11 while Kotlin defaults to
# JVM 17 on current toolchains; D8 handles mixed bytecode, so don't fail on it.
props=android/gradle.properties
if [ -f "$props" ] && ! grep -q "kotlin.jvm.target.validation.mode" "$props"; then
  printf '\nkotlin.jvm.target.validation.mode=warning\n' >> "$props"
fi

tool/sync_models.sh "${MODEL_VARIANT:-int8}"
flutter pub get
echo "Done. Run: flutter run"
