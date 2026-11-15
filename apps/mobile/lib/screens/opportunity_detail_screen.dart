import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/entity_status.dart';

class OpportunityDetailScreen extends StatefulWidget {
  final Opportunity opportunity;
  final User user;
  final ValueChanged<Opportunity>? onChanged;
  const OpportunityDetailScreen(
      {super.key,
      required this.opportunity,
      required this.user,
      this.onChanged});

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  late Opportunity _o = widget.opportunity;
  bool _busy = false;

  String _t(String key, [String? fallback]) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? (fallback ?? key) : value;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await AuthApi.opportunity(_o.id);
      if (!mounted) return;
      setState(() => _o = fresh);
      widget.onChanged?.call(fresh);
    } catch (_) {}
  }

  Future<void> _apply() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        String t(String key) => MasarenLocalizations.of(c, key);
        return AlertDialog(
          title:
              Text(t('opportunities.applyTitle').replaceAll('{title}', _o.title)),
          content: TextField(
            controller: note,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: t('opportunities.note'),
                hintText: t('opportunities.noteHint')),
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
    setState(() => _busy = true);
    try {
      await AuthApi.applyOpportunity(_o.id, note: note.text);
      final fresh = await AuthApi.opportunity(_o.id);
      if (!mounted) return;
      setState(() => _o = fresh);
      widget.onChanged?.call(fresh);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('opportunities.sent'))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t('common.failed').replaceAll('{error}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _closed =>
      (_o.status ?? 'OPEN').toUpperCase() != 'OPEN' ||
      (_o.deadline != null &&
          DateTime.tryParse(_o.deadline!)?.isBefore(DateTime.now()) == true);

  String _typeLabel() {
    final type = _o.type ?? '';
    if (type.isEmpty) return type;
    final key = 'opportunities.type.${type.toLowerCase()}';
    final value = MasarenLocalizations.of(context, key);
    if (value != key) return value;
    return type
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_t('opportunities.details'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _hero(context, cs),
            if (_o.description != null &&
                _o.description!.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: SectionTitle(title: _t('opportunities.about')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_o.description!,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        height: 1.55,
                        fontSize: 14)),
              ),
            ],
            if (_o.skills.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: SectionTitle(title: _t('opportunities.skills')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _o.skills
                      .map((s) => Chip(
                          label: Text(s.toString(),
                              style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _applyCard(context, cs),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if ((_o.type ?? '').isNotEmpty)
                _pill(_typeLabel(), icon: Icons.work_outline),
              if (_o.sdg != null) ...[
                const SizedBox(width: 6),
                _pill('SDG ${_o.sdg}'),
              ],
              const Spacer(),
              _pill(_closed ? _t('opportunities.closed') : _t('opportunities.open'),
                  icon: _closed
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined),
              EntityStatusChip(
                  status: _o.verificationStatus,
                  reason: _o.rejectionReason),
            ],
          ),
          const SizedBox(height: 14),
          Text(_o.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.25)),
          if (_o.author != null) ...[
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openEntityAuthor(context,
                  author: _o.author, currentUser: widget.user),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    AppAvatar(
                        name: _o.author!.name,
                        url: _o.author!.avatarUrl,
                        size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_o.author!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.8), size: 18),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (_o.location != null)
                _stat(Icons.place_outlined, _o.location!),
              if (_o.isRemote)
                _stat(Icons.wifi_outlined, _t('opportunities.remote')),
              if (_o.deadline != null)
                _stat(Icons.event_busy_outlined,
                    '${_t('opportunities.deadline')}: ${_o.deadline!.split('T').first}'),
              if (_o.minPms != null)
                _stat(Icons.stars_outlined,
                    'PMS ${_o.minPms!.toInt()}+'),
              _stat(Icons.people_outline,
                  _t('opportunities.applicants')
                      .replaceAll('{count}', '${_o.applicationsCount}')),
            ],
          ),
          if (_o.applied) ...[
            const SizedBox(height: 14),
            _pill(_t('action.applied'), icon: Icons.check_circle),
          ],
        ],
      ),
    );
  }

  Widget _applyCard(BuildContext context, ColorScheme cs) {
    final applied = _o.applied;
    final approved = _o.verificationStatus == 'APPROVED';
    final canApply = !applied && !_closed && approved;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: applied
            ? cs.secondary.withValues(alpha: 0.10)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: applied
                ? cs.secondary.withValues(alpha: 0.45)
                : cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(applied ? Icons.verified_rounded : Icons.send_outlined,
                  color: applied ? cs.secondary : cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    applied
                        ? _t('opportunities.applicationSubmitted')
                        : !approved
                            ? _t('entity.pending')
                            : _closed
                                ? _t('opportunities.closed')
                                : _t('opportunities.applyNow'),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
            ],
          ),
          if (applied) ...[
            const SizedBox(height: 8),
            Text(_t('opportunities.applicationTracked'),
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.4)),
          ],
          if (!approved) ...[
            const SizedBox(height: 8),
            Text(_t('entity.pendingNote'),
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canApply && !_busy ? _apply : null,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(applied ? Icons.check : Icons.send_outlined, size: 16),
              label: Text(applied
                  ? _t('action.applied')
                  : _closed
                      ? _t('opportunities.closed')
                      : _t('opportunities.applyNow')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
