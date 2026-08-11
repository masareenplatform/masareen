import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/core/models/user_model.dart';
import 'package:masaren/di/injection.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  final ApiService _api = getIt<ApiService>();
  final _feeController = TextEditingController();

  Map<String, dynamic>? _fee;
  Map<String, dynamic>? _summary;
  List<dynamic> _events = [];
  UserModel? _user;
  bool _busy = false;
  String? _message;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _api.getCurrentUser();
      final fee = await _api.getFee();
      final summary = await _api.revenueSummary();
      final events = await _api.revenueEvents();
      setState(() {
        _user = user;
        _fee = fee;
        _summary = summary;
        _events = events;
        _loaded = true;
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  bool get _isAdmin => _user?.role.toUpperCase() == 'ADMIN';

  double get _feeRate => (_fee?['fee_rate'] is num) ? (_fee!['fee_rate'] as num).toDouble() : 0.0;

  Future<void> _setFee() async {
    final rate = double.tryParse(_feeController.text);
    if (rate == null || rate < 0 || rate > 1) {
      setState(() => _message = 'Fee must be a percentage between 0 and 1 (e.g. 0.05 for 5%).');
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.setFee(rate);
      setState(() => _message = 'Brokerage fee updated to ${(rate * 100).toStringAsFixed(2)}%');
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(appBar: AppBar(title: const Text('Platform Revenue & Fees')), body: const Center(child: CircularProgressIndicator()));
    }
    final totals = _summary?['totals'] as Map<String, dynamic>? ?? {};
    final bySource = _summary?['by_source'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Revenue & Fees')),
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
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: MasarenTheme.gold.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Platform brokerage fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MasarenTheme.navy)),
                  const SizedBox(height: 4),
                  Text('${(_feeRate * 100).toStringAsFixed(2)}%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: MasarenTheme.gold, fontWeight: FontWeight.bold)),
                  Text('The platform earns this on every coin conversion, peer transfer, PSP payment and ad.',
                      style: const TextStyle(color: MasarenTheme.navyDark)),
                ],
              ),
            ),
          ),
          if (_isAdmin) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update brokerage fee', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
                    const SizedBox(height: 8),
                    TextField(controller: _feeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'New fee rate (0..1)', border: OutlineInputBorder())),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _busy ? null : _setFee, child: Text(_busy ? 'Working…' : 'Update fee')),
                  ],
                ),
              ),
            ),
          ] else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Only admins can change the brokerage fee. Your role: not ADMIN.'),
              ),
            ),
          const SizedBox(height: 8),
          const Text('Revenue totals', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MRC: ${totals['MRC'] ?? '—'}'),
                  Text('EGP: ${totals['EGP'] ?? '—'}'),
                  Text('Current fee_rate: ${_summary?['fee_rate'] ?? '—'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('By source', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          if (bySource.isEmpty)
            const Text('No revenue recorded yet.')
          else
            ...bySource.entries.map((e) => ListTile(
                  leading: const Icon(Icons.pie_chart, color: MasarenTheme.navyLight),
                  title: Text(e.key),
                  trailing: Text(e.value.toString()),
                )),
          const SizedBox(height: 12),
          const Text('Recent revenue events', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            const Text('No events yet.')
          else
            ..._events.map((ev) {
              final m = ev as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.attach_money, color: MasarenTheme.gold),
                  title: Text('${m['source_service'] ?? '-'} · ${m['amount']} ${m['currency'] ?? ''}'),
                  subtitle: Text('${m['reference'] ?? ''} · ${m['created_at'] ?? ''}'),
                ),
              );
            }),
        ],
      ),
    );
  }
}




