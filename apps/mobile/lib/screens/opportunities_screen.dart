import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

class OpportunitiesScreen extends StatefulWidget {
  final User user;
  const OpportunitiesScreen({super.key, required this.user});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  List<Opportunity> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await AuthApi.opportunities();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Opportunity> get _visible => _filter == 'ALL'
      ? _items
      : _items.where((o) => (o.type ?? '').toUpperCase() == _filter).toList();

  Future<void> _apply(Opportunity o) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Apply: ${o.title}'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Short note (optional)',
            hintText: 'Why are you a good fit?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Send application')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await AuthApi.applyOpportunity(o.id, note: note.text);
      final i = _items.indexWhere((e) => e.id == o.id);
      if (i != -1) _items[i] = updated;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application sent to the publisher')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final skills = TextEditingController();
    final location = TextEditingController();
    final sdg = TextEditingController();
    final minPms = TextEditingController();
    String type = 'VOLUNTEER';
    bool remote = false;
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Publish an opportunity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const ['JOB', 'INTERNSHIP', 'GRANT', 'VOLUNTEER', 'TRAINING', 'CSR']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? 'VOLUNTEER'),
                ),
                TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Location')),
                TextField(
                    controller: skills,
                    decoration: const InputDecoration(
                        labelText: 'Skills (comma separated)')),
                TextField(
                    controller: sdg,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'SDG (1-17)')),
                TextField(
                    controller: minPms,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Minimum PMS (optional)')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remote'),
                  value: remote,
                  onChanged: (v) => setDialogState(() => remote = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(c, {
                  'title': title.text.trim(),
                  'description': desc.text.trim().isNotEmpty ? desc.text.trim() : null,
                  'type': type,
                  'location': location.text.trim().isNotEmpty ? location.text.trim() : null,
                  'is_remote': remote,
                  'skills': skills.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList(),
                  'sdg': int.tryParse(sdg.text.trim()),
                  'min_pms': double.tryParse(minPms.text.trim()),
                });
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (created == null) return;
    try {
      final o = await AuthApi.createOpportunity(created);
      setState(() {
        _items.insert(0, o);
        _filter = 'ALL';
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Opportunity published')));
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: AppColors.azure,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SectionTitle(title: 'Find your next impact'),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            'ALL', 'JOB', 'INTERNSHIP', 'GRANT', 'VOLUNTEER', 'TRAINING', 'CSR'
                          ]
                              .map((t) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(t),
                                      selected: _filter == t,
                                      onSelected: (_) => setState(() => _filter = t),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _items.isEmpty
                                ? 'No opportunities right now.'
                                : 'No $_filter opportunities right now.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ..._visible.map((o) => _OpportunityCard(o: o, onApply: _apply)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity o;
  final ValueChanged<Opportunity> onApply;
  const _OpportunityCard({required this.o, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.explore, color: AppColors.azure),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(o.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 16)),
                ),
                if (o.sdg != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('SDG ${o.sdg}',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 12)),
                  ),
              ],
            ),
            if (o.type != null) ...[
              const SizedBox(height: 6),
              Text(o.type!,
                  style: const TextStyle(
                      color: AppColors.azure,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ],
            if (o.description != null) ...[
              const SizedBox(height: 8),
              Text(o.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, height: 1.4)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (o.minPms != null)
                  Chip(
                    label: Text('Min PMS ${o.minPms!.toInt()}',
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (o.location != null)
                  Chip(
                    label: Text(o.location!,
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (o.deadline != null)
                  Chip(
                    label: Text('Apply by ${o.deadline!.split('T').first}',
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                ...o.skills.take(3).map((s) => Chip(
                      label: Text(s.toString(),
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: o.applied ? null : () => onApply(o),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azure,
                      side: const BorderSide(color: AppColors.azure),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(o.applied ? 'Applied' : 'Apply'),
                  ),
                ),
                if (o.applicationsCount > 0) ...[
                  const SizedBox(width: 10),
                  Text('${o.applicationsCount} applied',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
