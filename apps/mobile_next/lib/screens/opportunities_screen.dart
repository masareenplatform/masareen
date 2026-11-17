import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/screens/create_opportunity_screen.dart';
import 'package:masaren/screens/opportunity_detail_screen.dart';
import 'package:masaren/widgets/entity_status.dart';
import 'package:masaren/widgets/smart_image.dart';

const _opportunityTypes = [
  'JOB',
  'INTERNSHIP',
  'GRANT',
  'VOLUNTEER',
  'TRAINING',
  'CSR',
];

String _opportunityTypeLabel(BuildContext context, String? type) {
  if (type == null || type.isEmpty) return '';
  final key = 'opportunities.type.${type.toLowerCase()}';
  final label = MasarenLocalizations.of(context, key);
  return label == key ? type : label;
}

class OpportunitiesScreen extends StatefulWidget {
  final User user;
  final VoidCallback? onMenu;
  const OpportunitiesScreen({super.key, required this.user, this.onMenu});

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
      builder: (c) {
        String t(String key) => MasarenLocalizations.of(c, key);
        return AlertDialog(
          title: Text(
              t('opportunities.applyTitle').replaceAll('{title}', o.title)),
          content: TextField(
            controller: note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t('opportunities.note'),
              hintText: t('opportunities.noteHint'),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(t('action.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(t('opportunities.send'))),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      final updated = await AuthApi.applyOpportunity(o.id, note: note.text);
      final i = _items.indexWhere((e) => e.id == o.id);
      if (i != -1) _items[i] = updated;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(MasarenLocalizations.of(context, 'opportunities.sent'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context, 'common.failed')
                .replaceAll('{error}', e.toString()))));
      }
    }
  }

  Future<void> _openDetail(Opportunity o) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(
            opportunity: o, user: widget.user)));
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Opportunity>(
        MaterialPageRoute(
            builder: (_) => CreateOpportunityScreen(user: widget.user)));
    if (created != null) {
      setState(() => _items.insert(0, created));
    }
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'opportunities.title')),
        actions: [
          if (widget.onMenu != null)
            IconButton(
              tooltip: MasarenLocalizations.of(context, 'nav.more'),
              icon: const Icon(Icons.menu_open),
              onPressed: widget.onMenu,
            ),
        ],
      ),
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
                      SectionTitle(
                          title: MasarenLocalizations.of(
                              context, 'opportunities.findImpact')),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            'ALL',
                            ..._opportunityTypes,
                          ]
                              .map((type) => Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        end: 6),
                                    child: ChoiceChip(
                                      label: Text(type == 'ALL'
                                          ? MasarenLocalizations.of(
                                              context, 'opportunities.all')
                                          : _opportunityTypeLabel(
                                              context, type)),
                                      selected: _filter == type,
                                      onSelected: (_) =>
                                          setState(() => _filter = type),
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
                                ? MasarenLocalizations.of(
                                    context, 'opportunities.empty')
                                : MasarenLocalizations.of(
                                        context, 'opportunities.emptyFilter')
                                    .replaceAll(
                                        '{type}',
                                        _opportunityTypeLabel(
                                            context, _filter)),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ..._visible.map((o) => _OpportunityCard(
                          o: o,
                          onApply: _apply,
                          onOpen: () => _openDetail(o),
                          currentUser: widget.user)),
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
  final VoidCallback onOpen;
  final User currentUser;
  const _OpportunityCard(
      {required this.o,
      required this.onApply,
      required this.onOpen,
      required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (o.coverUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SmartImage(
                  url: o.coverUrl,
                  height: 120,
                  borderRadius: BorderRadius.circular(14),
                  fallbackIcon: Icons.work_outline,
                ),
              ),
            Row(
              children: [
                Icon(Icons.explore_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(o.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          fontSize: 16)),
                ),
                if (o.sdg != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                        '${MasarenLocalizations.of(context, "opportunities.sdg")} ${o.sdg}',
                        style: TextStyle(
                            color: cs.onSecondaryContainer, fontSize: 12)),
                  ),
                if (o.applied)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: Icon(Icons.verified_rounded,
                        size: 16, color: cs.secondary),
                  ),
                EntityStatusChip(
                    status: o.verificationStatus, reason: o.rejectionReason),
                Icon(Icons.chevron_right,
                    size: 18, color: cs.onSurfaceVariant),
              ],
            ),
            if (o.type?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(_opportunityTypeLabel(context, o.type),
                  style: TextStyle(
                      color: cs.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ],
            if (o.author != null) ...[
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => openEntityAuthor(context,
                    author: o.author, currentUser: currentUser),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      AppAvatar(
                          name: o.author!.name,
                          url: o.author!.avatarUrl,
                          size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          o.author!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: cs.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (o.description != null) ...[
              const SizedBox(height: 8),
              Text(o.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (o.minPms != null)
                  Chip(
                    label: Text(
                        MasarenLocalizations.of(
                                context, 'opportunities.minPmsValue')
                            .replaceAll('{value}', '${o.minPms!.toInt()}'),
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (o.location != null)
                  Chip(
                    label:
                        Text(o.location!, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (o.isRemote)
                  Chip(
                    label: Text(
                        MasarenLocalizations.of(
                            context, 'opportunities.remote'),
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (o.deadline != null)
                  Chip(
                    label: Text(
                        MasarenLocalizations.of(
                                context, 'opportunities.applyBy')
                            .replaceAll('{date}', o.deadline!.split('T').first),
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
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(MasarenLocalizations.of(context,
                        o.applied ? 'action.applied' : 'action.apply')),
                  ),
                ),
                if (o.applicationsCount > 0) ...[
                  const SizedBox(width: 10),
                  Text(
                      MasarenLocalizations.of(
                              context, 'opportunities.appliedCount')
                          .replaceAll('{count}', '${o.applicationsCount}'),
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
