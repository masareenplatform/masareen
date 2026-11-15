import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/profile_ui.dart';
import 'package:masaren/screens/course_detail_screen.dart';
import 'package:masaren/screens/courses_screen.dart';
import 'package:masaren/screens/event_hub_screen.dart';
import 'package:masaren/screens/events_screen.dart';
import 'package:masaren/screens/opportunities_screen.dart';
import 'package:masaren/screens/opportunity_detail_screen.dart';
import 'package:masaren/screens/podcast_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/program_detail_screen.dart';
import 'package:masaren/screens/projects_screen.dart';
import 'package:masaren/screens/vod_screen.dart';

class InstitutionProfileScreen extends StatefulWidget {
  final String institutionId;
  final User? user;
  const InstitutionProfileScreen(
      {super.key, required this.institutionId, this.user});

  @override
  State<InstitutionProfileScreen> createState() =>
      _InstitutionProfileScreenState();
}

class _InstitutionProfileScreenState extends State<InstitutionProfileScreen> {
  Map<String, dynamic>? _remote;
  bool _loading = false;
  String? _error;
  bool _following = false;
  int _followers = 0;
  bool _followBusy = false;

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
      final data = await AuthApi.institution(widget.institutionId);
      if (!mounted) return;
      final type = (data['institution_type'] ?? data['role'] ?? '')
          .toString()
          .toUpperCase();
      final kind = type.contains('UNIVERS')
          ? 'university'
          : type.contains('SCHOOL')
              ? 'university'
              : type.contains('SPORT')
                  ? 'sports'
                  : type.contains('MEDIA')
                      ? 'media'
                      : type.contains('PLATFORM')
                          ? 'platform'
                          : type.contains('GOV')
                              ? 'government'
                              : 'organization';
      final metrics = data['metrics'];
      final services = data['services'];
      final departments = data['departments'];
      setState(() {
        _following = data['is_following'] == true;
        _followers = (data['followers_count'] as num?)?.toInt() ?? 0;
        _remote = {
          ...data,
          'kind': kind,
          'handle': data['handle'] ?? 'institution',
          'note': data['bio'] ?? '',
          'mandate': data['bio'] ?? '',
          'hq': data['city'] ?? data['country'] ?? '',
          'established': data['jurisdiction'] ?? '',
          'sectors': services is List
              ? services
                  .map((s) => s is Map ? (s['name'] ?? s['title'] ?? '') : s)
                  .where((s) => s.toString().isNotEmpty)
                  .toList()
              : <dynamic>[],
          'services': services is List ? services : <dynamic>[],
          'departments': departments is List ? departments : <dynamic>[],
          'metrics': metrics is Map ? metrics : <String, dynamic>{},
          'remote': true,
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const Map<String, Map<String, dynamic>> _registry = {
    'inst-1': {
      'name': 'Al-Baraka Foundation',
      'nameKey': 'institution.registry.inst1.name',
      'handle': 'albaraka',
      'kind': 'media',
      'badgeKey': 'institution.badge.platinum',
      'noteKey': 'institution.registry.inst1.note',
    },
    'inst-2': {
      'name': 'Green Hope Initiative',
      'nameKey': 'institution.registry.inst2.name',
      'handle': 'greenhope',
      'kind': 'organization',
      'badgeKey': 'institution.badge.gold',
      'noteKey': 'institution.registry.inst2.note',
    },
    'u_gov': {
      'name': 'Ministry of Environment',
      'nameKey': 'institution.registry.moenv.name',
      'handle': 'moenv',
      'kind': 'government',
      'badgeKey': 'institution.badge.governmentPartner',
      'noteKey': 'institution.registry.moenv.note',
      'mandateKey': 'institution.registry.moenv.mandate',
      'sectorKeys': [
        'institution.sector.climate',
        'institution.sector.biodiversity',
        'institution.sector.water',
        'institution.sector.publicHealth',
      ],
      'established': '1975',
      'hq': 'Capital District',
      'hqKey': 'institution.registry.moenv.hq',
    },
    'u_almasareen': {
      'name': 'Al-Masareen News Network',
      'nameKey': 'institution.registry.almasareen.name',
      'handle': 'almasareen',
      'kind': 'media',
      'badgeKey': 'institution.badge.esteemedMedia',
      'noteKey': 'institution.registry.almasareen.note',
    },
    'u_usf': {
      'name': 'United Sports Federation',
      'nameKey': 'institution.registry.usf.name',
      'handle': 'usports',
      'kind': 'sports',
      'badgeKey': 'institution.badge.esteemedSports',
      'noteKey': 'institution.registry.usf.note',
    },
    'platform': {
      'name': 'MASAREEN Platform',
      'nameKey': 'institution.registry.platform.name',
      'handle': 'masareen',
      'kind': 'platform',
      'badgeKey': 'institution.badge.officialPlatform',
      'noteKey': 'institution.registry.platform.note',
    },
  };

  static const Map<String, IconData> _icons = {
    'government': Icons.account_balance_outlined,
    'media': Icons.newspaper,
    'sports': Icons.emoji_events_outlined,
    'organization': Icons.handshake_outlined,
    'individual': Icons.person_outline,
    'platform': Icons.verified,
    'university': Icons.school_outlined,
  };

  static const Map<String, String> _typeLabelKeys = {
    'government': 'institution.type.government',
    'media': 'institution.type.media',
    'sports': 'institution.type.sports',
    'organization': 'institution.type.organization',
    'individual': 'institution.type.individual',
    'platform': 'institution.type.platform',
    'university': 'institution.type.university',
  };

  Future<void> _openCourse(String id) async {
    if (widget.user == null) return;
    try {
      final course = await AuthApi.course(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              CourseDetailScreen(course: course, user: widget.user!)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                MasarenLocalizations.of(context, 'institution.loadFailed'))));
      }
    }
  }

  Future<void> _openOpportunity(String id) async {
    if (widget.user == null) return;
    try {
      final opportunity = await AuthApi.opportunity(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OpportunityDetailScreen(
              opportunity: opportunity, user: widget.user!)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                MasarenLocalizations.of(context, 'institution.loadFailed'))));
      }
    }
  }

  Future<void> _openProgram(String id) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProgramDetailScreen(programId: id)));
    if (mounted) _load();
  }

  Future<void> _openEvent(String id) async {
    if (widget.user == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventHubScreen(eventId: id, user: widget.user!)));
    if (mounted) _load();
  }

  Future<void> _openResearch(String postId) async {
    if (widget.user == null || postId.isEmpty) return;
    try {
      final post = await AuthApi.postById(postId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(
              post: post, currentUser: widget.user!, onChanged: (_) {})));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                MasarenLocalizations.of(context, 'institution.loadFailed'))));
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || widget.user == null) return;
    setState(() => _followBusy = true);
    try {
      final result = await AuthApi.toggleFollow(widget.institutionId);
      if (!mounted) return;
      setState(() {
        _following = result['following'] == true;
        _followers = (result['followers_count'] as num?)?.toInt() ?? _followers;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? (e.message ?? 'Could not update follow state.')
          : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _addLink() async {
    final targetId = TextEditingController();
    final relation = TextEditingController(text: 'RELATED');
    String targetType = 'course';
    const types = [
      'course',
      'event',
      'program',
      'project',
      'opportunity',
      'research_stage',
      'user',
    ];
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
              MasarenLocalizations.of(context, 'institution.connectTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetType,
                decoration: InputDecoration(
                    labelText: MasarenLocalizations.of(
                        context, 'institution.targetType')),
                items: types
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.replaceAll('_', ' '))))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => targetType = v ?? 'course'),
              ),
              TextField(
                controller: targetId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: MasarenLocalizations.of(
                        context, 'institution.targetId')),
              ),
              TextField(
                controller: relation,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: MasarenLocalizations.of(
                        context, 'institution.relation'),
                    hintText: 'PARTNER, TEACHES, HOSTS...'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(MasarenLocalizations.of(context, 'common.cancel'))),
            FilledButton(
              onPressed: () {
                final id = int.tryParse(targetId.text.trim());
                if (id == null) return;
                Navigator.pop(dialogContext, {
                  'source_type': 'user',
                  'source_id': widget.institutionId,
                  'links': [
                    {
                      'target_type': targetType,
                      'target_id': id,
                      'relation': relation.text.trim().isEmpty
                          ? 'RELATED'
                          : relation.text.trim(),
                    }
                  ],
                });
              },
              child:
                  Text(MasarenLocalizations.of(context, 'institution.connect')),
            ),
          ],
        ),
      ),
    );
    targetId.dispose();
    relation.dispose();
    if (payload == null || !mounted) return;
    try {
      await AuthApi.createEntityLinks(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              MasarenLocalizations.of(context, 'institution.connectSuccess'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? (e.message ?? 'Could not connect this entity.')
          : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _fundEvent(String id, String title) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(MasarenLocalizations.of(context, 'institution.fundEvent')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    MasarenLocalizations.of(context, 'institution.amountMrc'),
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
            child: Text(MasarenLocalizations.of(context, 'institution.fund')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;
    try {
      await AuthApi.fundEvent(id, amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              MasarenLocalizations.of(context, 'institution.fundingThanks'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? (e.message ?? 'Could not fund this event.')
          : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Map<String, dynamic> _localize(
      BuildContext context, Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    if (raw['remote'] == true) {
      out['badge'] = MasarenLocalizations.of(
          context,
          raw['verified'] == true
              ? 'institution.badge.verified'
              : 'institution.badge.institution');
      return out;
    }
    for (final field in ['name', 'note', 'mandate', 'badge', 'hq']) {
      final key = raw['${field}Key'];
      if (key is String) {
        out[field] = MasarenLocalizations.of(context, key);
      }
    }
    final sectorKeys = raw['sectorKeys'];
    if (sectorKeys is List) {
      out['sectors'] = sectorKeys
          .map((k) => MasarenLocalizations.of(context, k.toString()))
          .toList();
    }
    return out;
  }

  String _typeLabel(BuildContext context, String kind) {
    return MasarenLocalizations.of(
        context, _typeLabelKeys[kind] ?? 'institution.type.individual');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final raw = _remote ?? _registry[widget.institutionId];
    if (raw == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error == null
              ? Text(MasarenLocalizations.of(context, 'institution.notFound'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _load,
                        child: Text(
                            MasarenLocalizations.of(context, 'common.retry'))),
                  ],
                ),
        ),
      );
    }
    final inst = _localize(context, raw);
    final kind = inst['kind'] as String? ?? 'individual';
    final icon = _icons[kind] ?? Icons.business;
    final typeLabel = _typeLabel(context, kind);
    final linked = inst['linked'] is Map
        ? Map<String, dynamic>.from(inst['linked'] as Map)
        : const <String, dynamic>{};
    int countOf(String key) =>
        linked[key] is List ? (linked[key] as List).length : 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top),
              ProfileHero(
                title: (inst['name'] ?? '').toString(),
                subtitle: '@${inst['handle']} · $typeLabel',
                kind: kind,
                icon: icon,
                imageUrl: (inst['avatar_url'] ?? inst['logo_url'])?.toString(),
                coverUrl: inst['cover_url']?.toString(),
                badge: ProfilePill(
                    label: (inst['badge'] ?? '').toString(),
                    icon: Icons.workspace_premium_outlined,
                    color: ProfileColors.gold),
                onShare: () => copyProfileLink(context, widget.institutionId,
                    MasarenLocalizations.of(context, 'profile.linkCopied'),
                    verified: inst['verified'] == true),
                stats: [
                  if (countOf('courses') > 0)
                    ProfileStat('${countOf('courses')}',
                        MasarenLocalizations.of(context, 'institution.courses'),
                        icon: Icons.menu_book_outlined),
                  if (countOf('events') > 0)
                    ProfileStat('${countOf('events')}',
                        MasarenLocalizations.of(context, 'institution.events'),
                        icon: Icons.event_outlined),
                  if (countOf('projects') > 0)
                    ProfileStat(
                        '${countOf('projects')}',
                        MasarenLocalizations.of(
                            context, 'institution.projects'),
                        icon: Icons.rocket_launch_outlined),
                  if (countOf('research_stages') > 0)
                    ProfileStat(
                        '${countOf('research_stages')}',
                        MasarenLocalizations.of(
                            context, 'institution.research'),
                        icon: Icons.science_outlined),
                ],
              ),
              if (inst['remote'] == true &&
                  widget.user != null &&
                  widget.user!.id != widget.institutionId)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _followBusy ? null : _toggleFollow,
                          icon: Icon(
                              _following
                                  ? Icons.check
                                  : Icons.add_circle_outline,
                              size: 18),
                          label: Text(MasarenLocalizations.of(
                              context,
                              _following
                                  ? 'action.following'
                                  : 'action.follow')),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44)),
                        ),
                      ),
                      if (_followers > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                            '$_followers ${MasarenLocalizations.of(context, 'profile.followers')}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
              if (inst['remote'] == true)
                _RemoteBody(
                  inst: inst,
                  user: widget.user,
                  onCourse: _openCourse,
                  onOpportunity: _openOpportunity,
                  onResearch: _openResearch,
                  onEvent: _openEvent,
                  onProgram: _openProgram,
                  onFund: _fundEvent,
                  onBrowseCourses: widget.user == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CoursesScreen(user: widget.user!))),
                  onBrowseEvents: widget.user == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EventsScreen(user: widget.user!))),
                  onBrowseProjects: widget.user == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProjectsScreen(user: widget.user!))),
                  onBrowseOpportunities: widget.user == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              OpportunitiesScreen(user: widget.user!))),
                )
              else if (kind == 'government')
                _GovBody(inst: inst)
              else if (kind == 'sports')
                _SportsBody(inst: inst)
              else if (kind == 'media')
                _MediaBody(inst: inst)
              else if (kind == 'platform')
                _PlatformBody(inst: inst)
              else
                _GenericBody(inst: inst, typeLabel: typeLabel),
              if (inst['remote'] == true &&
                  widget.user != null &&
                  (inst['user_id'] ?? '').toString() == widget.user!.id)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: OutlinedButton.icon(
                    onPressed: _addLink,
                    icon: const Icon(Icons.add_link, size: 18),
                    label: Text(MasarenLocalizations.of(
                        context, 'institution.connect')),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46)),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  final User? user;
  final void Function(String id)? onCourse;
  final void Function(String id)? onOpportunity;
  final void Function(String postId)? onResearch;
  final void Function(String id)? onEvent;
  final void Function(String id)? onProgram;
  final void Function(String id, String title)? onFund;
  final VoidCallback? onBrowseCourses;
  final VoidCallback? onBrowseEvents;
  final VoidCallback? onBrowseProjects;
  final VoidCallback? onBrowseOpportunities;
  const _RemoteBody({
    required this.inst,
    this.user,
    this.onCourse,
    this.onOpportunity,
    this.onResearch,
    this.onEvent,
    this.onProgram,
    this.onFund,
    this.onBrowseCourses,
    this.onBrowseEvents,
    this.onBrowseProjects,
    this.onBrowseOpportunities,
  });

  List<Map<String, dynamic>> _rows(String key) =>
      inst['linked'] is Map && (inst['linked'] as Map)[key] is List
          ? ((inst['linked'] as Map)[key] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [];

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  String _date(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return raw ?? '';
    return DateFormat.yMMMd().format(parsed.toLocal());
  }

  String _money(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  String _t(BuildContext context, String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metrics = inst['metrics'] is Map ? inst['metrics'] as Map : const {};
    final services =
        inst['services'] is List ? inst['services'] as List : const [];
    final departments =
        inst['departments'] is List ? inst['departments'] as List : const [];
    final note = (inst['note'] ?? '').toString();
    final transparency = (inst['transparency_score'] as num?) ?? 0;
    final courses = _rows('courses');
    final events = _rows('events');
    final projects = _rows('projects');
    final opportunities = _rows('opportunities');
    final research = _rows('research_stages');
    final programs = _rows('programs');
    final podcasts = _rows('podcasts');
    final vod = _rows('vod');
    final links = _rows('links');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isNotEmpty)
            _SectionCard(
              title: MasarenLocalizations.of(context, 'institution.about'),
              icon: Icons.info_outline,
              child: Text(note,
                  style: TextStyle(
                      fontSize: 15, height: 1.65, color: cs.onSurface)),
            ),
          if (research.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.research', 'Research stages'),
              icon: Icons.science_outlined,
              child: Column(
                children: research
                    .map((r) => _LinkTile(
                          icon: Icons.science_outlined,
                          title: (r['title'] ?? '').toString(),
                          subtitle: [
                            (r['stage'] ?? 'IDEA').toString(),
                            (r['researcher_name'] ?? '').toString(),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          body: (r['summary'] ?? '').toString(),
                          onTap: onResearch == null
                              ? null
                              : () =>
                                  onResearch!((r['post_id'] ?? '').toString()),
                        ))
                    .toList(),
              ),
            ),
          if (podcasts.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.podcasts', 'Podcasts'),
              icon: Icons.podcasts,
              child: Column(
                children: podcasts
                    .map((p) => _LinkTile(
                          icon: Icons.podcasts,
                          title: (p['title'] ?? '').toString(),
                          subtitle:
                              '${p['episodes_count'] ?? 0} ${_t(context, 'podcast.episodes', 'episodes')}',
                          onTap: user == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => PodcastShowScreen(
                                          showId: p['id'].toString(),
                                          user: user!))),
                        ))
                    .toList(),
              ),
            ),
          if (vod.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.vod', 'VOD & replays'),
              icon: Icons.video_library_outlined,
              child: Column(
                children: vod
                    .map((v) => _LinkTile(
                          icon: Icons.play_circle_outline,
                          title: (v['title'] ?? '').toString(),
                          subtitle: user == null
                              ? ''
                              : _t(context, 'vod.views', 'views'),
                          onTap: user == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => VodPlayerScreen(
                                          videoId: v['id'].toString(),
                                          user: user!))),
                        ))
                    .toList(),
              ),
            ),
          if (programs.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.programs', 'Programs'),
              icon: Icons.route_outlined,
              child: Column(
                children: programs
                    .map((p) => _LinkTile(
                          icon: Icons.route_outlined,
                          title: (p['title'] ?? '').toString(),
                          subtitle: (p['status'] ?? '').toString(),
                          onTap: onProgram == null
                              ? null
                              : () => onProgram!((p['id'] ?? '').toString()),
                        ))
                    .toList(),
              ),
            ),
          if (courses.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.courses', 'Courses'),
              icon: Icons.menu_book_outlined,
              trailing: onBrowseCourses == null
                  ? null
                  : TextButton(
                      onPressed: onBrowseCourses,
                      child: Text(_t(context, 'common.viewAll', 'View all'))),
              child: Column(
                children: courses
                    .map((c) => _LinkTile(
                          icon: Icons.play_circle_outline,
                          title: (c['title'] ?? '').toString(),
                          subtitle: [
                            (c['provider'] ?? '').toString(),
                            '${c['lessons'] ?? 0} ${_t(context, 'institution.lessons', 'lessons')}',
                            (c['is_free'] == false || c['is_free'] == 0)
                                ? '${_money((c['price_mrc'] as num?)?.toDouble() ?? 0)} MRC'
                                : _t(context, 'institution.free', 'Free'),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          onTap: onCourse == null
                              ? null
                              : () => onCourse!((c['id'] ?? '').toString()),
                        ))
                    .toList(),
              ),
            ),
          if (events.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.events', 'Events'),
              icon: Icons.event_outlined,
              trailing: onBrowseEvents == null
                  ? null
                  : TextButton(
                      onPressed: onBrowseEvents,
                      child: Text(_t(context, 'common.viewAll', 'View all'))),
              child: Column(
                children: events.map((e) {
                  final goal = (e['funding_goal'] as num?)?.toDouble() ?? 0;
                  final raised = (e['funding_raised'] as num?)?.toDouble() ?? 0;
                  final eventId = (e['id'] ?? '').toString();
                  return _LinkTile(
                    icon: Icons.event_available_outlined,
                    title: (e['title'] ?? '').toString(),
                    subtitle: [
                      _date(e['starts_at']?.toString()),
                      (e['location'] ?? '').toString(),
                      if (e['is_online'] == true || e['is_online'] == 1)
                        _t(context, 'events.online', 'Online'),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    progress: goal > 0
                        ? (raised / goal).clamp(0.0, 1.0).toDouble()
                        : null,
                    progressLabel: goal > 0
                        ? '${_money(raised)} / ${_money(goal)} MRC'
                        : null,
                    onTap: onEvent == null ? null : () => onEvent!(eventId),
                    action: goal > 0 &&
                            onFund != null &&
                            (e['author_id'] ?? '').toString() !=
                                (user?.id ?? '')
                        ? IconButton(
                            tooltip: _t(context, 'institution.fund', 'Fund'),
                            icon: const Icon(Icons.volunteer_activism_outlined,
                                size: 20),
                            onPressed: () =>
                                onFund!(eventId, (e['title'] ?? '').toString()),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
          if (projects.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.projects', 'Projects'),
              icon: Icons.rocket_launch_outlined,
              trailing: onBrowseProjects == null
                  ? null
                  : TextButton(
                      onPressed: onBrowseProjects,
                      child: Text(_t(context, 'common.viewAll', 'View all'))),
              child: Column(
                children: projects.map((p) {
                  final type = (p['project_type'] ?? 'COMMUNITY').toString();
                  final goal = (p['goal'] as num?)?.toDouble() ?? 0;
                  final raised = (p['raised'] as num?)?.toDouble() ?? 0;
                  final details = [
                    if (type != 'COMMUNITY')
                      _t(context, 'projects.type.$type', _label(type)),
                    if ((p['academic_year'] ?? '').toString().isNotEmpty)
                      (p['academic_year'] ?? '').toString(),
                    if ((p['student_names'] ?? '').toString().isNotEmpty)
                      (p['student_names'] ?? '').toString(),
                    if ((p['supervisor'] ?? '').toString().isNotEmpty)
                      '${_t(context, 'projects.supervisor', 'Supervisor')}: ${p['supervisor']}',
                  ];
                  return _LinkTile(
                    icon: Icons.workspace_premium_outlined,
                    title: (p['title'] ?? '').toString(),
                    subtitle: details.join(' · '),
                    progress: goal > 0
                        ? (raised / goal).clamp(0.0, 1.0).toDouble()
                        : null,
                    progressLabel: goal > 0
                        ? '${_money(raised)} / ${_money(goal)} MRC'
                        : null,
                  );
                }).toList(),
              ),
            ),
          if (opportunities.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.opportunities', 'Opportunities'),
              icon: Icons.work_outline,
              trailing: onBrowseOpportunities == null
                  ? null
                  : TextButton(
                      onPressed: onBrowseOpportunities,
                      child: Text(_t(context, 'common.viewAll', 'View all'))),
              child: Column(
                children: opportunities
                    .map((o) => _LinkTile(
                          icon: Icons.work_outline,
                          title: (o['title'] ?? '').toString(),
                          subtitle: [
                            (o['type'] ?? '').toString(),
                            (o['location'] ?? '').toString(),
                            if (o['is_remote'] == true || o['is_remote'] == 1)
                              _t(context, 'opportunities.remote', 'Remote'),
                            if ((o['deadline'] ?? '').toString().isNotEmpty)
                              _date(o['deadline']?.toString()),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          onTap: onOpportunity == null
                              ? null
                              : () =>
                                  onOpportunity!((o['id'] ?? '').toString()),
                        ))
                    .toList(),
              ),
            ),
          if (metrics.isNotEmpty)
            _SectionCard(
              title: MasarenLocalizations.of(context, 'institution.keyMetrics'),
              icon: Icons.insights_outlined,
              child: Wrap(
                spacing: 12,
                runSpacing: 0,
                children: metrics.entries
                    .map((e) => SizedBox(
                          width: 150,
                          child: _Stat(
                            e.value is num
                                ? (e.value as num) % 1 == 0
                                    ? (e.value as num).toInt().toString()
                                    : (e.value as num).toStringAsFixed(1)
                                : e.value.toString(),
                            _label(e.key.toString()),
                          ),
                        ))
                    .toList(),
              ),
            ),
          if (services.isNotEmpty)
            _SectionCard(
              title: MasarenLocalizations.of(context, 'institution.services'),
              icon: Icons.volunteer_activism_outlined,
              child: Column(
                children: services.map((s) {
                  final map = s is Map ? s : const {};
                  final name = (map['name'] ?? map['title'] ?? s).toString();
                  final description =
                      (map['description'] ?? map['detail'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeatureRow(Icons.check_circle_outline, name),
                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                                start: 30, bottom: 4),
                            child: Text(description,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, height: 1.45)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (departments.isNotEmpty)
            _SectionCard(
              title:
                  MasarenLocalizations.of(context, 'institution.departments'),
              icon: Icons.account_balance_outlined,
              child: Column(
                children: departments.map((d) {
                  final map = d is Map ? d : const {};
                  final name = (map['name'] ?? map['title'] ?? d).toString();
                  final contact = (map['contact'] ?? '').toString();
                  return _FeatureRow(
                    Icons.apartment_outlined,
                    contact.isEmpty ? name : '$name · $contact',
                  );
                }).toList(),
              ),
            ),
          if (transparency > 0)
            _SectionCard(
              title:
                  MasarenLocalizations.of(context, 'institution.transparency'),
              icon: Icons.verified_outlined,
              child: Row(
                children: [
                  Expanded(
                      child: _Stat(
                          '${transparency % 1 == 0 ? transparency.toInt() : transparency}%',
                          MasarenLocalizations.of(
                              context, 'institution.transparencyScore'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _Stat(
                          MasarenLocalizations.of(
                              context,
                              inst['verified'] == true
                                  ? 'institution.verified'
                                  : 'institution.listed'),
                          MasarenLocalizations.of(
                              context, 'institution.status'))),
                ],
              ),
            ),
          if (inst['reputation'] is Map &&
              ((inst['reputation'] as Map)['total_events'] ?? 0) > 0)
            _SectionCard(
              title:
                  _t(context, 'institution.reputation', 'Verified reputation'),
              icon: Icons.workspace_premium_outlined,
              child: Builder(builder: (context) {
                final reputation =
                    Map<String, dynamic>.from(inst['reputation'] as Map);
                return Row(
                  children: [
                    Expanded(
                        child: _Stat(
                            '${reputation['verified_events'] ?? 0}',
                            _t(context, 'events.verifiedEvents',
                                'verified events'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Stat('${reputation['clients'] ?? 0}',
                            _t(context, 'events.clients', 'clients'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Stat('${reputation['rating_avg'] ?? 0}',
                            _t(context, 'events.rating', 'rating'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Stat('#${reputation['rank'] ?? '-'}',
                            _t(context, 'events.rank', 'rank'))),
                  ],
                );
              }),
            ),
          if (links.isNotEmpty)
            _SectionCard(
              title: _t(context, 'institution.connected', 'Connected entities'),
              icon: Icons.hub_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: links.map((l) {
                  final type = (l['target_type'] ?? '').toString();
                  final id = (l['target_id'] ?? '').toString();
                  VoidCallback? action;
                  if (type == 'course' && onCourse != null) {
                    action = () => onCourse!(id);
                  } else if (type == 'opportunity' && onOpportunity != null) {
                    action = () => onOpportunity!(id);
                  } else if (type == 'post' && onResearch != null) {
                    action = () => onResearch!(id);
                  } else if (type == 'event' && onEvent != null) {
                    action = () => onEvent!(id);
                  } else if (type == 'project') {
                    action = onBrowseProjects;
                  }
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: action,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: cs.primary.withValues(alpha: .3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 14, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${(l['title'] ?? '').toString()} · ${(l['relation'] ?? '').toString()}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final double? progress;
  final String? progressLabel;
  final Widget? action;
  final VoidCallback? onTap;
  const _LinkTile({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.body = '',
    this.progress,
    this.progressLabel,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: cs.onSurface)),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(subtitle,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: cs.onSurfaceVariant)),
                    ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: cs.onSurfaceVariant)),
                    ),
                  if (progress != null) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: cs.surfaceContainerHighest),
                    ),
                    if (progressLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(progressLabel!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                      ),
                  ],
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class _GovBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _GovBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title:
                MasarenLocalizations.of(context, 'institution.officialMandate'),
            child: Text(inst['mandate'],
                style:
                    TextStyle(fontSize: 15, height: 1.6, color: cs.onSurface)),
          ),
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      inst['established'],
                      MasarenLocalizations.of(
                          context, 'institution.established'))),
              const SizedBox(width: 12),
              Expanded(
                  child: _Stat(
                      inst['hq'],
                      MasarenLocalizations.of(
                          context, 'institution.headquarters'))),
            ],
          ),
          _SectionCard(
            title: MasarenLocalizations.of(context, 'institution.sectors'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (inst['sectors'] as List)
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.brand),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ))
                  .toList(),
            ),
          ),
          _SectionCard(
            title:
                MasarenLocalizations.of(context, 'institution.publicReporting'),
            child: Text(
              MasarenLocalizations.of(
                  context, 'institution.publicReportingBody'),
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _MediaBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title:
                MasarenLocalizations.of(context, 'institution.whyRecognized'),
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      '96%',
                      MasarenLocalizations.of(
                          context, 'institution.evidenceAccuracy'))),
              const SizedBox(width: 12),
              Expanded(
                  child: _Stat(
                      '14',
                      MasarenLocalizations.of(
                          context, 'institution.countries'))),
              const SizedBox(width: 12),
              Expanded(
                  child: _Stat(
                      'A+',
                      MasarenLocalizations.of(
                          context, 'institution.trustRating'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SportsBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _SportsBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: MasarenLocalizations.of(context, 'institution.about'),
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      MasarenLocalizations.of(context, 'institution.active'),
                      MasarenLocalizations.of(context, 'institution.status'))),
              const SizedBox(width: 12),
              Expanded(
                  child: _Stat(inst['badge'],
                      MasarenLocalizations.of(context, 'institution.level'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  const _PlatformBody({required this.inst});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: MasarenLocalizations.of(context, 'institution.about'),
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
          _SectionCard(
            title: MasarenLocalizations.of(context, 'institution.features'),
            child: Column(
              children: [
                _FeatureRow(
                    Icons.verified,
                    MasarenLocalizations.of(
                        context, 'institution.feature.verified')),
                _FeatureRow(
                    Icons.campaign_outlined,
                    MasarenLocalizations.of(
                        context, 'institution.feature.announcements')),
                _FeatureRow(
                    Icons.emoji_events,
                    MasarenLocalizations.of(
                        context, 'institution.feature.recognition')),
                _FeatureRow(
                    Icons.work_outline,
                    MasarenLocalizations.of(
                        context, 'institution.feature.opportunities')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _GenericBody extends StatelessWidget {
  final Map<String, dynamic> inst;
  final String typeLabel;
  const _GenericBody({required this.inst, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          _SectionCard(
            title: MasarenLocalizations.of(context, 'institution.about'),
            child: Text(inst['note'],
                style: TextStyle(fontSize: 15, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  const _SectionCard(
      {required this.title, required this.child, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: cs.primary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        height: 1.2,
                        letterSpacing: -0.2)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}
