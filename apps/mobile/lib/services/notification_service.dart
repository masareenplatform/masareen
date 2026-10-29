import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badge/flutter_app_badge.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/firebase_options.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('FCM background init skipped: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'masaren_notifications';
  static const _channelName = 'MASAREEN Notifications';
  static const _messageChannelId = 'masaren_messages';
  static const _messageChannelName = 'MASAREEN Messages';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _fcmInitialized = false;
  bool enabled = true;
  int? quietStart;
  int? quietEnd;
  String? initialPayload;
  String? _fcmToken;
  void Function(String? payload)? _onTap;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  String? get fcmToken => _fcmToken;

  Future<void> init({void Function(String? payload)? onTap}) async {
    if (onTap != null) _onTap = onTap;
    if (_initialized) {
      await syncDeviceToken();
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _onTap?.call(response.payload);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      initialPayload = launch?.notificationResponse?.payload;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Impact, opportunities and account updates',
          importance: Importance.high,
          showBadge: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _messageChannelId,
          _messageChannelName,
          description: 'New private messages',
          importance: Importance.high,
          showBadge: true,
        ),
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    await _requestPermission();
    await _initFirebaseMessaging();

    _initialized = true;

    final pending = initialPayload;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onTap?.call(pending);
      });
    }
  }

  Future<void> _initFirebaseMessaging() async {
    if (_fcmInitialized) {
      await syncDeviceToken();
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        initialPayload = _payloadFromRemoteMessage(initialMsg);
      }

      _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        final notification = msg.notification;
        final title =
            notification?.title ?? msg.data['title']?.toString() ?? 'MASAREEN';
        final body = notification?.body ?? msg.data['body']?.toString() ?? '';
        final type = msg.data['type']?.toString() ?? '';
        final payload = _payloadFromRemoteMessage(msg);
        showNotification(
          msg.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title,
          body,
          payload: payload,
          message: type == 'message',
        );
      });

      _onMessageOpenedSub?.cancel();
      _onMessageOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        final payload = _payloadFromRemoteMessage(msg);
        _onTap?.call(payload);
      });

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((String newToken) {
        _fcmToken = newToken;
        _registerTokenWithBackend(newToken);
      });

      _fcmInitialized = true;
      await syncDeviceToken();
    } catch (e) {
      debugPrint('FCM initialization skipped or failed: $e');
    }
  }

  String _payloadFromRemoteMessage(RemoteMessage msg) {
    final explicit = msg.data['payload']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final type = msg.data['type']?.toString() ?? '';
    if (type == 'message') return 'messages';
    if (type.startsWith('opportunity')) return 'opportunities';
    return 'notifications';
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS || Platform.isMacOS) return 'ios';
    return 'android';
  }

  Future<void> syncDeviceToken() async {
    if (!_fcmInitialized || api.token == null || api.token!.isEmpty) return;
    try {
      final token = _fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('Failed to obtain/sync FCM token: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    if (api.token == null || api.token!.isEmpty) return;
    try {
      await AuthApi.registerDeviceToken(token, _platformName());
    } catch (e) {
      debugPrint('Failed to register FCM token with backend: $e');
    }
  }

  Future<void> unregisterDeviceToken() async {
    final token = _fcmToken;
    if (token == null || token.isEmpty) return;
    try {
      if (api.token != null && api.token!.isNotEmpty) {
        await AuthApi.removeDeviceToken(token);
      }
    } catch (_) {}
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
    }
  }

  void configure({
    required bool pushEnabled,
    int? quietStart,
    int? quietEnd,
  }) {
    enabled = pushEnabled;
    this.quietStart = quietStart;
    this.quietEnd = quietEnd;
  }

  bool get isQuietNow {
    final start = quietStart;
    final end = quietEnd;
    if (start == null || end == null || start == end) return false;
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    if (start < end) return minutes >= start && minutes < end;
    return minutes >= start || minutes < end;
  }

  Future<void> showNotification(
    int id,
    String title,
    String body, {
    String? payload,
    bool message = false,
  }) async {
    if (!enabled || isQuietNow) return;
    final channelId = message ? _messageChannelId : _channelId;
    final channelName = message ? _messageChannelName : _channelName;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: message
            ? 'New private messages'
            : 'Impact, opportunities and account updates',
        importance: message ? Importance.high : Importance.defaultImportance,
        priority: message ? Priority.high : Priority.defaultPriority,
        showWhen: true,
        styleInformation: BigTextStyleInformation(body),
        category: message
            ? AndroidNotificationCategory.message
            : AndroidNotificationCategory.social,
        groupKey: 'masaren_notifications',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: 'masaren_notifications',
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id & 0x7fffffff, title, body, details, payload: payload);
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

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
