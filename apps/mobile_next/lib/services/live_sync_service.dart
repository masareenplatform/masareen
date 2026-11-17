import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:masaren/api_client.dart';

class LivePostStats {
  final String id;
  final int likes;
  final int comments;
  final int shares;
  final double? impactValue;
  final double? confidenceScore;
  final String? latestCommentId;
  final bool likedByMe;
  final bool bookmarkedByMe;

  const LivePostStats({
    required this.id,
    required this.likes,
    required this.comments,
    required this.shares,
    this.impactValue,
    this.confidenceScore,
    this.latestCommentId,
    this.likedByMe = false,
    this.bookmarkedByMe = false,
  });

  factory LivePostStats.fromJson(Map<String, dynamic> j) => LivePostStats(
        id: (j['id'] ?? '').toString(),
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        shares: (j['shares'] as num?)?.toInt() ?? 0,
        impactValue: (j['impact_value'] as num?)?.toDouble(),
        confidenceScore: (j['confidence_score'] as num?)?.toDouble(),
        latestCommentId: j['latest_comment_id']?.toString(),
        likedByMe: j['liked_by_me'] == true,
        bookmarkedByMe: j['bookmarked_by_me'] == true,
      );
}

class LiveSyncService extends ChangeNotifier with WidgetsBindingObserver {
  LiveSyncService._();

  static final LiveSyncService instance = LiveSyncService._();

  static const Duration interval = Duration(seconds: 8);

  final Map<Object, Set<String>> _watchers = {};
  final Map<String, LivePostStats> _stats = {};
  Timer? _timer;
  bool _started = false;
  bool _active = true;
  bool _polling = false;

  int unreadMessages = 0;
  int unreadNotifications = 0;

  LivePostStats? statsFor(String postId) => _stats[postId];

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(interval, (_) => _poll());
  }

  void watch(Object owner, Iterable<String> postIds) {
    start();
    final ids = postIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (ids.isEmpty) {
      _watchers.remove(owner);
      return;
    }
    _watchers[owner] = ids;
    _poll();
  }

  void unwatch(Object owner) {
    _watchers.remove(owner);
  }

  Future<void> _poll() async {
    if (!_active || _polling || _watchers.isEmpty) return;
    final ids = <String>{};
    for (final group in _watchers.values) {
      ids.addAll(group);
    }
    if (ids.isEmpty) return;
    _polling = true;
    try {
      final data = await AuthApi.liveInteractions(ids.take(60));
      final posts = data['posts'];
      if (posts is List) {
        for (final raw in posts) {
          if (raw is! Map) continue;
          final item = LivePostStats.fromJson(Map<String, dynamic>.from(raw));
          if (item.id.isNotEmpty) _stats[item.id] = item;
        }
      }
      unreadMessages =
          (data['unread_messages'] as num?)?.toInt() ?? unreadMessages;
      unreadNotifications = (data['unread_notifications'] as num?)?.toInt() ??
          unreadNotifications;
      notifyListeners();
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _startTimer();
      _poll();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }
}
