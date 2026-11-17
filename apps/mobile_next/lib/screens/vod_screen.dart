import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/create_vod_screen.dart';
import 'package:masaren/services/share_policy.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets/content_engagement.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:video_player/video_player.dart';

class VodHubScreen extends StatefulWidget {
  final User user;
  const VodHubScreen({super.key, required this.user});

  @override
  State<VodHubScreen> createState() => _VodHubScreenState();
}

class _VodHubScreenState extends State<VodHubScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await AuthApi.vodVideos();
      if (!mounted) return;
      setState(() => _videos = videos);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  String _duration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CreateVodScreen()));
    if (created != null) await _load();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_t('vod.titlePlural', 'VOD & replays'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.video_library_outlined),
        label: Text(_t('vod.newVideo', 'New video')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load,
                          child: Text(_t('common.retry', 'Retry'))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                    itemCount: _videos.length,
                    itemBuilder: (_, index) {
                      final video = _videos[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: index * 55),
                        child: PressScale(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => VodPlayerScreen(
                                    videoId: video['id'].toString(),
                                    user: widget.user)),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: .55)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    SmartImage(
                                        url: video['cover_url']?.toString(),
                                        height: 150,
                                        width: double.infinity,
                                        fallbackIcon:
                                            Icons.video_library_outlined,
                                        accent: cs.primary),
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: .45),
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 32),
                                        ),
                                      ),
                                    ),
                                    if (video['verified'] == true)
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: .5),
                                              borderRadius:
                                                  BorderRadius.circular(999)),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified,
                                                  color: Colors.white,
                                                  size: 13),
                                              SizedBox(width: 3),
                                              Text('VERIFIED',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8.5,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text((video['title'] ?? '').toString(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: cs.onSurface)),
                                      const SizedBox(height: 3),
                                      Text(
                                          [
                                            if ((video['event_title'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              video['event_title'].toString(),
                                            (video['owner_name'] ?? '')
                                                .toString(),
                                            _duration(
                                                (video['duration_sec'] as num?)
                                                        ?.toInt() ??
                                                    0),
                                            '${video['views'] ?? 0} ${_t('vod.views', 'views')}',
                                          ]
                                              .where((s) => s.isNotEmpty)
                                              .join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class VodPlayerScreen extends StatefulWidget {
  final String videoId;
  final User user;
  const VodPlayerScreen({super.key, required this.videoId, required this.user});

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  Map<String, dynamic>? _video;
  VideoPlayerController? _videoController;
  ChewieController? _chewie;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final video = await AuthApi.vodVideo(widget.videoId);
      final source = (video['hls_url'] ?? video['video_url'] ?? '').toString();
      if (source.isEmpty) throw Exception('Video source is missing.');
      final controller = VideoPlayerController.networkUrl(Uri.parse(source));
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        aspectRatio: controller.value.aspectRatio,
        placeholder: SmartImage(
            url: video['cover_url']?.toString(),
            fallbackIcon: Icons.video_library_outlined),
        errorBuilder: (_, __) => const Center(
            child: Icon(Icons.error_outline, color: Colors.white, size: 48)),
      );
      if (!mounted) {
        chewie.dispose();
        controller.dispose();
        return;
      }
      setState(() {
        _video = video;
        _videoController = controller;
        _chewie = chewie;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  void _share() {
    final video = _video;
    if (video == null) return;
    SharePolicy.copy(context,
        allowed: video['verified'] == true,
        text: '${video['title']} · https://masareen.com/vod/${video['id']}',
        confirmation: _t('vod.linkCopied', 'Video link copied.'));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text((_video?['title'] ?? _t('vod.player', 'Video')).toString(),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              onPressed: _video == null ? null : _share,
              icon: const Icon(Icons.ios_share),
              tooltip: _t('vod.share', 'Share video')),
        ],
      ),
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SmartImage(
                            url: _video?['cover_url']?.toString(),
                            height: 180,
                            fallbackIcon: Icons.video_library_outlined),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load,
                            child: Text(_t('common.retry', 'Retry'))),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    AspectRatio(
                      aspectRatio:
                          _videoController?.value.aspectRatio ?? 16 / 9,
                      child: _chewie == null
                          ? const Center(child: CircularProgressIndicator())
                          : Chewie(controller: _chewie!),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Theme.of(context).scaffoldBackgroundColor,
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            Text((_video?['title'] ?? '').toString(),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface)),
                            const SizedBox(height: 6),
                            Text(
                                [
                                  (_video?['event_title'] ?? '').toString(),
                                  (_video?['owner_name'] ?? '').toString(),
                                  '${_video?['views'] ?? 0} ${_t('vod.views', 'views')}',
                                ].where((s) => s.isNotEmpty).join(' · '),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant)),
                            if ((_video?['description'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(_video!['description'].toString(),
                                    textDirection: textDirectionFor(
                                        _video!['description'].toString()),
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.6,
                                        color: cs.onSurface)),
                              ),
                            const SizedBox(height: 8),
                            ContentEngagement(
                              targetType: 'vod',
                              targetId: widget.videoId,
                              user: widget.user,
                              initialReactions:
                                  (_video?['reaction_count'] as num?)
                                          ?.toInt() ??
                                      0,
                              initialComments:
                                  (_video?['comment_count'] as num?)
                                          ?.toInt() ??
                                      0,
                              initiallyReacted: _video?['reacted'] == true,
                              onShare: () async => _share(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
