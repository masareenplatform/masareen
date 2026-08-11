import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences (theme, haptics, sound) persisted on-device.
///
/// Exposes [ValueNotifier]s so the widget tree can react instantly while the
/// values are durably stored in [SharedPreferences] — this is what makes the
/// light/dark switch and the reaction feedback toggles survive app restarts.
class AppSettings {
  static const String _kTheme = 'pref.theme_mode';
  static const String _kHaptics = 'pref.haptics_enabled';
  static const String _kSound = 'pref.sound_enabled';
  static const String _kOnboarding = 'pref.onboarding_seen';
  static const String _kReducedMotion = 'pref.reduced_motion';
  static const String onboardingSeenKey = 'onboarding_seen';

  static final AppSettings instance = AppSettings._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  final ValueNotifier<bool> hapticsEnabled = ValueNotifier(true);
  final ValueNotifier<bool> soundEnabled = ValueNotifier(true);
  final ValueNotifier<bool> reducedMotion = ValueNotifier(false);
  final ValueNotifier<bool> onboardingSeen = ValueNotifier(false);

  bool _ready = false;

  AppSettings._();

  Future<void> init() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    final themeIdx = prefs.getInt(_kTheme) ?? ThemeMode.light.index;
    themeMode.value = ThemeMode.values[themeIdx.clamp(0, ThemeMode.values.length - 1)];
    hapticsEnabled.value = prefs.getBool(_kHaptics) ?? true;
    soundEnabled.value = prefs.getBool(_kSound) ?? true;
    reducedMotion.value = prefs.getBool(_kReducedMotion) ?? false;
    onboardingSeen.value = prefs.getBool(_kOnboarding) ?? false;
    _ready = true;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTheme, mode.index);
  }

  Future<void> toggleHaptics(bool value) async {
    hapticsEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, value);
  }

  Future<void> toggleSound(bool value) async {
    soundEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSound, value);
  }

  Future<void> toggleReducedMotion(bool value) async {
    reducedMotion.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReducedMotion, value);
  }

  Future<void> markOnboardingSeen() async {
    onboardingSeen.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }
}



