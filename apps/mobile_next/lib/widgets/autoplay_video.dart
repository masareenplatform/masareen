import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:masaren/services/analytics_service.dart';
import 'package:masaren/services/video_playback.dart';
import 'package:masaren/widgets.dart';

/// Muted, autoplaying video used in the feed and on post detail.
///
/// The video plays while at least 60% of it is visible, pauses when it leaves
/// the viewport, and only one video plays at a time. The mute choice is global
/// and persisted: unmuting one video keeps the following videos unmuted.
class AutoplayVideo extends StatefulWidget {
  final String? id;
  final String url;
  final String? posterUrl;

  const AutoplayVideo(
      {super.key, this.id, required this.url, this.posterUrl});

  @override
  State<AutoplayVideo> createState() => _AutoplayVideoState();
}

class _AutoplayVideoState extends State<AutoplayVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _playing = false;
  bool _visible = false;
  bool _userPaused = false;
  bool _initializing = false;
  DateTime? _watchStart;

  String get _id => widget.id ?? widget.url;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VideoPlaybackController.instance.init();
    VideoPlaybackController.instance.addListener(_sync);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VideoPlaybackController.instance.removeListener(_sync);
    VideoPlaybackController.instance.release(_id);
    _endWatch();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
      return;
    }
    if (_visible && !_userPaused) _activate();
  }

  @override
  void didUpdateWidget(covariant AutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _playing = false;
      _userPaused = false;
      if (_visible) _activate();
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null || _initializing) return;
    _initializing = true;
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(
          VideoPlaybackController.instance.muted ? 0 : 1);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _ready = true);
      if (_visible && !_userPaused) _activate();
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    } finally {
      _initializing = false;
    }
  }

  void _activate() {
    if (!_visible || _userPaused) return;
    VideoPlaybackController.instance.claim(_id);
    _ensureController();
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      controller
          .setVolume(VideoPlaybackController.instance.muted ? 0 : 1)
          .catchError((_) {});
      controller.play().catchError((_) {});
      _watchStart ??= DateTime.now();
      if (mounted) setState(() => _playing = true);
    }
  }

  void _pause() {
    _controller?.pause().catchError((_) {});
    _endWatch();
    if (mounted && _playing) setState(() => _playing = false);
  }

  void _endWatch() {
    final since = _watchStart;
    _watchStart = null;
    if (since == null) return;
    final ms = DateTime.now().difference(since).inMilliseconds;
    if (ms >= 2000) {
      AnalyticsService.instance.track('video_watch',
          targetType: 'video',
          targetId: _id,
          durationMs: ms,
          metadata: {'url': widget.url});
    }
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.6;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _userPaused = false;
      _activate();
    } else {
      _pause();
      VideoPlaybackController.instance.release(_id);
    }
  }

  void _sync() {
    if (!mounted) return;
    final global = VideoPlaybackController.instance;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      controller.setVolume(global.muted ? 0 : 1).catchError((_) {});
    }
    if (global.isActive(_id) && _visible && !_userPaused) {
      controller?.play().catchError((_) {});
      _watchStart ??= DateTime.now();
      if (!_playing) setState(() => _playing = true);
    } else {
      controller?.pause().catchError((_) {});
      _endWatch();
      if (_playing) setState(() => _playing = false);
    }
    setState(() {});
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _activate();
      return;
    }
    if (_playing) {
      _userPaused = true;
      _pause();
      VideoPlaybackController.instance.release(_id);
    } else {
      _userPaused = false;
      _activate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = _ready &&
        controller != null &&
        controller.value.isInitialized;
    final ratio = ready && controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    final isHls = widget.url.contains('.m3u8');
    final muted = VideoPlaybackController.instance.muted;

    return VisibilityDetector(
      key: Key('autoplay-$_id'),
      onVisibilityChanged: _onVisibility,
      child: AspectRatio(
        aspectRatio: ratio.clamp(0.8, 2.2).toDouble(),
        child: Clickable(
          onTap: _togglePlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.posterUrl != null && (!ready || !_playing))
                Image.network(widget.posterUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Colors.black))
              else
                const ColoredBox(color: Colors.black),
              if (ready) VideoPlayer(controller),
              if (!ready && _visible)
                const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.2),
                  ),
                ),
              if (!ready && !_visible && widget.posterUrl == null)
                const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white54, size: 42),
                ),
              if (ready && !_playing)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                child: _videoChip(
                    isHls ? 'HLS' : 'Video',
                    isHls ? Icons.hd_outlined : Icons.videocam_outlined),
              ),
              if (ready)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    onPressed: () =>
                        VideoPlaybackController.instance.toggleMuted(),
                    tooltip: muted ? 'Unmute' : 'Mute',
                    icon: Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 19),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              if (ready)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
