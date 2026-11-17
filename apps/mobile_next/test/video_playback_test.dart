import 'package:flutter_test/flutter_test.dart';
import 'package:masaren/services/video_playback.dart';

void main() {
  test('mute is global and only one video is active', () {
    final controller = VideoPlaybackController.instance;
    controller.setMuted(true);
    expect(controller.muted, isTrue);
    controller.toggleMuted();
    expect(controller.muted, isFalse);
    controller.toggleMuted();
    expect(controller.muted, isTrue);

    expect(controller.claim('video-a'), isTrue);
    expect(controller.isActive('video-a'), isTrue);
    expect(controller.claim('video-b'), isTrue);
    expect(controller.isActive('video-a'), isFalse);
    expect(controller.isActive('video-b'), isTrue);
    controller.release('video-b');
    expect(controller.activeId, isNull);
  });
}
