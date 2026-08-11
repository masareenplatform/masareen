import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final ApiService _api = getIt<ApiService>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _invoiceController = TextEditingController();

  String _method = 'card';
  Map<String, dynamic>? _psp;
  List<dynamic> _history = [];
  Map<String, dynamic>? _intent;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final psp = await _api.pspStatus();
      final uid = await _api.currentUserId();
      final orgId = uid.isNotEmpty ? uid : 'mobile-org';
      final history = await _api.paymentHistory(orgId);
      setState(() {
        _psp = psp;
        _history = history;
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  Future<void> _paymob() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _message = 'Enter a valid EGP amount.');
      return;
    }
    final uid = await _api.currentUserId();
    final orgId = uid.isNotEmpty ? uid : 'mobile-org';
    setState(() => _busy = true);
    try {
      final res = await _api.paymobIntent(
        orgId: orgId,
        amountEgp: amount,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        invoiceId: _invoiceController.text.trim().isEmpty ? null : _invoiceController.text.trim(),
        method: _method,
      );
      setState(() => _intent = res);
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = (_psp?['providers']?['paymob']?['methods'] as List?)?.cast<String>() ?? ['card', 'vodafone_cash'];
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_message != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MasarenTheme.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MasarenTheme.gold.withOpacity(0.4)),
              ),
              child: Text(_message!, style: const TextStyle(color: MasarenTheme.navyDark)),
            ),
          const Text('PSP status', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          if (_psp == null)
            const Text('Loading…')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stripe enabled: ${_psp?['providers']?['stripe']?['enabled'] ?? '—'}'),
                    Text('Paymob enabled: ${_psp?['providers']?['paymob']?['enabled'] ?? '—'}'),
                    Text('Paymob currency: ${_psp?['providers']?['paymob']?['currency'] ?? '—'}'),
                    Text('Paymob methods: ${methods.join(', ')}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Make a Paymob payment', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (EGP)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _invoiceController, decoration: const InputDecoration(labelText: 'Invoice id (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: methods.contains(_method) ? _method : methods.first,
            items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _method = v ?? _method),
            decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _busy ? null : _paymob, child: Text(_busy ? 'Working…' : 'Create payment intent')),
          if (_intent != null) ...[
            const SizedBox(height: 12),
            Card(
              color: MasarenTheme.gold.withOpacity(0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment intent created', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Redirect URL: ${_intent?['psp']?['redirect_url'] ?? '—'}'),
                    Text('Payment key: ${_intent?['psp']?['payment_key'] ?? '—'}'),
                    Text('Order id: ${_intent?['psp']?['order_id'] ?? '—'}'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Payment history', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Text('No payments yet.')
          else
            ..._history.map((h) {
              final m = h as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.payment, color: MasarenTheme.navyLight),
                  title: Text('${m['amount'] ?? '—'} ${m['currency'] ?? ''}'),
                  subtitle: Text('${m['provider'] ?? ''} · ${m['status'] ?? ''}'),
                ),
              );
            }),
        ],
      ),
    );
  }
}




