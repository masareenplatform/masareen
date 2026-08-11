import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badge/flutter_app_badge.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'masaren_notifications';
  static const _channelName = 'MASAREEN Notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'MASAREEN app notifications',
          importance: Importance.high,
          showBadge: true,
        ),
      );
    }

    await _requestPermission();
    _initialized = true;
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        if (result.isPermanentlyDenied) {
          debugPrint('Notification permission permanently denied. User should enable in settings.');
        }
      }
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
    }
  }

  Future<void> showNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'MASAREEN app notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> setBadgeCount(int count) async {
    try {
      await FlutterAppBadge.count(count);
    } catch (_) {}
  }

  Future<void> clearBadge() async {
    try {
      await FlutterAppBadge.count(0);
    } catch (_) {}
  }
}
