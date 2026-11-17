import 'package:flutter_test/flutter_test.dart';
import 'package:masaren/services/live_sync_service.dart';

void main() {
  test('parses live interaction counters', () {
    final stats = LivePostStats.fromJson({
      'id': '42',
      'likes': 3,
      'comments': 2,
      'shares': 1,
      'impact_value': 4.5,
      'confidence_score': 72,
      'latest_comment_id': '99',
      'liked_by_me': true,
      'bookmarked_by_me': false,
    });

    expect(stats.id, '42');
    expect(stats.likes, 3);
    expect(stats.comments, 2);
    expect(stats.shares, 1);
    expect(stats.impactValue, 4.5);
    expect(stats.confidenceScore, 72);
    expect(stats.latestCommentId, '99');
    expect(stats.likedByMe, isTrue);
    expect(stats.bookmarkedByMe, isFalse);
  });

  test('defaults missing counters safely', () {
    final stats = LivePostStats.fromJson({'id': 7});

    expect(stats.id, '7');
    expect(stats.likes, 0);
    expect(stats.comments, 0);
    expect(stats.shares, 0);
    expect(stats.impactValue, isNull);
    expect(stats.confidenceScore, isNull);
    expect(stats.latestCommentId, isNull);
    expect(stats.likedByMe, isFalse);
    expect(stats.bookmarkedByMe, isFalse);
  });
}
