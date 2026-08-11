import 'package:flutter/material.dart';
import 'package:masaren/core/theme/masaren_theme.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/di/injection.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  final ApiService _api = getIt<ApiService>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  Map<String, dynamic>? _fee;
  List<dynamic> _campaigns = [];
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fee = await _api.getFee();
      final campaigns = await _api.listCampaigns();
      setState(() {
        _fee = fee;
        _campaigns = campaigns;
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  double get _feeRate => (_fee?['fee_rate'] is num) ? (_fee!['fee_rate'] as num).toDouble() : 0.0;

  double get _estimatedFee {
    final budget = double.tryParse(_budgetController.text) ?? 0.0;
    return budget * _feeRate;
  }

  double get _estimatedDeliverable {
    final budget = double.tryParse(_budgetController.text) ?? 0.0;
    return budget - budget * _feeRate;
  }

  Future<void> _createCampaign() async {
    final name = _nameController.text.trim();
    final budget = double.tryParse(_budgetController.text);
    if (name.isEmpty || budget == null || budget <= 0) {
      setState(() => _message = 'Enter a name and a valid budget.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _api.createCampaign(name, budget);
      setState(() => _message =
          'Created "${res['name'] ?? name}". Deliverable budget: ${res['budget_coins'] ?? '—'} MRC. Platform fee taken: ${res['platform_fee_coins'] ?? '—'} MRC');
      _nameController.clear();
      _budgetController.clear();
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await _api.setCampaignStatus(id, status);
      setState(() => _message = 'Campaign $id -> $status');
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  Future<void> _record(String id, bool click) async {
    try {
      if (click) {
        await _api.recordClick(id);
      } else {
        await _api.recordImpression(id);
      }
      setState(() => _message = 'Recorded ${click ? 'click' : 'impression'} for $id');
      await _load();
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ads Manager')),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create campaign', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
                  const SizedBox(height: 8),
                  Text('Platform brokerage fee on ad budget: ${(_feeRate * 100).toStringAsFixed(2)}%',
                      style: const TextStyle(color: MasarenTheme.navyLight)),
                  const SizedBox(height: 8),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Campaign name', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: _budgetController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Budget (MRC)', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  Text('Platform fee (brokerage): ${_estimatedFee.toStringAsFixed(2)} MRC'),
                  Text('Deliverable budget: ${_estimatedDeliverable.toStringAsFixed(2)} MRC'),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _busy ? null : _createCampaign, child: Text(_busy ? 'Working…' : 'Create')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Your campaigns', style: TextStyle(fontWeight: FontWeight.bold, color: MasarenTheme.navy)),
          const SizedBox(height: 8),
          if (_campaigns.isEmpty)
            const Text('No campaigns yet.')
          else
            ..._campaigns.map((c) {
              final m = c as Map<String, dynamic>;
              final id = m['id']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(m['name']?.toString() ?? id),
                        subtitle: Text('Status: ${m['status'] ?? '—'}'),
                      ),
                      Text('Budget (deliverable): ${m['budget_coins'] ?? '—'} MRC'),
                      Text('Platform fee: ${m['platform_fee_coins'] ?? '—'} MRC'),
                      Text('Spent: ${m['spent_coins'] ?? '—'} MRC'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(onPressed: () => _setStatus(id, 'ACTIVE'), child: const Text('Activate')),
                          OutlinedButton(onPressed: () => _setStatus(id, 'PAUSED'), child: const Text('Pause')),
                          OutlinedButton(onPressed: () => _record(id, false), child: const Text('Impression')),
                          OutlinedButton(onPressed: () => _record(id, true), child: const Text('Click')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}




