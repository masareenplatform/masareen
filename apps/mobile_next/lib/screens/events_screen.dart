import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/widgets/entity_status.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/widgets/stacked_avatars.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/create_event_screen.dart';
import 'package:masaren/screens/event_dashboard_screen.dart';
import 'package:masaren/screens/event_hub_screen.dart';

class EventsScreen extends StatefulWidget {
  final User user;
  const EventsScreen({super.key, required this.user});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Event> _items = [];
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
      _items = await AuthApi.events(includePast: true);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Event>(
      MaterialPageRoute(builder: (_) => CreateEventScreen(user: widget.user)),
    );
    if (created == null || !mounted) return;
    setState(() => _items.insert(0, created));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(MasarenLocalizations.of(context, 'events.createdToast'))));
  }

  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventHubScreen(eventId: event.id, user: widget.user)));
    if (mounted) _load();
  }

  Future<void> _openDashboard() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventDashboardScreen(user: widget.user)));
    if (mounted) _load();
  }

  final Set<String> _busyIds = {};

  Future<void> _join(Event e) async {
    if (_busyIds.contains(e.id)) return;
    _busyIds.add(e.id);
    if (mounted) setState(() {});
    try {
      final r = await AuthApi.joinEvent(e.id);
      final updated = Event(
        id: e.id,
        title: e.title,
        description: e.description,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        location: e.location,
        isOnline: e.isOnline,
        linkUrl: e.linkUrl,
        sdg: e.sdg,
        capacity: e.capacity,
        fundingGoal: e.fundingGoal,
        fundingRaised: e.fundingRaised,
        eventType: e.eventType,
        programId: e.programId,
        sourceUrl: e.sourceUrl,
        activityVerified: e.activityVerified,
        ratingAvg: e.ratingAvg,
        ratingCount: e.ratingCount,
        participantsCount: e.participantsCount,
        boothsCount: e.boothsCount,
        attendeesCount: (r['attendees_count'] is num)
            ? (r['attendees_count'] as num).toInt()
            : e.attendeesCount,
        attending: r['attending'] == true,
        authorName: e.authorName,
        author: e.author,
        createdAt: e.createdAt,
        coverUrl: e.coverUrl,
        membersPreview: e.membersPreview,
      );
      final i = _items.indexWhere((x) => x.id == e.id);
      if (i >= 0) _items[i] = updated;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        final message = MasarenLocalizations.of(context, 'common.failed')
            .replaceAll('{error}', '$e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      _busyIds.remove(e.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _fund(Event e) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(MasarenLocalizations.of(context, 'events.fundTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    MasarenLocalizations.of(context, 'events.fundAmount'),
                suffixText: 'MRC',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MasarenLocalizations.of(context, 'common.cancel'))),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: Text(MasarenLocalizations.of(context, 'events.fund')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;
    try {
      await AuthApi.fundEvent(e.id, amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(MasarenLocalizations.of(context, 'events.fundedToast'))));
      _load();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? (error.message ?? 'Could not fund this event.')
          : error.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _when(BuildContext context, String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    final ml = MaterialLocalizations.of(context);
    final time = ml.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    return '${ml.formatMediumDate(local)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = MasarenLocalizations.of(context, 'events.goingCount');
    final onlineLink =
        MasarenLocalizations.of(context, 'events.onlineWithLink');
    final onlineLabel = MasarenLocalizations.of(context, 'events.onlineLabel');
    Event? acvDemo;
    Event? ktiDemo;
    for (final event in _items) {
      if (event.title.contains('Commercial Vehicle Show') &&
          event.title.contains('2026')) {
        acvDemo = event;
      }
      if (event.title.contains('Knowledge to Impact')) ktiDemo = event;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(MasarenLocalizations.of(context, 'events.title')),
        actions: [
          IconButton(
              tooltip: MasarenLocalizations.of(context, 'events.dashboard'),
              onPressed: _openDashboard,
              icon: const Icon(Icons.insights_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      if (acvDemo != null || ktiDemo != null)
                        FadeSlideIn(
                          child: _PartnershipDemoBanner(
                            acv: acvDemo,
                            kti: ktiDemo,
                            onEvent: _openEvent,
                            onDashboard: _openDashboard,
                          ),
                        ),
                      SectionTitle(
                          title: MasarenLocalizations.of(
                              context, 'events.section')),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            MasarenLocalizations.of(context, 'events.empty'),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ..._items.map((e) => FadeSlideIn(
                              child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openEvent(e),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SmartImage(
                                          url: e.coverUrl,
                                          width: 52,
                                          height: 52,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          fallbackIcon: e.isOnline
                                              ? Icons.language
                                              : Icons.event,
                                          accent: cs.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(e.title,
                                                        style: TextStyle(
                                                            color: cs.onSurface,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800)),
                                                  ),
                                                  EntityStatusChip(
                                                      status:
                                                          e.verificationStatus,
                                                      reason:
                                                          e.rejectionReason),
                                                ],
                                              ),
                                              Text(
                                                  '${_when(context, e.startsAt)}'
                                                  '${e.sdg != null ? " · ${MasarenLocalizations.of(context, 'events.sdg').replaceAll('{sdg}', '${e.sdg}')}" : ""}',
                                                  style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 12)),
                                              Text(
                                                  e.isOnline
                                                      ? e.linkUrl != null
                                                          ? onlineLink
                                                          : onlineLabel
                                                      : (e.location ?? ''),
                                                  style: TextStyle(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (e.author != null) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => openEntityAuthor(context,
                                            author: e.author,
                                            currentUser: widget.user),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3),
                                          child: Row(
                                            children: [
                                              AppAvatar(
                                                  name: e.author!.name,
                                                  url: e.author!.avatarUrl,
                                                  size: 18),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  e.author!.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: cs.primary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else if (e.authorName != null &&
                                        e.authorName!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline_rounded,
                                              size: 14,
                                              color: cs.onSurfaceVariant),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              e.authorName!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: cs.onSurfaceVariant,
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (e.description != null &&
                                        e.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(e.description!,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 13)),
                                      ),
                                    if (e.fundingGoal > 0) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                              Icons.volunteer_activism_outlined,
                                              size: 16,
                                              color: cs.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                              MasarenLocalizations.of(
                                                  context, 'events.funding'),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: cs.onSurface)),
                                          const Spacer(),
                                          Text(
                                              '${e.fundingRaised % 1 == 0 ? e.fundingRaised.toInt() : e.fundingRaised.toStringAsFixed(2)}'
                                              ' / ${e.fundingGoal % 1 == 0 ? e.fundingGoal.toInt() : e.fundingGoal.toStringAsFixed(2)} MRC',
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.primary)),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      AnimatedProgressBar(
                                        value: (e.fundingRaised / e.fundingGoal)
                                            .clamp(0.0, 1.0),
                                        height: 5,
                                      ),
                                      if (e.author == null ||
                                          e.author!.id != widget.user.id)
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: TextButton.icon(
                                            onPressed: () => _fund(e),
                                            icon: const Icon(
                                                Icons.volunteer_activism,
                                                size: 16),
                                            label: Text(MasarenLocalizations.of(
                                                context, 'events.fund')),
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        StackedAvatars(
                                            people: e.membersPreview,
                                            total: e.attendeesCount,
                                            size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                            l10n.replaceAll('{count}',
                                                '${e.attendeesCount}'),
                                            style: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 12)),
                                        const Spacer(),
                                        if (e.attending && e.linkUrl != null)
                                          TextButton.icon(
                                            onPressed: () async {
                                              final uri =
                                                  Uri.tryParse(e.linkUrl!);
                                              if (uri != null) {
                                                await launchUrl(uri,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              }
                                            },
                                            icon: const Icon(Icons.open_in_new,
                                                size: 16),
                                            label: Text(MasarenLocalizations.of(
                                                context, 'events.joinOnline')),
                                          ),
                                        if (e.author == null ||
                                            e.author!.id != widget.user.id)
                                          TextButton.icon(
                                            onPressed: _busyIds.contains(e.id)
                                                ? null
                                                : () => _join(e),
                                            icon: Icon(
                                                e.attending
                                                    ? Icons.close
                                                    : Icons.check,
                                                size: 16),
                                            label: Text(MasarenLocalizations.of(
                                                context,
                                                e.attending
                                                    ? 'events.leave'
                                                    : 'events.join')),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ))),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _PartnershipDemoBanner extends StatelessWidget {
  final Event? acv;
  final Event? kti;
  final void Function(Event) onEvent;
  final VoidCallback onDashboard;
  const _PartnershipDemoBanner(
      {required this.acv,
      required this.kti,
      required this.onEvent,
      required this.onDashboard});

  String _t(BuildContext context, String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedGradientBackground(
          colors: const [
            AppColors.ink,
            Color(0xFF155B4D),
            AppColors.ink,
          ],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(999)),
                      child: const Text('TIYE � ACU � MASAREEN',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4)),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                    _t(context, 'events.demoTitle',
                        'A live 365-day event economy demo'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    _t(context, 'events.demoBody',
                        'Open the ACV digital hub or the ACU Knowledge to Impact program to see booths, verified proof, leads and MRC rewards.'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .76),
                        fontSize: 11.5,
                        height: 1.45)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (acv != null)
                      FilledButton.tonalIcon(
                        onPressed: () => onEvent(acv!),
                        icon:
                            const Icon(Icons.local_shipping_outlined, size: 16),
                        label: Text(_t(context, 'events.demoACV', 'ACV 2026')),
                      ),
                    if (kti != null)
                      FilledButton.tonalIcon(
                        onPressed: () => onEvent(kti!),
                        icon: const Icon(Icons.school_outlined, size: 16),
                        label: Text(_t(
                            context, 'events.demoKTI', 'Knowledge to Impact')),
                      ),
                    OutlinedButton.icon(
                      onPressed: onDashboard,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: .35))),
                      icon: const Icon(Icons.insights_outlined, size: 16),
                      label: Text(_t(
                          context, 'events.demoDashboard', 'TIYE dashboard')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
