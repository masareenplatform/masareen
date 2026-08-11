import 'dart:async';

import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/services/notification_service.dart';

class PollingService {
  PollingService._();
  static final PollingService instance = PollingService._();

  Timer? _timer;
  int _unreadCount = 0;
  List<AppNotification> _lastSnapshot = [];
  String? _userId;
  bool _active = false;

  int get unreadCount => _unreadCount;
  List<AppNotification> get lastSnapshot => List.unmodifiable(_lastSnapshot);

  void start(String userId, {Duration interval = const Duration(seconds: 30)}) {
    _userId = userId;
    _active = true;
    _poll();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (!_active || _userId == null) return;
    try {
      final notifications = await AuthApi.notifications(_userId!);
      final unread = notifications.where((n) => !n.read).toList();
      final previousCount = _unreadCount;
      _lastSnapshot = notifications;
      _unreadCount = unread.length;
      if (_unreadCount > previousCount && onNewNotification != null) {
        onNewNotification!(_unreadCount);
        // Show local notification for the newest unread
        if (unread.isNotEmpty) {
          final newest = unread.first;
          await NotificationService.instance.showNotification(
            newest.id.hashCode,
            newest.title,
            newest.body ?? '',
          );
        }
      }
    } catch (_) {}
  }

  void Function(int unreadCount)? onNewNotification;
}
