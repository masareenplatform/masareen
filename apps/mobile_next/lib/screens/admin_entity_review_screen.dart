import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class AdminEntityReviewScreen extends StatefulWidget {
  final User user;
  const AdminEntityReviewScreen({super.key, required this.user});

  @override
  State<AdminEntityReviewScreen> createState() =>
      _AdminEntityReviewScreenState();
}

class _AdminEntityReviewScreenState extends State<AdminEntityReviewScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

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
      final rows = await AuthApi.adminEntities(status: 'PENDING');
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _t(BuildContext context, String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  String _typeLabel(BuildContext context, String type) {
    switch (type) {
      case 'course':
        return _t(context, 'nav.courses', 'Course');
      case 'event':
        return _t(context, 'nav.events', 'Event');
      case 'program':
        return _t(context, 'nav.programs', 'Program');
      case 'project':
        return _t(context, 'nav.projects', 'Project');
      case 'opportunity':
        return _t(context, 'nav.opportunities', 'Opportunity');
    }
    return type;
  }

  IconData _icon(String type) {
    switch (type) {
      case 'course':
        return Icons.school_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'program':
        return Icons.hub_outlined;
      case 'project':
        return Icons.handshake_outlined;
      case 'opportunity':
        return Icons.work_outline;
    }
    return Icons.category_outlined;
  }

  Future<void> _verdict(Map<String, dynamic> item, String status,
      {String? reason}) async {
    final key = '${item['type']}:${item['id']}';
    setState(() => _busy.add(key));
    try {
      await AuthApi.adminEntityVerdict(
        type: item['type'].toString(),
        id: item['id'].toString(),
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e['id'] == item['id']));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t(
              context,
              status == 'APPROVED'
                  ? 'admin.entityApproved'
                  : 'admin.entityRejected',
              status == 'APPROVED' ? 'Approved.' : 'Rejected.'))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t(context, 'common.failed')
                .replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t(context, 'admin.rejectReason')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
              labelText: _t(context, 'admin.rejectReason')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(_t(context, 'action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(_t(context, 'admin.reject'))),
        ],
      ),
    );
    if (ok == true) {
      await _verdict(item, 'REJECTED', reason: controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'admin.entityReview')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SectionTitle(
                          title: _t(context, 'admin.pendingEntities')),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              _t(context, 'admin.noPendingEntities'),
                              style:
                                  TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ..._items.map((item) => _card(context, cs, item)),
                    ],
                  ),
                ),
    );
  }

  Widget _card(
      BuildContext context, ColorScheme cs, Map<String, dynamic> item) {
    final type = item['type'].toString();
    final key = '$type:${item['id']}';
    final busy = _busy.contains(key);
    final fee = (item['creation_fee_mrc'] as num?)?.toDouble() ?? 0;
    final created = (item['created_at'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(_icon(type),
                      color: cs.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title']?.toString() ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                      Text(
                          '${_typeLabel(context, type)} · '
                          '${_t(context, 'admin.author')}: ${item['author_name'] ?? ''}',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 11.5)),
                      if (fee > 0)
                        Text(
                            _t(context, 'admin.fee')
                                .replaceAll('{fee}', fee.toStringAsFixed(0)),
                            style: const TextStyle(
                                color: AppColors.amber, fontSize: 11.5)),
                      if (created.length >= 10)
                        Text(created.substring(0, 10),
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _reject(item),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(_t(context, 'admin.reject')),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warm,
                        side: const BorderSide(color: AppColors.warm)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _verdict(item, 'APPROVED'),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check, size: 16),
                    label: Text(_t(context, 'admin.approve')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
