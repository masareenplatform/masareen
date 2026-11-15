import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps video playback consistent across the whole app:
/// - one video plays at a time (the most visible one claims playback)
/// - the mute choice is global and survives restarts. Unmuting one video
///   keeps every following video unmuted until the member mutes again.
class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController._();
  static final VideoPlaybackController instance = VideoPlaybackController._();

  static const _mutedKey = 'masaren_video_muted';

  bool _muted = true;
  bool _initialized = false;
  String? _activeId;
  SharedPreferences? _prefs;

  bool get muted => _muted;
  String? get activeId => _activeId;
  bool isActive(String id) => _activeId == id;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _prefs = await SharedPreferences.getInstance();
      _muted = _prefs?.getBool(_mutedKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    _prefs?.setBool(_mutedKey, value);
    notifyListeners();
  }

  void toggleMuted() => setMuted(!_muted);

  /// Called when a video becomes visible. Returns true when this video is
  /// allowed to play; other players listen and pause themselves.
  bool claim(String id) {
    if (_activeId == id) return true;
    _activeId = id;
    notifyListeners();
    return true;
  }

  void release(String id) {
    if (_activeId == id) {
      _activeId = null;
      notifyListeners();
    }
  }

  void pauseAll() {
    if (_activeId == null) return;
    _activeId = null;
    notifyListeners();
  }
}
