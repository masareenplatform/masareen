---
id: mobile
title: Mobile Application (Flutter)
sidebar_position: 3
---

# Mobile Application (Flutter)

A focused Android app for **capture-and-verify in the field**: sign in, browse
opportunities, do the work, capture GPS-stamped evidence, and watch your reputation grow.

## Stack

- **Flutter 3.32 / Dart 3.8**.
- **`http`** — pure-Dart HTTP client (no native code → no Gradle/AGP/Kotlin conflicts).
- **`url_launcher`** — opens Google sign-in in the device browser (the web app handles the
  full OAuth + id_token exchange, then returns the user to the app already verified).

## Screens

| Screen | File | Purpose |
|--------|------|---------|
| Login | `lib/screens/login_screen.dart` | Email/password + Google + link to register. Configurable API base URL. |
| Register | `lib/screens/register_screen.dart` | Create account (auto-verified in demo). |
| Feed | `lib/screens/feed_screen.dart` | Authenticated feed of verified posts; pull-to-refresh; logout. |

## API client

`lib/api_client.dart` is a thin client using the shared envelope
(`{ success, data, message, errors, meta }`). It **defaults the base URL to
`https://masareen.mediahubnetwork.net`** so it works on real devices out of the box. The
login screen also lets you override the base URL if needed.

```dart
final api = ApiClient(); // baseUrl = https://masareen.mediahubnetwork.net
final data = await api.post('/api/v1/auth/login', {
  'email': email, 'password': password,
});
api.setToken(data['access_token']);
```

## Permissions & installability

The Android manifest declares `INTERNET` (required for all network calls) and uses the
MASAREEN launcher icons + splash. The build is **plugin-free**, so it installs cleanly on
standard Android without native dependencies.

## Building the APK

```bash
cd apps/mobile
flutter pub get
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk  (~24 MB)
```

The latest APK is published to `public/downloads/masaren-app-release.apk` and linked from
the web landing page and the footer of this docs site.

## Google sign-in on mobile

Tapping **Continue with Google** launches
`https://masareen.mediahubnetwork.net/login?google=1` in the external browser. After the
web app completes OAuth, the user returns to the app verified. (Requires the Google Cloud
redirect URI to be registered, same as web.)

## Tips

- On an emulator, `10.0.2.2` is the host — but the app already defaults to the public
  domain, so no change is needed.
- Keep `debugShowCheckedModeBanner: false` for release builds (already set).
