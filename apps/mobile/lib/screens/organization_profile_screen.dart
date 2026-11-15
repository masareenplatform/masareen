import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/event_hub_screen.dart';
import 'package:masaren/screens/interview_screen.dart';
import 'package:masaren/screens/program_detail_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/widgets/post_media_gallery.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/profile_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class OrganizationProfileScreen extends StatefulWidget {
  final String orgId;
  final User currentUser;
  const OrganizationProfileScreen(
      {super.key, required this.orgId, required this.currentUser});

  @override
  State<OrganizationProfileScreen> createState() =>
      _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState extends State<OrganizationProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  late TabController _tabController;

  String _name = 'Organization';
  String _orgType = 'NGO';
  String _handle = '';
  String _email = '';
  String _mission = '';
  String _about = '';
  String? _avatarUrl;
  String? _coverUrl;
  int _impactScore = 0;
  int _avgImpactPercent = 0;
  bool _autoSelectedEvents = false;
  bool _following = false;
  bool _verified = false;
  Map<String, String> _socialLinks = {};
  bool get _isDonatable => widget.orgId != widget.currentUser.id;
  bool get _isSelf => widget.orgId == widget.currentUser.id;

  List<Post> _feed = [];
  List<Map<String, dynamic>> _team = [];
  List<Project> _projects = [];
  List<Event> _events = [];
  List<Program> _programs = [];

  Map<String, dynamic> _impactMetrics = {
    'beneficiaries': '0',
    'programs': 0,
    'sdgsContributed': <int>[],
    'countries': 0,
    'volunteers': 0,
    'fundsRaised': '\$0',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AuthApi.getUser(widget.orgId),
        AuthApi.feed(authorId: widget.orgId),
        AuthApi.projects(),
        AuthApi.events(includePast: true),
        AuthApi.programs(),
      ]);
      final user = results[0] as User;
      final posts = results[1] as List<Post>;
      final allProjects = results[2] as List<Project>;
      final allEvents = results[3] as List<Event>;
      final allPrograms = results[4] as List<Program>;
      Map<String, dynamic> institution = const {};
      try {
        institution = await api.get('/api/v1/users/${widget.orgId}/institution')
            as Map<String, dynamic>;
      } catch (_) {}
      final metrics = institution['metrics'] is Map
          ? institution['metrics'] as Map
          : const {};
      final socialLinks = institution['social_links'] is Map
          ? (institution['social_links'] as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{};
      final website = (institution['website'])?.toString() ?? '';
      final orgProjects = allProjects
          .where((p) =>
              p.author?.id == widget.orgId ||
              (p.ownerName != null && p.ownerName == user.fullName))
          .toList();
      final orgEvents = allEvents
          .where((e) => e.author?.id == widget.orgId)
          .toList();
      final linkedProgramIds = orgEvents
          .map((e) => e.programId)
          .whereType<String>()
          .toSet();
      final orgPrograms = allPrograms
          .where((p) =>
              p.author?.id == widget.orgId || linkedProgramIds.contains(p.id))
          .toList();

      if (mounted) {
        setState(() {
          _name = user.fullName;
          _handle = user.handle ?? user.email.split('@').first;
          _email = user.email;
          _avatarUrl = user.avatarUrl;
          _coverUrl = user.coverUrl;
          _socialLinks = socialLinks;
          if (website.isNotEmpty) _socialLinks['website'] = website;
          if (user.bio != null && user.bio!.isNotEmpty) {
            _about = user.bio!;
          }
          if (_mission.isEmpty) _mission = _about;
          _orgType = user.role.toUpperCase();
          _following = user.isFollowing;
          _verified = user.emailVerified || institution['verified'] == true;

          _feed = posts;
          _projects = orgProjects;
          _events = orgEvents;
          _programs = orgPrograms;
          final impactValues = posts
              .map((p) => p.isaScore != null
                  ? p.isaScore! / 10
                  : (p.impactValue ?? 0) * 10)
              .where((v) => v > 0)
              .map((v) => v.clamp(0, 100))
              .toList();
          _avgImpactPercent = impactValues.isEmpty
              ? 0
              : (impactValues.reduce((a, b) => a + b) / impactValues.length)
                  .round();
          if (!_autoSelectedEvents && orgEvents.isNotEmpty) {
            _autoSelectedEvents = true;
            _tabController.index = 1;
          }

          final authorNames = <String>{};
          for (final p in posts) {
            if (p.author.name.isNotEmpty) {
              authorNames.add(p.author.name);
            }
          }
          _team = authorNames
              .map((name) => {
                    'name': name,
                    'role': '',
                    'avatar': null,
                  })
              .toList();
          _impactScore = (metrics['impact_score'] as num?)?.toInt() ?? 0;

          final sdgs = metrics['sdgs_contributed'] is List
              ? (metrics['sdgs_contributed'] as List)
                  .whereType<num>()
                  .map((e) => e.toInt())
                  .toList()
              : <int>{
                  for (final p in orgProjects)
                    if (p.sdg != null) p.sdg!
                }.toList();
          _impactMetrics = {
            'beneficiaries': (metrics['beneficiaries'] ?? 0).toString(),
            'programs': (metrics['programs'] ?? 0).toString(),
            'sdgsContributed': sdgs,
            'countries': (metrics['countries'] ?? 0).toString(),
            'volunteers': (metrics['volunteers'] ?? 0).toString(),
            'fundsRaised': (metrics['funds_raised'] ?? '\$0').toString(),
          };
        });
      }
    } on ApiException catch (e) {
      if (mounted) _error = e.message;
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow() async {
    if (_busy || _isSelf) return;
    setState(() => _busy = true);
    try {
      final res = await AuthApi.followPersonnel(widget.orgId);
      if (mounted) {
        setState(
            () => _following = res['following'] == true ? true : !_following);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context,
                _following ? 'action.following' : 'organization.unfollowed'))));
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

  Future<void> _openDonation() async {
    final amountCtl = TextEditingController();
    var busy = false;
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.favorite_outline, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      MasarenLocalizations.of(
                              context, 'organization.donationTitle')
                          .replaceAll('{name}', _name),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                MasarenLocalizations.of(context, 'organization.donationBody'),
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: MasarenLocalizations.of(
                      context, 'organization.donationAmount'),
                  prefixIcon: const Icon(Icons.paid_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final amount =
                              double.tryParse(amountCtl.text.trim()) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(MasarenLocalizations.of(
                                    context, 'organization.donationInvalid'))));
                            return;
                          }
                          setSheet(() => busy = true);
                          try {
                            await AuthApi.transferCoins(widget.orgId, amount,
                                reference: 'Donation to $_name');
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(MasarenLocalizations.of(
                                          context,
                                          'organization.donationSent'))));
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(MasarenLocalizations.of(
                                          ctx, 'common.failed')
                                      .replaceAll('{error}', '$e'))));
                            }
                          } finally {
                            if (ctx.mounted) setSheet(() => busy = false);
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(MasarenLocalizations.of(
                          context, 'organization.donationSend')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    amountCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'feed.loading')),
          backgroundColor: cs.surface,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(MasarenLocalizations.of(context, 'common.error')),
          backgroundColor: cs.surface,
        ),
        body: ErrorView(message: _error, onRetry: () => _load()),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: cs.primary,
      backgroundColor: cs.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).top)),
          SliverToBoxAdapter(
            child: ProfileHero(
              title: _name,
              subtitle: _handle.isNotEmpty ? '@$_handle' : _email,
              kind: 'organization',
              icon: Icons.groups_outlined,
              imageUrl: _avatarUrl,
              coverUrl: _coverUrl,
              badge: ProfilePill(
                  label: _orgType,
                  icon: Icons.verified_outlined,
                  color: ProfileColors.gold),
              onShare: () => copyProfileLink(context, widget.orgId,
                  MasarenLocalizations.of(context, 'organization.linkCopied'),
                  verified: _verified),
              stats: [
                ProfileStat(_compact(_events.length),
                    MasarenLocalizations.of(context, 'nav.events'),
                    icon: Icons.event_outlined),
                ProfileStat(_compact(_programs.length),
                    MasarenLocalizations.of(context, 'nav.programs'),
                    icon: Icons.hub_outlined),
                ProfileStat(_compact(_feed.length),
                    MasarenLocalizations.of(context, 'profile.posts'),
                    icon: Icons.dynamic_feed_outlined),
                ProfileStat('$_avgImpactPercent%',
                    MasarenLocalizations.of(context, 'organization.impact'),
                    icon: Icons.trending_up_rounded),
              ],
            ),
          ),
          if (_mission.isNotEmpty)
            SliverToBoxAdapter(child: _buildMissionStatement(cs, dark)),
          SliverToBoxAdapter(child: _buildStatsRow(cs, dark)),
          SliverToBoxAdapter(child: _buildActionButtons(cs)),
          SliverToBoxAdapter(child: _buildTabBar(cs)),
          SliverToBoxAdapter(child: _buildTabContent(dark)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _postKindLabel(String? kind) {
    if (kind == null || kind.isEmpty) return '';
    final key = 'post.${kind.toLowerCase()}';
    final label = MasarenLocalizations.of(context, key);
    return label == key ? kind : label;
  }

  Color get _orgTypeColor {
    switch (_orgType.toUpperCase()) {
      case 'NGO':
        return AppColors.accent;
      case 'CORPORATE':
      case 'COMPANY':
        return AppColors.azure;
      case 'FOUNDATION':
        return AppColors.amber;
      default:
        return AppColors.azure;
    }
  }

  // ── Mission Statement ──────────────────────────────────────────────────
  Widget _buildMissionStatement(ColorScheme cs, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: glassDecoration(dark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote,
                size: 28, color: _orgTypeColor.withValues(alpha: 0.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _mission,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────
  Future<void> _openPost(Post post) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(
            post: post,
            currentUser: widget.currentUser,
            onChanged: (_) => _load())));
  }
  Widget _buildStatsRow(ColorScheme cs, bool dark) {
    final items = [
      _OrgStatData(MasarenLocalizations.of(context, 'nav.events'),
          _events.length.toString(), Icons.event_outlined),
      _OrgStatData(MasarenLocalizations.of(context, 'nav.programs'),
          _programs.length.toString(), Icons.hub_outlined),
      _OrgStatData(MasarenLocalizations.of(context, 'profile.posts'),
          _feed.length.toString(), Icons.dynamic_feed_outlined),
      _OrgStatData(MasarenLocalizations.of(context, 'organization.impact'),
          '$_avgImpactPercent%', Icons.analytics_outlined, AppColors.accent),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: items
            .map((e) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: glassDecoration(dark),
                    child: Column(
                      children: [
                        Icon(e.icon, size: 18, color: e.color ?? cs.primary),
                        const SizedBox(height: 6),
                        Text(e.value,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Action Buttons ─────────────────────────────────────────────────────
  Future<void> _toggleBlock() async {
    final name = _name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this account?'),
        content: Text(
            'You will no longer see $name in your feed, search or messages. You can unblock from Settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await AuthApi.toggleBlock(widget.orgId);
      final blocked = res['blocked'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(blocked ? '$name is blocked.' : '$name is unblocked.')));
        if (blocked) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
  Widget _buildActionButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: MasarenLocalizations.of(
                context, _following ? 'action.following' : 'action.follow'),
            child: IconButton.filledTonal(
              onPressed: _busy ? null : _follow,
              iconSize: 22,
              style: IconButton.styleFrom(
                backgroundColor: _following
                    ? AppColors.azure.withValues(alpha: .16)
                    : cs.primary.withValues(alpha: .12),
                foregroundColor: _following ? AppColors.azure : cs.primary,
                minimumSize: const Size(52, 52),
              ),
              icon: Icon(_following ? Icons.check : Icons.person_add_alt_1),
            ),
          ),
          const SizedBox(width: 14),
          Tooltip(
            message: MasarenLocalizations.of(
                context, 'organization.collaborate'),
            child: IconButton.filledTonal(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => InterviewScreen(
                    roomId: 'org_${widget.orgId}',
                    userName: widget.currentUser.fullName,
                    isInitiator: true,
                  ),
                ));
              },
              iconSize: 22,
              style: IconButton.styleFrom(
                backgroundColor: cs.surfaceContainerHighest,
                foregroundColor: cs.onSurface,
                minimumSize: const Size(52, 52),
              ),
              icon: const Icon(Icons.handshake_outlined),
            ),
          ),
          if (!_isSelf) ...[
            const SizedBox(width: 14),
            Tooltip(
              message: 'Block or unblock',
              child: IconButton.filledTonal(
                onPressed: _toggleBlock,
                iconSize: 22,
                style: IconButton.styleFrom(
                  backgroundColor: cs.errorContainer.withValues(alpha: .5),
                  foregroundColor: cs.error,
                  minimumSize: const Size(52, 52),
                ),
                icon: const Icon(Icons.block),
              ),
            ),
          ],
          if (_isDonatable) ...[
            const SizedBox(width: 14),
            Tooltip(
              message:
                  MasarenLocalizations.of(context, 'organization.donate'),
              child: IconButton.filled(
                onPressed: _openDonation,
                iconSize: 22,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(52, 52),
                ),
                icon: const Icon(Icons.favorite_outline),
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ── Tab Bar ────────────────────────────────────────────────────────────
  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelPadding: EdgeInsets.zero,
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicator: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerHeight: 0,
        splashBorderRadius: BorderRadius.circular(10),
        tabs: [
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'nav.feed'), child: const Icon(Icons.dynamic_feed_outlined))),
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'nav.events'), child: const Icon(Icons.event_outlined))),
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'nav.programs'), child: const Icon(Icons.hub_outlined))),
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'organization.tab.team'), child: const Icon(Icons.groups_outlined))),
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'projects.title'), child: const Icon(Icons.folder_outlined))),
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'organization.tab.impact'), child: const Icon(Icons.insights_outlined))),
          Tab(icon: Tooltip(message: MasarenLocalizations.of(context, 'institution.about'), child: const Icon(Icons.info_outline))),
        ],
      ),
    );
  }

  // ── Tab Content ────────────────────────────────────────────────────────
  Widget _buildTabContent(bool dark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (_, __) {
        switch (_tabController.index) {
          case 0:
            return _buildFeedTab(dark);
          case 1:
            return _buildEventsTab(dark);
          case 2:
            return _buildProgramsTab(dark);
          case 3:
            return _buildTeamTab(dark);
          case 4:
            return _buildProjectsTab(dark);
          case 5:
            return _buildImpactTab(dark);
          case 6:
            return _buildAboutTab(dark);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // ── Feed Tab ───────────────────────────────────────────────────────────
  Widget _buildFeedTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_feed.isEmpty) {
      return _emptyState(cs, Icons.dynamic_feed_outlined,
          MasarenLocalizations.of(context, 'organization.noPosts'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _feed.map((post) {
          final isAnnouncement =
              (post.kind ?? '').toUpperCase() == 'ANNOUNCEMENT';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(dark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isAnnouncement)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.azure.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                            MasarenLocalizations.of(
                                context, 'organization.announcement'),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.azure)),
                      ),
                    if (!isAnnouncement && post.kind != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _orgTypeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_postKindLabel(post.kind),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _orgTypeColor)),
                      ),
                    const Spacer(),
                    Text(post.createdAt != null ? timeAgo(post.createdAt!) : '',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.text,
                    style: TextStyle(
                        fontSize: 14, color: cs.onSurface, height: 1.5)),
                if (post.media.isNotEmpty || post.videoHlsUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PostMediaGallery(
                      media: post.media,
                      videoHlsUrl: post.videoHlsUrl,
                      videoPosterUrl: post.videoPosterUrl,
                      videoId: post.id,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.favorite_outline,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.likes}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.comments}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openPost(post),
                      icon: const Icon(Icons.forum_outlined, size: 15),
                      label: const Text('Discuss',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Team Tab ───────────────────────────────────────────────────────────
  String _label(String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  Widget _buildEventsTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_events.isEmpty) {
      return _emptyState(cs, Icons.event_outlined,
          _label('organization.noEvents', 'No events published yet.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _events.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: glassDecoration(dark),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventHubScreen(
                      eventId: e.id, user: widget.currentUser))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartImage(
                    url: e.coverUrl,
                    height: 150,
                    width: double.infinity,
                    fallbackIcon: Icons.event_outlined,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.title,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                            ),
                            if (e.activityVerified)
                              const Icon(Icons.verified,
                                  size: 18, color: AppColors.brand),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                            '${e.startsAt.length >= 10 ? e.startsAt.substring(0, 10) : e.startsAt}${e.location?.isNotEmpty == true ? ' - ${e.location}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _orgPill(e.eventType, AppColors.azure),
                            if (e.sdg != null)
                              _orgPill('SDG ${e.sdg}', AppColors.brand),
                            _orgPill(
                                '${e.participantsCount} ${_label('events.participants', 'participants')}',
                                AppColors.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgramsTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_programs.isEmpty) {
      return _emptyState(cs, Icons.hub_outlined,
          _label('organization.noPrograms', 'No programmes published yet.'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _programs.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: glassDecoration(dark),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProgramDetailScreen(programId: p.id))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartImage(
                    url: p.coverUrl,
                    height: 130,
                    width: double.infinity,
                    fallbackIcon: Icons.hub_outlined,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        if (p.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(p.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: cs.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _orgPill(p.status ?? 'ACTIVE', AppColors.brand),
                            _orgPill(
                                '${p.members ?? 0} ${_label('organization.members', 'members')}',
                                AppColors.azure),
                            if (p.sdg != null)
                              _orgPill('SDG ${p.sdg}', AppColors.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _orgPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
  Widget _buildTeamTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_team.isEmpty) {
      return _emptyState(cs, Icons.group_outlined,
          MasarenLocalizations.of(context, 'organization.noTeam'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: _team.map((m) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: glassDecoration(dark),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _orgTypeColor.withValues(alpha: 0.15),
                  child: Text(
                    m['name'].toString().isNotEmpty
                        ? m['name'][0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: _orgTypeColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Text(m['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    (m['role']?.toString().isNotEmpty ?? false)
                        ? m['role'].toString()
                        : MasarenLocalizations.of(
                            context, 'organization.contributor'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Projects Tab ───────────────────────────────────────────────────────
  Widget _buildProjectsTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_projects.isEmpty) {
      return _emptyState(cs, Icons.folder_outlined,
          MasarenLocalizations.of(context, 'organization.noProjects'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _projects.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(dark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (p.description != null) ...[
                  const SizedBox(height: 6),
                  Text(p.description!,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          height: 1.4)),
                ],
                if (p.sdg != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.azure.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                        MasarenLocalizations.of(context, 'government.sdg')
                            .replaceAll('{sdg}', '${p.sdg}'),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.azure)),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Impact Tab ─────────────────────────────────────────────────────────
  Widget _buildImpactTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    final sdgs = (_impactMetrics['sdgsContributed'] as List)
        .map((e) => e as int)
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
              title: MasarenLocalizations.of(
                  context, 'organization.impactMetrics')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: glassDecoration(dark),
              child: Column(
                children: [
                  Row(
                    children: [
                      _impactItem(
                          cs,
                          MasarenLocalizations.of(
                              context, 'organization.beneficiaries'),
                          _impactMetrics['beneficiaries'].toString(),
                          Icons.people_outline),
                      _impactItem(
                          cs,
                          MasarenLocalizations.of(
                              context, 'organization.programs'),
                          _impactMetrics['programs'].toString(),
                          Icons.dashboard_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _impactItem(
                          cs,
                          MasarenLocalizations.of(
                              context, 'organization.volunteers'),
                          _impactMetrics['volunteers'].toString(),
                          Icons.volunteer_activism_outlined),
                      _impactItem(
                          cs,
                          MasarenLocalizations.of(
                              context, 'organization.fundsRaised'),
                          _impactMetrics['fundsRaised'].toString(),
                          Icons.payments_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _impactItem(
                          cs,
                          MasarenLocalizations.of(
                              context, 'organization.countries'),
                          _impactMetrics['countries'].toString(),
                          Icons.public_outlined),
                      _impactItem(
                          cs,
                          MasarenLocalizations.of(
                              context, 'organization.impactScore'),
                          '$_impactScore/100',
                          Icons.analytics_outlined,
                          AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SectionTitle(
              title: MasarenLocalizations.of(
                  context, 'organization.sdgContributions')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sdgs
                  .map((sdg) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _sdgColor(sdg).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _sdgColor(sdg).withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                            MasarenLocalizations.of(
                                    context, 'organization.sdgShort')
                                .replaceAll('{sdg}', '$sdg'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _sdgColor(sdg),
                                height: 1.2)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactItem(ColorScheme cs, String label, String value, IconData icon,
      [Color? color]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color ?? cs.primary),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ── About Tab ──────────────────────────────────────────────────────────
  Widget _buildAboutTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
              title: MasarenLocalizations.of(context, 'institution.about')),
          _aboutCard(
              cs,
              dark,
              MasarenLocalizations.of(context, 'organization.organizationType'),
              _orgType,
              Icons.business_outlined),
          _aboutCard(
              cs,
              dark,
              MasarenLocalizations.of(context, 'organization.description'),
              _about,
              Icons.info_outline),
          _aboutCard(
              cs,
              dark,
              MasarenLocalizations.of(context, 'organization.email'),
              _email,
              Icons.email_outlined),
          const SizedBox(height: 8),
          SectionTitle(
              title:
                  MasarenLocalizations.of(context, 'organization.socialLinks')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _socialLinks.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: glassDecoration(dark),
                    child: Center(
                      child: Text(
                        MasarenLocalizations.of(
                            context, 'organization.noLinks'),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: glassDecoration(dark),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.center,
                      children: _socialLinks.entries
                          .map((entry) =>
                              _socialLink(entry.key, entry.value, cs, dark))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _socialLink(String key, String value, ColorScheme cs, bool dark) {
    final icon = switch (key.toLowerCase()) {
      'facebook' => Icons.facebook,
      'twitter' || 'x' => Icons.alternate_email,
      'linkedin' => Icons.business_center,
      'instagram' => Icons.photo_camera,
      'youtube' => Icons.play_circle_outline,
      _ => Icons.language,
    };
    final uri =
        Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: uri == null
          ? null
          : () async {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Icon(icon, size: 24, color: _orgTypeColor),
            const SizedBox(height: 4),
            Text(key,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _aboutCard(
      ColorScheme cs, bool dark, String title, String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _orgTypeColor),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _orgTypeColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 14, color: cs.onSurfaceVariant, height: 1.5)),
        ],
      ),
    );
  }

  Color _sdgColor(int sdg) {
    const colors = {
      1: Color(0xFFE5243B),
      2: Color(0xFFDDA63A),
      3: Color(0xFF4C9F38),
      4: Color(0xFFC5192D),
      5: Color(0xFFFF3A21),
      6: Color(0xFF26BDE2),
      7: Color(0xFFFCC30B),
      8: Color(0xFFA21942),
      9: Color(0xFFFD6925),
      10: Color(0xFFDD1367),
      11: Color(0xFFFD9D24),
      12: Color(0xFFBF8B2E),
      13: Color(0xFF3F7E44),
      14: Color(0xFF0A97D9),
      15: Color(0xFF56C02B),
      16: Color(0xFF00689D),
      17: Color(0xFF19486A),
    };
    return colors[sdg] ?? AppColors.azure;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _emptyState(ColorScheme cs, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon,
              size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _OrgStatData {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  _OrgStatData(this.label, this.value, this.icon, [this.color]);
}
