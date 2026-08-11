import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

class AdsScreen extends StatefulWidget {
  final User user;
  const AdsScreen({super.key, required this.user});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  List<Campaign> _campaigns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _campaigns = await AuthApi.campaigns();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final budget = TextEditingController();
    final created = await showDialog<Campaign>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New campaign'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Campaign name'),
            ),
            TextField(
              controller: budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budget (MRC)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final b = double.tryParse(budget.text) ?? 0;
              if (name.text.trim().isEmpty || b <= 0) return;
              Navigator.pop(
                  c,
                  Campaign(
                      id: '',
                      name: name.text.trim(),
                      status: 'DRAFT',
                      budget: b));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == null) return;
    try {
      final c = await AuthApi.createCampaign({
        'name': created.name,
        'budget_coins': created.budget,
        'currency': 'MRC',
        'targeting': {},
      });
      _campaigns.insert(0, c);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setStatus(Campaign c, String status) async {
    try {
      final updated = await AuthApi.setCampaignStatus(c.id, status);
      final i = _campaigns.indexWhere((e) => e.id == c.id);
      if (i != -1) {
        _campaigns[i] = updated;
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ads Manager'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _create)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SectionTitle(title: 'Your campaigns'),
                      ..._campaigns.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No campaigns yet. Tap + to create one.',
                                    style: TextStyle(color: AppColors.muted)),
                              )
                            ]
                          : _campaigns
                              .map((c) => _CampaignCard(
                                    campaign: c,
                                    onStatus: (s) => _setStatus(c, s),
                                  ))
                              .cast<Widget>(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final void Function(String) onStatus;
  const _CampaignCard({required this.campaign, required this.onStatus});

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE':
        return AppColors.accent;
      case 'PAUSED':
        return Colors.orange;
      case 'COMPLETED':
        return AppColors.muted;
      default:
        return AppColors.azure;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(campaign.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(campaign.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(campaign.status,
                        style: TextStyle(
                            color: _statusColor(campaign.status),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Budget: ${campaign.budget.toStringAsFixed(0)} ${campaign.currency}',
                  style: const TextStyle(color: AppColors.muted)),
              if (campaign.creatives.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...campaign.creatives
                    .map((cr) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.photo, color: AppColors.azure),
                          title: Text(cr.title,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: cr.body != null
                              ? Text(cr.body!,
                                  style: const TextStyle(color: AppColors.muted))
                              : null,
                        )),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => onStatus(
                        campaign.status == 'ACTIVE' ? 'PAUSED' : 'ACTIVE'),
                    child: Text(campaign.status == 'ACTIVE'
                        ? 'Pause'
                        : 'Activate'),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => onStatus('COMPLETED'),
                    child: const Text('Complete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
