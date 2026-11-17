# MASAREEN Next

An experimental visual direction for MASAREEN. It keeps the full MASAREEN product
surface and backend, but applies the Fabrika AI design language to the original
green, gold and deep-teal brand palette.

## Design direction

- Near-black OLED canvas, charcoal surfaces and 1 px hairline borders.
- Cairo typography with high-contrast display weights and compact micro-labels.
- Outlined navigation icons, flat bottom navigation and restrained motion.
- Green is the action color, gold is the signal color, and white is reserved for
  reading surfaces and high-emphasis content.
- Cards use 20 px corners, no elevation and a single hairline border.
- Authentication keeps the split desktop composition and uses a forest-green
  monochrome stage instead of the previous blue/purple gradients.

## Product scope

This build keeps the same API and feature set as `apps/mobile`: feed, markets,
newsroom, events, courses, programs, projects, opportunities, wallet, MRC,
calls, messaging, Live TV, podcasts, VOD, reports, admin tools and OTA-safe
navigation. Push notifications and the existing MASAREEN backend are unchanged.

## Identity

- Android application ID: `com.masaren.next`
- Display name: `MASAREEN Next`
- Version: `0.5.0+20`
- The current `apps/mobile` app remains the production build and is not replaced.

## Run

```bash
flutter pub get
flutter run
flutter build apk --release
```

The in-app OTA updater is disabled for this package so it can never replace the
production MASAREEN app with the stable APK.
