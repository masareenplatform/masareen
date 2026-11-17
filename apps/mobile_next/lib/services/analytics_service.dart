import 'dart:async';

import 'package:masaren/api_client.dart';

/// Lightweight, privacy-conscious product analytics. Events are batched and
/// sent to the Worker, where admins can see what is working and where people
/// drop off. No message content is stored in metadata.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _flushing = false;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void track(
    String type, {
    String? targetType,
    String? targetId,
    int? postId,
    double? value,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) {
    _queue.add({
      'type': type,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (postId != null) 'post_id': postId,
      if (value != null) 'value': value,
      if (durationMs != null) 'duration_ms': durationMs,
      if (metadata != null) 'metadata': metadata,
    });
    if (_queue.length >= 20) flush();
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = _queue.take(60).toList();
    _queue.removeRange(0, batch.length);
    try {
      await AuthApi.sendAnalytics(batch);
    } catch (_) {
      _queue.insertAll(0, batch);
      if (_queue.length > 250) {
        _queue.removeRange(0, _queue.length - 250);
      }
    } finally {
      _flushing = false;
    }
  }
}
