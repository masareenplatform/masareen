import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:masaren/models.dart';

/// Full-width media attached to a post: a swipeable image gallery or an
/// inline HLS/MP4 player. Keeps the feed edge-to-edge and caption-aware.
class PostMediaGallery extends StatefulWidget {
  final List<PostMedia> media;
  final String? videoHlsUrl;
  final String? videoPosterUrl;
  final ValueChanged<String>? onImageTap;

  const PostMediaGallery({
    super.key,
    required this.media,
    this.videoHlsUrl,
    this.videoPosterUrl,
    this.onImageTap,
  });

  @override
  State<PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<PostMediaGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final video = widget.media.where((m) => m.isVideo).toList();
    if (video.isNotEmpty) {
      final v = video.first;
      return PostVideoPlayer(
        url: widget.videoHlsUrl ?? v.hlsUrl ?? v.url,
        posterUrl: widget.videoPosterUrl ?? v.posterUrl,
      );
    }
    if (widget.videoHlsUrl != null && widget.media.isEmpty) {
      return PostVideoPlayer(
        url: widget.videoHlsUrl!,
        posterUrl: widget.videoPosterUrl,
      );
    }

    final images = widget.media.where((m) => !m.isVideo && m.url.isNotEmpty).toList();
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _GalleryImage(
        image: images.first,
        onTap: widget.onImageTap == null ? null : () => widget.onImageTap!(images.first.url),
      );
    }

    final active = _page.clamp(0, images.length - 1);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: widget.onImageTap == null ? null : () => widget.onImageTap!(images[i].url),
              child: _ImageFill(url: images[i].url),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _Chip(label: '${active + 1}/${images.length}', icon: Icons.photo_library_outlined),
          ),
          if (images[active].caption != null && images[active].caption!.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Caption(text: images[active].caption!),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: images[active].caption == null ? 10 : 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final selected = i == active;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryImage extends StatelessWidget {
  final PostMedia image;
  final VoidCallback? onTap;
  const _GalleryImage({required this.image, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(onTap: onTap, child: _ImageFill(url: image.url)),
          if (image.caption != null && image.caption!.trim().isNotEmpty)
            Positioned(left: 0, right: 0, bottom: 0, child: _Caption(text: image.caption!)),
        ],
      ),
    );
  }
}

class _ImageFill extends StatelessWidget {
  final String url;
  const _ImageFill({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 34),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Inline video player that prefers HLS when the backend has finished
/// transcoding, and falls back to the original MP4/WebM upload until then.
class PostVideoPlayer extends StatefulWidget {
  final String url;
  final String? posterUrl;
  const PostVideoPlayer({super.key, required this.url, this.posterUrl});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _playing = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void didUpdateWidget(covariant PostVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _playing = false;
      _open();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      _playing = !_playing;
      if (_playing) {
        c.play();
      } else {
        c.pause();
      }
    });
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ratio = _ready && c != null && c.value.isInitialized && c.value.aspectRatio > 0
        ? c.value.aspectRatio
        : 16 / 9;
    final isHls = widget.url.contains('.m3u8');

    return AspectRatio(
      aspectRatio: ratio.clamp(0.8, 2.2).toDouble(),
      child: GestureDetector(
        onTap: _ready ? _toggle : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.posterUrl != null && (!_ready || !_playing))
              Image.network(widget.posterUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black))
            else
              const ColoredBox(color: Colors.black),
            if (_ready && c != null) VideoPlayer(c),
            if (!_ready)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                ),
              ),
            if (_ready && !_playing)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: _Chip(
                label: isHls ? 'HLS' : 'Video',
                icon: isHls ? Icons.hd_outlined : Icons.videocam_outlined,
              ),
            ),
            if (_ready)
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: _toggleMute,
                  icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white, size: 19),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            if (_ready && c != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  c,
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
    );
  }
}
