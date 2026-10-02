# Windows equivalent of tool/bootstrap.sh
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
flutter create . --platforms=android,ios --org com.nagarjunasagar --project-name croheal | Out-Null
$manifest = "android/app/src/main/AndroidManifest.xml"
if (Test-Path $manifest) {
  (Get-Content $manifest) -replace 'android:label="croheal"', 'android:label="CroHeal"' | Set-Content $manifest
}
foreach ($g in "android/app/build.gradle.kts", "android/app/build.gradle") {
  if (Test-Path $g) { (Get-Content $g) -replace 'minSdk(Version)? *=? *flutter\.minSdkVersion', 'minSdk = 26' | Set-Content $g }
}
$props = "android/gradle.properties"
if ((Test-Path $props) -and -not (Select-String -Path $props -Pattern "kotlin.jvm.target.validation.mode" -Quiet)) {
  Add-Content $props "`nkotlin.jvm.target.validation.mode=warning"
}
$variant = if ($env:MODEL_VARIANT) { $env:MODEL_VARIANT } else { "int8" }
New-Item -ItemType Directory -Force assets/models | Out-Null
Copy-Item "../models/crop_disease_$variant.tflite" assets/models/crop_disease.tflite -Force
Copy-Item ../models/labels.txt, ../models/disease_info.json, ../models/model_info.json assets/models/ -Force
flutter pub get
Write-Host "Done. Run: flutter run  (iOS permission strings are added by bootstrap.sh on macOS)"
