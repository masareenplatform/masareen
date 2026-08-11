import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';

/// Plays reaction feedback: a short "pop" sound plus a haptic tap.
///
/// Both channels honour the user's preferences in [AppSettings] so they can be
/// switched off independently from the Settings screen.
class FeedbackService {
  static final FeedbackService instance = FeedbackService._();
  final AudioPlayer _player = AudioPlayer();

  FeedbackService._() {
    _player.setReleaseMode(ReleaseMode.release);
  }

  Future<void> like() async {
    final settings = AppSettings.instance;
    if (settings.soundEnabled.value) {
      try {
        await _player.play(AssetSource('sounds/pop.wav'));
      } catch (_) {}
    }
    if (settings.hapticsEnabled.value) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  Future<void> tap() async {
    final settings = AppSettings.instance;
    if (settings.hapticsEnabled.value) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  Future<void> success() async {
    final settings = AppSettings.instance;
    if (settings.hapticsEnabled.value) HapticFeedback.lightImpact();
    if (settings.soundEnabled.value) {
      try {
        await _player.play(AssetSource('sounds/pop.wav'));
      } catch (_) {}
    }
  }
}



