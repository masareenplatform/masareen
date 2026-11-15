import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class CreateLeaderboardScreen extends StatefulWidget {
  final User user;
  const CreateLeaderboardScreen({super.key, required this.user});

  @override
  State<CreateLeaderboardScreen> createState() =>
      _CreateLeaderboardScreenState();
}

class _CreateLeaderboardScreenState extends State<CreateLeaderboardScreen> {
  static const _scopes = [
    'institutions',
    'governments',
    'programs',
    'opportunities',
    'events',
    'courses',
    'projects',
  ];
  final _title = TextEditingController();
  String _scope = 'institutions';
  String _period = 'month';
  String _metric = 'impact';
  Map<String, dynamic> _entities = {};
  final Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;

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
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await AuthApi.leaderboardOptions();
      if (mounted) {
        setState(() => _entities =
            Map<String, dynamic>.from(data['entities'] as Map? ?? {}));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      final post = await AuthApi.createLeaderboard({
        'scope': _scope,
        'period': _period,
        'metric': _metric,
        'title': _title.text.trim(),
        'entity_ids': _selected.map(int.tryParse).whereType<int>().toList(),
      });
      if (mounted) Navigator.pop(context, post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                _t('common.failed').replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final owned = (_entities[_scope] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text(_t('leaderboards.create', 'Create leaderboard'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      gradient: brandGradient,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _t('leaderboards.hero',
                              'Turn impact into a ranking your community can share'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      const SizedBox(height: 6),
                      Text(
                          _t('leaderboards.heroHint',
                              'Choose a category, period and the entities you own. Leaderboards are reviewed before going public.'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  maxLength: 140,
                  decoration: InputDecoration(
                      labelText: _t('leaderboards.title', 'Headline'),
                      hintText: _t('leaderboards.titleHint',
                          'Top institutions creating change this month')),
                ),
                const SizedBox(height: 4),
                Text(_t('leaderboards.type', 'Leaderboard type'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final scope in _scopes)
                      ChoiceChip(
                        label: Text(scope[0].toUpperCase() + scope.substring(1)),
                        selected: _scope == scope,
                        onSelected: (_) => setState(() {
                          _scope = scope;
                          _selected.clear();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _period,
                        decoration: InputDecoration(
                            labelText: _t('leaderboards.period', 'Period')),
                        items: [
                          DropdownMenuItem(
                              value: 'week',
                              child: Text(_t('leaderboards.week', 'This week'))),
                          DropdownMenuItem(
                              value: 'month',
                              child:
                                  Text(_t('leaderboards.month', 'This month'))),
                          DropdownMenuItem(
                              value: 'all',
                              child:
                                  Text(_t('leaderboards.allTime', 'All time'))),
                        ],
                        onChanged: (value) =>
                            setState(() => _period = value ?? _period),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _metric,
                        decoration: InputDecoration(
                            labelText: _t('leaderboards.metric', 'Rank by')),
                        items: [
                          DropdownMenuItem(
                              value: 'impact',
                              child:
                                  Text(_t('leaderboards.impact', 'Impact'))),
                          DropdownMenuItem(
                              value: 'participants',
                              child: Text(_t(
                                  'leaderboards.participants', 'Participants'))),
                          DropdownMenuItem(
                              value: 'posts',
                              child: Text(_t('leaderboards.posts', 'Posts'))),
                        ],
                        onChanged: (value) =>
                            setState(() => _metric = value ?? _metric),
                      ),
                    ),
                  ],
                ),
                if (owned.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                      _t('leaderboards.selectEntities',
                          'Select the entities you own (optional)'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final entity in owned)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value:
                          _selected.contains(entity['id']?.toString()),
                      title: Text(entity['name']?.toString() ?? 'Entity'),
                      onChanged: (checked) {
                        final id = entity['id']?.toString();
                        if (id == null) return;
                        setState(() {
                          if (checked == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                    ),
                ],
                const SizedBox(height: 10),
                Text(
                    _t('leaderboards.moderation',
                        'Non-admin leaderboards are reviewed by the platform before appearing in the feed.'),
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _publish,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.leaderboard_rounded, size: 18),
                  label: Text(_t('leaderboards.publish', 'Submit leaderboard')),
                ),
              ],
            ),
    );
  }
}
