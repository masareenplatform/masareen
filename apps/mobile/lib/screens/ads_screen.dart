import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

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
  String _filter = 'ALL';
  double? _balance;

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
      final campaigns = await AuthApi.campaigns();
      double? balance;
      try {
        balance = (await AuthApi.wallet(widget.user.id)).balance;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _balance = balance;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Campaign> get _visible => _filter == 'ALL'
      ? _campaigns
      : _campaigns.where((c) => c.status == _filter).toList();

  Future<void> _create() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CampaignEditorScreen(user: widget.user),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _open(Campaign campaign) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CampaignDetailScreen(
          user: widget.user,
          campaignId: campaign.id,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc('nav.ads')),
        actions: [
          IconButton(
            tooltip: loc('admin.refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: loc('ads.create'),
            onPressed: _create,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      _AdsHero(
                        balance: _balance,
                        campaigns: _campaigns,
                        onCreate: _create,
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            for (final status in const [
                              'ALL',
                              'DRAFT',
                              'ACTIVE',
                              'PAUSED',
                              'COMPLETED'
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(status == 'ALL'
                                      ? loc('ads.filterAll')
                                      : loc(
                                          'ads.status.${status.toLowerCase()}')),
                                  selected: _filter == status,
                                  onSelected: (_) =>
                                      setState(() => _filter = status),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SectionTitle(title: loc('ads.yourCampaigns')),
                      if (_visible.isEmpty)
                        _EmptyAds(onCreate: _create)
                      else
                        ..._visible.map(
                          (c) => _CampaignCard(
                            campaign: c,
                            onTap: () => _open(c),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          loc('ads.notSpammy'),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _AdsHero extends StatelessWidget {
  final double? balance;
  final List<Campaign> campaigns;
  final VoidCallback onCreate;
  const _AdsHero({
    required this.balance,
    required this.campaigns,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    final active = campaigns.where((c) => c.status == 'ACTIVE').length;
    final spend = campaigns.fold<double>(0, (sum, c) => sum + c.spent);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc('ads.managerTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            loc('ads.managerSubtitle'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82), height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroMetric(
                label: loc('ads.balance'),
                value: balance == null ? '-' : '${_coins(balance!)} MRC',
              ),
              _HeroMetric(label: loc('ads.active'), value: '$active'),
              _HeroMetric(
                  label: loc('ads.spend'), value: '${_coins(spend)} MRC'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc('ads.create')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _EmptyAds extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyAds({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          Text(loc('ads.noCampaigns'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(loc('ads.create')),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;
  const _CampaignCard({required this.campaign, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    final color = _statusColor(campaign.status);
    final creative = campaign.primaryCreative;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(_placementIcon(campaign.placement), color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(campaign.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '${loc('ads.objective.${campaign.objective}')} · ${loc('ads.placement.${campaign.placement}')}',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: campaign.status, color: color),
                ],
              ),
              const SizedBox(height: 12),
              if (creative != null) ...[
                Text(creative.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (creative.body != null) ...[
                  const SizedBox(height: 2),
                  Text(creative.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
                const SizedBox(height: 10),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: campaign.budgetProgress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_coins(campaign.spent)} / ${_coins(campaign.budget)} MRC',
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${campaign.impressions} ${loc('ads.impressions')} · ${campaign.clicks} ${loc('ads.clicks')}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          MasarenLocalizations.of(
              context, 'ads.status.${status.toLowerCase()}'),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
}

class _CampaignEditorScreen extends StatefulWidget {
  final User user;
  final Campaign? existing;
  const _CampaignEditorScreen({required this.user, this.existing});

  @override
  State<_CampaignEditorScreen> createState() => _CampaignEditorScreenState();
}

class _CampaignEditorScreenState extends State<_CampaignEditorScreen> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  final _countries = TextEditingController();
  final _roles = TextEditingController();
  final _sdgs = TextEditingController();
  final _keywords = TextEditingController();
  String _objective = 'awareness';
  String _placement = 'feed';
  DateTime? _startAt;
  DateTime? _endAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _budget.text = _coins(e.budget);
      _objective = e.objective;
      _placement = e.placement;
      _startAt = _parseDate(e.startAt);
      _endAt = _parseDate(e.endAt);
      _countries.text = _listText(e.targeting['countries']);
      _roles.text = _listText(e.targeting['roles']);
      _sdgs.text = _listText(e.targeting['sdgs']);
      _keywords.text = _listText(e.targeting['keywords']);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _countries.dispose();
    _roles.dispose();
    _sdgs.dispose();
    _keywords.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final initial = start
        ? (_startAt ?? DateTime.now())
        : (_endAt ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startAt = picked;
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save() async {
    String loc(String key) => MasarenLocalizations.of(context, key);
    final name = _name.text.trim();
    final budget = double.tryParse(_budget.text.trim());
    if (name.length < 2) {
      _snack(loc('ads.nameRequired'));
      return;
    }
    if (budget == null || budget < 0) {
      _snack(loc('ads.invalidBudget'));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'objective': _objective,
        'placement': _placement,
        'budget_coins': budget,
        'targeting': {
          'countries': _split(_countries.text),
          'roles': _split(_roles.text),
          'sdgs': _split(_sdgs.text)
              .map((e) => int.tryParse(e))
              .whereType<int>()
              .toList(),
          'keywords': _split(_keywords.text),
        },
      };
      if (_startAt != null) {
        body['start_at'] =
            DateTime(_startAt!.year, _startAt!.month, _startAt!.day, 0, 0)
                .toIso8601String();
      }
      if (_endAt != null) {
        body['end_at'] =
            DateTime(_endAt!.year, _endAt!.month, _endAt!.day, 23, 59)
                .toIso8601String();
      }
      if (widget.existing == null) {
        await AuthApi.createCampaign(body);
      } else {
        await AuthApi.updateCampaign(widget.existing!.id, body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(loc('common.failed').replaceAll('{error}', '$e'));
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc(
            widget.existing == null ? 'ads.newCampaign' : 'ads.editCampaign')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(loc('action.save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: loc('ads.campaignName'),
              prefixIcon: const Icon(Icons.campaign_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _objective,
                  decoration: InputDecoration(labelText: loc('ads.objective')),
                  items: const [
                    'awareness',
                    'traffic',
                    'engagement',
                    'leads',
                    'donations'
                  ]
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(loc('ads.objective.$v')),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _objective = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _placement,
                  decoration: InputDecoration(labelText: loc('ads.placement')),
                  items: const ['feed', 'search', 'profile']
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(loc('ads.placement.$v')),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _placement = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: loc('ads.budgetMrc'),
              helperText: loc('ads.minimumBudget'),
              prefixIcon: const Icon(Icons.token),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: loc('ads.start'),
                  value: _startAt,
                  onTap: () => _pickDate(true),
                  onClear: () => setState(() => _startAt = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: loc('ads.end'),
                  value: _endAt,
                  onTap: () => _pickDate(false),
                  onClear: () => setState(() => _endAt = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(loc('ads.targeting'),
              style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 4),
          Text(loc('ads.targetingHint'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          _TagField(
              controller: _countries,
              label: loc('ads.countries'),
              icon: Icons.public),
          const SizedBox(height: 10),
          _TagField(
              controller: _roles,
              label: loc('ads.roles'),
              icon: Icons.badge_outlined),
          const SizedBox(height: 10),
          _TagField(
              controller: _sdgs,
              label: loc('ads.sdgs'),
              icon: Icons.track_changes),
          const SizedBox(height: 10),
          _TagField(
              controller: _keywords,
              label: loc('ads.keywords'),
              icon: Icons.tag),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(loc('ads.budgetHelp'),
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.35)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _TagField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          helperText: MasarenLocalizations.of(context, 'ads.commaHint'),
        ),
      );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
        child: Text(
          value == null ? '-' : DateFormat('d MMM yyyy').format(value!),
          style: TextStyle(color: cs.onSurface),
        ),
      ),
    );
  }
}

class _CampaignDetailScreen extends StatefulWidget {
  final User user;
  final String campaignId;
  const _CampaignDetailScreen({
    required this.user,
    required this.campaignId,
  });

  @override
  State<_CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<_CampaignDetailScreen> {
  Campaign? _campaign;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _campaign == null;
      _error = null;
    });
    try {
      final campaign = await AuthApi.campaign(widget.campaignId);
      Map<String, dynamic>? stats;
      try {
        stats = await AuthApi.campaignStats(widget.campaignId, days: 14);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _campaign = campaign;
        _stats = stats;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated =
          await AuthApi.setCampaignStatus(widget.campaignId, status);
      if (!mounted) return;
      setState(() => _campaign = updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(MasarenLocalizations.of(context, 'common.failed')
          .replaceAll('{error}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final c = _campaign;
    if (c == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CampaignEditorScreen(user: widget.user, existing: c),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    String loc(String key) => MasarenLocalizations.of(context, key);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc('ads.deleteCampaign')),
        content: Text(loc('ads.deleteConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: Text(loc('action.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthApi.deleteCampaign(widget.campaignId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack(loc('common.failed').replaceAll('{error}', '$e'));
    }
  }

  Future<void> _addCreative([Creative? existing]) async {
    final c = _campaign;
    if (c == null) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CreativeDialog(existing: existing),
    );
    if (data == null) return;
    setState(() => _busy = true);
    try {
      if (existing?.id == null) {
        await AuthApi.addCreative(c.id, data);
      } else {
        await AuthApi.updateCreative(existing!.id!, data);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(MasarenLocalizations.of(context, 'common.failed')
          .replaceAll('{error}', '$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCreative(Creative creative) async {
    String loc(String key) => MasarenLocalizations.of(context, key);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc('ads.deleteCreative')),
        content: Text(loc('ads.deleteCreativeConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: Text(loc('action.delete'))),
        ],
      ),
    );
    if (ok != true || creative.id == null) return;
    try {
      await AuthApi.deleteCreative(creative.id!);
      await _load();
    } catch (e) {
      _snack(loc('common.failed').replaceAll('{error}', '$e'));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    final c = _campaign;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? loc('ads.campaigns')),
        actions: [
          if (c != null && (c.status == 'DRAFT' || c.status == 'PAUSED'))
            IconButton(
                tooltip: loc('ads.editCampaign'),
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined)),
          if (c != null && c.status == 'DRAFT')
            IconButton(
                tooltip: loc('ads.deleteCampaign'),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
          IconButton(
              tooltip: loc('admin.refresh'),
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && c == null
              ? ErrorView(message: _error, onRetry: _load)
              : c == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _DetailHeader(campaign: c),
                          const SizedBox(height: 14),
                          _StatusActions(
                            campaign: c,
                            busy: _busy,
                            onStatus: _setStatus,
                          ),
                          const SizedBox(height: 18),
                          _PerformanceCard(campaign: c),
                          const SizedBox(height: 18),
                          _StatsChart(stats: _stats),
                          const SizedBox(height: 18),
                          _ScheduleCard(campaign: c),
                          const SizedBox(height: 18),
                          _TargetingCard(campaign: c),
                          const SizedBox(height: 18),
                          SectionTitle(title: loc('ads.creatives')),
                          if (c.creatives.isEmpty)
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    Icon(Icons.photo_library_outlined,
                                        color: cs.outline, size: 40),
                                    const SizedBox(height: 8),
                                    Text(loc('ads.noCreatives'),
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant)),
                                    const SizedBox(height: 10),
                                    FilledButton.icon(
                                      onPressed: c.status == 'COMPLETED' ||
                                              c.status == 'REJECTED'
                                          ? null
                                          : () => _addCreative(),
                                      icon: const Icon(Icons.add),
                                      label: Text(loc('ads.addCreative')),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            ...c.creatives.map((creative) => _CreativeCard(
                                  creative: creative,
                                  locked: c.status == 'COMPLETED' ||
                                      c.status == 'REJECTED',
                                  onEdit: () => _addCreative(creative),
                                  onDelete: () => _deleteCreative(creative),
                                )),
                            if (c.status != 'COMPLETED' &&
                                c.status != 'REJECTED')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: OutlinedButton.icon(
                                  onPressed: c.creatives.length >= 5
                                      ? null
                                      : () => _addCreative(),
                                  icon: const Icon(Icons.add),
                                  label: Text(loc('ads.addCreative')),
                                ),
                              ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final Campaign campaign;
  const _DetailHeader({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    final color = _statusColor(campaign.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_placementIcon(campaign.placement), color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${loc('ads.objective.${campaign.objective}')} · ${loc('ads.placement.${campaign.placement}')}',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
              _StatusChip(status: campaign.status, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigMetric(
                    label: loc('ads.budget'),
                    value: '${_coins(campaign.budget)} MRC'),
              ),
              Expanded(
                child: _BigMetric(
                    label: loc('ads.spend'),
                    value: '${_coins(campaign.spent)} MRC'),
              ),
              Expanded(
                child: _BigMetric(
                    label: loc('ads.remaining'),
                    value: '${_coins(campaign.remaining)} MRC'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: campaign.budgetProgress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  final String label;
  final String value;
  const _BigMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
      ],
    );
  }
}

class _StatusActions extends StatelessWidget {
  final Campaign campaign;
  final bool busy;
  final ValueChanged<String> onStatus;
  const _StatusActions({
    required this.campaign,
    required this.busy,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    String loc(String key) => MasarenLocalizations.of(context, key);
    final canActivate =
        campaign.status == 'DRAFT' || campaign.status == 'PAUSED';
    final canPause = campaign.status == 'ACTIVE';
    final canComplete =
        campaign.status == 'ACTIVE' || campaign.status == 'PAUSED';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canActivate)
          FilledButton.icon(
            onPressed: busy ? null : () => onStatus('ACTIVE'),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text(loc('ads.activate')),
          ),
        if (canPause)
          OutlinedButton.icon(
            onPressed: busy ? null : () => onStatus('PAUSED'),
            icon: const Icon(Icons.pause, size: 18),
            label: Text(loc('ads.pause')),
          ),
        if (canComplete)
          TextButton.icon(
            onPressed: busy ? null : () => onStatus('COMPLETED'),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(loc('ads.complete')),
          ),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final Campaign campaign;
  const _PerformanceCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc('ads.performance'),
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                _PerfMetric(
                    label: loc('ads.impressions'),
                    value: '${campaign.impressions}'),
                _PerfMetric(
                    label: loc('ads.clicks'), value: '${campaign.clicks}'),
                _PerfMetric(
                    label: loc('ads.ctr'),
                    value: '${campaign.ctrPercent.toStringAsFixed(1)}%'),
                _PerfMetric(
                    label: loc('ads.cpc'),
                    value: '${_coins(campaign.cpc)} MRC'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PerfMetric extends StatelessWidget {
  final String label;
  final String value;
  const _PerfMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatsChart extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _StatsChart({this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    final raw = stats?['series'];
    final series = raw is List ? raw : const [];
    if (series.isEmpty) return const SizedBox.shrink();
    final values = series
        .map((e) => e is Map ? (e['impressions'] as num? ?? 0).toDouble() : 0.0)
        .toList();
    final max = values.fold<double>(1, (m, v) => v > m ? v : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc('ads.dailyImpressions'),
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final v in values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 8 + (v / max) * 64,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Campaign campaign;
  const _ScheduleCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc('ads.schedule'),
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _InfoRow(
                icon: Icons.play_circle_outline,
                label: loc('ads.start'),
                value: _date(campaign.startAt)),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.stop_circle_outlined,
                label: loc('ads.end'),
                value: _date(campaign.endAt)),
          ],
        ),
      ),
    );
  }
}

class _TargetingCard extends StatelessWidget {
  final Campaign campaign;
  const _TargetingCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    final entries = <String>[];
    for (final key in const ['countries', 'roles', 'sdgs', 'keywords']) {
      final v = campaign.targeting[key];
      if (v is List && v.isNotEmpty) {
        entries.add('${loc('ads.$key')}: ${v.join(', ')}');
      }
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc('ads.targeting'),
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              entries.isEmpty ? loc('ads.everyone') : entries.join('\n'),
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        Expanded(
          child:
              Text(value, style: TextStyle(color: cs.onSurface, fontSize: 12)),
        ),
      ],
    );
  }
}

class _CreativeCard extends StatelessWidget {
  final Creative creative;
  final bool locked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CreativeCard({
    required this.creative,
    required this.locked,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String loc(String key) => MasarenLocalizations.of(context, key);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CreativeThumb(creative: creative),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(creative.title,
                      style: TextStyle(
                          color: cs.onSurface, fontWeight: FontWeight.w700)),
                  if (creative.body != null) ...[
                    const SizedBox(height: 2),
                    Text(creative.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${loc('ads.${creative.mediaType}')}${creative.ctaLabel == null ? '' : ' · ${creative.ctaLabel}'}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!locked)
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(loc('ads.edit'))),
                  PopupMenuItem(
                      value: 'delete', child: Text(loc('ads.delete'))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CreativeThumb extends StatelessWidget {
  final Creative creative;
  const _CreativeThumb({required this.creative});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (creative.mediaUrl != null && !creative.isText) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          creative.mediaUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconBox(cs),
        ),
      );
    }
    return _iconBox(cs);
  }

  Widget _iconBox(ColorScheme cs) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          creative.isVideo
              ? Icons.videocam_outlined
              : creative.isText
                  ? Icons.notes
                  : Icons.image_outlined,
          color: cs.onSurfaceVariant,
        ),
      );
}

class _CreativeDialog extends StatefulWidget {
  final Creative? existing;
  const _CreativeDialog({this.existing});

  @override
  State<_CreativeDialog> createState() => _CreativeDialogState();
}

class _CreativeDialogState extends State<_CreativeDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _mediaUrl = TextEditingController();
  final _ctaLabel = TextEditingController();
  final _ctaUrl = TextEditingController();
  String _mediaType = 'image';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _body.text = e.body ?? '';
      _mediaUrl.text = e.mediaUrl ?? '';
      _ctaLabel.text = e.ctaLabel ?? '';
      _ctaUrl.text = e.ctaUrl ?? '';
      _mediaType = e.mediaType;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _mediaUrl.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    String loc(String key) => MasarenLocalizations.of(context, key);
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await AuthApi.uploadMedia(
          Uint8List.fromList(bytes), file.name, _mime(file.name));
      if (!mounted) return;
      _mediaUrl.text = url;
      setState(() => _mediaType = 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc('common.failed').replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    String loc(String key) => MasarenLocalizations.of(context, key);
    final title = _title.text.trim();
    if (title.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc('ads.nameRequired'))));
      return;
    }
    if (_mediaType != 'text' && _mediaUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc('ads.mediaRequired'))));
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'title': title,
      'body': _body.text.trim(),
      'media_type': _mediaType,
      'media_url': _mediaUrl.text.trim(),
      'cta_label': _ctaLabel.text.trim(),
      'cta_url': _ctaUrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    String loc(String key) => MasarenLocalizations.of(context, key);
    return AlertDialog(
      title: Text(loc(
          widget.existing == null ? 'ads.addCreative' : 'ads.editCreative')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration:
                    InputDecoration(labelText: loc('ads.creativeTitle')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                maxLines: 3,
                decoration: InputDecoration(labelText: loc('ads.creativeBody')),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _mediaType,
                decoration: InputDecoration(labelText: loc('ads.mediaType')),
                items: const ['image', 'video', 'text']
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(loc('ads.$v')),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _mediaType = v!),
              ),
              if (_mediaType != 'text') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _mediaUrl,
                  decoration: InputDecoration(
                    labelText: loc('ads.mediaUrl'),
                    helperText: loc('ads.mediaUrlHint'),
                  ),
                ),
                if (_mediaType == 'image')
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _uploading ? null : _uploadImage,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file, size: 18),
                      label: Text(loc('ads.uploadImage')),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctaLabel,
                      decoration: InputDecoration(
                          labelText: loc('ads.ctaLabel'),
                          helperText: loc('ads.optional')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctaUrl,
                      decoration: InputDecoration(
                          labelText: loc('ads.ctaUrl'),
                          helperText: loc('ads.optional')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc('action.cancel'))),
        FilledButton(onPressed: _submit, child: Text(loc('action.save'))),
      ],
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'ACTIVE':
      return AppColors.accent;
    case 'PAUSED':
      return Colors.orange;
    case 'COMPLETED':
      return AppColors.muted;
    case 'REJECTED':
      return Colors.red.shade600;
    default:
      return AppColors.azure;
  }
}

IconData _placementIcon(String placement) {
  switch (placement) {
    case 'search':
      return Icons.search;
    case 'profile':
      return Icons.person_outline;
    default:
      return Icons.dynamic_feed_outlined;
  }
}

String _coins(num value) {
  final fixed = value.toDouble().toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _date(String? value) {
  if (value == null || value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('d MMM yyyy').format(parsed.toLocal());
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

List<String> _split(String value) =>
    value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

String _listText(dynamic value) {
  if (value is List) return value.map((e) => '$e').join(', ');
  return '';
}

String _mime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
