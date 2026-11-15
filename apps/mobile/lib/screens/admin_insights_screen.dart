import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AdminInsightsScreen extends StatefulWidget {
  final User user;
  final int initialTab;
  const AdminInsightsScreen(
      {super.key, required this.user, this.initialTab = 0});

  @override
  State<AdminInsightsScreen> createState() => _AdminInsightsScreenState();
}

class _AdminInsightsScreenState extends State<AdminInsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
  Map<String, dynamic>? _reports;
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _leaderboards = [];
  int _days = 30;
  bool _loading = true;
  String? _error;

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AuthApi.adminReports(days: _days),
        AuthApi.adminAnalytics(days: _days),
        AuthApi.adminTransactions(),
        AuthApi.adminLeaderboards(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as Map<String, dynamic>;
        _analytics = results[1] as Map<String, dynamic>;
        _transactions = results[2] as List<Map<String, dynamic>>;
        _leaderboards = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyReport() async {
    final payload = const JsonEncoder.withIndent('  ').convert({
      'reports': _reports,
      'analytics': _analytics,
      'generated_at': DateTime.now().toIso8601String(),
    });
    await Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('admin.reportCopied',
              'Report JSON copied. Paste it anywhere for archiving.'))));
    }
  }

  Future<void> _export(String kind) async {
    try {
      final bytes = await AuthApi.adminExport(kind, days: _days);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/masareen-$kind-${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _verdict(Map<String, dynamic> item, String status) async {
    try {
      await AuthApi.adminLeaderboardVerdict(item['id'].toString(), status);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('common.failed').replaceAll('{error}', '$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('admin.insights', 'Reports & analytics')),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              setState(() => _days = value);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('7 days')),
              PopupMenuItem(value: 30, child: Text('30 days')),
              PopupMenuItem(value: 90, child: Text('90 days')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'users', child: Text('Users CSV')),
              PopupMenuItem(value: 'transactions', child: Text('MRC ledger CSV')),
              PopupMenuItem(value: 'reports', child: Text('Reports CSV')),
              PopupMenuItem(value: 'impact', child: Text('Impact CSV')),
              PopupMenuItem(value: 'analytics', child: Text('Analytics CSV')),
            ],
          ),
          IconButton(onPressed: _copyReport, icon: const Icon(Icons.copy_all)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: _t('admin.impactReport', 'Impact')),
            Tab(text: _t('admin.productAnalytics', 'Analytics')),
            Tab(text: _t('admin.transactions', 'MRC')),
            Tab(text: _t('admin.leaderboards', 'Leaderboards')),
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
                    _impactTab(cs),
                    _analyticsTab(cs),
                    _transactionsTab(cs),
                    _leaderboardsTab(cs),
                  ],
                ),
    );
  }

  Widget _impactTab(ColorScheme cs) {
    final totals = Map<String, dynamic>.from(
        _reports?['totals'] as Map? ?? <String, dynamic>{});
    final topUsers = (_reports?['top_users'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final bySdg = (_reports?['by_sdg'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _kpi('Users', '${totals['users'] ?? 0}', Icons.people, AppColors.azure),
          _kpi('Posts', '${totals['posts'] ?? 0}', Icons.feed, AppColors.accent),
          _kpi('Impact', '${totals['impact'] ?? 0}', Icons.bolt, AppColors.brand),
          _kpi('MRC spent', '${totals['mrc_spend'] ?? 0}', Icons.paid_outlined,
              AppColors.amber),
        ]),
        SectionTitle(title: _t('admin.bestUsers', 'Best users by impact')),
        ...topUsers.take(12).map((u) => Card(
              child: ListTile(
                leading: AppAvatar(
                    name: u['name']?.toString() ?? 'Member',
                    url: u['avatar_url']?.toString()),
                title: Text(u['name']?.toString() ?? 'Member',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${u['role'] ?? ''} · ${u['posts'] ?? 0} posts'),
                trailing: Text('${u['impact_score'] ?? 0}',
                    style: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w900)),
              ),
            )),
        if (bySdg.isNotEmpty) ...[
          SectionTitle(title: _t('admin.impactBySdg', 'Impact by SDG')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final row in bySdg.take(17))
                Chip(
                    label: Text(
                        'SDG ${row['sdg']} · ${row['count']} posts · ${row['impact']}')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _analyticsTab(ColorScheme cs) {
    final events = (_analytics?['events'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final topPosts = (_analytics?['top_posts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
            '${_t('admin.scrollDepth', 'Avg feed scroll depth')}: '
            '${(_analytics?['avg_scroll_depth'] ?? 0).toStringAsFixed(1)}% · '
            '${_analytics?['scroll_events'] ?? 0} sessions',
            style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        SectionTitle(title: _t('admin.events', 'Tracked events')),
        ...events.take(20).map((e) => ListTile(
              dense: true,
              title: Text(e['event_type']?.toString() ?? ''),
              subtitle: Text('${e['count']} events · ${e['users'] ?? 0} users'
                  '${e['avg_ms'] == null ? '' : ' · ${e['avg_ms']} ms avg'}'),
            )),
        SectionTitle(title: _t('admin.topPosts', 'Top posts')),
        ...topPosts.take(10).map((p) => ListTile(
              dense: true,
              title: Text(p['text']?.toString() ?? '',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${p['author_name'] ?? ''} · ${p['likes'] ?? 0} likes · ${p['comments'] ?? 0} comments'),
            )),
      ],
    );
  }

  Widget _transactionsTab(ColorScheme cs) {
    if (_transactions.isEmpty) {
      return Center(
          child: Text(_t('admin.noTransactions', 'No MRC transactions yet.'),
              style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = _transactions[i];
        final spend = t['type'] == 'SPEND';
        return ListTile(
          leading: Icon(spend ? Icons.arrow_upward : Icons.arrow_downward,
              color: spend ? AppColors.warm : AppColors.brand),
          title: Text(t['user_name']?.toString() ?? 'Member',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${t['reference'] ?? 'Wallet activity'} · ${t['created_at'] ?? ''}'),
          trailing: Text('${spend ? '-' : '+'}${t['amount'] ?? 0} MRC',
              style: TextStyle(
                  color: spend ? AppColors.warm : AppColors.brand,
                  fontWeight: FontWeight.w800)),
        );
      },
    );
  }

  Widget _leaderboardsTab(ColorScheme cs) {
    if (_leaderboards.isEmpty) {
      return Center(
          child: Text(
              _t('admin.noLeaderboards', 'No leaderboards waiting for review.'),
              style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _leaderboards.map((l) {
        final structured = l['structured'] is Map
            ? Map<String, dynamic>.from(l['structured'] as Map)
            : <String, dynamic>{};
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l['text']?.toString() ?? '',
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('${structured['scope'] ?? ''} · ${l['author_name'] ?? ''}',
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => _verdict(l, 'REJECTED'),
                        child: Text(_t('admin.reject', 'Reject'))),
                    FilledButton(
                        onPressed: () => _verdict(l, 'APPROVED'),
                        child: Text(_t('admin.approve', 'Approve'))),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(fontSize: 11.5, color: color)),
        ],
      ),
    );
  }
}
