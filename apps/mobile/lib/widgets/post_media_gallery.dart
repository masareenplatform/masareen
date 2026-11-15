
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:masaren/models.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/screens/document_viewer_screen.dart';
import 'package:masaren/widgets/autoplay_video.dart';
import 'package:masaren/widgets/smart_image.dart';

/// Full-width media attached to a post: a swipeable image gallery or an
/// inline video player. Keeps the feed edge-to-edge and caption-aware.
class PostMediaGallery extends StatefulWidget {
  final List<PostMedia> media;
  final String? videoHlsUrl;
  final String? videoPosterUrl;
  final String? videoId;
  final ValueChanged<String>? onImageTap;

  const PostMediaGallery({
    super.key,
    required this.media,
    this.videoHlsUrl,
    this.videoPosterUrl,
    this.videoId,
    this.onImageTap,
  });

  @override
  State<PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<PostMediaGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final audio = widget.media.where((m) => m.isAudio && m.url.isNotEmpty).toList();
    if (audio.isNotEmpty) return _VoiceNotePlayer(media: audio.first);
    final video = widget.media.where((m) => m.isVideo).toList();
    if (video.isNotEmpty) {
      final v = video.first;
      return AutoplayVideo(
        id: widget.videoId,
        url: widget.videoHlsUrl ?? v.hlsUrl ?? v.url,
        posterUrl: widget.videoPosterUrl ?? v.posterUrl,
      );
    }
    if (widget.videoHlsUrl != null && widget.media.isEmpty) {
      return AutoplayVideo(
        id: widget.videoId,
        url: widget.videoHlsUrl!,
        posterUrl: widget.videoPosterUrl,
      );
    }

    final images =
        widget.media.where((m) => !m.isVideo && m.url.isNotEmpty).toList();
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _GalleryImage(
        image: images.first,
        onTap: widget.onImageTap == null
            ? null
            : () => widget.onImageTap!(images.first.url),
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
              onTap: widget.onImageTap == null
                  ? null
                  : () => widget.onImageTap!(images[i].url),
              child: _ImageFill(url: images[i].url),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _Chip(
                label: '${active + 1}/${images.length}',
                icon: Icons.photo_library_outlined),
          ),
          if (images[active].caption != null &&
              images[active].caption!.trim().isNotEmpty)
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
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
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
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Caption(text: image.caption!)),
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
    return SmartImage(
      url: url,
      fit: BoxFit.cover,
      fallbackIcon: Icons.broken_image_outlined,
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
        style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500),
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
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class PostFilesList extends StatelessWidget {
  final List<PostFile> files;
  const PostFilesList({super.key, required this.files});

  IconData _iconFor(PostFile file) {
    final type = (file.contentType ?? '').toLowerCase();
    final name = file.name.toLowerCase();
    if (type.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (type.contains('word') ||
        name.endsWith('.doc') ||
        name.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (type.contains('sheet') ||
        name.endsWith('.xls') ||
        name.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    if (type.contains('presentation') ||
        name.endsWith('.ppt') ||
        name.endsWith('.pptx')) {
      return Icons.slideshow_outlined;
    }
    if (type.contains('zip') || name.endsWith('.zip')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.attach_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: files.map((file) {
          return Material(
            color: dark ? const Color(0xFF1A2622) : const Color(0xFFF1F4EF),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final name = file.name.toLowerCase();
                if (name.endsWith('.pdf') ||
                    name.endsWith('.docx') ||
                    name.endsWith('.doc')) {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DocumentViewerScreen(
                          url: file.url, name: file.name)));
                  return;
                }
                final uri = Uri.tryParse(file.url);
                if (uri == null) return;
                final ok =
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          MasarenLocalizations.of(context, 'common.failed')
                              .replaceAll('{error}', file.url))));
                }
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: dark
                          ? const Color(0xFF2E3B36)
                          : const Color(0xFFDDE5DE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconFor(file), size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          if (file.sizeLabel.isNotEmpty)
                            Text(
                              file.sizeLabel,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.download_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PostLinkCard extends StatelessWidget {
  final String url;
  const PostLinkCard({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final uri = Uri.tryParse(url);
    final host = uri?.host.replaceFirst('www.', '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: dark ? const Color(0xFF1A2622) : const Color(0xFFF1F4EF),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (uri == null) return;
            final ok =
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      MasarenLocalizations.of(context, 'common.failed')
                          .replaceAll('{error}', url))));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      dark ? const Color(0xFF2E3B36) : const Color(0xFFDDE5DE)),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MasarenLocalizations.of(context, 'post.openLink'),
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                      if (host != null && host.isNotEmpty)
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 10.5),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  final PostMedia media;
  const _VoiceNotePlayer({required this.media});

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      if (!_ready) {
        await _player.setSourceUrl(widget.media.url);
        _ready = true;
      }
      await _player.resume();
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  String _fmt(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final progress =
        (_position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: cs.primary, shape: BoxShape.circle),
              child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: cs.onPrimary,
                  size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Voice note',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
              _duration.inMilliseconds > 0
                  ? '${_fmt(_position)} / ${_fmt(_duration)}'
                  : _fmt(_position),
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10.5,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}
