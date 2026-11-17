import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminOperationsScreen extends StatefulWidget {
  final User user;
  final int initialTab;
  const AdminOperationsScreen({
    super.key,
    required this.user,
    this.initialTab = 0,
  });

  @override
  State<AdminOperationsScreen> createState() => _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends State<AdminOperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 3),
  );

  Map<String, dynamic> _ai = {};
  Map<String, dynamic> _moderation = {};
  Map<String, dynamic> _video = {};
  Map<String, dynamic> _behavior = {};
  Map<String, dynamic> _live = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _moderationStatus = 'REVIEW';
  String _videoStatus = 'all';
  final _behaviorId = TextEditingController();
  final _transcodePost = TextEditingController();
  final _liveTitle = TextEditingController();
  final _liveUrl = TextEditingController();
  final _livePoster = TextEditingController();
  bool _liveEnabled = false;

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
    _tabs.dispose();
    _behaviorId.dispose();
    _transcodePost.dispose();
    _liveTitle.dispose();
    _liveUrl.dispose();
    _livePoster.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AuthApi.adminAiStatus(),
        AuthApi.adminModeration(status: _moderationStatus),
        AuthApi.adminVideoJobs(status: _videoStatus),
        AuthApi.adminSettings(),
        AuthApi.liveTv(),
      ]);
      if (!mounted) return;
      setState(() {
        _ai = results[0];
        _moderation = results[1];
        _video = results[2];
        final settings = results[3]['settings'];
        final map = settings is Map ? Map<String, dynamic>.from(settings) : {};
        _liveTitle.text =
            map['live_tv_title']?.toString() ??
            results[4]['title']?.toString() ??
            '';
        _liveUrl.text =
            map['live_tv_url']?.toString() ??
            results[4]['hls_url']?.toString() ??
            '';
        _livePoster.text = map['live_tv_poster']?.toString() ?? '';
        final enabled = map['live_tv_enabled'];
        _liveEnabled = enabled == null
            ? true
            : ![
                '0',
                'false',
                'off',
                'no',
              ].contains(enabled.toString().toLowerCase());
        _live = results[4];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moderate(String id, String status) => _run(() async {
    await AuthApi.adminModeratePost(id, status);
  });

  Future<void> _resolve(String id) => _run(() async {
    await AuthApi.resolveReport(id);
  });

  Future<void> _loadBehavior() async {
    final id = _behaviorId.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final data = await AuthApi.adminUserBehavior(id);
      if (mounted) setState(() => _behavior = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLive() => _run(() async {
    final result = await AuthApi.saveAdminSettings({
      'live_tv_title': _liveTitle.text.trim(),
      'live_tv_url': _liveUrl.text.trim(),
      'live_tv_poster': _livePoster.text.trim(),
      'live_tv_enabled': _liveEnabled ? '1' : '0',
    });
    if (mounted) {
      setState(() {
        final settings = result['settings'];
        _live = {
          'ok': true,
          'title': _liveTitle.text.trim(),
          'hls_url': _liveUrl.text.trim(),
          'enabled': _liveEnabled,
        };
        if (settings is Map) {
          _live = {..._live, ...Map<String, dynamic>.from(settings)};
        }
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('admin.operations', 'Operations center')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.shield_outlined, size: 18),
              text: _t('admin.moderation', 'Moderation'),
            ),
            Tab(
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              text: _t('admin.aiVideo', 'AI & video'),
            ),
            Tab(
              icon: const Icon(Icons.insights_outlined, size: 18),
              text: _t('admin.behavior', 'User behavior'),
            ),
            Tab(
              icon: const Icon(Icons.live_tv_outlined, size: 18),
              text: _t('admin.liveTv', 'Live TV'),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorView(message: _error, onRetry: _load)
          : TabBarView(
              controller: _tabs,
              children: [
                _moderationTab(cs),
                _aiTab(cs),
                _behaviorTab(cs),
                _liveTab(cs),
              ],
            ),
      bottomNavigationBar: _busy
          ? const LinearProgressIndicator(minHeight: 2)
          : null,
    );
  }

  Widget _moderationTab(ColorScheme cs) {
    final counts = (_moderation['counts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final posts = (_moderation['posts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final reports = (_moderation['open_reports'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in counts)
              Chip(
                avatar: Icon(
                  c['status'] == 'BLOCKED'
                      ? Icons.block
                      : c['status'] == 'REVIEW'
                      ? Icons.flag_outlined
                      : Icons.check_circle_outline,
                  size: 16,
                ),
                label: Text('${c['status']} · ${c['count']}'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'REVIEW', label: Text('Review')),
            ButtonSegment(value: 'PENDING', label: Text('Pending')),
            ButtonSegment(value: 'BLOCKED', label: Text('Blocked')),
            ButtonSegment(value: 'APPROVED', label: Text('Approved')),
          ],
          selected: {_moderationStatus},
          onSelectionChanged: (value) {
            setState(() => _moderationStatus = value.first);
            _load();
          },
        ),
        SectionTitle(title: _t('admin.moderationQueue', 'Moderation queue')),
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_t('admin.noItems', 'Nothing here right now.')),
          ),
        ...posts.map((p) {
          final status = p['status']?.toString() ?? '';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['author_name']?.toString() ?? 'Member',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(
                        label: Text(status),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (p['text'] ?? '').toString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _moderate(p['id'].toString(), 'APPROVED'),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(_t('admin.approve', 'Approve')),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _moderate(p['id'].toString(), 'REJECTED'),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(_t('admin.reject', 'Reject')),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final post = await AuthApi.postById(
                              p['id'].toString(),
                            );
                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(
                                  post: post,
                                  currentUser: widget.user,
                                  onChanged: (_) {},
                                ),
                              ),
                            );
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(_t('common.open', 'Open')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        SectionTitle(
          title:
              _t('admin.openReports', 'Open reports') +
              (reports.isEmpty ? '' : ' · ${reports.length}'),
        ),
        ...reports.map(
          (r) => Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('${r['target_type']} · ${r['reason']}'),
              subtitle: Text(
                '${r['post_text'] ?? r['details'] ?? ''}\n'
                '${r['reporter_name'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: _t('admin.resolve', 'Resolve'),
                onPressed: () => _resolve(r['id'].toString()),
                icon: const Icon(Icons.done_all),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiTab(ColorScheme cs) {
    final embedding = (_ai['embedding'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final jobs = (_ai['failed_jobs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final allJobs = (_video['jobs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final deepfakeRows = (_ai['deepfake'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final evidenceDeepfakeRows = (_ai['evidence_deepfake'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    int flagged(List<Map<String, dynamic>> rows) => rows
        .where((r) => r['status'] == 'LIKELY_AI' || r['status'] == 'SUSPICIOUS')
        .fold(0, (sum, r) => sum + ((r['count'] as num?)?.toInt() ?? 0));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpi(
              'Provider',
              '${_ai['ai_provider'] ?? 'local-hash'}',
              Icons.auto_awesome,
              AppColors.brand,
            ),
            _kpi(
              'Transcription queue',
              '${_ai['transcription_queue'] ?? 0}',
              Icons.graphic_eq,
              AppColors.azure,
            ),
            _kpi(
              'AI-flagged posts',
              '${flagged(deepfakeRows)}',
              Icons.fact_check_outlined,
              AppColors.amber,
            ),
            _kpi(
              'Flagged evidence',
              '${flagged(evidenceDeepfakeRows)}',
              Icons.photo_camera_back_outlined,
              AppColors.amber,
            ),
            _kpi(
              'Failed video jobs',
              '${jobs.length}',
              Icons.error_outline,
              cs.error,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _run(() async {
                final result = await AuthApi.adminAiBackfill();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Embeddings updated: ${result['updated'] ?? 0}',
                      ),
                    ),
                  );
                }
              }),
              icon: const Icon(Icons.auto_fix_high),
              label: Text(_t('admin.backfill', 'Backfill embeddings')),
            ),
            OutlinedButton.icon(
              onPressed: _ai['transcription_configured'] == true
                  ? null
                  : () => _launch('https://developers.openai.com/'),
              icon: const Icon(Icons.key_outlined),
              label: const Text('OpenAI key not set'),
            ),
          ],
        ),
        SectionTitle(title: _t('admin.embeddingStatus', 'Embedding status')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in embedding)
              Chip(label: Text('${e['status']} · ${e['count']}')),
          ],
        ),
        SectionTitle(title: _t('admin.failedJobs', 'Failed video jobs')),
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_t('admin.noItems', 'Nothing here right now.')),
          ),
        ...jobs.map(
          (j) => Card(
            child: ListTile(
              leading: const Icon(Icons.movie_filter_outlined),
              title: Text('Post ${j['post_id'] ?? '—'} · ${j['error'] ?? ''}'),
              subtitle: Text(
                j['original_url']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => _run(() async {
                  await AuthApi.adminRequeueVideoJob(j['id'].toString());
                }),
                child: Text(_t('admin.requeue', 'Requeue')),
              ),
            ),
          ),
        ),
        SectionTitle(title: _t('admin.videoJobs', 'Video jobs')),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _transcodePost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Post ID',
                  hintText: '47',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _run(() async {
                final id = _transcodePost.text.trim();
                if (id.isEmpty) return;
                await AuthApi.adminTranscodePost(id);
              }),
              child: Text(_t('admin.transcode', 'Transcode')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All')),
            ButtonSegment(value: 'queued', label: Text('Queued')),
            ButtonSegment(value: 'processing', label: Text('Processing')),
            ButtonSegment(value: 'ready', label: Text('Ready')),
            ButtonSegment(value: 'error', label: Text('Error')),
          ],
          selected: {_videoStatus},
          onSelectionChanged: (value) {
            setState(() => _videoStatus = value.first);
            _load();
          },
        ),
        const SizedBox(height: 8),
        ...allJobs
            .take(50)
            .map(
              (j) => Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    j['status'] == 'ready'
                        ? Icons.check_circle_outline
                        : j['status'] == 'error'
                        ? Icons.error_outline
                        : Icons.hourglass_bottom,
                  ),
                  title: Text(
                    '${j['status']} · post ${j['post_id'] ?? '—'} · ${j['id']}',
                  ),
                  subtitle: Text(
                    j['hls_url']?.toString() ??
                        j['original_url']?.toString() ??
                        '',
                  ),
                  trailing: j['status'] == 'error'
                      ? IconButton(
                          onPressed: () => _run(() async {
                            await AuthApi.adminRequeueVideoJob(
                              j['id'].toString(),
                            );
                          }),
                          icon: const Icon(Icons.refresh),
                        )
                      : null,
                ),
              ),
            ),
      ],
    );
  }

  Widget _behaviorTab(ColorScheme cs) {
    final user = Map<String, dynamic>.from(
      _behavior['user'] as Map? ?? <String, dynamic>{},
    );
    final summary = Map<String, dynamic>.from(
      _behavior['summary'] as Map? ?? <String, dynamic>{},
    );
    final events = (_behavior['events'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final recent = (_behavior['recent'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _behaviorId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  hintText: '12',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loadBehavior,
              icon: const Icon(Icons.search),
              label: Text(_t('common.search', 'Search')),
            ),
          ],
        ),
        if (user.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: AppAvatar(name: user['name']?.toString() ?? 'Member'),
              title: Text(
                user['name']?.toString() ?? 'Member',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${user['email'] ?? ''} · ${user['role'] ?? ''}\n'
                'Last active: ${user['last_active_at'] ?? '—'}',
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpi(
                'Events',
                '${summary['events'] ?? 0}',
                Icons.touch_app,
                AppColors.azure,
              ),
              _kpi(
                'Watch time',
                '${((summary['watch_ms'] ?? 0) / 60000).toStringAsFixed(1)} min',
                Icons.play_circle_outline,
                AppColors.brand,
              ),
              _kpi(
                'Post views',
                '${summary['post_views'] ?? 0}',
                Icons.visibility_outlined,
                AppColors.accent,
              ),
              _kpi(
                'MRC balance',
                '${summary['mrc_balance'] ?? 0}',
                Icons.token_outlined,
                AppColors.amber,
              ),
            ],
          ),
        ],
        SectionTitle(title: _t('admin.eventMix', 'Event mix')),
        ...events.map(
          (e) => ListTile(
            dense: true,
            leading: const Icon(Icons.insights),
            title: Text(e['event_type']?.toString() ?? ''),
            subtitle: Text(
              'duration ${e['duration_ms'] ?? 0} ms · value ${e['total_value'] ?? 0}',
            ),
            trailing: Text(
              '${e['count'] ?? 0}',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SectionTitle(title: _t('admin.recentEvents', 'Recent events')),
        ...recent
            .take(40)
            .map(
              (e) => ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 18),
                title: Text(
                  '${e['event_type']} · ${e['target_type'] ?? e['target_id'] ?? ''}',
                ),
                subtitle: Text(
                  '${e['created_at']} · ${e['duration_ms'] ?? 0} ms',
                ),
              ),
            ),
      ],
    );
  }

  Widget _liveTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.live_tv,
                      color: _live['enabled'] == true
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _live['enabled'] == true
                            ? 'Live channel is on air'
                            : 'Live channel is offline',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: _liveEnabled,
                      onChanged: (v) => setState(() => _liveEnabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Playlist: ${_live['hls_url'] ?? 'not configured yet'}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                if (_live['hls_url'] != null)
                  TextButton.icon(
                    onPressed: () => _launch(_live['hls_url'].toString()),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Test playlist'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liveTitle,
          decoration: const InputDecoration(
            labelText: 'Channel title',
            hintText: 'MASAREEN Live TV',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liveUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'HLS playlist URL',
            hintText: 'https://masareen.com/live/tv/index.m3u8',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _livePoster,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Poster image URL (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _saveLive,
          icon: const Icon(Icons.save_outlined),
          label: Text(_t('common.save', 'Save')),
        ),
        const SizedBox(height: 20),
        Text(
          'Broadcast from the studio computer with tools/media/live.ps1 and '
          'tools/media/broadcast-tv.ps1. The playlist stays behind the '
          'masareen.com/live proxy so it works in the app and on the web.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    final width = ((MediaQuery.sizeOf(context).width - 52) / 3).clamp(
      104.0,
      190.0,
    );
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
