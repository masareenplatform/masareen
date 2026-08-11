import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _api = getIt<ApiService>();
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _fiatController = TextEditingController();

  late Future<String> _userIdFuture;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _rate;
  Map<String, dynamic>? _fee;
  List<dynamic> _transactions = [];
  bool _convertDeposit = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _userIdFuture = _api.currentUserId();
    _load();
  }

  Future<void> _load() async {
    final uid = await _userIdFuture;
    final fee = await _api.getFee();
    final rate = await _api.getRate(currency: 'EGP');
    if (uid.isEmpty) {
      setState(() => _message = 'No logged-in user found.');
      return;
    }
    try {
      final wallet = await _api.getWallet(uid);
      if (wallet.isEmpty) {
        await _api.createWallet(uid);
      }
      final wallet2 = await _api.getWallet(uid);
      final tx = await _api.history(uid);
      setState(() {
        _wallet = wallet2;
        _rate = rate;
        _fee = fee;
        _transactions = tx;
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  double get _feeRate => (_fee?['fee_rate'] is num) ? (_fee!['fee_rate'] as num).toDouble() : 0.0;
  double get _rateToMrc => (_rate?['rate_to_mrc'] is num) ? (_rate!['rate_to_mrc'] as num).toDouble() : 0.0;

  double get _estimatedFeeMrc {
    final fiat = double.tryParse(_fiatController.text) ?? 0.0;
    final gross = fiat * _rateToMrc;
    return gross * _feeRate;
  }

  Future<void> _doConvert() async {
    final uid = await _userIdFuture;
    final fiat = double.tryParse(_fiatController.text);
    if (fiat == null || fiat <= 0) {
      setState(() => _message = 'Enter a valid fiat amount.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.convert(uid, 'EGP', fiat, _convertDeposit ? 'deposit' : 'withdraw');
      setState(() {
        _message =
            'Converted. Platform fee (brokerage): ${(res['fee_mrc'] ?? 0)} MRC. Net: ${(res['net_mrc'] ?? 0)} MRC';
      });
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _doTransfer() async {
    final uid = await _userIdFuture;
    final to = _toController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (to.isEmpty || amount == null || amount <= 0) {
      setState(() => _message = 'Enter a valid recipient and amount.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.transfer(uid, to, amount, _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim());
      setState(() => _message =
          'Transferred $amount MRC. Platform brokerage fee: ${(res['fee'] ?? 0)} MRC. Net to recipient: ${(res['net'] ?? 0)} MRC');
      _amountController.clear();
      _toController.clear();
      _referenceController.clear();
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _wallet?['balance'];
    final currency = _wallet?['currency'] ?? 'MRC';
    return Scaffold(
      appBar: AppBar(title: const Text('MASAREEN Coin Wallet')),
      body: FutureBuilder<String>(
        future: _userIdFuture,
        builder: (context, uidSnap) {
          if (uidSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
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
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance', style: TextStyle(fontSize: 14, color: MasarenTheme.navyLight)),
                      const SizedBox(height: 4),
                      Text('${balance ?? '—'} $currency',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: MasarenTheme.gold, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Exchange rate: 1 EGP = ${_rateToMrc.toStringAsFixed(4)} MRC',
                          style: const TextStyle(color: MasarenTheme.navy)),
                      Text('Platform brokerage fee on monetizable actions: ${(_feeRate * 100).toStringAsFixed(2)}%',
                          style: const TextStyle(color: MasarenTheme.navyLight)),
                    ],
                  ),
                ),
              ),
              ExpansionTile(
                title: const Text('Convert (EGP ⇄ MRC)'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ToggleButtons(
                          isSelected: [_convertDeposit, !_convertDeposit],
                          onPressed: (i) => setState(() => _convertDeposit = i == 0),
                          children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Deposit (buy)')), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Withdraw (cash out)'))],
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: _fiatController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fiat amount (EGP)', border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        Text('Estimated platform brokerage fee: ${_estimatedFeeMrc.toStringAsFixed(4)} MRC'),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _busy ? null : _doConvert, child: Text(_busy ? 'Working…' : 'Convert')),
                      ],
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('Transfer to another owner'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(controller: _toController, decoration: const InputDecoration(labelText: 'To owner id', border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (MRC)', border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        TextField(controller: _referenceController, decoration: const InputDecoration(labelText: 'Reference (optional)', border: OutlineInputBorder())),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _busy ? null : _doTransfer, child: Text(_busy ? 'Working…' : 'Transfer')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Recent transactions', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
              const SizedBox(height: 8),
              if (_transactions.isEmpty)
                const Text('No transactions yet.')
              else
                ..._transactions.map((t) {
                  final m = t as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.swap_horiz, color: MasarenTheme.navyLight),
                      title: Text('${m['type'] ?? m['reference'] ?? 'txn'}'),
                      subtitle: Text('amount: ${m['amount']} · fee: ${m['fee'] ?? '-'} · net: ${m['net'] ?? '-'}'),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}




