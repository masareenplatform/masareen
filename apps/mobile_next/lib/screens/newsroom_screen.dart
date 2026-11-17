import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/content_engagement.dart';
import 'package:masaren/screens/news_journalists_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsroomScreen extends StatefulWidget {
  final User user;
  const NewsroomScreen({super.key, required this.user});

  @override
  State<NewsroomScreen> createState() => _NewsroomScreenState();
}

class _NewsroomScreenState extends State<NewsroomScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _mine = false;
  String? _error;

  bool get _canPublish =>
      widget.user.isAdmin ||
      [
        'MEDIA',
        'ORGANIZATION',
        'UNIVERSITY',
        'INSTITUTION',
        'GOVERNMENT',
      ].contains(widget.user.role);

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
      final items = await AuthApi.newsList(mine: _mine);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> article) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsArticleScreen(
          articleId: article['id'].toString(),
          user: widget.user,
        ),
      ),
    );
    _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => NewsEditorScreen(user: widget.user)),
    );
    if (created != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('MASAREEN Newsroom'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (_canPublish)
            IconButton(
              tooltip: 'New article',
              onPressed: _create,
              icon: const Icon(Icons.edit_note),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2C6E8F), Color(0xFF174B43)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified data. Real reporting.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'News outlets publish evidence-backed articles, attach live platform data and earn from funded reporting. The platform keeps 30% of funding as brokerage.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Published'),
                            selected: !_mine,
                            onSelected: (_) {
                              setState(() => _mine = false);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          if (_canPublish)
                            ChoiceChip(
                              label: const Text('My newsroom'),
                              selected: _mine,
                              onSelected: (_) {
                                setState(() => _mine = true);
                                _load();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No articles yet.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        ..._items.map(
                          (a) => _NewsCard(article: a, onTap: () => _open(a)),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: _canPublish
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Write'),
            )
          : null,
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final VoidCallback onTap;
  const _NewsCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((article['cover_url'] ?? '').toString().isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  article['cover_url'].toString(),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (article['verification_status'] == 'VERIFIED')
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(
                            Icons.verified,
                            size: 15,
                            color: AppColors.brand,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          (article['outlet_name'] ?? 'Newsroom').toString(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      Text(
                        article['created_at'] == null
                            ? ''
                            : DateFormat.yMMMd().format(
                                DateTime.parse(
                                  article['created_at'].toString(),
                                ),
                              ),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (article['title'] ?? '').toString(),
                    textDirection: textDirectionFor(
                      (article['title'] ?? '').toString(),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((article['summary'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      article['summary'].toString(),
                      textDirection: textDirectionFor(
                        article['summary'].toString(),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: AppColors.accent,
                      ),
                      Text(
                        ' ${article['rating_avg'] ?? 0}',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      Text(
                        ' ${article['views'] ?? 0}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${article['mrc_earned'] ?? 0} MRC earned',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsArticleScreen extends StatefulWidget {
  final String articleId;
  final User user;
  const NewsArticleScreen({
    super.key,
    required this.articleId,
    required this.user,
  });

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  Map<String, dynamic>? _article;
  List<Map<String, dynamic>> _verifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthApi.newsDetail(widget.articleId),
        AuthApi.newsVerifications(widget.articleId),
      ]);
      if (mounted) {
        setState(() {
          _article = results[0] as Map<String, dynamic>;
          _verifications = results[1] as List<Map<String, dynamic>>;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canVerify {
    final role = widget.user.role.toUpperCase();
    return widget.user.isAdmin ||
        [
          'JOURNALIST',
          'MEDIA',
          'ACADEMIC',
          'RESEARCHER',
          'TEACHING_ASSISTANT',
          'ASSISTANT_LECTURER',
          'LECTURER',
          'ASSISTANT_PROFESSOR',
          'ASSOCIATE_PROFESSOR',
          'PROFESSOR',
        ].contains(role);
  }

  Future<void> _verify() async {
    final notes = TextEditingController();
    String verdict = 'VERIFIED';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Verify this story'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: verdict,
                decoration: const InputDecoration(labelText: 'Verdict'),
                items: const [
                  DropdownMenuItem(value: 'VERIFIED', child: Text('Verified')),
                  DropdownMenuItem(value: 'DISPUTED', child: Text('Disputed')),
                  DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                ],
                onChanged: (v) => setDialog(() => verdict = v ?? verdict),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reviewer notes',
                  helperText: 'Your review earns 5 MRC and feeds news impact.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit review'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final result = await AuthApi.verifyNews(
        widget.articleId,
        verdict,
        notes: notes.text,
        confidence: 0.8,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review saved. +${result['reward_mrc'] ?? 5} MRC.'),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      notes.dispose();
    }
  }

  Future<void> _openSource() async {
    final url = _article?['source_url']?.toString() ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rate(int stars) async {
    try {
      await AuthApi.rateNews(widget.articleId, stars);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _fund() async {
    final amount = TextEditingController(text: '100');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fund this reporting'),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'MRC amount',
            helperText: '70% goes to the outlet, 30% platform brokerage.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(amount.text.trim())),
            child: const Text('Fund'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (result == null) return;
    try {
      final res = await AuthApi.fundNews(widget.articleId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Funded. Outlet received ${res['payout_mrc']} MRC; platform fee ${res['platform_fee_mrc']} MRC.',
            ),
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = _article;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Not found')),
      );
    }
    final snapshot = a['data_snapshot'];
    return Scaffold(
      appBar: AppBar(
        title: Text((a['outlet_name'] ?? 'Newsroom').toString()),
        actions: [
          if (_canVerify && a['author_id']?.toString() != widget.user.id)
            IconButton(
              onPressed: _verify,
              tooltip: 'Verify story',
              icon: const Icon(Icons.fact_check_outlined),
            ),
          IconButton(
            onPressed: _fund,
            tooltip: 'Fund this reporting',
            icon: const Icon(Icons.volunteer_activism_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          if ((a['cover_url'] ?? '').toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                a['cover_url'].toString(),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (a['verification_status'] == 'VERIFIED')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'VERIFIED DATA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '${a['views'] ?? 0} views',
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (a['title'] ?? '').toString(),
            textDirection: textDirectionFor((a['title'] ?? '').toString()),
            style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${a['journalist'] is Map ? (a['journalist']['title'] ?? 'Correspondent') : 'Newsroom'} · ${a['outlet_name'] ?? a['source_name'] ?? ''}',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (a['journalist'] is Map)
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: AppAvatar(
                  name: a['journalist']['name']?.toString() ?? 'Journalist',
                  url: a['journalist']['avatar_url']?.toString(),
                  size: 38,
                ),
                title: Text(
                  a['journalist']['name']?.toString() ?? 'Journalist',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  a['outlet_name']?.toString() ?? '',
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JournalistProfileScreen(
                      journalistId: a['journalist']['id'].toString(),
                      user: widget.user,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if ((a['source_url'] ?? '').toString().isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _openSource,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('Read at ${a['source_name'] ?? 'source'}'),
              ),
            ),
          const SizedBox(height: 10),
          if ((a['summary'] ?? '').toString().isNotEmpty)
            Text(
              a['summary'].toString(),
              textDirection: textDirectionFor(a['summary'].toString()),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          if (a['media'] is List && (a['media'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: (a['media'] as List).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = (a['media'] as List)[i];
                  if (m is! Map) return const SizedBox.shrink();
                  final type = m['type']?.toString() ?? 'PHOTO';
                  final url = m['url']?.toString() ?? '';
                  return InkWell(
                    onTap: url.isEmpty
                        ? null
                        : () => launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          if (type == 'VIDEO')
                            Container(
                              width: 190,
                              color: cs.surfaceContainerHigh,
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 42,
                                color: cs.primary,
                              ),
                            )
                          else
                            Image.network(
                              url,
                              width: 190,
                              height: 128,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(width: 190),
                            ),
                          if (type == 'VIDEO')
                            const Positioned(
                              right: 8,
                              bottom: 8,
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (snapshot is Map) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withValues(alpha: .15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verified data snapshot · ${snapshot['type'] ?? ''}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (snapshot['title'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (snapshot['metrics'] is Map)
                    ...(snapshot['metrics'] as Map).entries.map(
                          (e) => Text(
                            '${e.key.replaceAll('_', ' ')}: ${e.value}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            a['body'].toString(),
            textDirection: textDirectionFor(a['body'].toString()),
            style: const TextStyle(fontSize: 15, height: 1.65),
          ),
          const SizedBox(height: 14),
          ContentEngagement(
            targetType: 'news',
            targetId: widget.articleId,
            user: widget.user,
            initialReactions: (a['reaction_count'] as num?)?.toInt() ?? 0,
            initialComments: (a['comment_count'] as num?)?.toInt() ?? 0,
            initiallyReacted: a['reacted'] == true,
            initialMyReaction: a['my_reaction']?.toString(),
          ),
          if (_verifications.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reviewer verifications',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            ..._verifications.take(5).map(
                  (v) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        v['verdict'] == 'VERIFIED'
                            ? Icons.verified_outlined
                            : Icons.flag_outlined,
                        color: v['verdict'] == 'VERIFIED'
                            ? AppColors.brand
                            : AppColors.warm,
                      ),
                      title: Text(
                        v['reviewer_name']?.toString() ?? 'Reviewer',
                      ),
                      subtitle: Text(
                        '${v['verdict']} · ${v['notes'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Rate this article',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              for (var i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _rate(i),
                  icon: const Icon(
                    Icons.star_border_rounded,
                    size: 22,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          Text(
            '${a['rating_avg']} / 5 from ${a['rating_count']} ratings',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _fund,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: Text(
              'Fund reporting · ${a['funding_raised_mrc']} / ${a['funding_goal_mrc']} MRC',
            ),
          ),
        ],
      ),
    );
  }
}

class NewsEditorScreen extends StatefulWidget {
  final User user;
  const NewsEditorScreen({super.key, required this.user});

  @override
  State<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends State<NewsEditorScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _body = TextEditingController();
  final _entityType = TextEditingController(text: 'EVENT');
  final _entityId = TextEditingController();
  final _goal = TextEditingController();
  String? _coverUrl;
  String? _coverPath;
  Map<String, dynamic>? _snapshot;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _entityType.dispose();
    _entityId.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 84,
    );
    if (picked == null) return;
    setState(() {
      _coverPath = picked.path;
      _uploading = true;
    });
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final url = await AuthApi.uploadMedia(
        bytes,
        picked.name,
        ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/jpeg',
      );
      if (mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _attachData() async {
    try {
      final snapshot = await AuthApi.newsSnapshot(
        _entityType.text.trim().toUpperCase(),
        _entityId.text.trim(),
      );
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _save({required bool draft}) async {
    if (_title.text.trim().length < 5 || _body.text.trim().length < 30) {
      setState(() => _error = 'Add a headline and a substantive article body.');
      return;
    }
    if (_uploading) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final article = await AuthApi.createNews({
        'title': _title.text.trim(),
        'summary': _summary.text.trim(),
        'body': _body.text.trim(),
        'cover_url': _coverUrl,
        'status': draft ? 'DRAFT' : 'PUBLISHED',
        'funding_goal_mrc': double.tryParse(_goal.text.trim()) ?? 0,
        if (_snapshot != null) 'data_snapshot': _snapshot,
      });
      if (mounted) Navigator.pop(context, article);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('News editor'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _save(draft: true),
            child: const Text('Draft'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _save(draft: false),
            child: const Text('Publish'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          TextField(
            controller: _title,
            maxLength: 180,
            decoration: const InputDecoration(
              labelText: 'Headline',
              helperText: 'Specific, factual and data-led.',
            ),
          ),
          TextField(
            controller: _summary,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Standfirst'),
          ),
          if (_coverPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(_coverPath!),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickCover,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _uploading ? 'Uploading cover...' : 'Add cover from device',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Verified data snapshot',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _entityType.text,
                  items: const ['EVENT', 'USER', 'PROGRAM', 'PROJECT']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _entityType.text = v ?? 'EVENT'),
                  decoration: const InputDecoration(labelText: 'Entity'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _entityId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Entity ID'),
                ),
              ),
              IconButton.filled(
                onPressed: _attachData,
                icon: const Icon(Icons.analytics_outlined),
              ),
            ],
          ),
          if (_snapshot != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Attached verified snapshot: ${_snapshot!['title']} · ${_snapshot!['metrics']}',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: 30,
            maxLength: 30000,
            decoration: const InputDecoration(
              labelText: 'Article body',
              alignLabelWithHint: true,
            ),
          ),
          TextField(
            controller: _goal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Crowdfunding goal (MRC, optional)',
              helperText:
                  '70% of funding goes to your outlet, 30% platform brokerage.',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
