import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/interview_screen.dart';

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
  String _mission = '';
  String _about = '';
  String? _avatarUrl;
  String? _coverUrl;
  String _logoUrl = '';
  int _membersCount = 0;
  int _projectsCount = 0;
  int _impactScore = 0;
  int _partnersCount = 0;
  bool _following = false;
  bool _isDonatable = true;

  List<Post> _feed = [];
  List<Map<String, dynamic>> _team = [];
  List<Project> _projects = [];

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
    _tabController = TabController(length: 5, vsync: this);
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
      ]);
      final user = results[0] as User;
      final posts = results[1] as List<Post>;
      final allProjects = results[2] as List<Project>;

      if (mounted) {
        setState(() {
          _name = user.fullName;
          _handle = user.email.split('@').first;
          _avatarUrl = user.avatarUrl;
          _coverUrl = user.coverUrl;
          if (user.bio != null && user.bio!.isNotEmpty) {
            _about = user.bio!;
          }
          _orgType = user.role.toUpperCase();
          _following = false;

          _feed = posts;
          _projectsCount = allProjects.length;
          _projects = allProjects;

          final authorNames = <String>{};
          for (final p in posts) {
            if (p.author.name.isNotEmpty) {
              authorNames.add(p.author.name);
            }
          }
          _team = authorNames.map((name) => {
            'name': name,
            'role': 'Contributor',
            'avatar': null,
          }).toList();
          _membersCount = authorNames.isEmpty ? 0 : authorNames.length;
          _impactScore = posts.length;
          _partnersCount = 0;
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
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AuthApi.followPersonnel(widget.orgId);
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
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: cs.surface,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
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
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          _buildCoverBanner(cs, dark),
          SliverToBoxAdapter(child: _buildLogoSection(cs, dark)),
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

  // ── Cover Banner ───────────────────────────────────────────────────────
  Widget _buildCoverBanner(ColorScheme cs, bool dark) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: cs.onSurface),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.share_outlined, size: 18, color: cs.onSurface),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied'))),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _coverUrl != null && _coverUrl!.isNotEmpty
                ? Image.network(_coverUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverGradient(cs))
                : _coverGradient(cs),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    cs.surface.withValues(alpha: 0.85),
                    cs.surface,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildOrgAvatar(cs),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_name,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _orgTypeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _orgTypeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(_orgType,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _orgTypeColor)),
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
    );
  }

  Widget _coverGradient(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _orgTypeColor.withValues(alpha: 0.8),
            _orgTypeColor.withValues(alpha: 0.5),
            cs.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  // ── Logo Section ───────────────────────────────────────────────────────
  Widget _buildLogoSection(ColorScheme cs, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_orgTypeColor, _orgTypeColor.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _orgTypeColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
              ),
              child: ClipOval(
                child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? Image.network(_avatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _orgFallback(cs))
                    : _orgFallback(cs),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Icon(Icons.verified, color: AppColors.azure, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_orgType,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _orgTypeColor)),
                Text('@$_handle',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orgFallback(ColorScheme cs) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_orgTypeColor, _orgTypeColor.withValues(alpha: 0.7)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _name.isNotEmpty ? _name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildOrgAvatar(ColorScheme cs) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.surface, width: 4),
        image: _logoUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(_logoUrl), fit: BoxFit.cover)
            : null,
      ),
      child: _logoUrl.isEmpty
          ? Icon(Icons.apartment, size: 36, color: cs.onSurfaceVariant)
          : null,
    );
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
  Widget _buildStatsRow(ColorScheme cs, bool dark) {
    final items = [
      _OrgStatData(
          'Members', _membersCount.toString(), Icons.group_outlined),
      _OrgStatData(
          'Projects', _projectsCount.toString(), Icons.folder_outlined),
      _OrgStatData(
          'Impact', '$_impactScore', Icons.analytics_outlined, AppColors.accent),
      _OrgStatData(
          'Partners', _partnersCount.toString(), Icons.handshake_outlined),
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
                        Icon(e.icon,
                            size: 18, color: e.color ?? cs.primary),
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
  Widget _buildActionButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _busy ? null : _follow,
                icon: Icon(
                    _following ? Icons.check : Icons.person_add_alt_1,
                    size: 16),
                label: Text(_following ? 'Following' : 'Follow'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _following ? AppColors.azure : cs.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InterviewScreen(
                      roomId: 'org_${widget.orgId}',
                      userName: widget.currentUser.fullName,
                      isInitiator: true,
                    ),
                  ));
                },
                icon: const Icon(Icons.handshake_outlined, size: 16),
                label: const Text('Collaborate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  side: BorderSide(color: cs.outlineVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          if (_isDonatable) ...[
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Donation portal opening soon')));
                  },
                  icon: const Icon(Icons.favorite_outline, size: 16),
                  label: const Text('Donate'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
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
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerHeight: 0,
        splashBorderRadius: BorderRadius.circular(10),
        tabs: const [
          Tab(text: 'Feed'),
          Tab(text: 'Team'),
          Tab(text: 'Projects'),
          Tab(text: 'Impact'),
          Tab(text: 'About'),
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
            return _buildTeamTab(dark);
          case 2:
            return _buildProjectsTab(dark);
          case 3:
            return _buildImpactTab(dark);
          case 4:
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
      return _emptyState(cs, Icons.dynamic_feed_outlined, 'No posts yet');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _feed.map((post) {
          final isAnnouncement = post.kind == 'announcement';
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
                        child: const Text('ANNOUNCEMENT',
                            style: TextStyle(
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
                        child: Text(post.kind!.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _orgTypeColor)),
                      ),
                    const Spacer(),
                    Text(post.createdAt ?? '',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.text,
                    style: TextStyle(
                        fontSize: 14, color: cs.onSurface, height: 1.5)),
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
  Widget _buildTeamTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_team.isEmpty) {
      return _emptyState(cs, Icons.group_outlined, 'No team members listed');
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
                Text(m['role'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
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
      return _emptyState(cs, Icons.folder_outlined, 'No active projects');
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
                    child: Text('SDG ${p.sdg}',
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
          SectionTitle(title: 'Impact Metrics'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: glassDecoration(dark),
              child: Column(
                children: [
                  Row(
                    children: [
                      _impactItem(cs, 'Beneficiaries',
                          _impactMetrics['beneficiaries'].toString(),
                          Icons.people_outline),
                      _impactItem(cs, 'Programs',
                          _impactMetrics['programs'].toString(),
                          Icons.dashboard_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _impactItem(cs, 'Volunteers',
                          _impactMetrics['volunteers'].toString(),
                          Icons.volunteer_activism_outlined),
                      _impactItem(cs, 'Funds Raised',
                          _impactMetrics['fundsRaised'].toString(),
                          Icons.payments_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _impactItem(cs, 'Countries',
                          _impactMetrics['countries'].toString(),
                          Icons.public_outlined),
                      _impactItem(cs, 'Impact Score',
                          '$_impactScore/100',
                          Icons.analytics_outlined, AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SectionTitle(title: 'SDG Contributions'),
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
                        child: Text('SDG\n$sdg',
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
          SectionTitle(title: 'About'),
          _aboutCard(cs, dark, 'Organization Type', _orgType,
              Icons.business_outlined),
          _aboutCard(cs, dark, 'Description', _about, Icons.info_outline),
          _aboutCard(cs, dark, 'Email', '${_handle}@organization.org',
              Icons.email_outlined),
          const SizedBox(height: 8),
          SectionTitle(title: 'Social Links'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: glassDecoration(dark),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _socialIcon(Icons.language, 'Website', cs),
                  _socialIcon(Icons.facebook, 'Facebook', cs),
                  _socialIcon(Icons.code, 'GitHub', cs),
                  _socialIcon(Icons.alternate_email, 'X', cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(ColorScheme cs, bool dark, String title, String text,
      IconData icon) {
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
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _orgTypeColor,
                      letterSpacing: 1)),
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

  Widget _socialIcon(IconData icon, String label, ColorScheme cs) {
    return Column(
      children: [
        Icon(icon, size: 24, color: cs.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
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
