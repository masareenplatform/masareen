import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/services/analytics_service.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:video_player/video_player.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  Map<String, dynamic> _config = {};
  bool _loading = true;
  String? _error;
  VideoPlayerController? _video;
  ChewieController? _chewie;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await AuthApi.liveTv();
      if (!mounted) return;
      setState(() => _config = config);
      final url = config['hls_url']?.toString() ?? '';
      if (config['enabled'] == true && url.isNotEmpty) {
        await _start(url);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start(String url) async {
    _chewie?.dispose();
    await _video?.dispose();
    _chewie = null;
    _video = null;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _video = controller;
      _chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9,
        errorBuilder: (context, message) => _offline(message),
      );
      AnalyticsService.instance
          .track('live_tv_open', targetType: 'live_tv', metadata: {'url': url});
      setState(() {});
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _config['title']?.toString() ?? 'MASAREEN Live TV';
    final live = _config['enabled'] == true && _video != null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: live ? const Color(0xFFB3261E) : Colors.grey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.white),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _video == null
              ? Center(child: ErrorView(message: _error, onRetry: _load))
              : _video == null
                  ? Center(
                      child: _offline(_t('live.offline',
                          'The channel is off air right now. Come back soon.')))
                  : Column(
                      children: [
                        AspectRatio(
                          aspectRatio: _chewie != null
                              ? (_video!.value.aspectRatio > 0
                                  ? _video!.value.aspectRatio
                                  : 16 / 9)
                              : 16 / 9,
                          child: Chewie(controller: _chewie!),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Text(
                                _t('live.subtitle',
                                    'MASAREEN Live TV streams our field stories, launches and community events as they happen.'),
                                style: const TextStyle(
                                    color: Colors.white70, height: 1.5),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.public,
                                      color: AppColors.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _t('live.global',
                                        'Broadcasting to the MASAREEN community worldwide'),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _offline(String message) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if ((_config['poster_url']?.toString() ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(_config['poster_url'].toString(),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          const SizedBox(height: 16),
          const Icon(Icons.live_tv_outlined, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(
            _config['enabled'] == true
                ? message
                : _t('live.offline',
                    'The channel is off air right now. Come back soon.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(_t('common.retry', 'Try again')),
          ),
        ],
      ),
    );
  }
}
