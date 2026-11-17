import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/models.dart';
import 'package:masaren/profile_ui.dart';
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
  bool _verified = false;

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
        // Count every post by the institution, not only kind=ANNOUNCEMENT.
        AuthApi.feed(authorId: widget.orgId),
        AuthApi.projects(),
      ]);
      final user = results[0] as User;
      final posts = results[1] as List<Post>;
      final allProjects = results[2] as List<Project>;
      Map<String, dynamic> institution = const {};
      try {
        institution = await api.get('/api/v1/users/${widget.orgId}/institution')
            as Map<String, dynamic>;
      } catch (_) {}
      final services = institution['services'] is List
          ? (institution['services'] as List)
              .whereType<Map>()
              .map((s) => <String, dynamic>{
                    'name': (s['name'] ?? s['title'] ?? '').toString(),
                    'description':
                        (s['description'] ?? s['detail'] ?? '').toString(),
                    'icon': _serviceIcon(
                        (s['name'] ?? s['title'] ?? '').toString()),
                  })
              .where((s) => (s['name'] as String).isNotEmpty)
              .toList()
          : <Map<String, dynamic>>[];
      final departments = institution['departments'] is List
          ? (institution['departments'] as List)
              .whereType<Map>()
              .map((d) => <String, dynamic>{
                    'name': (d['name'] ?? d['title'] ?? '').toString(),
                    'head': (d['head'] ?? d['manager'] ?? '').toString(),
                    'contact': (d['contact'] ?? d['email'] ?? '').toString(),
                  })
              .where((d) => (d['name'] as String).isNotEmpty)
              .toList()
          : <Map<String, dynamic>>[];
      final metrics = institution['metrics'] is Map
          ? institution['metrics'] as Map
          : const {};

      if (mounted) {
        setState(() {
          _name = user.fullName;
          _avatarUrl = user.avatarUrl;
          if (user.bio != null && user.bio!.isNotEmpty) {
            _about = user.bio!;
          }
          _subtitle = [user.city, user.country]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' · ');
          if (_subtitle.isEmpty) {
            _subtitle =
                MasarenLocalizations.of(context, 'government.defaultSubtitle');
          }
          _following = user.isFollowing;
          _verified = user.emailVerified || institution['verified'] == true;

          _announcements = posts;
          _publicationsCount = posts.length;

          _projects = allProjects
              .where((p) =>
                  p.author?.id == widget.orgId ||
                  (p.ownerName != null && p.ownerName == user.fullName))
              .toList();
          _projectsCount = _projects.length;

          _services = services;
          _departments = departments;
          _servicesCount = services.length;
          _citizensReached =
              (metrics['citizens_reached'] as num?)?.toInt() ?? 0;
          _transparencyRating =
              (institution['transparency_score'] as num?)?.toDouble() ?? 0;
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

  bool get _isSelf => widget.orgId == widget.currentUser.id;

  Future<void> _follow() async {
    if (_busy || _isSelf) return;
    setState(() => _busy = true);
    try {
      final res = await AuthApi.followPersonnel(widget.orgId);
      if (mounted) {
        setState(() {
          _following = res['following'] == true ? true : !_following;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(MasarenLocalizations.of(context,
                _following ? 'action.following' : 'government.unfollowed'))));
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

  Future<void> _openInquiry(
      {String? department, String type = 'general'}) async {
    final subjectCtl = TextEditingController();
    final messageCtl = TextEditingController();
    var selectedType = type;
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
                  Icon(Icons.description_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      MasarenLocalizations.of(
                          context, 'government.inquiryTitle'),
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
              if (department != null && department.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    MasarenLocalizations.of(context, 'government.inquiryTo')
                        .replaceAll('{name}', department),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final t in [
                    'general',
                    'complaint',
                    'document',
                    'meeting'
                  ])
                    ChoiceChip(
                      label: Text(MasarenLocalizations.of(
                          context, 'government.inquiry.type.$t')),
                      selected: selectedType == t,
                      onSelected: (_) => setSheet(() => selectedType = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectCtl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: MasarenLocalizations.of(
                      context, 'government.inquirySubject'),
                  hintText: MasarenLocalizations.of(
                      context, 'government.inquirySubjectHint'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageCtl,
                minLines: 4,
                maxLines: 7,
                decoration: InputDecoration(
                  labelText: MasarenLocalizations.of(
                      context, 'government.inquiryDetails'),
                  hintText: MasarenLocalizations.of(
                      context, 'government.inquiryDetailsHint'),
                  alignLabelWithHint: true,
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
                          if (subjectCtl.text.trim().length < 3 ||
                              messageCtl.text.trim().length < 5) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(MasarenLocalizations.of(
                                    context, 'government.inquiryRequired'))));
                            return;
                          }
                          setSheet(() => busy = true);
                          try {
                            await AuthApi.submitInquiry(
                              orgId: widget.orgId,
                              type: selectedType,
                              department: department,
                              subject: subjectCtl.text.trim(),
                              message: messageCtl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(MasarenLocalizations.of(
                                          context, 'government.inquirySent'))));
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(MasarenLocalizations.of(
                                          ctx, 'government.inquiryFailed')
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
                          context, 'government.inquirySend')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    subjectCtl.dispose();
    messageCtl.dispose();
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

    return Stack(
      children: [
        const Positioned.fill(
            child:
                FloatingShapes(shapeCount: 3, baseColor: ProfileColors.forest)),
        RefreshIndicator(
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
                  subtitle: _subtitle,
                  kind: 'government',
                  icon: Icons.account_balance_outlined,
                  imageUrl: _avatarUrl,
                  onShare: () => copyProfileLink(context, widget.orgId,
                      MasarenLocalizations.of(context, 'government.linkCopied'),
                      verified: _verified),
                  badge: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ProfilePill(
                          label: MasarenLocalizations.of(
                              context, 'government.verified'),
                          icon: Icons.verified_rounded,
                          color: ProfileColors.gold),
                      ProfilePill(
                          label:
                              '\u2066${_transparencyRating.toStringAsFixed(1)} / 5\u2069',
                          icon: Icons.star_rounded,
                          color: ProfileColors.gold),
                    ],
                  ),
                  stats: [
                    ProfileStat(
                        _compact(_servicesCount),
                        MasarenLocalizations.of(
                            context, 'government.stat.services'),
                        icon: Icons.home_repair_service_outlined),
                    ProfileStat(
                        _compact(_citizensReached),
                        MasarenLocalizations.of(
                            context, 'government.stat.citizensReached'),
                        icon: Icons.people_outline),
                    ProfileStat(
                        _compact(_projectsCount),
                        MasarenLocalizations.of(
                            context, 'government.stat.projects'),
                        icon: Icons.folder_outlined),
                    ProfileStat(
                        _compact(_publicationsCount),
                        MasarenLocalizations.of(
                            context, 'government.stat.publications'),
                        icon: Icons.article_outlined),
                  ],
                ),
              ),
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

  IconData _serviceIcon(String name) {
    final value = name.toLowerCase();
    if (value.contains('water')) return Icons.water_drop_outlined;
    if (value.contains('health')) return Icons.health_and_safety_outlined;
    if (value.contains('climate') || value.contains('environment')) {
      return Icons.eco_outlined;
    }
    if (value.contains('waste')) return Icons.recycling_outlined;
    if (value.contains('education')) return Icons.school_outlined;
    if (value.contains('transport')) return Icons.directions_bus_outlined;
    return Icons.home_repair_service_outlined;
  }

  // ── Action Buttons ─────────────────────────────────────────────────────
  Widget _buildActionButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (!_isSelf)
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _follow,
                  icon: Icon(_following ? Icons.check : Icons.person_add_alt_1,
                      size: 16),
                  label: Text(
                      MasarenLocalizations.of(context,
                          _following ? 'action.following' : 'action.follow'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  style: profilePrimaryStyle(
                      color: _following
                          ? ProfileColors.emerald
                          : ProfileColors.forest),
                ),
              ),
            ),
          if (!_isSelf) const SizedBox(width: 10),
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
                label: Text(
                    MasarenLocalizations.of(
                        context, 'government.requestMeeting'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                style: profileSecondaryStyle(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _openInquiry(type: 'document'),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: Text(
                    MasarenLocalizations.of(context, 'government.fileRequest'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                style: profileSecondaryStyle(context),
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
      decoration: profilePanel(context, radius: 16),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: ProfileColors.slate,
        labelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(2),
        indicator: BoxDecoration(
          color: ProfileColors.forest,
          borderRadius: BorderRadius.circular(11),
        ),
        dividerHeight: 0,
        splashBorderRadius: BorderRadius.circular(11),
        tabs: [
          Tab(text: MasarenLocalizations.of(context, 'institution.services')),
          Tab(
              text: MasarenLocalizations.of(
                  context, 'government.tab.announcements')),
          Tab(text: MasarenLocalizations.of(context, 'projects.title')),
          Tab(
              text:
                  MasarenLocalizations.of(context, 'institution.departments')),
          Tab(text: MasarenLocalizations.of(context, 'institution.about')),
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
          MasarenLocalizations.of(context, 'government.noServices'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _services.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return SlideInWidget(
            delay: Duration(milliseconds: i * 100),
            child: Clickable(
              onTap: () => _openInquiry(
                  department: s['name']?.toString(), type: 'document'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: profilePanel(context),
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
                    Icon(directionalChevronIcon(context),
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
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
      return _emptyState(cs, Icons.campaign_outlined,
          MasarenLocalizations.of(context, 'government.noAnnouncements'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _announcements.map((post) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: profilePanel(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle_notifications_outlined,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(post.createdAt != null ? timeAgo(post.createdAt!) : '',
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
      return _emptyState(cs, Icons.folder_outlined,
          MasarenLocalizations.of(context, 'government.noProjects'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _projects.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: profilePanel(context),
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

  // ── Departments Tab ────────────────────────────────────────────────────
  Widget _buildDepartmentsTab(bool dark) {
    final cs = Theme.of(context).colorScheme;
    if (_departments.isEmpty) {
      return _emptyState(cs, Icons.business_outlined,
          MasarenLocalizations.of(context, 'government.noDepartments'));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: _departments.map((d) {
          return Clickable(
            onTap: () => _openInquiry(department: d['name']?.toString()),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: profilePanel(context),
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
                        Text(
                            MasarenLocalizations.of(context, 'government.head')
                                .replaceAll('{name}', '${d['head']}'),
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
                  Icon(directionalChevronIcon(context),
                      size: 20, color: cs.onSurfaceVariant),
                ],
              ),
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
          _aboutCard(
              cs,
              dark,
              MasarenLocalizations.of(context, 'government.jurisdiction'),
              _subtitle,
              Icons.location_city_outlined),
          _aboutCard(
              cs,
              dark,
              MasarenLocalizations.of(context, 'government.departmentHead'),
              MasarenLocalizations.of(context, 'government.ministerName'),
              Icons.person_outline),
          _aboutCard(
              cs,
              dark,
              MasarenLocalizations.of(context, 'institution.about'),
              _about,
              Icons.info_outline),
          const SizedBox(height: 8),
          SectionTitle(
              title: MasarenLocalizations.of(
                  context, 'government.serviceCategories')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _categoryChip(
                    MasarenLocalizations.of(
                        context, 'government.category.climate'),
                    AppColors.azure),
                _categoryChip(
                    MasarenLocalizations.of(
                        context, 'government.category.biodiversity'),
                    AppColors.accent),
                _categoryChip(
                    MasarenLocalizations.of(
                        context, 'government.category.water'),
                    AppColors.azure),
                _categoryChip(
                    MasarenLocalizations.of(
                        context, 'government.category.publicHealth'),
                    AppColors.warm),
                _categoryChip(
                    MasarenLocalizations.of(
                        context, 'government.category.waste'),
                    AppColors.amber),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(
              title: MasarenLocalizations.of(
                  context, 'government.transparencyRating')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: profilePanel(context),
              child: Row(
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < _transparencyRating.floor();
                    final partial = !filled && i < _transparencyRating;
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
                      Text(
                          '\u2066${_transparencyRating.toStringAsFixed(1)} / 5.0\u2069',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                          MasarenLocalizations.of(
                              context, 'government.transparencyBasis'),
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

  Widget _aboutCard(
      ColorScheme cs, bool dark, String title, String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: profilePanel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.primary)),
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

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
