import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

class EventManageScreen extends StatefulWidget {
  final String eventId;
  final User user;
  const EventManageScreen(
      {super.key, required this.eventId, required this.user});

  @override
  State<EventManageScreen> createState() => _EventManageScreenState();
}

class _EventManageScreenState extends State<EventManageScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      final data = await AuthApi.eventDashboard(widget.eventId);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _t(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  List<Map<String, dynamic>> _list(String key) => _data?[key] is List
      ? (_data![key] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : [];

  Future<void> _verdict(String participantId, String status) async {
    try {
      await AuthApi.eventParticipantVerdict(widget.eventId, participantId,
          status: status);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? (e.message ?? '$e') : '$e')));
    }
  }

  Future<void> _leadStatus(Map<String, dynamic> lead, String status) async {
    try {
      await AuthApi.updateBoothLead(
          lead['booth_id'].toString(), lead['id'].toString(), status);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException ? (e.message ?? '$e') : '$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading && _data == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ??
                  _t('events.dashboardError', 'Could not load dashboard.')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _load, child: Text(_t('common.retry', 'Retry'))),
            ],
          ),
        ),
      );
    }
    final event = _data!;
    final participants = _list('participants');
    final booths = _list('booths');
    final leads = _list('leads');
    final rewards = _list('rewards');
    final ratings = _list('ratings');
    final stats = event['stats'] is Map
        ? Map<String, dynamic>.from(event['stats'] as Map)
        : const <String, dynamic>{};
    final queue = participants
        .where((p) =>
            ['SUBMITTED', 'UNDER_REVIEW'].contains(p['status']?.toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(_t('events.dashboard', 'Event dashboard')),
          actions: [
            IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: _t('common.refresh', 'Refresh'))
          ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Text((event['title'] ?? '').toString(),
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            Text(
                '${_t('events.organizer', 'Organizer')}: ${event['author']?['name'] ?? ''}',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            _SummaryGrid(stats: stats),
            if (event['activity_verified'] == true)
              _Banner(
                  icon: Icons.verified,
                  color: AppColors.brand,
                  text: _t('events.verifiedBody',
                      'The host confirmed this activity with evidence.')),
            _Section(
              title: _t('events.verificationQueue', 'Verification queue'),
              icon: Icons.fact_check_outlined,
              child: queue.isEmpty
                  ? Text(
                      _t('events.queueEmpty', 'No proof waiting for review.'),
                      style: TextStyle(color: cs.onSurfaceVariant))
                  : Column(
                      children: queue
                          .map((p) => _QueueTile(
                                participant: p,
                                onVerify: () =>
                                    _verdict(p['id'].toString(), 'VERIFIED'),
                                onReject: () =>
                                    _verdict(p['id'].toString(), 'REJECTED'),
                              ))
                          .toList(),
                    ),
            ),
            _Section(
              title:
                  '${_t('events.contributors', 'Contributors')} · ${participants.length}',
              icon: Icons.groups_outlined,
              child: Column(
                children: participants
                    .map((p) => _PersonRow(
                          name: (p['name'] ?? '').toString(),
                          avatar: p['avatar_url']?.toString(),
                          subtitle:
                              '${p['role']} · ${p['status']}${(p['role_title'] ?? '').toString().isNotEmpty ? ' · ${p['role_title']}' : ''}',
                          trailing: (p['status'] == 'VERIFIED')
                              ? const Icon(Icons.verified,
                                  size: 18, color: AppColors.brand)
                              : null,
                        ))
                    .toList(),
              ),
            ),
            _Section(
              title:
                  '${_t('events.booths', 'Interactive booths')} · ${booths.length}',
              icon: Icons.storefront_outlined,
              child: booths.isEmpty
                  ? Text(_t('events.noBooths', 'No booths yet.'),
                      style: TextStyle(color: cs.onSurfaceVariant))
                  : Column(
                      children: booths
                          .map((b) => _BoothRow(
                                booth: b,
                                leads: leads
                                    .where((l) => l['booth_id'] == b['id'])
                                    .toList(),
                                onLeadStatus: _leadStatus,
                              ))
                          .toList(),
                    ),
            ),
            _Section(
              title:
                  '${_t('events.incomingLeads', 'Incoming leads')} · ${leads.length}',
              icon: Icons.handshake_outlined,
              child: leads.isEmpty
                  ? Text(_t('events.noLeads', 'No leads yet.'),
                      style: TextStyle(color: cs.onSurfaceVariant))
                  : Column(
                      children: leads
                          .map((l) => _LeadRow(
                                lead: l,
                                onStatus: (s) => _leadStatus(l, s),
                              ))
                          .toList(),
                    ),
            ),
            _Section(
              title:
                  '${_t('events.rewards', 'MRC rewards')} · ${rewards.length}',
              icon: Icons.workspace_premium_outlined,
              child: rewards.isEmpty
                  ? Text(_t('events.noRewards', 'No rewards issued yet.'),
                      style: TextStyle(color: cs.onSurfaceVariant))
                  : Column(
                      children: rewards
                          .map((r) => _PersonRow(
                                name: (r['user_name'] ?? 'Member').toString(),
                                subtitle: '${r['kind']} · ${r['reference']}',
                                trailing: Text('+${r['amount']} MRC',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.brand)),
                              ))
                          .toList(),
                    ),
            ),
            if (ratings.isNotEmpty)
              _Section(
                title:
                    '${_t('events.reviews', 'Reviews')} · ${event['rating_avg']} (${event['rating_count']})',
                icon: Icons.star_outline,
                child: Column(
                  children: ratings
                      .map((r) => _PersonRow(
                            name: (r['name'] ?? 'Member').toString(),
                            avatar: r['avatar_url']?.toString(),
                            subtitle: '${r['rating']}/5 · ${r['review'] ?? ''}',
                            trailing: const Icon(Icons.star_rounded,
                                size: 17, color: AppColors.accent),
                          ))
                      .toList(),
                ),
              ),
            if (leads.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    _t('events.leadFootnote',
                        'Leads stay private to the organizer and the exhibitor.'),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SummaryGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('participants', Icons.groups_outlined),
      ('verified_participants', Icons.verified_outlined),
      ('active_booths', Icons.storefront_outlined),
      ('leads', Icons.handshake_outlined),
      ('reviews', Icons.star_outline),
      ('reward_total', Icons.workspace_premium_outlined),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final value = stats[entry.$1] ?? 0;
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 32 - 24) / 3,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Icon(entry.$2, size: 18, color: AppColors.brand),
                const SizedBox(height: 4),
                Text('$value',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface)),
                Text(entry.$1.replaceAll('_', ' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Banner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Map<String, dynamic> participant;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  const _QueueTile(
      {required this.participant,
      required this.onVerify,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${participant['name']} · ${participant['role']}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              Text((participant['status'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent)),
            ],
          ),
          if ((participant['contribution'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(participant['contribution'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, height: 1.35, color: cs.onSurfaceVariant)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: onReject,
                  child: Text(
                      MasarenLocalizations.of(context, 'events.reject') ==
                              'events.reject'
                          ? 'Reject'
                          : MasarenLocalizations.of(context, 'events.reject'))),
              FilledButton(
                  onPressed: onVerify,
                  child: Text(
                      MasarenLocalizations.of(context, 'events.verify') ==
                              'events.verify'
                          ? 'Verify'
                          : MasarenLocalizations.of(context, 'events.verify'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String name;
  final String? avatar;
  final String subtitle;
  final Widget? trailing;
  const _PersonRow(
      {required this.name, required this.subtitle, this.avatar, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AppAvatar(name: name, url: avatar, size: 32),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _BoothRow extends StatelessWidget {
  final Map<String, dynamic> booth;
  final List<Map<String, dynamic>> leads;
  final Future<void> Function(Map<String, dynamic>, String) onLeadStatus;
  const _BoothRow(
      {required this.booth, required this.leads, required this.onLeadStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final owner = booth['owner'] is Map
        ? Map<String, dynamic>.from(booth['owner'] as Map)
        : const <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((booth['title'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              Text(booth['active'] == true ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: booth['active'] == true
                          ? AppColors.brand
                          : cs.error)),
            ],
          ),
          Text(
              '${owner['name'] ?? ''} · ${booth['views'] ?? 0} views · ${booth['leads_count'] ?? 0} leads',
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
          if (leads.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...leads.map((l) => _LeadRow(
                lead: l, onStatus: (s) => onLeadStatus(l, s), compact: true)),
          ],
        ],
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  final Map<String, dynamic> lead;
  final void Function(String) onStatus;
  final bool compact;
  const _LeadRow(
      {required this.lead, required this.onStatus, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (lead['status'] ?? 'NEW').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${lead['name'] ?? 'Visitor'}${compact ? '' : ' · ${lead['booth_title'] ?? ''}'}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                Text(
                    [
                      (lead['type'] ?? '').toString(),
                      if ((lead['email'] ?? '').toString().isNotEmpty)
                        lead['email'].toString(),
                      if ((lead['phone'] ?? '').toString().isNotEmpty)
                        lead['phone'].toString(),
                    ].join(' · '),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                if ((lead['message'] ?? '').toString().isNotEmpty)
                  Text(lead['message'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          DropdownButton<String>(
            value: status,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 10.5, color: cs.primary),
            items: const ['NEW', 'CONTACTED', 'QUALIFIED', 'CLOSED']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null && v != status) onStatus(v);
            },
          ),
        ],
      ),
    );
  }
}
