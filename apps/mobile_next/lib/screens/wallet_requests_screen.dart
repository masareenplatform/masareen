import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

class WalletRequestsScreen extends StatefulWidget {
  final User user;
  const WalletRequestsScreen({super.key, required this.user});

  @override
  State<WalletRequestsScreen> createState() => _WalletRequestsScreenState();
}

class _WalletRequestsScreenState extends State<WalletRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthApi.walletRequests(),
        AuthApi.invoices(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0];
        _invoices = results[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(String kind) async {
    final amount = TextEditingController();
    final method = TextEditingController(text: 'InstaPay');
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == 'BUY' ? 'Buy MRC' : 'Cash out MRC'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount in MRC')),
          const SizedBox(height: 14),
          TextField(
              controller: method,
              decoration: const InputDecoration(labelText: 'Method')),
          const SizedBox(height: 14),
          TextField(
              controller: ref,
              decoration: const InputDecoration(
                  labelText: 'InstaPay / bank reference')),
          const SizedBox(height: 12),
          const Text(
              'Manual processing until Paymob is activated. 1 MRC = 1 EGP.',
              style: TextStyle(fontSize: 11)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthApi.requestWalletPayment(
          kind, double.tryParse(amount.text) ?? 0,
          method: method.text.trim(), accountRef: ref.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted for admin review.')));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('MRC & invoices')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    Expanded(
                        child: FilledButton.icon(
                            onPressed: () => _request('BUY'),
                            icon: const Icon(Icons.add_card),
                            label: const Text('Buy MRC'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () => _request('CASHOUT'),
                            icon: const Icon(Icons.account_balance),
                            label: const Text('Cash out'))),
                  ]),
                  const SizedBox(height: 18),
                  const SectionTitle(title: 'Requests'),
                  if (_requests.isEmpty)
                    Text('No requests yet.',
                        style: TextStyle(color: cs.onSurfaceVariant))
                  else
                    ..._requests.map((r) => Card(
                          child: ListTile(
                            leading: Icon(
                                r['kind'] == 'BUY'
                                    ? Icons.south_west
                                    : Icons.north_east,
                                color: cs.primary),
                            title: Text(
                                '${r['kind']} ${r['amount_mrc']} MRC = ${r['amount_egp']} EGP'),
                            subtitle: Text(
                                '${r['status']} | ${r['method']} ${r['account_ref'] ?? ''}'),
                          ),
                        )),
                  const SizedBox(height: 16),
                  const SectionTitle(title: 'Invoices'),
                  if (_invoices.isEmpty)
                    Text('No invoices yet.',
                        style: TextStyle(color: cs.onSurfaceVariant))
                  else
                    ..._invoices.take(40).map((i) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(i['number']?.toString() ?? 'Invoice'),
                            subtitle: Text(
                                '${i['kind']} | ${i['description'] ?? ''}'),
                            trailing: Text('${i['amount_mrc']} MRC',
                                style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800)),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
