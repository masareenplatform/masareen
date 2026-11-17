import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/edit_professional_profile_screen.dart';
import 'package:masaren/profile_ui.dart';

class PersonnelProfileScreen extends StatefulWidget {
  final String userId;
  final User currentUser;
  const PersonnelProfileScreen(
      {super.key, required this.userId, required this.currentUser});

  @override
  State<PersonnelProfileScreen> createState() => _PersonnelProfileScreenState();
}

class _PersonnelProfileScreenState extends State<PersonnelProfileScreen> {
  Personnel? _p;
  List<PersonnelReport> _reports = [];
  List<AnalyticsPoint> _analytics = [];
  List<dynamic> _timeline = [];
  List<dynamic> _achievements = [];
  List<dynamic> _orgs = [];
  List<dynamic> _recommendations = [];
  bool _loading = true;
  bool _busy = false;
  bool _following = false;
  String? _error;
  String _tab = 'Overview';
  final List<String> _tabs = const [
    'Overview',
    'Reports',
    'Coverage',
    'Analytics',
    'Achievements',
    'Timeline',
    'Recommendations',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await AuthApi.personnel(widget.userId);
      final results = await Future.wait([
        AuthApi.personnelReports(widget.userId)
            .then<Object>((v) => v)
            .catchError((_) => <PersonnelReport>[]),
        AuthApi.personnelAnalytics(widget.userId)
            .then<Object>((v) => v)
            .catchError((_) => <AnalyticsPoint>[]),
        AuthApi.personnelTimeline(widget.userId)
            .then<Object>((v) => v)
            .catchError((_) => <dynamic>[]),
        AuthApi.personnelAchievements(widget.userId)
            .then<Object>((v) => v)
            .catchError((_) => <dynamic>[]),
        AuthApi.personnelOrganizations(widget.userId)
            .then<Object>((v) => v)
            .catchError((_) => <dynamic>[]),
        AuthApi.personnelRecommendations(widget.userId)
            .then<Object>((v) => v)
            .catchError((_) => <dynamic>[]),
      ]);
      if (mounted) {
        setState(() {
          _p = p;
          _following = p.isFollowing;
          _reports = results[0] as List<PersonnelReport>;
          _analytics = results[1] as List<AnalyticsPoint>;
          _timeline = results[2] as List<dynamic>;
          _achievements = results[3] as List<dynamic>;
          _orgs = results[4] as List<dynamic>;
          _recommendations = results[5] as List<dynamic>;
        });
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isMe => _p?.userId == widget.currentUser.id;

  Future<void> _follow() async {
    if (_busy || _isMe) return;
    setState(() => _busy = true);
    try {
      final res = await AuthApi.followPersonnel(widget.userId);
      if (mounted) {
        setState(
            () => _following = res['following'] == true ? true : !_following);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context,
                _following ? 'action.following' : 'profile.unfollowed'))));
      }
    } catch (e) {
      if (mounted) {
        final message = MasarenLocalizations.of(context, 'common.failed')
            .replaceAll('{error}', '$e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor() async {
    if (_p == null) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => EditProfessionalProfileScreen(profile: _p!)));
    if (saved == true) _load();
  }

  Future<void> _exportProfile() async {
    final p = _p;
    if (p == null) return;
    final buffer = StringBuffer()
      ..writeln(p.name)
      ..writeln(p.headline)
      ..writeln()
      ..writeln(p.bio)
      ..writeln()
      ..writeln('Impact score: ${p.impactScore.toStringAsFixed(1)}')
      ..writeln('Trust score: ${p.trustScore.toStringAsFixed(0)}')
      ..writeln('PMS: ${p.pmsScore.toStringAsFixed(0)} (${p.pmsTier})')
      ..writeln('Rank: ${p.professionalRank}')
      ..writeln('Skills: ${_strList(p.skills).join(', ')}')
      ..writeln('Languages: ${_strList(p.languages).join(', ')}')
      ..writeln('Coverage: ${_strList(p.coverageRegions).join(', ')}')
      ..writeln('Website: ${p.website ?? ''}')
      ..writeln()
      ..writeln('https://masareen.com/u/${p.userId}');
    await copyProfileText(context, buffer.toString(),
        MasarenLocalizations.of(context, 'personnel.exportReady'));
  }

  Future<void> _shareProfile() async {
    await copyProfileLink(context, widget.userId,
        MasarenLocalizations.of(context, 'personnel.linkCopied'),
        verified: _p?.emailVerified == true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
            message: _error ?? 'Profile not found', onRetry: () => _load()),
      );
    }
    final p = _p!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).top)),
            _buildHeader(p),
            SliverToBoxAdapter(child: _buildPrimaryActions()),
            SliverToBoxAdapter(
              child: _buildImpactCard(p),
            ),
            SliverToBoxAdapter(child: _buildProfessionalCard(p)),
            SliverToBoxAdapter(child: _buildKpiGrid(p)),
            SliverToBoxAdapter(child: _buildTabBar()),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildTabContent(p),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(Personnel p) {
    return SliverToBoxAdapter(
      child: ProfileHero(
        title: p.name,
        subtitle: p.headline,
        kind: 'personnel',
        icon: Icons.badge_outlined,
        imageUrl: p.avatarUrl,
        coverUrl: p.coverUrl,
        badge: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ProfilePill(
                label: p.professionalRank,
                icon: Icons.workspace_premium_outlined,
                color: ProfileColors.gold),
            ProfilePill(
                label: p.impactTier,
                icon: Icons.trending_up_rounded,
                color: ProfileColors.gold),
          ],
        ),
        stats: [
          ProfileStat(_num(p.impactScore.toStringAsFixed(1)),
              MasarenLocalizations.of(context, 'personnel.metric.impactScore'),
              icon: Icons.insights_outlined),
          ProfileStat(_num(p.trustScore.toStringAsFixed(0)),
              MasarenLocalizations.of(context, 'personnel.trustScore'),
              icon: Icons.verified_user_outlined),
          ProfileStat(_num(p.currentReach.toStringAsFixed(0)),
              MasarenLocalizations.of(context, 'personnel.metric.reach'),
              icon: Icons.visibility_outlined),
          ProfileStat(_num(p.pmsScore.toStringAsFixed(0)),
              MasarenLocalizations.of(context, 'personnel.metric.influence'),
              icon: Icons.auto_graph_rounded),
        ],
        trailing: _HeaderAction(
          icon: Icons.download_outlined,
          onTap: _exportProfile,
        ),
        onShare: _shareProfile,
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return ProfileActionBar(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _isMe ? _openEditor : (_busy ? null : _follow),
            icon: Icon(_isMe ? Icons.edit_outlined : Icons.person_add_alt_1,
                size: 16),
            label: Text(
                MasarenLocalizations.of(
                    context,
                    _isMe
                        ? 'profile.edit'
                        : (_following ? 'action.following' : 'action.follow')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            style: profilePrimaryStyle(),
          ),
        ),
      ],
    );
  }

  // ── Primary Impact Card ───────────────────────────────────────────────────────
  Widget _buildImpactCard(Personnel p) {
    final k = p.kpi;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(18),
      decoration:
          glassDecoration(Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.azure, size: 20),
              const SizedBox(width: 8),
              Text(
                  MasarenLocalizations.of(
                      context, 'personnel.professionalImpact'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              _ScoreBadge(
                  label:
                      MasarenLocalizations.of(context, 'organization.impact'),
                  value: p.impactScore,
                  color: AppColors.azure),
              const SizedBox(width: 8),
              _ScoreBadge(
                  label: MasarenLocalizations.of(context, 'profile.trust'),
                  value: p.trustScore,
                  color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 14),
          _ImpactRow(children: [
            _ImpactStat(
                MasarenLocalizations.of(context, 'personnel.verifiedReports'),
                _num(k['verified_reports'])),
            _ImpactStat(MasarenLocalizations.of(context, 'personnel.published'),
                _num(k['total_reports'])),
            _ImpactStat(MasarenLocalizations.of(context, 'personnel.evidence'),
                _num(k['evidence_submitted'])),
            _ImpactStat(MasarenLocalizations.of(context, 'personnel.missions'),
                _num(k['verified_missions'])),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(Icons.flag,
                  MasarenLocalizations.of(context, 'personnel.beat'), p.beat),
              _InfoChip(
                  Icons.star,
                  MasarenLocalizations.of(context, 'personnel.expertise'),
                  _first(p.expertise) ??
                      MasarenLocalizations.of(
                          context, 'personnel.generalReporting')),
              _InfoChip(
                  Icons.public,
                  MasarenLocalizations.of(context, 'personnel.coverage'),
                  [p.country, p.city].where((e) => e != null).join(', ')),
              _InfoChip(
                  Icons.g_translate,
                  MasarenLocalizations.of(context, 'personnel.languages'),
                  _listStr(p.languages).take(3).join(', ')),
              _InfoChip(
                  Icons.work,
                  MasarenLocalizations.of(context, 'personnel.status'),
                  p.employmentStatus),
              _InfoChip(
                  Icons.calendar_today,
                  MasarenLocalizations.of(context, 'profile.joined'),
                  p.joined?.substring(0, 10) ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalCard(Personnel p) {
    final raw = p.pms['dimensions'];
    final dims =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final entries = dims.entries
        .where((e) => e.value is num)
        .map((e) => MapEntry(e.key, (e.value as num).toDouble()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(16),
      decoration:
          glassDecoration(Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                  MasarenLocalizations.of(
                      context, 'personnel.professionalStanding'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              _Pill(label: '${p.pmsTier} · ${p.pmsScore.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                  MasarenLocalizations.of(context, 'personnel.profileStrength'),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const Spacer(),
              Text('${p.completeness}%',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (p.completeness / 100).clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: AppColors.darkLine,
              color: AppColors.accent,
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...entries.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _DimensionBar(
                      label: _dimensionLabel(e.key), value: e.value),
                )),
          ],
          if (p.badges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: p.badges
                  .take(6)
                  .map((b) =>
                      _Pill(label: b.toString(), color: AppColors.accent))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _tabLabel(String tab) =>
      MasarenLocalizations.of(context, 'personnel.tab.${tab.toLowerCase()}');

  String _dimensionLabel(String key) {
    final l10nKey = 'personnel.dimension.$key';
    final label = MasarenLocalizations.of(context, l10nKey);
    if (label != l10nKey) return label;
    return key
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // ── KPI grid ──────────────────────────────────────────────────────────────────
  Widget _buildKpiGrid(Personnel p) {
    final k = p.kpi;
    final items = <_Kpi>[
      _Kpi(MasarenLocalizations.of(context, 'personnel.totalReports'),
          _num(k['total_reports']), Icons.article_outlined),
      _Kpi(MasarenLocalizations.of(context, 'personnel.verified'),
          _num(k['verified_reports']), Icons.verified, AppColors.accent),
      _Kpi(MasarenLocalizations.of(context, 'personnel.trustScore'),
          _num(k['trust_score']), Icons.shield, AppColors.azure),
      _Kpi(MasarenLocalizations.of(context, 'personnel.aiConfidence'),
          _num(k['ai_confidence']), Icons.psychology),
      _Kpi(MasarenLocalizations.of(context, 'personnel.community'),
          _num(k['community_rating']), Icons.thumb_up),
      _Kpi(MasarenLocalizations.of(context, 'profile.followers'),
          _num(k['followers']), Icons.people),
      _Kpi(MasarenLocalizations.of(context, 'organization.countries'),
          _num(k['countries_covered']), Icons.public),
      _Kpi(MasarenLocalizations.of(context, 'personnel.coverageHrs'),
          _num(k['coverage_hours']), Icons.access_time),
      _Kpi(MasarenLocalizations.of(context, 'personnel.quality'),
          _num(k['average_quality_score']), Icons.grade),
      _Kpi(MasarenLocalizations.of(context, 'personnel.growth'),
          _num(k['monthly_growth']), Icons.trending_up, AppColors.accent),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: items
            .map((e) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: glassDecoration(
                      Theme.of(context).brightness == Brightness.dark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(e.icon, size: 18, color: e.color ?? AppColors.azure),
                      const SizedBox(height: 6),
                      Text(e.value,
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(e.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = _tabs[i] == _tab;
          return ChoiceChip(
            label: Text(_tabLabel(_tabs[i])),
            selected: active,
            onSelected: (_) => setState(() => _tab = _tabs[i]),
            selectedColor: AppColors.azure,
            labelStyle: TextStyle(
                color: active ? Colors.white : null,
                fontWeight: FontWeight.w700),
          );
        },
      ),
    );
  }

  Widget _buildTabContent(Personnel p) {
    switch (_tab) {
      case 'Reports':
        return _ReportsTab(reports: _reports);
      case 'Coverage':
        return _CoverageTab(
            country: p.country, city: p.city, regions: p.coverageRegions);
      case 'Analytics':
        return _AnalyticsTab(points: _analytics);
      case 'Achievements':
        return _AchievementsTab(items: _achievements);
      case 'Timeline':
        return _TimelineTab(items: _timeline);
      case 'Recommendations':
        return _RecommendationsTab(items: _recommendations);
      default:
        return _OverviewTab(p: p, orgs: _orgs, recs: _recommendations);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────────
  String _num(dynamic v) => v == null
      ? '0'
      : (v is num
          ? (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1))
          : v.toString());
  String? _first(dynamic v) =>
      v is List && v.isNotEmpty ? v.first.toString() : null;
  List<String> _listStr(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, this.color = AppColors.azure});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (color).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _DimensionBar extends StatelessWidget {
  final String label;
  final double value;
  const _DimensionBar({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.darkLine,
                color: AppColors.azure,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: Text(value.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 20), onPressed: onTap),
      );
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ScoreBadge(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value.toStringAsFixed(0),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      );
}

class _ImpactStat extends StatelessWidget {
  final String label;
  final String value;
  const _ImpactStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );
}

class _ImpactRow extends StatelessWidget {
  final List<Widget> children;
  const _ImpactRow({required this.children});
  @override
  Widget build(BuildContext context) => Row(children: children);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.darkSurface2.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkLine.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.azure),
            const SizedBox(width: 5),
            Text('$label: ',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  _Kpi(this.label, this.value, this.icon, [this.color]);
}

// ── Tab: Overview ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Personnel p;
  final List<dynamic> orgs;
  final List<dynamic> recs;
  const _OverviewTab({required this.p, required this.orgs, required this.recs});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.summary.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.professionalSummary')),
              _CardText(p.summary),
            ],
            if (p.mission.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.missionStatement')),
              _CardText(p.mission),
            ],
            if (p.bio.isNotEmpty) ...[
              SectionTitle(
                  title:
                      MasarenLocalizations.of(context, 'personnel.biography')),
              _CardText(p.bio),
            ],
            SectionTitle(
                title: MasarenLocalizations.of(
                    context, 'personnel.areasOfExpertise')),
            _WrapChips(_strList(p.expertise)),
            if (p.specializations.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.specializations')),
              _WrapChips(_strList(p.specializations)),
            ],
            SectionTitle(
                title: MasarenLocalizations.of(context, 'profile.skills')),
            _WrapChips(_strList(p.skills)),
            if (p.education.isNotEmpty) ...[
              SectionTitle(
                  title:
                      MasarenLocalizations.of(context, 'personnel.education')),
              _WrapChips(_strList(p.education)),
            ],
            if (p.certificates.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.certificates')),
              _WrapChips(_strList(p.certificates)),
            ],
            if (p.awards.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(context, 'personnel.awards')),
              _WrapChips(_strList(p.awards)),
            ],
            if (p.publications.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.publications')),
              _WrapChips(_strList(p.publications)),
            ],
            if (p.memberships.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.memberships')),
              _WrapChips(_strList(p.memberships)),
            ],
            if (p.experience.isNotEmpty) ...[
              SectionTitle(
                  title:
                      MasarenLocalizations.of(context, 'personnel.experience')),
              ...p.experience.map((e) => e is Map
                  ? _ExperienceTile(e['role'] ?? '', e['org'] ?? '',
                      '${e['from'] ?? ''} - ${e['to'] ?? ''}')
                  : _CardText(e.toString())),
            ],
            if (p.socialLinks.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.socialLinks')),
              _WrapChips(p.socialLinks.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .toList()),
            ],
            if (orgs.isNotEmpty) ...[
              SectionTitle(
                  title: MasarenLocalizations.of(
                      context, 'personnel.organizations')),
              ...orgs.map((o) => _ExperienceTile(
                  o['role'] ?? '', o['name'] ?? '', o['duration'] ?? '')),
            ],
            const SizedBox(height: 12),
          ],
        ),
      );
}

class _CardText extends StatelessWidget {
  final String text;
  const _CardText(this.text);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration:
            glassDecoration(Theme.of(context).brightness == Brightness.dark),
        child: Text(text,
            style: const TextStyle(color: AppColors.muted, height: 1.5)),
      );
}

class _WrapChips extends StatelessWidget {
  final List<String> items;
  const _WrapChips(this.items);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.isEmpty
              ? [
                  Text(
                      MasarenLocalizations.of(
                          context, 'personnel.notSpecified'),
                      style: const TextStyle(color: AppColors.muted))
                ]
              : items
                  .map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 12))))
                  .toList(),
        ),
      );
}

class _ExperienceTile extends StatelessWidget {
  final String role;
  final String org;
  final String duration;
  const _ExperienceTile(this.role, this.org, this.duration);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration:
            glassDecoration(Theme.of(context).brightness == Brightness.dark),
        child: Row(
          children: [
            const Icon(Icons.work_outline, color: AppColors.azure, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(org,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Text(duration,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );
}

List<String> _strList(dynamic v) => v is List
    ? v
        .map((e) => (e is Map ? (e['name'] ?? '') : e.toString()).toString())
        .toList()
    : const [];

// ── Tab: Reports ──────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  final List<PersonnelReport> reports;
  const _ReportsTab({required this.reports});
  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: Text(MasarenLocalizations.of(context, 'personnel.noReports'),
                style: const TextStyle(color: AppColors.muted))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final r = reports[i];
        final verified = r.verificationStatus == 'VERIFIED';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration:
              glassDecoration(Theme.of(context).brightness == Brightness.dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(r.category.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.azure)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    verified ? Icons.verified : Icons.pending,
                    size: 15,
                    color: verified ? AppColors.accent : Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                      MasarenLocalizations.of(
                          context,
                          verified
                              ? 'personnel.verified'
                              : 'personnel.inReview'),
                      style: TextStyle(
                          fontSize: 11,
                          color: verified ? AppColors.accent : Colors.amber)),
                  const Spacer(),
                  if (r.sdg > 0)
                    Text(
                        MasarenLocalizations.of(context, 'government.sdg')
                            .replaceAll('{sdg}', '${r.sdg}'),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 8),
              Text(r.headline,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MiniStat(Icons.visibility, r.reach),
                  _MiniStat(Icons.favorite, r.likes),
                  _MiniStat(Icons.comment, r.comments),
                  _MiniStat(Icons.grade, r.qualityScore.toInt()),
                  const Spacer(),
                  Text(
                      MasarenLocalizations.of(context, 'personnel.impactValue')
                          .replaceAll('{value}', '${r.impactScore.toInt()}'),
                      style: const TextStyle(
                          color: AppColors.azure,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final int value;
  const _MiniStat(this.icon, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.muted),
            const SizedBox(width: 3),
            Text(value.toString(),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      );
}

// ── Tab: Coverage ──────────────────────────────────────────────────────────────
class _CoverageTab extends StatelessWidget {
  final String? country;
  final String? city;
  final List<dynamic> regions;
  const _CoverageTab({this.country, this.city, this.regions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
                title: MasarenLocalizations.of(
                    context, 'personnel.coverageRegions')),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [AppColors.brand, AppColors.azure],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, color: Colors.white, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            country ??
                                MasarenLocalizations.of(
                                    context, 'personnel.global'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text(
                            city ??
                                MasarenLocalizations.of(
                                    context, 'personnel.fieldCoverage'),
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const Icon(Icons.location_on, color: Colors.white70),
                ],
              ),
            ),
            if (regions.isNotEmpty) ...[
              const SizedBox(height: 4),
              _WrapChips(_strList(regions)),
            ],
            const SizedBox(height: 12),
          ],
        ),
      );
}

// ── Tab: Analytics ────────────────────────────────────────────────────────────
class _AnalyticsTab extends StatefulWidget {
  final List<AnalyticsPoint> points;
  const _AnalyticsTab({required this.points});
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  String _metric = 'impact_score';

  String _trend(
      List<AnalyticsPoint> points, double Function(AnalyticsPoint) pick) {
    if (points.length < 2) return '';
    final first = pick(points.first);
    final last = pick(points.last);
    if (first == 0) return '';
    final delta = (last - first) / first * 100;
    return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%';
  }

  final Map<String, String> _metrics = const {
    'impact_score': 'personnel.metric.impactScore',
    'reach': 'personnel.metric.reach',
    'engagement': 'personnel.metric.engagement',
    'verified_reports': 'personnel.metric.verifiedReports',
    'trust_score': 'personnel.metric.trustScore',
    'influence': 'personnel.metric.influence',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
              title: MasarenLocalizations.of(
                  context, 'personnel.impactAnalytics')),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _metrics.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label:
                              Text(MasarenLocalizations.of(context, e.value)),
                          selected: _metric == e.key,
                          selectedColor: AppColors.azure,
                          labelStyle: TextStyle(
                              color: _metric == e.key ? Colors.white : null,
                              fontWeight: FontWeight.w700),
                          onSelected: (_) => setState(() => _metric = e.key),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 240,
            padding: const EdgeInsets.all(14),
            decoration: glassDecoration(dark),
            child: widget.points.isEmpty
                ? Center(
                    child: Text(
                        MasarenLocalizations.of(
                            context, 'personnel.noAnalytics'),
                        style: const TextStyle(color: AppColors.muted)))
                : _MiniChart(
                    points: widget.points,
                    metric: _metric,
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TrendCard(
                  MasarenLocalizations.of(
                      context, 'personnel.metric.impactScore'),
                  widget.points.isNotEmpty
                      ? widget.points.last.impactScore.toStringAsFixed(0)
                      : '0',
                  _trend(widget.points, (p) => p.impactScore)),
              _TrendCard(
                  MasarenLocalizations.of(context, 'personnel.metric.reach'),
                  widget.points.isNotEmpty
                      ? _compact(widget.points.last.reach)
                      : '0',
                  _trend(widget.points, (p) => p.reach)),
              _TrendCard(
                  MasarenLocalizations.of(context, 'profile.trust'),
                  widget.points.isNotEmpty
                      ? widget.points.last.trustScore.toStringAsFixed(0)
                      : '0',
                  _trend(widget.points, (p) => p.trustScore)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _compact(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
}

class _TrendCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  const _TrendCard(this.label, this.value, this.trend);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(14),
          decoration:
              glassDecoration(Theme.of(context).brightness == Brightness.dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(trend,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _MiniChart extends StatelessWidget {
  final List<AnalyticsPoint> points;
  final String metric;
  const _MiniChart({required this.points, required this.metric});

  double _val(AnalyticsPoint p) {
    switch (metric) {
      case 'reach':
        return p.reach;
      case 'engagement':
        return p.engagement;
      case 'verified_reports':
        return p.verifiedReports.toDouble();
      case 'trust_score':
        return p.trustScore;
      case 'influence':
        return p.influence;
      default:
        return p.impactScore;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: const Size(double.infinity, 200),
            painter: _LineBarPainter(
              points.map(_val).toList(),
              Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: points
              .map((p) => Text(p.bucket,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted)))
              .toList(),
        ),
      ],
    );
  }
}

class _LineBarPainter extends CustomPainter {
  final List<double> values;
  final bool dark;
  _LineBarPainter(this.values, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final range = (max - min) == 0 ? 1.0 : (max - min);
    const pad = 18.0;
    final w = size.width;
    final h = size.height - pad * 2;
    final step = w / (values.length + 1);

    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.brand, AppColors.azure],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, pad, w, h))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    final offsets = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = step * (i + 1);
      final norm = (values[i] - min) / range;
      final y = pad + h - norm * h;
      offsets.add(Offset(x, y));
      final barW = step * 0.5;
      final top = y;
      final bottom = pad + h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barW / 2, top, barW, bottom - top),
          const Radius.circular(4),
        ),
        barPaint,
      );
    }
    for (var i = 0; i < offsets.length; i++) {
      if (i == 0) {
        linePath.moveTo(offsets[i].dx, offsets[i].dy);
      } else {
        linePath.lineTo(offsets[i].dx, offsets[i].dy);
      }
    }
    canvas.drawPath(linePath, linePaint);
    final dot = Paint()..color = AppColors.accent;
    for (final o in offsets) {
      canvas.drawCircle(o, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ── Tab: Achievements ─────────────────────────────────────────────────────────
class _AchievementsTab extends StatelessWidget {
  final List<dynamic> items;
  const _AchievementsTab({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: Text(
                MasarenLocalizations.of(context, 'personnel.noAchievements'),
                style: const TextStyle(color: AppColors.muted))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final a = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration:
              glassDecoration(Theme.of(context).brightness == Brightness.dark),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (a['detail'] != null)
                      Text(a['detail'],
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab: Timeline ─────────────────────────────────────────────────────────────
class _TimelineTab extends StatelessWidget {
  final List<dynamic> items;
  const _TimelineTab({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: Text(
                MasarenLocalizations.of(context, 'personnel.noActivity'),
                style: const TextStyle(color: AppColors.muted))),
      );
    }
    final icons = <String, IconData>{
      'report': Icons.article_outlined,
      'mission': Icons.flag,
      'evidence': Icons.photo_library,
      'award': Icons.emoji_events,
      'org': Icons.work,
    };
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final t = items[i];
        final kind = (t['kind'] ?? 'report').toString();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration:
              glassDecoration(Theme.of(context).brightness == Brightness.dark),
          child: Row(
            children: [
              Icon(icons[kind] ?? Icons.circle,
                  color: AppColors.azure, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (t['happened_at'] != null)
                      Text(t['happened_at'].toString().substring(0, 10),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab: Recommendations ──────────────────────────────────────────────────────
class _RecommendationsTab extends StatelessWidget {
  final List<dynamic> items;
  const _RecommendationsTab({required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: Text(
                MasarenLocalizations.of(context, 'personnel.noRecommendations'),
                style: const TextStyle(color: AppColors.muted))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final r = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration:
              glassDecoration(Theme.of(context).brightness == Brightness.dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_quote,
                      color: AppColors.azure, size: 18),
                  const SizedBox(width: 8),
                  Text(r['author_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (r['relation'] != null)
                    Chip(
                        label: Text(r['relation'],
                            style: const TextStyle(fontSize: 10))),
                ],
              ),
              const SizedBox(height: 6),
              Text(r['text'] ?? '',
                  style: const TextStyle(color: AppColors.muted, height: 1.5)),
            ],
          ),
        );
      },
    );
  }
}
