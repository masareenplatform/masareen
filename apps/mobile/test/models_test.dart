import 'package:flutter_test/flutter_test.dart';
import 'package:masaren/models.dart';

void main() {
  test(
    'resolveMediaUrl prefixes root-relative /media paths with base origin',
    () {
      expect(resolveMediaUrl(null), isNull);
      expect(resolveMediaUrl('  '), isNull);
      expect(
        resolveMediaUrl('/media/posts/42-1.jpg'),
        'https://masareen.com/media/posts/42-1.jpg',
      );
      expect(
        resolveMediaUrl('https://cdn.example.org/photo.png'),
        'https://cdn.example.org/photo.png',
      );
    },
  );

  test(
    'Post.fromJson and User.fromJson normalize relative media and avatar URLs',
    () {
      final user = User.fromJson({
        'id': '7',
        'email': 'nour@example.com',
        'full_name': 'Nour Hassan',
        'role': 'STUDENT',
        'profile': {
          'avatar_url': '/media/avatars/7.jpg',
          'cover_url': '/media/covers/7.jpg',
        },
      });
      expect(user.avatarUrl, 'https://masareen.com/media/avatars/7.jpg');
      expect(user.coverUrl, 'https://masareen.com/media/covers/7.jpg');

      final post = Post.fromJson({
        'id': '101',
        'author': {
          'id': '7',
          'name': 'Nour Hassan',
          'avatar_url': '/media/avatars/7.jpg',
        },
        'text': 'Verified field update',
        'media': [
          {
            'url': '/media/videos/101.mp4',
            'type': 'VIDEO',
            'hls_url': '/media/videos/101/master.m3u8',
            'poster_url': '/media/videos/101/poster.jpg',
          },
        ],
        'files': [
          {
            'url': '/media/files/report.pdf',
            'name': 'report.pdf',
            'size': 2048,
          },
        ],
        'video_hls_url': '/media/videos/101/master.m3u8',
        'video_poster_url': '/media/videos/101/poster.jpg',
      });

      expect(post.author.avatarUrl, 'https://masareen.com/media/avatars/7.jpg');
      expect(
        post.media.single.url,
        'https://masareen.com/media/videos/101.mp4',
      );
      expect(
        post.media.single.hlsUrl,
        'https://masareen.com/media/videos/101/master.m3u8',
      );
      expect(
        post.media.single.posterUrl,
        'https://masareen.com/media/videos/101/poster.jpg',
      );
      expect(
        post.files.single.url,
        'https://masareen.com/media/files/report.pdf',
      );
      expect(
        post.videoHlsUrl,
        'https://masareen.com/media/videos/101/master.m3u8',
      );
      expect(
        post.videoPosterUrl,
        'https://masareen.com/media/videos/101/poster.jpg',
      );
    },
  );

  test('Post.fromJson accepts numeric post, author and shared_by IDs', () {
    final post = Post.fromJson({
      'id': 101,
      'author': {'id': 7, 'name': 'Nour Hassan'},
      'text': 'Numeric IDs from SQLite',
      'shared_by': [
        {'id': 9, 'name': 'Mona Ali', 'avatar_url': null},
      ],
    });
    expect(post.id, '101');
    expect(post.author.id, '7');
    expect(post.sharedBy.single.id, '9');
  });

  test('Wallet.fromJson reads the server-defined daily reward state', () {
    final wallet = Wallet.fromJson({
      'owner_id': '7',
      'balance': 1250.5,
      'currency': 'MRC',
      'daily_reward': 500,
      'claimed_today': true,
      'last_claim_at': '2026-10-30T08:15:00.000Z',
    });
    expect(wallet.balance, 1250.5);
    expect(wallet.dailyReward, 500);
    expect(wallet.claimedToday, isTrue);
    expect(wallet.lastClaimAt, '2026-10-30T08:15:00.000Z');

    final fresh = Wallet.fromJson({'owner_id': '8', 'balance': 0});
    expect(fresh.dailyReward, 10);
    expect(fresh.claimedToday, isFalse);
  });

  test('GpsRecord.fromJson parses coordinates and builds a maps link', () {
    final record = GpsRecord.fromJson({
      'id': '11',
      'latitude': 30.04442,
      'longitude': 31.23571,
      'accuracy': 12.4,
      'captured_at': '2026-10-30T09:00:00.000Z',
    });
    expect(record.latitude, 30.04442);
    expect(record.longitude, 31.23571);
    expect(record.accuracy, 12.4);
    expect(
      record.mapsUrl,
      'https://www.google.com/maps/search/?api=1&query=30.04442,31.23571',
    );
  });
}
