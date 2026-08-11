import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/interview_screen.dart';
import 'package:masaren/widgets/animations.dart';

class GovernmentProfileScreen extends StatefulWidget {
  final String orgId;
  final User currentUser;
  const GovernmentProfileScreen(
      {super.key, required this.orgId, required this.currentUser});

  @override
  State<GovernmentProfileScreen> createState() =>
      _GovernmentProfileScreenState();
}

class _GovernmentProfileScreenState extends State<GovernmentProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  late TabController _tabController;

  String _name = 'Ministry of Environment';
  String _subtitle = 'Government of Egypt';
  String _about = '';
  String? _avatarUrl;
  int _servicesCount = 0;
  int _citizensReached = 0;
  int _projectsCount = 0;
  int _publicationsCount = 0;
  double _transparencyRating = 0;
  bool _following = false;

  List<Map<String, dynamic>> _services = [];
  List<Post> _announcements = [];
  List<Project> _projects = [];
  List<Map<String, dynamic>> _departments = [];

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
        AuthApi.feed(authorId: widget.orgId, kind: 'announcement'),
        AuthApi.projects(),
      ]);
      final user = results[0] as User;
      final posts = results[1] as List<Post>;
      final allProjects = results[2] as List<Project>;

      if (mounted) {
        setState(() {
          _name = user.fullName;
          _avatarUrl = user.avatarUrl;
          if (user.bio != null && user.bio!.isNotEmpty) {
            _about = user.bio!;
          }
          _following = false;

          _announcements = posts;
          _publicationsCount = posts.length;

          _projects = allProjects;
          _projectsCount = allProjects.length;

          _servicesCount = 0;
          _citizensReached = 0;
          _transparencyRating = 0;
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

    return Stack(
      children: [
        Positioned.fill(child: FloatingShapes(shapeCount: 3, baseColor: const Color(0xFF0B1B3A))),
        RefreshIndicator(
      onRefresh: _load,
      color: cs.primary,
      backgroundColor: cs.surface,
      child: CustomScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          _buildHeader(cs, dark),
          SliverToBoxAdapter(child: _buildOfficialBadge(cs, dark)),
          SliverToBoxAdapter(child: _buildStatsRow(cs, dark)),
          SliverToBoxAdapter(child: _buildActionButtons(cs)),
          SliverToBoxAdapter(child: _buildTabBar(cs)),
          SliverToBoxAdapter(child: _buildTabContent(dark)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
      ),
    ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(ColorScheme cs, bool dark) {
    return SliverAppBar(
      expandedHeight: 240,
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
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B1B3A), Color(0xFF14305F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
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
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1B3A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B1B3A)
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(_avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _sealIcon(Colors.white)),
                          )
                        : _sealIcon(Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            )),
                        const SizedBox(height: 4),
                        Text(_subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              letterSpacing: 0.8,
                            )),
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

  Widget _sealIcon(Color color) {
    return Icon(Icons.account_balance, color: color, size: 36);
  }

  // ── Official Badge ──────────────────────────────────────────────────────
  Widget _buildOfficialBadge(ColorScheme cs, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.azure.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.azure.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: AppColors.azure, size: 16),
                SizedBox(width: 6),
                Text('Verified Government Institution',
                    style: TextStyle(
                      color: AppColors.azure,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ...List.generate(5, (i) {
            final filled = i < _transparencyRating.floor();
            final partial = !filled && i < _transparencyRating;
            return Icon(
              partial ? Icons.star_half : Icons.star,
              size: 16,
              color: filled || partial
                  ? AppColors.amber
                  : cs.onSurfaceVariant.withValues(alpha: 0.3),
            );
          }),
          const SizedBox(width: 6),
          Text('${_transparencyRating.toStringAsFixed(1)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────
  Widget _buildStatsRow(ColorScheme cs, bool dark) {
    final items = [
      _GovStatData('Services', _compact(_servicesCount), Icons.home_repair_service_outlined),
      _GovStatData('Citizens Reached', _compact(_citizensReached), Icons.people_outline),
      _GovStatData('Projects', _compact(_projectsCount), Icons.folder_outlined),
      _GovStatData('Publications', _compact(_publicationsCount), Icons.article_outlined),
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
                        Icon(e.icon, size: 18, color: cs.primary),
                        const SizedBox(height: 6),
                        Text(e.value,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
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
                      _following ? AppColors.azure : const Color(0xFF0B1B3A),
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
                      roomId: 'gov_${widget.orgId}',
                      userName: widget.currentUser.fullName,
                      isInitiator: true,
                    ),
                  ));
                },
                icon: const Icon(Icons.video_call_outlined, size: 16),
                label: const Text('Request Meeting'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  side: BorderSide(color: cs.outlineVariant),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Request form opening soon')));
                },
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('File Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  side: BorderSide(color: cs.outlineVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
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
          Tab(text: 'Services'),
          Tab(text: 'Announcements'),
          Tab(text: 'Projects'),
          Tab(text: 'Departments'),
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
            return _buildServicesTab(dark);
          case 1:
            return _buildAnnouncementsTab(dark);
          case 2:
            return _buildProjectsTab(dark);
          case 3:
            return _buildDepartmentsTab(dark);
          case 4:
            return _buildAboutTab(dark);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // ── Services Tab ───────────────────────────────────────────────────────
  Widget _buildServicesTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_services.isEmpty) {
      return _emptyState(cs, Icons.home_repair_service_outlined,
          'No services listed');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _services.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return SlideInWidget(
            delay: Duration(milliseconds: i * 100),
            child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(dark),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1B3A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(s['icon'] as IconData,
                      color: cs.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'],
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(s['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              height: 1.4)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: cs.onSurfaceVariant),
              ],
            ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Announcements Tab ──────────────────────────────────────────────────
  Widget _buildAnnouncementsTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_announcements.isEmpty) {
      return _emptyState(
          cs, Icons.campaign_outlined, 'No announcements');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _announcements.map((post) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(dark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle_notifications_outlined,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(post.createdAt ?? '',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 10),
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

  // ── Departments Tab ────────────────────────────────────────────────────
  Widget _buildDepartmentsTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_departments.isEmpty) {
      return _emptyState(
          cs, Icons.business_outlined, 'No departments listed');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _departments.map((d) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(dark),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1B3A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_center_outlined,
                      color: cs.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['name'],
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('Head: ${d['head']}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      Text(d['contact'],
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.azure,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          );
        }).toList(),
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
          _aboutCard(cs, dark, 'Jurisdiction', _subtitle,
              Icons.location_city_outlined),
          _aboutCard(cs, dark, 'Department Head', 'Minister Dr. Yasmine Fouad',
              Icons.person_outline),
          _aboutCard(cs, dark, 'About', _about, Icons.info_outline),
          const SizedBox(height: 8),
          SectionTitle(title: 'Service Categories'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _categoryChip('Climate Action', AppColors.azure),
                _categoryChip('Biodiversity', AppColors.accent),
                _categoryChip('Water Resources', AppColors.azure),
                _categoryChip('Public Health', AppColors.warm),
                _categoryChip('Waste Management', AppColors.amber),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(title: 'Transparency Rating'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: glassDecoration(dark),
              child: Row(
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < _transparencyRating.floor();
                    final partial =
                        !filled && i < _transparencyRating;
                    return Icon(
                      partial ? Icons.star_half : Icons.star,
                      size: 28,
                      color: filled || partial
                          ? AppColors.amber
                          : cs.onSurfaceVariant.withValues(alpha: 0.3),
                    );
                  }),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_transparencyRating.toStringAsFixed(1)} / 5.0',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Based on public reporting compliance',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
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
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
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

  Widget _categoryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _emptyState(ColorScheme cs, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 14)),
        ],
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _GovStatData {
  final String label;
  final String value;
  final IconData icon;
  _GovStatData(this.label, this.value, this.icon);
}
