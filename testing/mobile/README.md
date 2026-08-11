# MASAREN Mobile — Emulator / Integration-Test Simulation Scheme

Goal: reproducibly launch the Flutter app on an Android emulator, drive through the
four new monetisation surfaces (Wallet, Ads, Payments, Platform Revenue), capture
screenshots, and assert they render — without depending on a human.

## Prerequisites
- Flutter SDK (3.44.x) + `JAVA_HOME` set (JDK 17). ✅ already working — `flutter build apk` succeeds.
- An Android emulator (AVD). Create one if missing:
  ```powershell
  flutter emulators --create --name masaren_test -s "pixel_6"
  ```
- A running backend is **required for live data**. Until Docker is fixed, run against
  the same offline mock used by the web harness: point the app at a mock gateway, OR
  pre-seed `flutter_secure_storage` with a fake token (see `app_test.dart` comments).
  The UI shells (AppBar titles, forms, empty/error states) render regardless.

## What to run
1. `testing/mobile/run_emulator.ps1` — boots the AVD, waits for `adb`, then:
   - `flutter test integration_test/app_test.dart` (drives + asserts every screen), and
   - `flutter drive --driver=testing_driver.dart --target=integration_test/app_test.dart`
     to capture `screenshots/*.png` via `integrationDriver`.
2. The integration test (`app_test.dart`) opens the nav drawer and taps each new entry,
   then verifies a screen-specific widget/text is present and records a pass/fail row.

## Adding the dev deps (one time)
In `apps/mobile/pubspec.yaml` dev_dependencies:
```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

## Output
- `testing/mobile/screenshots/wallet.png`, `ads.png`, `payments.png`, `revenue.png`
- Console pass/fail table; non-zero exit on any failure (CI-friendly).

## Notes / gotchas
- The app boots to `/login`. `app_test.dart` seeds a fake session **before** pump when
  `MASAREN_MOCK_AUTH=1` is set (see comments), bypassing the real login call so the
  drawer + screens are reachable offline.
- Screenshots require `flutter drive` (not plain `flutter test`); the `testing_driver.dart`
  harness enables `enableFlutterDriverExtension()` and writes PNGs to `screenshots/`.
- Once Docker is up, drop `MASAREN_MOCK_AUTH` and run the same scripts against the live
  gateway for true end-to-end validation.
