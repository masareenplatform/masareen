import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';

class PaymentsScreen extends StatefulWidget {
  final User user;
  const PaymentsScreen({super.key, required this.user});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  Map<String, dynamic>? _psp;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  final _amountCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  int _selectedMethod = 0;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AuthApi.pspStatus(),
        AuthApi.paymentHistory(widget.user.id),
      ]);
      _psp = results[0] as Map<String, dynamic>;
      _history = results[1] as List<Map<String, dynamic>>;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _selectedMethodKey => _selectedMethod == 0 ? 'card' : 'vodafone_cash';

  Future<void> _pay() async {
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (_selectedMethod == 1 && _phoneCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number required for Vodafone Cash')),
      );
      return;
    }

    setState(() => _paying = true);
    try {
      final resp = await AuthApi.paymobIntent(
        orgId: widget.user.id,
        amountEgp: amount,
        method: _selectedMethodKey,
        phone: _selectedMethod == 1 ? _phoneCtl.text.trim() : null,
      );

      if (!mounted) return;

      final redirectUrl = resp['redirect_url'] as String?;
      final paymentKey = resp['payment_key'] as String?;
      final orderId = resp['order_id']?.toString();

      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        final uri = Uri.parse(redirectUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showResultDialog(
            title: 'Payment Details',
            redirectUrl: redirectUrl,
            paymentKey: paymentKey,
            orderId: orderId,
          );
        }
      } else {
        _showResultDialog(
          title: 'Payment Initiated',
          redirectUrl: null,
          paymentKey: paymentKey,
          orderId: orderId,
        );
      }

      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showResultDialog({
    required String title,
    String? redirectUrl,
    String? paymentKey,
    String? orderId,
  }) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (orderId != null) ...[
              Text('Order ID', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              Text(orderId, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
            if (paymentKey != null) ...[
              Text('Payment Key', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              SelectableText(paymentKey, style: TextStyle(color: cs.onSurface, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            if (redirectUrl != null) ...[
              Text('Redirect URL', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              SelectableText(redirectUrl, style: TextStyle(color: cs.primary, fontSize: 13)),
            ],
            if (redirectUrl == null && paymentKey == null && orderId == null)
              const Text('Payment intent created. Check your inbox for updates.'),
          ],
        ),
        actions: [
          if (redirectUrl != null)
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse(redirectUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open in Browser'),
            ),
          if (redirectUrl != null || paymentKey != null)
            TextButton.icon(
              onPressed: () {
                final text = redirectUrl ?? paymentKey ?? '';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payment_outlined, size: 48, color: cs.outline),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPspStatusCard(cs),
                      const SizedBox(height: 20),
                      _buildTopUpSection(cs),
                      const SizedBox(height: 24),
                      _buildHistorySection(cs),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPspStatusCard(ColorScheme cs) {
    final enabled = _psp?['enabled'] ?? _psp?['is_active'] ?? false;
    final currency = _psp?['currency'] ?? 'EGP';
    final methods = _psp?['methods'] ?? _psp?['available_methods'];
    final methodsList = methods is List
        ? methods.map((m) => m.toString()).toList()
        : <String>[];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (enabled ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  enabled ? Icons.check_circle_outline : Icons.info_outline,
                  color: enabled ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paymob',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      enabled ? 'Active' : 'Unavailable',
                      style: TextStyle(
                        color: enabled ? Colors.green : Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(label: 'Currency', value: currency.toString(), cs: cs),
              const SizedBox(width: 12),
              _InfoChip(
                label: 'Methods',
                value: methodsList.isEmpty ? '—' : methodsList.join(', '),
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpSection(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Up',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Amount (EGP)',
              prefixIcon: const Icon(Icons.attach_money, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.credit_card,
                  label: 'Card',
                  selected: _selectedMethod == 0,
                  cs: cs,
                  onTap: () => setState(() => _selectedMethod = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodCard(
                  icon: Icons.phone_android,
                  label: 'Vodafone Cash',
                  selected: _selectedMethod == 1,
                  cs: cs,
                  onTap: () => setState(() => _selectedMethod = 1),
                ),
              ),
            ],
          ),
          if (_selectedMethod == 1) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Phone number',
                prefixIcon: const Icon(Icons.phone, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _paying ? null : _pay,
              child: _paying
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Pay Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No payments yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ..._history.map((p) => _HistoryTile(payment: p, cs: cs)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  const _InfoChip({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _MethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> payment;
  final ColorScheme cs;
  const _HistoryTile({required this.payment, required this.cs});

  @override
  Widget build(BuildContext context) {
    final status = (payment['status'] ?? payment['state'] ?? '').toString().toUpperCase();
    final amount = payment['amount'] ?? payment['amount_egp'] ?? '';
    final method = (payment['method'] ?? payment['payment_method'] ?? '').toString();
    final createdAt = payment['created_at'] ?? payment['createdAt'];
    final orderId = payment['order_id']?.toString() ?? payment['id']?.toString();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'SUCCESS':
      case 'SUCCESSFUL':
      case 'PAID':
      case 'COMPLETE':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'PENDING':
      case 'PROCESSING':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'FAILED':
      case 'CANCELLED':
      case 'DECLINED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = cs.onSurfaceVariant;
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      amount.toString(),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EGP',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    if (method.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          method,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      status,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        createdAt.toString().length > 10
                            ? createdAt.toString().substring(0, 16).replaceFirst('T', ' ')
                            : createdAt.toString(),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                if (orderId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '#$orderId',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
