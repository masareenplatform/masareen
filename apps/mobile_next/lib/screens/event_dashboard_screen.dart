import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/event_hub_screen.dart';
import 'package:masaren/screens/event_manage_screen.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets/animations.dart';

class EventDashboardScreen extends StatefulWidget {
  final User user;
  const EventDashboardScreen({super.key, required this.user});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
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
      final data = await AuthApi.managedEvents();
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

  String _date(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return '';
    return DateFormat.yMMMd().format(parsed.toLocal());
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
    final events = (_data!['events'] is List)
        ? (_data!['events'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final summary = _data!['summary'] is Map
        ? Map<String, dynamic>.from(_data!['summary'] as Map)
        : const <String, dynamic>{};
    final reputation = _data!['reputation'] is Map
        ? Map<String, dynamic>.from(_data!['reputation'] as Map)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('events.enterprise', 'Event enterprise dashboard')),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: _t('common.refresh', 'Refresh'))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Text(_t('events.portfolio', 'Your event portfolio'),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(
                    '${summary['events'] ?? 0}', _t('events.events', 'Events')),
                _Metric('${summary['verified_events'] ?? 0}',
                    _t('events.verified', 'Verified')),
                _Metric(
                    '${summary['booths'] ?? 0}', _t('events.booths', 'Booths')),
                _Metric(
                    '${summary['leads'] ?? 0}', _t('events.leads', 'Leads')),
                _Metric('${summary['attendees'] ?? 0}',
                    _t('events.attendees', 'Attendees')),
                _Metric('${summary['rating_avg'] ?? 0}',
                    _t('events.rating', 'Rating')),
              ],
            ),
            if (reputation != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.brand.withValues(alpha: .9),
                    AppColors.ink.withValues(alpha: .88),
                  ]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined,
                        color: Colors.white, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${reputation['badge'] ?? 'EMERGING'} · #${reputation['rank'] ?? '-'}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          Text(
                              _t('events.reputationBody',
                                      '{verified} verified events · {clients} clients · {rating} rating')
                                  .replaceAll('{verified}',
                                      '${reputation['verified_events'] ?? 0}')
                                  .replaceAll('{clients}',
                                      '${reputation['clients'] ?? 0}')
                                  .replaceAll('{rating}',
                                      '${reputation['rating_avg'] ?? 0}'),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: .78),
                                  fontSize: 11.5,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    _t('events.noManagedEvents',
                        'Create or join an event as organizer or host to use this dashboard.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else
              ...events.map((e) => _EventCard(
                    event: e,
                    date: _date(e['starts_at']?.toString()),
                    onOpen: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => EventHubScreen(
                                eventId: e['id'].toString(),
                                user: widget.user)))
                        .then((_) => _load()),
                    onManage: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => EventManageScreen(
                                eventId: e['id'].toString(),
                                user: widget.user)))
                        .then((_) => _load()),
                  )),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final number = double.tryParse(value);
    return FadeSlideIn(
      child: Container(
        width: (MediaQuery.sizeOf(context).width - 32 - 24) / 3,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            number == null
                ? Text(value,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface))
                : CountUpNumber(
                    target: number,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
            Text(label,
                style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

String _localized(BuildContext context, String key, String fallback) {
  final value = MasarenLocalizations.of(context, key);
  return value == key ? fallback : value;
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String date;
  final VoidCallback onOpen;
  final VoidCallback onManage;
  const _EventCard(
      {required this.event,
      required this.date,
      required this.onOpen,
      required this.onManage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((event['title'] ?? '').toString(),
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
              if (event['activity_verified'] == true)
                const Icon(Icons.verified, size: 18, color: AppColors.brand),
            ],
          ),
          Text(
              [
                date,
                (event['location'] ?? '').toString(),
                (event['my_role'] ?? '').toString(),
              ].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              _SmallStat('${event['participants_count'] ?? 0}',
                  _localized(context, 'events.contributorsShort', 'people')),
              const SizedBox(width: 12),
              _SmallStat('${event['booths_count'] ?? 0}',
                  _localized(context, 'events.boothsShort', 'booths')),
              const SizedBox(width: 12),
              _SmallStat('${event['leads_count'] ?? 0}',
                  _localized(context, 'events.leads', 'leads')),
              const Spacer(),
              TextButton(
                  onPressed: onOpen,
                  child: Text(_localized(context, 'common.open', 'Open'))),
              FilledButton.tonal(
                  onPressed: onManage,
                  child: Text(_localized(context, 'events.manage', 'Manage'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String value;
  final String label;
  const _SmallStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text('$value $label',
        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));
  }
}
