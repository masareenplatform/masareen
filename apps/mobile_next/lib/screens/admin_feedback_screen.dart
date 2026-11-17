import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class AdminFeedbackScreen extends StatefulWidget {
  final User user;
  const AdminFeedbackScreen({super.key, required this.user});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _status = '';

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

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
      final rows = await AuthApi.adminFeedback(
          status: _status.isEmpty ? null : _status);
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    try {
      await AuthApi.adminFeedbackStatus(item['id'].toString(), status);
      if (mounted) {
        setState(() => item['status'] = status);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('feedback.updated', 'Feedback updated.'))));
      }
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
    final filters = <(String, String)>[
      ('', _t('feedback.all', 'All')),
      ('OPEN', _t('feedback.open', 'Open')),
      ('REVIEWED', _t('feedback.reviewed', 'Reviewed')),
      ('CLOSED', _t('feedback.closed', 'Closed')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('feedback.adminTitle', 'User feedback')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _status == f.$1,
                      onSelected: (_) {
                        setState(() => _status = f.$1);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorView(message: _error, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(28),
                                child: Center(
                                    child: Text(_t('feedback.empty',
                                        'No feedback in this view.'))),
                              ),
                            ..._items.map((f) => _card(context, cs, f)),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(
      BuildContext context, ColorScheme cs, Map<String, dynamic> f) {
    final type = (f['type'] ?? 'idea').toString();
    final status = (f['status'] ?? 'OPEN').toString();
    final rating = (f['rating'] as num?)?.toInt();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    type == 'bug'
                        ? Icons.bug_report_outlined
                        : type == 'praise'
                            ? Icons.favorite_outline
                            : Icons.lightbulb_outline,
                    color: type == 'bug' ? AppColors.warm : AppColors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(type.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                if (rating != null)
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(i < rating ? Icons.star : Icons.star_border,
                            size: 14, color: AppColors.amber),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(f['message']?.toString() ?? '',
                style: TextStyle(color: cs.onSurface, height: 1.4)),
            const SizedBox(height: 8),
            Text(
                '${f['user_name'] ?? 'Member'} · ${f['user_email'] ?? ''} · ${f['created_at'] ?? ''}',
                style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                _statusChip(cs, status),
                const Spacer(),
                if (status != 'REVIEWED')
                  TextButton(
                      onPressed: () => _setStatus(f, 'REVIEWED'),
                      child: Text(_t('feedback.reviewed', 'Reviewed'))),
                if (status != 'CLOSED')
                  TextButton(
                      onPressed: () => _setStatus(f, 'CLOSED'),
                      child: Text(_t('feedback.closed', 'Closed'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ColorScheme cs, String status) {
    final color = status == 'OPEN'
        ? AppColors.amber
        : status == 'REVIEWED'
            ? AppColors.azure
            : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
