import 'package:flutter/material.dart';
import 'package:masaren/di/injection.dart';
import 'package:masaren/services/api_service.dart';

/// In-memory social feed store.
///
/// Owns the post list for the home feed, seeds it from the mock gateway
/// (`/matching/feed`), applies the ranking algorithm client-side (confidence
/// score desc, recency tie-break) and supports optimistic compose + like
/// toggles. It is a [ChangeNotifier] so the feed and the compose sheet stay
/// in sync without prop drilling.
class FeedStore extends ChangeNotifier {
  List<Map<String, dynamic>> _posts = [];
  bool loading = false;
  bool _likedSeq = false;

  List<Map<String, dynamic>> get posts => List.unmodifiable(_posts);

  /// Feed ranking algorithm: higher POAI confidence first, newest first on tie.
  void _rank() {
    _posts.sort((a, b) {
      final sa = (a['score'] is num ? a['score'] as num : 0).toDouble();
      final sb = (b['score'] is num ? b['score'] as num : 0).toDouble();
      if (sb != sa) return sb.compareTo(sa);
      final ta = a['timestamp']?.toString() ?? '';
      final tb = b['timestamp']?.toString() ?? '';
      return tb.compareTo(ta);
    });
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final api = getIt<ApiService>();
      final raw = await api.getFeed(userId: 'current-user', limit: 40, offset: 0);
      _posts = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        // Mobile mock gateway uses `liked`; normalise to the UI field.
        if (!m.containsKey('likedByMe') && m.containsKey('liked')) {
          m['likedByMe'] = m['liked'] == true;
        }
        return m;
      }).toList();
      _rank();
    } catch (_) {
      // Offline / no gateway: keep whatever we have (optimistic posts survive).
    }
    loading = false;
    notifyListeners();
  }

  void toggleLike(String id) {
    final i = _posts.indexWhere((p) => p['id'] == id);
    if (i == -1) return;
    final p = Map<String, dynamic>.from(_posts[i]);
    final liked = !(p['likedByMe'] == true);
    p['likedByMe'] = liked;
    p['likes'] = ((p['likes'] is num ? p['likes'] as num : 0) + (liked ? 1 : -1)).toInt();
    _posts[i] = p;
    notifyListeners();
  }

  /// Optimistic compose: a freshly authored post jumps to the top of the feed.
  void addPost({required String creator, required String caption, String type = 'TEXT', int sdg = 0}) {
    _likedSeq = !_likedSeq;
    _posts.insert(0, {
      'id': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'creator': creator,
      'caption': caption,
      'type': type,
      'sdg': sdg,
      'score': 50,
      'likes': 0,
      'comments': 0,
      'likedByMe': false,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'local': true,
    });
    notifyListeners();
  }
}

/// App-wide singleton so the shell's compose FAB and the feed share one list.
final FeedStore feedStore = FeedStore();



