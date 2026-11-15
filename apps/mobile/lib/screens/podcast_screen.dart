import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/create_episode_screen.dart';
import 'package:masaren/screens/create_podcast_screen.dart';
import 'package:masaren/screens/event_hub_screen.dart';
import 'package:masaren/services/share_policy.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets/smart_image.dart';

class PodcastHubScreen extends StatefulWidget {
  final User user;
  const PodcastHubScreen({super.key, required this.user});

  @override
  State<PodcastHubScreen> createState() => _PodcastHubScreenState();
}

class _PodcastHubScreenState extends State<PodcastHubScreen> {
  List<Map<String, dynamic>> _shows = [];
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
      final shows = await AuthApi.podcastShows();
      if (!mounted) return;
      setState(() => _shows = shows);
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CreatePodcastScreen()));
    if (created != null) await _load();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar:
          AppBar(title: Text(_t('podcast.titlePlural', 'Podcasts & shows'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.podcasts),
        label: Text(_t('podcast.newShow', 'New show')),
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
                    itemCount: _shows.length,
                    itemBuilder: (_, index) {
                      final show = _shows[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: index * 60),
                        child: PressScale(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PodcastShowScreen(
                                  showId: show['id'].toString(),
                                  user: widget.user),
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: .55)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SmartImage(
                                      url: show['cover_url']?.toString(),
                                      width: 88,
                                      height: 88,
                                      fallbackIcon: Icons.podcasts,
                                      accent: cs.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                                (show['title'] ?? '')
                                                    .toString(),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: cs.onSurface)),
                                          ),
                                          if (show['verified'] == true)
                                            Icon(Icons.verified,
                                                size: 17, color: cs.primary),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                          '${show['owner_name'] ?? ''} · ${show['episodes_count'] ?? 0} ${_t('podcast.episodes', 'episodes')}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: cs.onSurfaceVariant)),
                                      if ((show['description'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 5),
                                          child: Text(
                                              show['description'].toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  height: 1.35,
                                                  color: cs.onSurfaceVariant)),
                                        ),
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

class PodcastShowScreen extends StatefulWidget {
  final String showId;
  final User user;
  const PodcastShowScreen(
      {super.key, required this.showId, required this.user});

  @override
  State<PodcastShowScreen> createState() => _PodcastShowScreenState();
}

class _PodcastShowScreenState extends State<PodcastShowScreen> {
  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? _show;
  List<Map<String, dynamic>> _episodes = [];
  bool _loading = true;
  String? _error;
  String? _playingId;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _playingId = null;
          _position = Duration.zero;
        });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final show = await AuthApi.podcastShow(widget.showId);
      if (!mounted) return;
      setState(() {
        _show = show;
        _episodes = (show['episodes'] is List)
            ? (show['episodes'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
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

  String _time(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggle(Map<String, dynamic> episode) async {
    final url = (episode['audio_url'] ?? '').toString();
    if (url.isEmpty) return;
    final id = episode['id'].toString();
    if (_playingId == id && _playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _player.stop();
    await _player.play(UrlSource(url));
    if (!mounted) return;
    setState(() {
      _playingId = id;
      _playing = true;
      _position = Duration.zero;
    });
  }

  Future<void> _share() async {
    final show = _show;
    if (show == null) return;
    SharePolicy.copy(context,
        allowed: show['verified'] == true,
        text: '${show['title']} · https://masareen.com/podcasts/${show['id']}',
        confirmation: _t('podcast.linkCopied', 'Podcast link copied.'));
  }

  Future<void> _addEpisode() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CreateEpisodeScreen(
              showId: widget.showId,
              showTitle: (_show?['title'] ?? 'Podcast').toString(),
            )));
    if (changed == true) await _load();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading && _show == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_show == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? _t('podcast.notFound', 'Podcast not found.')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _load, child: Text(_t('common.retry', 'Retry'))),
            ],
          ),
        ),
      );
    }
    final show = _show!;
    final owner = show['owner_id'].toString() == widget.user.id;
    return Scaffold(
      appBar: AppBar(
        title: Text((show['title'] ?? '').toString(),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              tooltip: _t('podcast.share', 'Share podcast')),
        ],
      ),
      floatingActionButton: owner
          ? FloatingActionButton.extended(
              onPressed: _addEpisode,
              icon: const Icon(Icons.add),
              label: Text(_t('podcast.newEpisode', 'New episode')),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            FadeSlideIn(
              child: Stack(
                children: [
                  SmartImage(
                      url: show['cover_url']?.toString(),
                      height: 190,
                      width: double.infinity,
                      fallbackIcon: Icons.podcasts,
                      accent: cs.primary),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .7)
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text((show['title'] ?? '').toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (show['verified'] == true)
                              const Icon(Icons.verified,
                                  color: Colors.white, size: 20),
                          ],
                        ),
                        Text(
                            '${show['owner_name'] ?? ''} · ${_episodes.length} ${_t('podcast.episodes', 'episodes')}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if ((show['description'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(show['description'].toString(),
                    style: TextStyle(
                        fontSize: 13.5, height: 1.6, color: cs.onSurface)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(_t('podcast.episodePlural', 'Episodes'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
            ),
            ..._episodes.asMap().entries.map((entry) {
              final episode = entry.value;
              final id = episode['id'].toString();
              final isPlaying = _playingId == id && _playing;
              final progress = _playingId == id && _duration.inMilliseconds > 0
                  ? (_position.inMilliseconds / _duration.inMilliseconds)
                      .clamp(0.0, 1.0)
                  : 0.0;
              return FadeSlideIn(
                delay: Duration(milliseconds: entry.key * 45),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: .55)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _toggle(episode),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: .1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: cs.primary,
                                  size: 24),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${_t('podcast.episode', 'Episode')} ${episode['episode_number']} · ${episode['title']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface)),
                                const SizedBox(height: 3),
                                Text(
                                    [
                                      if ((episode['event_title'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        episode['event_title'].toString(),
                                      if (episode['guests'] is List)
                                        (episode['guests'] as List).join(' · '),
                                      _time(Duration(
                                          seconds:
                                              (episode['duration_sec'] as num?)
                                                      ?.toInt() ??
                                                  0)),
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (episode['verified'] == true)
                            Icon(Icons.verified, size: 16, color: cs.primary),
                        ],
                      ),
                      if (isPlaying) ...[
                        const SizedBox(height: 8),
                        AnimatedProgressBar(value: progress, height: 4),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_time(_position),
                                style: TextStyle(
                                    fontSize: 9.5, color: cs.onSurfaceVariant)),
                            Text(_time(_duration),
                                style: TextStyle(
                                    fontSize: 9.5, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ],
                      if ((episode['description'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(episode['description'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    color: cs.onSurfaceVariant)),
                          ),
                        ),
                      if ((episode['event_id'] ?? '').toString().isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => EventHubScreen(
                                      eventId: episode['event_id'].toString(),
                                      user: widget.user)),
                            ),
                            icon: const Icon(Icons.event_outlined, size: 15),
                            label: Text(_t('podcast.openEvent', 'Open event')),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
