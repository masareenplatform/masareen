import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';

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
    'Overview', 'Reports', 'Coverage', 'Analytics',
    'Achievements', 'Timeline', 'Recommendations',
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
      final reports = await AuthApi.personnelReports(widget.userId);
      final analytics = await AuthApi.personnelAnalytics(widget.userId);
      final timeline = await AuthApi.personnelTimeline(widget.userId);
      final achievements = await AuthApi.personnelAchievements(widget.userId);
      final orgs = await AuthApi.personnelOrganizations(widget.userId);
      final recs = await AuthApi.personnelRecommendations(widget.userId);
      if (mounted) {
        setState(() {
          _p = p;
          _reports = reports;
          _analytics = analytics;
          _timeline = timeline;
          _achievements = achievements;
          _orgs = orgs;
          _recommendations = recs;
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
      await AuthApi.followPersonnel(widget.userId);
      if (mounted) {
        setState(() => _following = !_following);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_following ? 'Following' : 'Unfollowed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        body: ErrorView(message: _error ?? 'Profile not found', onRetry: () => _load()),
      );
    }
    final p = _p!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(p),
          SliverToBoxAdapter(
            child: _buildImpactCard(p),
          ),
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
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(Personnel p) {
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.darkBg,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            p.coverUrl != null && p.coverUrl!.isNotEmpty
                ? Image.network(p.coverUrl!, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(gradient: brandGradient),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppAvatar(name: p.name, url: p.avatarUrl, size: 84),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (p.emailVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.verified,
                                    color: Colors.white, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(p.headline,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            _Pill(label: p.professionalRank),
                            _Pill(label: p.impactTier, color: AppColors.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isMe)
          _HeaderAction(
            icon: _busy ? Icons.hourglass_top : Icons.person_add_alt_1,
            onTap: _follow,
          ),
        _HeaderAction(
          icon: Icons.share_outlined,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile link copied'))),
        ),
        _HeaderAction(
          icon: Icons.download_outlined,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Generating portfolio…'))),
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
      decoration: glassDecoration(Theme.of(context).brightness == Brightness.dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.azure, size: 20),
              const SizedBox(width: 8),
              const Text('Professional Impact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              _ScoreBadge(label: 'Impact', value: p.impactScore, color: AppColors.azure),
              const SizedBox(width: 8),
              _ScoreBadge(label: 'Trust', value: p.trustScore, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 14),
          _ImpactRow(children: [
            _ImpactStat('Verified Reports', _num(k['verified_reports'])),
            _ImpactStat('Published', _num(k['total_reports'])),
            _ImpactStat('Evidence', _num(k['evidence_submitted'])),
            _ImpactStat('Missions', _num(k['verified_missions'])),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(Icons.flag, 'Beat', p.beat),
              _InfoChip(Icons.star, 'Expertise',
                  _first(p.expertise) ?? 'General Reporting'),
              _InfoChip(Icons.public, 'Coverage',
                  [p.country, p.city].where((e) => e != null).join(', ')),
              _InfoChip(Icons.g_translate, 'Languages',
                  _listStr(p.languages).take(3).join(', ')),
              _InfoChip(Icons.work, 'Status', p.employmentStatus),
              _InfoChip(Icons.calendar_today, 'Joined',
                  p.joined?.substring(0, 10) ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI grid ──────────────────────────────────────────────────────────────────
  Widget _buildKpiGrid(Personnel p) {
    final k = p.kpi;
    final items = <_Kpi>[
      _Kpi('Total Reports', _num(k['total_reports']), Icons.article_outlined),
      _Kpi('Verified', _num(k['verified_reports']), Icons.verified, AppColors.accent),
      _Kpi('Trust Score', _num(k['trust_score']), Icons.shield, AppColors.azure),
      _Kpi('AI Confidence', _num(k['ai_confidence']), Icons.psychology),
      _Kpi('Community', _num(k['community_rating']), Icons.thumb_up),
      _Kpi('Followers', _num(k['followers']), Icons.people),
      _Kpi('Countries', _num(k['countries_covered']), Icons.public),
      _Kpi('Coverage Hrs', _num(k['coverage_hours']), Icons.access_time),
      _Kpi('Quality', _num(k['average_quality_score']), Icons.grade),
      _Kpi('Growth %', _num(k['monthly_growth']), Icons.trending_up, AppColors.accent),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: items
            .map((e) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: glassDecoration(
                      Theme.of(context).brightness == Brightness.dark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(e.icon, size: 18,
                          color: e.color ?? AppColors.azure),
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
            label: Text(_tabs[i]),
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
            country: p.country,
            city: p.city,
            lat: null,
            lng: null,
            orgs: _orgs);
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
  String _num(dynamic v) =>
      v == null ? '0' : (v is num ? (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1)) : v.toString());
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
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
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
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
              const SectionTitle(title: 'Professional Summary'),
              _CardText(p.summary),
            ],
            if (p.mission.isNotEmpty) ...[
              const SectionTitle(title: 'Mission Statement'),
              _CardText(p.mission),
            ],
            if (p.bio.isNotEmpty) ...[
              const SectionTitle(title: 'Biography'),
              _CardText(p.bio),
            ],
            const SectionTitle(title: 'Areas of Expertise'),
            _WrapChips(_strList(p.expertise)),
            const SectionTitle(title: 'Skills'),
            _WrapChips(_strList(p.skills)),
            if (p.experience.isNotEmpty) ...[
              const SectionTitle(title: 'Experience'),
              ...p.experience.map((e) => _ExperienceTile(
                  e is Map ? e['role'] ?? '' : '',
                  e is Map ? (e['org'] ?? '') : '',
                  e is Map ? '${e['from'] ?? ''} – ${e['to'] ?? ''}' : '')),
            ],
            if (orgs.isNotEmpty) ...[
              const SectionTitle(title: 'Organizations'),
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
              ? const [Text('Not specified',
                  style: TextStyle(color: AppColors.muted))]
              : items
                  .map((s) => Chip(
                      label: Text(s,
                          style: const TextStyle(fontSize: 12))))
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

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => (e is Map ? (e['name'] ?? '') : e.toString()).toString()).toList() : const [];

// ── Tab: Reports ──────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  final List<PersonnelReport> reports;
  const _ReportsTab({required this.reports});
  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Text('No published reports yet.',
                style: TextStyle(color: AppColors.muted))),
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
                  Text(verified ? 'Verified' : 'In Review',
                      style: TextStyle(
                          fontSize: 11,
                          color: verified ? AppColors.accent : Colors.amber)),
                  const Spacer(),
                  if (r.sdg > 0)
                    Text('SDG ${r.sdg}',
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
                  Text('Impact ${r.impactScore.toInt()}',
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
  final double? lat;
  final double? lng;
  final List<dynamic> orgs;
  const _CoverageTab(
      {this.country, this.city, this.lat, this.lng, required this.orgs});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Coverage Regions'),
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
                        Text(country ?? 'Global',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text(city ?? 'Field coverage',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const Icon(Icons.location_on, color: Colors.white70),
                ],
              ),
            ),
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
  final Map<String, String> _metrics = const {
    'impact_score': 'Impact Score',
    'reach': 'Reach',
    'engagement': 'Engagement',
    'verified_reports': 'Verified Reports',
    'trust_score': 'Trust Score',
    'influence': 'Influence',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Impact Analytics'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _metrics.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
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
                ? const Center(
                    child: Text('No analytics yet',
                        style: TextStyle(color: AppColors.muted)))
                : _MiniChart(
                    points: widget.points,
                    metric: _metric,
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TrendCard('Impact Score', widget.points.isNotEmpty
                  ? widget.points.last.impactScore.toStringAsFixed(0) : '0', '+12%'),
              _TrendCard('Reach', widget.points.isNotEmpty
                  ? _compact(widget.points.last.reach) : '0', '+8%'),
              _TrendCard('Trust', widget.points.isNotEmpty
                  ? widget.points.last.trustScore.toStringAsFixed(0) : '0', '+5%'),
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
          decoration: glassDecoration(
              Theme.of(context).brightness == Brightness.dark),
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
                      color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
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
    final pad = 18.0;
    final w = size.width;
    final h = size.height - pad * 2;
    final step = w / (values.length + 1);

    final barPaint = Paint()
      ..shader = LinearGradient(
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
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Text('No achievements recorded yet.',
                style: TextStyle(color: AppColors.muted))),
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
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Text('No activity yet.',
                style: TextStyle(color: AppColors.muted))),
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
              Icon(icons[kind] ?? Icons.circle, color: AppColors.azure, size: 20),
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
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: Text('No recommendations yet.',
                style: TextStyle(color: AppColors.muted))),
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
                  const Icon(Icons.format_quote, color: AppColors.azure, size: 18),
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
