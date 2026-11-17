import 'dart:async';

import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PollingService {
  PollingService._();
  static final PollingService instance = PollingService._();

  static const _seenKey = 'masaren_seen_notifications';

  Timer? _timer;
  int _unreadCount = 0;
  List<AppNotification> _lastSnapshot = [];
  String? _userId;
  bool _active = false;
  bool _seeded = false;
  bool _polling = false;
  Future<void>? _ready;
  final Set<String> _seen = <String>{};

  int get unreadCount => _unreadCount;
  List<AppNotification> get lastSnapshot => List.unmodifiable(_lastSnapshot);

  void start(String userId, {Duration interval = const Duration(seconds: 15)}) {
    if (_userId != userId) {
      _seen.clear();
      _seeded = false;
    }
    _userId = userId;
    _active = true;
    _ready = _loadSeen();
    _ready!.then((_) {
      if (_active) _poll();
    });
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _userId = null;
    _seeded = false;
    _ready = null;
  }

  Future<void> refresh() => _poll();

  Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_seenKey) ?? const [];
      _seen
        ..clear()
        ..addAll(stored);
    } catch (_) {}
  }

  Future<void> _saveSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = _seen.toList();
      if (values.length > 250) values.removeRange(0, values.length - 250);
      await prefs.setStringList(_seenKey, values);
    } catch (_) {}
  }

  int _notificationId(String id) {
    final numeric = int.tryParse(id);
    if (numeric != null) return numeric & 0x7fffffff;
    return id.hashCode & 0x7fffffff;
  }

  Future<void> _poll() async {
    if (!_active || _userId == null || _polling) return;
    _polling = true;
    try {
      await _ready;
      if (!_active || _userId == null) return;
      final notifications = await AuthApi.notifications(_userId!);
      if (!_active || _userId == null) return;
      final unread = notifications.where((n) => !n.read).toList();
      _lastSnapshot = notifications;
      _unreadCount = unread.length;
      onNewNotification?.call(_unreadCount);

      if (!_seeded) {
        _seen.addAll(notifications.map((n) => n.id));
        _seeded = true;
        await _saveSeen();
        return;
      }

      final fresh = unread.where((n) => !_seen.contains(n.id)).toList();
      if (fresh.isEmpty) return;
      for (final item in fresh) {
        _seen.add(item.id);
      }
      await _saveSeen();
      if (!_active || _userId == null) return;

      for (final item in fresh.take(3)) {
        await NotificationService.instance.showNotification(
          _notificationId(item.id),
          item.title,
          item.body ?? '',
          payload: item.link ??
              (item.type == 'message'
              ? 'messages'
              : (item.type?.startsWith('opportunity') == true
                  ? 'opportunities'
                  : 'notifications')),
          message: item.type == 'message',
        );
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  void Function(int unreadCount)? onNewNotification;
}
