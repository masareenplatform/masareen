import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';

/// Renders the media body of a feed post based on its `type`.
///
/// Supports every post kind the platform emits:
///  * TEXT   – no media
///  * IMAGE  – network or bundled asset image
///  * VIDEO  – progressive mp4 OR an HLS `.m3u8` stream (transcoded by the
///             media-service) via ExoPlayer-backed [VideoPlayer]
///  * AUDIO  – streamed audio clip with a play/pause control
///  * ARTICLE – rich article card (title + image + source)
///  * LINK   – link preview card
class PostMedia extends StatelessWidget {
  final Map<String, dynamic> post;
  final double height;
  const PostMedia({super.key, required this.post, this.height = 300});

  String? get _url => (post['content_url'] ?? post['mediaUrl'] ?? post['url'])?.toString();
  String get _type => (post['type'] ?? 'TEXT').toString().toUpperCase();

  @override
  Widget build(BuildContext context) {
    switch (_type) {
      case 'IMAGE':
        return _url != null && _url!.isNotEmpty ? _ImageMedia(_url!, height) : const SizedBox.shrink();
      case 'VIDEO':
        return _url != null && _url!.isNotEmpty ? _VideoMedia(_url!, height) : const SizedBox.shrink();
      case 'AUDIO':
        return _url != null && _url!.isNotEmpty ? _AudioMedia(_url!) : const SizedBox.shrink();
      case 'ARTICLE':
        return _ArticleCard(post: post);
      case 'LINK':
        return _LinkCard(post: post);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ImageMedia extends StatelessWidget {
  final String url;
  final double height;
  const _ImageMedia(this.url, this.height);
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height + 60),
      child: _MediaImage(url: url),
    );
  }
}

/// Network/asset image with a shimmer placeholder + graceful error fallback.
class _MediaImage extends StatelessWidget {
  final String url;
  const _MediaImage({required this.url});
  @override
  Widget build(BuildContext context) {
    if (url.startsWith('asset://')) {
      return Image.asset(url.replaceFirst('asset://', 'assets/'), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) =>
          prog == null ? child : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }
  Widget _fallback() => Container(
        height: 220,
        color: MasarenTheme.line,
        child: const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: MasarenTheme.muted)),
      );
}

class _VideoMedia extends StatefulWidget {
  final String url;
  final double height;
  const _VideoMedia(this.url, this.height);
  @override
  State<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends State<_VideoMedia> {
  late final VideoPlayerController _vc;
  ChewieController? _cc;
  bool _ready = false;
  bool _isHls = false;

  @override
  void initState() {
    super.initState();
    _isHls = widget.url.contains('.m3u8');
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _cc = ChewieController(
          videoPlayerController: _vc,
          autoPlay: false,
          looping: false,
          aspectRatio: _vc.value.aspectRatio,
          placeholder: const Center(child: CircularProgressIndicator()),
        );
        setState(() => _ready = true);
      }).catchError((e) {
        if (mounted) setState(() => _ready = false);
      });
  }

  @override
  void dispose() {
    _cc?.dispose();
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _vc.value.isInitialized ? _vc.value.aspectRatio : 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_ready && _cc != null)
            Chewie(controller: _cc!)
          else if (!_ready)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text('Loading video…', style: TextStyle(color: Colors.white70)),
                ]),
              ),
            ),
          if (_isHls)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: const Row(children: [
                  Icon(Icons.stream_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('HLS', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _AudioMedia extends StatefulWidget {
  final String url;
  const _AudioMedia(this.url);
  @override
  State<_AudioMedia> createState() => _AudioMediaState();
}

class _AudioMediaState extends State<_AudioMedia> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((d) => setState(() => _pos = d));
    _player.onDurationChanged.listen((d) => setState(() => _dur = d));
    _player.onPlayerComplete.listen((_) => setState(() => _playing = false));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds.remainder(60)).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [MasarenTheme.brand, MasarenTheme.azure]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: Colors.white, size: 44),
          onPressed: () async {
            if (_playing) {
              await _player.pause();
              setState(() => _playing = false);
            } else {
              await _player.play(UrlSource(widget.url));
              setState(() => _playing = true);
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Audio impact story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _dur.inSeconds == 0 ? 0 : _pos.inSeconds / _dur.inSeconds,
              backgroundColor: Colors.white38,
              color: Colors.white,
            ),
            const SizedBox(height: 4),
            Text('${_fmt(_pos)} / ${_fmt(_dur)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _ArticleCard({required this.post});
  @override
  Widget build(BuildContext context) {
    final img = post['imageUrl']?.toString() ?? '';
    final children = <Widget>[
      if (img.isNotEmpty) _MediaImage(url: img),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post['title']?.toString() ?? 'Impact story',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(post['summary']?.toString() ?? '',
                style: const TextStyle(color: MasarenTheme.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 8),
            Text(post['source']?.toString() ?? 'MASAREEN Journal',
                style: const TextStyle(color: MasarenTheme.brand, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: MasarenTheme.line), borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _LinkCard({required this.post});
  @override
  Widget build(BuildContext context) {
    final img = post['imageUrl']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: MasarenTheme.line), borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        if (img.isNotEmpty)
          SizedBox(width: 96, height: 96, child: _MediaImage(url: img))
        else
          const SizedBox(width: 96, height: 96, child: Icon(Icons.link_rounded, size: 36, color: MasarenTheme.muted)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['title']?.toString() ?? 'Shared link',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(post['domain']?.toString() ?? (post['url']?.toString() ?? ''),
                  style: TextStyle(color: MasarenTheme.brand, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ]),
    );
  }
}
