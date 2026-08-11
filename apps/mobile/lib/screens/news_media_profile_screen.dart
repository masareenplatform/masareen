import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/screens/interview_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/widgets/animations.dart';

class NewsMediaProfileScreen extends StatefulWidget {
  final String userId;
  final User currentUser;
  const NewsMediaProfileScreen(
      {super.key, required this.userId, required this.currentUser});

  @override
  State<NewsMediaProfileScreen> createState() => _NewsMediaProfileScreenState();
}

class _NewsMediaProfileScreenState extends State<NewsMediaProfileScreen>
    with SingleTickerProviderStateMixin {
  User? _org;
  List<Post> _posts = [];
  List<Personnel> _journalists = [];
  bool _loading = true;
  bool _busy = false;
  bool _following = false;
  String? _error;
  int _tabIdx = 0;
  late final TabController _tabCtrl;

  static const _tabs = ['Feed', 'Live', 'Packages', 'Journalists', 'About'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) setState(() => _tabIdx = _tabCtrl.index);
      });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final org = await AuthApi.getUser(widget.userId);
      final posts = await AuthApi.feed(authorId: widget.userId);
      List<Personnel> journalists = [];
      try {
        final data = await api.get('/api/v1/personnel',
            {'org_id': widget.userId, 'limit': 50});
        final list = data is List ? data : <dynamic>[];
        journalists = list
            .map((e) => Personnel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        journalists = [];
      }
      if (mounted) {
        setState(() {
          _org = org;
          _posts = posts;
          _journalists = journalists;
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

  bool get _isMe => _org?.id == widget.currentUser.id;

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
    if (_error != null || _org == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Organization not found', onRetry: () => _load()),
      );
    }
    final u = _org!;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: FloatingShapes(shapeCount: 4, baseColor: cs.primary)),
          RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
          slivers: [
            _buildCover(u, cs, dark),
            SliverToBoxAdapter(child: _buildIdentity(u, cs, dark)),
            SliverToBoxAdapter(child: _buildBrandColors(cs)),
            SliverToBoxAdapter(child: _buildStats(u, cs, dark)),
            SliverToBoxAdapter(child: _buildActions(cs, dark)),
            SliverToBoxAdapter(child: _buildTabBar(cs, dark)),
            SliverToBoxAdapter(child: _buildTabContent()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ],
  ),
    );
  }

  // ── 1. Brand header / cover ────────────────────────────────────────────────

  Widget _buildCover(User u, ColorScheme cs, bool dark) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: cs.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (u.coverUrl != null && u.coverUrl!.isNotEmpty)
              Image.network(u.coverUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary,
                      cs.primary.withValues(alpha: 0.7),
                      cs.secondary.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                u.fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isMe)
          _HeaderAction(
            icon: Icons.share_outlined,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile link copied'))),
          ),
      ],
    );
  }

  // ── 2. Logo / avatar section ───────────────────────────────────────────────

  Widget _buildIdentity(User u, ColorScheme cs, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AppAvatar(name: u.fullName, url: u.avatarUrl, size: 88),
              ),
              const SizedBox(width: 4),
              if (u.emailVerified)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified, color: cs.onPrimary, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(u.fullName,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('@${u.email.split('@').first}',
                  style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('News Media',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
              ),
              if (u.emailVerified) ...[
                const SizedBox(width: 6),
                Icon(Icons.verified, color: cs.primary, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (u.followersCount != null) ...[
                Icon(Icons.people_outline,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${u.followersCount} followers',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(width: 16),
              ],
              if (u.country != null || u.city != null) ...[
                Icon(Icons.location_on_outlined,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text([u.city, u.country].where((e) => e != null).join(', '),
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Brand colors indicator ──────────────────────────────────────────────

  Widget _buildBrandColors(ColorScheme cs) {
    final colors = [cs.primary, cs.secondary, cs.tertiary];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Text('Brand Identity',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(width: 10),
          ...colors.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ── 5. Stats bar ───────────────────────────────────────────────────────────

  Widget _buildStats(User u, ColorScheme cs, bool dark) {
    final stats = [
      _StatItem('Posts', '${_posts.length}', Icons.article_outlined, numericValue: _posts.length.toDouble()),
      _StatItem('Followers', '${u.followersCount ?? 0}', Icons.people_outline, numericValue: (u.followersCount ?? 0).toDouble()),
      _StatItem('Reports', '${_posts.where((p) => p.type == 'report').length}',
          Icons.assessment_outlined, numericValue: _posts.where((p) => p.type == 'report').length.toDouble()),
      _StatItem('Live', '0', Icons.wifi_tethering, numericValue: 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        children: List.generate(stats.length, (i) {
          final s = stats[i];
          return Expanded(
            child: SlideInWidget(
              delay: Duration(milliseconds: i * 100),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: glassDecoration(dark),
                child: Column(
                  children: [
                    Icon(s.icon, size: 18, color: cs.primary),
                    const SizedBox(height: 6),
                    if (s.numericValue != null)
                      CountUpNumber(
                        target: s.numericValue!,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface),
                      )
                    else
                      Text(s.value,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(s.label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 6. Action buttons ──────────────────────────────────────────────────────

  Widget _buildActions(ColorScheme cs, bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _isMe ? null : (_busy ? null : _follow),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _following ? cs.tertiary : cs.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary))
                    : Text(
                        _following ? 'Following' : 'Follow',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: dark
                          ? cs.outlineVariant.withValues(alpha: 0.4)
                          : cs.outline),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Message',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
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
                      roomId: 'interview-${widget.userId}',
                      userName: widget.currentUser.fullName,
                      isInitiator: true,
                    ),
                  ));
                },
                icon: Icon(Icons.videocam, size: 18, color: cs.onSurface),
                label: Text('Interview',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: dark
                          ? cs.outlineVariant.withValues(alpha: 0.4)
                          : cs.outline),
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

  // ── 7. Tab bar ─────────────────────────────────────────────────────────────

  Widget _buildTabBar(ColorScheme cs, bool dark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.darkSurface2.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark
                ? AppColors.darkLine.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicator: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerHeight: 0,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabAlignment: TabAlignment.start,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ── 8–12. Tab content ──────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_tabIdx) {
      case 0:
        return _FeedTab(posts: _posts, currentUser: widget.currentUser);
      case 1:
        return _LiveTab(
            orgName: _org?.fullName ?? '', isOwner: _isMe, orgId: widget.userId);
      case 2:
        return _PackagesTab(posts: _posts, currentUser: widget.currentUser);
      case 3:
        return _JournalistsTab(journalists: _journalists);
      case 4:
        return _AboutTab(org: _org!);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Private helpers & sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final double? numericValue;
  _StatItem(this.label, this.value, this.icon, {this.numericValue});
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

// ── Tab: Feed ─────────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  final List<Post> posts;
  final User currentUser;
  const _FeedTab({required this.posts, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No posts yet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Posts from this organization will appear here.',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => _PostCard(post: posts[i], currentUser: currentUser),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final User currentUser;
  const _PostCard({required this.post, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassDecoration(dark),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PostDetailScreen(
                post: post,
                currentUser: currentUser,
                onChanged: (_) {}))),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                    name: post.author.name,
                    url: null,
                    size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(post.author.name,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          if (post.author.verified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 14, color: cs.primary),
                          ],
                        ],
                      ),
                      if (post.createdAt != null)
                        Text(timeAgo(post.createdAt),
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (post.kind != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(post.kind!.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, height: 1.45, color: cs.onSurface)),
            if (post.contentUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(post.contentUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: cs.surfaceContainerHighest,
                          child: Center(
                              child: Icon(Icons.broken_image,
                                  color: cs.onSurfaceVariant)),
                        ))),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.favorite_outline,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.likes}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(Icons.mode_comment_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.comments}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 16),
                Icon(Icons.share_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${post.shares}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Live ─────────────────────────────────────────────────────────────────

class _LiveTab extends StatelessWidget {
  final String orgName;
  final bool isOwner;
  final String orgId;
  const _LiveTab(
      {required this.orgName, required this.isOwner, required this.orgId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: glassDecoration(dark),
            child: Column(
              children: [
                PulsingWidget(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.wifi_tethering,
                        size: 32, color: cs.error),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Live Streams',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
                const SizedBox(height: 6),
                Text('No active streams right now',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Upcoming and past broadcasts will appear here.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: dark
                      ? AppColors.darkLine.withValues(alpha: 0.3)
                      : cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Scheduled Streams',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      Text('No upcoming streams scheduled',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InterviewScreen(
                      roomId: 'live-$orgId',
                      userName: orgName,
                      isInitiator: true,
                    ),
                  ));
                },
                icon: const Icon(Icons.videocam, size: 20),
                label: const Text('Go Live',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Tab: Packages ─────────────────────────────────────────────────────────────

class _PackagesTab extends StatelessWidget {
  final List<Post> posts;
  final User currentUser;
  const _PackagesTab({required this.posts, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final packages = posts.where((p) => p.contentUrl != null).toList();

    if (packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.collections_bookmark_outlined,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No packages yet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('News packages with media will appear here.',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: packages.length,
        itemBuilder: (_, i) {
          final p = packages[i];
          return Container(
            decoration: glassDecoration(dark),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PostDetailScreen(
                      post: p,
                      currentUser: currentUser,
                      onChanged: (_) {}))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Image.network(p.contentUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Center(
                                  child: Icon(Icons.broken_image,
                                      color: cs.onSurfaceVariant)),
                        )),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.favorite_outline,
                                size: 12, color: cs.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text('${p.likes}',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant)),
                            const SizedBox(width: 10),
                            Icon(Icons.mode_comment_outlined,
                                size: 12, color: cs.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text('${p.comments}',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tab: Journalists ──────────────────────────────────────────────────────────

class _JournalistsTab extends StatelessWidget {
  final List<Personnel> journalists;
  const _JournalistsTab({required this.journalists});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (journalists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_outlined,
                  size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No journalists listed',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
              const SizedBox(height: 4),
              Text('Affiliated journalists will appear here.',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      itemCount: journalists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final j = journalists[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(dark),
          child: Row(
            children: [
              AppAvatar(name: j.name, url: j.avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(j.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                        ),
                        if (j.emailVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              size: 14, color: cs.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(j.headline.isNotEmpty ? j.headline : j.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab: About ────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final User org;
  const _AboutTab({required this.org});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final location =
        [org.city, org.country].where((e) => e != null).join(', ');
    final socialLinks = <String, String>{};

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (org.bio != null && org.bio!.isNotEmpty) ...[
            _AboutSection(
              icon: Icons.info_outline,
              title: 'Description',
              child: Text(org.bio!,
                  style: TextStyle(
                      fontSize: 14, height: 1.6, color: cs.onSurface)),
            ),
          ],
          _AboutSection(
            icon: Icons.public,
            title: 'Distribution Channels',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChannelChip(
                    icon: Icons.phone_android, label: 'Mobile App', cs: cs),
                _ChannelChip(
                    icon: Icons.language, label: 'Web Platform', cs: cs),
                _ChannelChip(
                    icon: Icons.podcasts, label: 'Broadcast', cs: cs),
              ],
            ),
          ),
          _AboutSection(
            icon: Icons.verified_user_outlined,
            title: 'Verification Level',
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verified News Organization',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface)),
                        Text(
                            'Identity and editorial standards verified by MASAREEN',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle,
                      size: 20, color: cs.tertiary),
                ],
              ),
            ),
          ),
          if (location.isNotEmpty)
            _AboutSection(
              icon: Icons.location_on_outlined,
              title: 'Headquarters',
              child: Text(location,
                  style: TextStyle(
                      fontSize: 14, color: cs.onSurface)),
            ),
          if (org.skills.isNotEmpty) ...[
            _AboutSection(
              icon: Icons.category_outlined,
              title: 'Coverage Areas',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: org.skills
                    .map((s) => Chip(
                        label:
                            Text(s, style: const TextStyle(fontSize: 12))))
                    .toList(),
              ),
            ),
          ],
          if (socialLinks.isNotEmpty) ...[
            _AboutSection(
              icon: Icons.link,
              title: 'Social Links',
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: socialLinks.entries
                    .map((e) => TextButton.icon(
                          onPressed: () {},
                          icon: Icon(Icons.open_in_new,
                              size: 14, color: cs.primary),
                          label: Text(e.value,
                              style: TextStyle(
                                  fontSize: 13, color: cs.primary)),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _AboutSection(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
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
                      letterSpacing: 0.8,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _ChannelChip(
      {required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
        ],
      ),
    );
  }
}
