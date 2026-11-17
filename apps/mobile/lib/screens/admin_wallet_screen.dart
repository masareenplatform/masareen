import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';

class AdminWalletScreen extends StatefulWidget {
  final User user;
  const AdminWalletScreen({super.key, required this.user});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  List<Map<String, dynamic>> _rows = [];
  final Set<String> _busy = {};
  String _filter = 'PENDING';
  bool _loading = true;
  String? _error;

  String _t(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

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
      final rows = await AuthApi.adminWalletRequests();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> row, String status) async {
    final id = row['id'].toString();
    final isReject = status == 'REJECTED';
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReject
            ? _t(context, 'Reject request', 'رفض الطلب')
            : _t(context, 'Approve request', 'اعتماد الطلب')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${row['user_name'] ?? row['user_email'] ?? ''} · ${row['kind']} · ${row['amount_mrc']} MRC'),
            if (isReject) ...[
              const SizedBox(height: 12),
              TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText:
                          _t(context, 'Reason (optional)', 'السبب (اختياري)'))),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t(context, 'Cancel', 'إلغاء'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isReject
                  ? _t(context, 'Reject', 'رفض')
                  : _t(context, 'Approve', 'اعتماد'))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy.add(id));
    try {
      await AuthApi.adminResolveWalletRequest(id, status, note: note.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isReject
              ? _t(context, 'Request rejected.', 'تم رفض الطلب.')
              : _t(context, 'Request approved.', 'تم اعتماد الطلب.'))));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Color _statusColor(String status) => switch (status) {
        'APPROVED' => AppColors.brand,
        'REJECTED' => AppColors.warm,
        _ => AppColors.amber,
      };

  String _date(dynamic value) {
    final raw = value?.toString() ?? '';
    return raw.length >= 16 ? raw.substring(0, 16).replaceFirst('T', ' ') : raw;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filter == 'ALL'
        ? _rows
        : _rows.where((r) => r['status'] == _filter).toList();
    final pending = _rows.where((r) => r['status'] == 'PENDING').toList();
    final pendingBuy = pending
        .where((r) => r['kind'] == 'BUY')
        .fold<double>(0, (sum, r) => sum + (r['amount_egp'] as num? ?? 0));
    final pendingCash = pending
        .where((r) => r['kind'] == 'CASHOUT')
        .fold<double>(0, (sum, r) => sum + (r['amount_egp'] as num? ?? 0));

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_t(context, 'MRC payments & invoices', 'مدفوعات وفواتير MRC')),
        actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _summary(_t(context, 'Pending', 'قيد المراجعة'),
                            pending.length.toString(), AppColors.amber),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summary(
                            _t(context, 'To collect', 'للتحصيل'),
                            '${pendingBuy.toStringAsFixed(0)} EGP',
                            AppColors.brand),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summary(
                            _t(context, 'To pay out', 'للصرف'),
                            '${pendingCash.toStringAsFixed(0)} EGP',
                            AppColors.warm),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['PENDING', 'APPROVED', 'REJECTED', 'ALL']
                          .map((value) => Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(end: 6),
                                child: ChoiceChip(
                                  label: Text(value == 'ALL'
                                      ? _t(context, 'All', 'الكل')
                                      : _statusLabel(context, value)),
                                  selected: _filter == value,
                                  onSelected: (_) =>
                                      setState(() => _filter = value),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(
                      color: cs.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(_error!,
                            style: TextStyle(color: cs.onErrorContainer)),
                      ),
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 70),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 50, color: cs.outline),
                          const SizedBox(height: 10),
                          Text(
                              _t(context, 'No requests in this view.',
                                  'لا توجد طلبات في هذا العرض.'),
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((row) => _requestCard(context, row)),
                ],
              ),
            ),
    );
  }

  String _statusLabel(BuildContext context, String status) => switch (status) {
        'APPROVED' => _t(context, 'Approved', 'معتمد'),
        'REJECTED' => _t(context, 'Rejected', 'مرفوض'),
        _ => _t(context, 'Pending', 'قيد المراجعة'),
      };

  Widget _summary(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> row) {
    final cs = Theme.of(context).colorScheme;
    final status = row['status']?.toString() ?? 'PENDING';
    final id = row['id'].toString();
    final busy = _busy.contains(id);
    final color = _statusColor(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(
                      row['kind'] == 'BUY'
                          ? Icons.south_west
                          : Icons.north_east,
                      color: color,
                      size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          row['user_name']?.toString() ??
                              row['user_email']?.toString() ??
                              'Member',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(row['user_email']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(context, status),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('${row['kind']} · ${row['amount_mrc']} MRC',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${row['amount_egp']} EGP',
                    style: TextStyle(color: cs.primary)),
                Text(row['method']?.toString() ?? '',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                Text(_date(row['created_at']),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            if ((row['account_ref']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Ref: ${row['account_ref']}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
            if ((row['admin_note']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${_t(context, 'Admin note', 'ملاحظة الإدارة')}: ${row['admin_note']}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
            if (status == 'PENDING') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                      onPressed: busy ? null : () => _decide(row, 'REJECTED'),
                      child: Text(_t(context, 'Reject', 'رفض'))),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                      onPressed: busy ? null : () => _decide(row, 'APPROVED'),
                      icon: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(_t(context, 'Approve', 'اعتماد'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
