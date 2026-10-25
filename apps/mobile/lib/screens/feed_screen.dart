import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/models.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/widgets/post_media_gallery.dart';
import 'package:masaren/screens/institution_profile_screen.dart';
import 'package:masaren/screens/news_media_profile_screen.dart';
import 'package:masaren/screens/sports_profile_screen.dart';
import 'package:masaren/screens/government_profile_screen.dart';
import 'package:masaren/screens/player_showcase_screen.dart';
import 'package:masaren/screens/organization_profile_screen.dart';
import 'package:masaren/screens/profile_screen.dart';
import 'package:masaren/screens/personnel_profile_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/create_post_screen.dart';
import 'package:masaren/screens/search_screen.dart';

class FeedScreen extends StatefulWidget {
  final User user;
  final VoidCallback onNotifications;
  final VoidCallback onMore;
  const FeedScreen({
    super.key,
    required this.user,
    required this.onNotifications,
    required this.onMore,
  });

  @override
  FeedScreenState createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  final int _limit = 20;
  String _filter = 'all';
  String _mode = 'for_you';

  static const _modes = [
    ('for_you', 'For you', Icons.auto_awesome),
    ('following', 'Following', Icons.people_outline),
    ('latest', 'Latest', Icons.schedule),
    ('impact', 'Impact', Icons.verified_outlined),
  ];

  static const _filters = [
    'all',
    'impact',
    'program',
    'evidence',
    'story',
    'opportunity',
    'recognition',
  ];

  final _recognized = const [
    {
      'id': 'inst-1',
      'name': 'Al-Baraka Foundation',
      'note': 'Recognized for education',
      'badge': 'PLATINUM'
    },
    {
      'id': 'inst-2',
      'name': 'Green Hope Initiative',
      'note': 'Environmental stewardship',
      'badge': 'GOLD'
    },
  ];

  List<Post> get _visiblePosts {
    return _filter == 'all'
        ? _posts
        : _posts.where((p) => p.kind == _filter).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _offset = 0;
      _hasMore = true;
    }
    setState(() => _loading = reset || _posts.isEmpty);
    try {
      final data =
          await AuthApi.feed(limit: _limit, offset: _offset, mode: _mode);
      if (reset) {
        _posts = data;
      } else {
        _posts.addAll(data);
      }
      _hasMore = data.length >= _limit;
      _offset += data.length;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void refresh() => _load(reset: true);

  void _setMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _posts = [];
      _filter = 'all';
    });
    _load(reset: true);
  }

  Future<void> _onShare(Post p) async {
    try {
      final res = await AuthApi.share(p.id);
      final i = _posts.indexWhere((e) => e.id == p.id);
      if (i != -1) {
        final shares = (res['shares'] as num?)?.toInt() ?? (p.shares + 1);
        _posts[i] = _posts[i].copyWith(shares: shares);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _onImpact(Post p) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ImpactSheet(post: p),
    );
    if (result == null) return;
    final i = _posts.indexWhere((e) => e.id == p.id);
    if (i == -1) return;
    _posts[i] = _posts[i].copyWith(
      impactValue: (result['impact_value'] as num?)?.toDouble(),
      impactLabel: result['impact_label'] as String?,
      confidenceScore: (result['confidence_score'] as num?)?.toDouble(),
      confidenceLabel: result['confidence_label'] as String?,
    );
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Rating saved. Impact score is now ${_posts[i].impactValue?.toStringAsFixed(1) ?? '—'}/10.')),
      );
    }
  }

  Future<void> _openPost(Post p) async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostDetailScreen(
              post: p,
              currentUser: widget.user,
              onChanged: (updated) {
                final i = _posts.indexWhere((e) => e.id == updated.id);
                if (i != -1) {
                  _posts[i] = updated;
                  if (mounted) setState(() {});
                }
              },
            )));
    if (result == 'deleted' && mounted) {
      setState(() => _posts.removeWhere((e) => e.id == p.id));
    }
  }

  void _openAuthor(Author a) {
    if (a.id.isEmpty) return;
    if (a.id == 'platform' || a.role?.toUpperCase() == 'PLATFORM') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InstitutionProfileScreen(institutionId: 'platform')));
      return;
    }
    if (a.id == widget.user.id) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(
              user: widget.user, onLogout: () {}, onToggleTheme: null)));
      return;
    }
    final r = a.role?.toUpperCase() ?? '';
    if (r.contains('MEDIA') || r.contains('PRESS') || r.contains('NEWS')) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              NewsMediaProfileScreen(userId: a.id, currentUser: widget.user)));
    } else if (r.contains('SPORT') ||
        r.contains('CLUB') ||
        r.contains('FEDERATION')) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              SportsProfileScreen(orgId: a.id, currentUser: widget.user)));
    } else if (r.contains('GOV') || r.contains('GOVERNMENT')) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              GovernmentProfileScreen(orgId: a.id, currentUser: widget.user)));
    } else if (r.contains('ATHLETE')) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              PlayerShowcaseScreen(playerId: a.id, currentUser: widget.user)));
    } else if (r.contains('NGO') ||
        r.contains('ORGANIZATION') ||
        r.contains('COMPANY') ||
        r.contains('CORPORATE')) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrganizationProfileScreen(
              orgId: a.id, currentUser: widget.user)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              PersonnelProfileScreen(userId: a.id, currentUser: widget.user)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(height: 56),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: cs.onSurface),
            onPressed: _openSearch,
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: cs.onSurface),
            onPressed: widget.onNotifications,
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: cs.onSurface),
            onPressed: widget.onMore,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(message: _error, onRetry: () => _load(reset: true))
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    children: [
                      _Composer(
                        user: widget.user,
                        onTap: () async {
                          final created = await Navigator.of(context)
                              .push<bool>(MaterialPageRoute(
                                  builder: (_) =>
                                      CreatePostScreen(user: widget.user)));
                          if (created == true) _load(reset: true);
                        },
                      ),
                      _FeaturedCarousel(posts: _visiblePosts.take(5).toList()),
                      _FeedModeBar(
                          modes: _modes, active: _mode, onSelect: _setMode),
                      _FilterChips(
                        filters: _filters,
                        active: _filter,
                        onSelect: (f) => setState(() => _filter = f),
                      ),
                      _RecognitionBanner(
                        items: _recognized,
                        onTap: (id) => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => InstitutionProfileScreen(
                                    institutionId: id))),
                      ),
                      SectionTitle(
                          title:
                              MasarenLocalizations.of(context, 'feed.title')),
                      if (_visiblePosts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              MasarenLocalizations.of(context, 'feed.empty'),
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ..._visiblePosts
                          .asMap()
                          .map((i, p) => MapEntry(
                                i,
                                SlideInWidget(
                                  delay: Duration(milliseconds: 120 * (i % 8)),
                                  slideOffset: const Offset(0, 0.08),
                                  child: _PostCard(
                                    post: p,
                                    currentUser: widget.user,
                                    onLike: () => _onLike(p),
                                    onBookmark: () => _onBookmark(p),
                                    onComment: () => _openPost(p),
                                    onImpact: () => _onImpact(p),
                                    onShare: () => _onShare(p),
                                    onImageTap: p.media.any((m) => !m.isVideo)
                                        ? (url) =>
                                            showEnlargedImage(context, url)
                                        : null,
                                    onAuthor: () => _openAuthor(p.author),
                                    onOpen: () => _openPost(p),
                                  ),
                                ),
                              ))
                          .values
                          .toList(),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!_hasMore && _visiblePosts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                                MasarenLocalizations.of(
                                    context, 'feed.caughtUp'),
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Future<void> _onBookmark(Post p) async {
    final i = _posts.indexWhere((e) => e.id == p.id);
    if (i == -1) return;
    final was = p.bookmarkedByMe;
    _posts[i] = p.copyWith(bookmarkedByMe: !was);
    if (mounted) setState(() {});
    try {
      final res = await AuthApi.toggleBookmark(p.id);
      final j = _posts.indexWhere((e) => e.id == p.id);
      if (j != -1) {
        _posts[j] =
            _posts[j].copyWith(bookmarkedByMe: res['bookmarked'] ?? !was);
      }
    } catch (_) {
      final j = _posts.indexWhere((e) => e.id == p.id);
      if (j != -1) _posts[j] = _posts[j].copyWith(bookmarkedByMe: was);
    }
    if (mounted) setState(() {});
  }

  void _openSearch() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SearchScreen(user: widget.user)));
  }

  Future<void> _onLike(Post p) async {
    final i = _posts.indexWhere((e) => e.id == p.id);
    if (i == -1) return;
    final wasLiked = p.likedByMe;
    final updated = p.copyWith(
      likedByMe: !wasLiked,
      likes: p.likes + (wasLiked ? -1 : 1),
    );
    _posts[i] = updated;
    if (mounted) setState(() {});
    try {
      final res = await AuthApi.toggleLike(p.id);
      _posts[i] = updated.copyWith(
        likedByMe: res['likedByMe'] ?? !wasLiked,
        likes: (res['likes'] is num)
            ? (res['likes'] as num).toInt()
            : updated.likes,
      );
    } catch (_) {
      _posts[i] = p;
    }
    if (mounted) setState(() {});
  }
}

class _FeaturedCarousel extends StatefulWidget {
  final List<Post> posts;
  const _FeaturedCarousel({required this.posts});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage && mounted) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.posts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.posts.length,
            itemBuilder: (_, i) {
              final p = widget.posts[i];
              final isCenter = i == _currentPage;
              final images = p.media.where((m) => !m.isVideo).toList();
              final cover = images.isNotEmpty ? images.first.url : p.contentUrl;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: isCenter ? 0 : 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      if (cover != null)
                        Image.network(
                          cover,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary,
                                  cs.primary.withValues(alpha: 0.6)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cs.primary,
                                cs.primary.withValues(alpha: 0.6)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black45, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (p.kind != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    p.kind!.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                p.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.favorite,
                                      size: 14, color: Colors.redAccent),
                                  const SizedBox(width: 4),
                                  Text('${p.likes}',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.posts.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentPage ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? cs.primary
                    : cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final String active;
  final ValueChanged<String> onSelect;
  const _FilterChips(
      {required this.filters, required this.active, required this.onSelect});

  static String _label(BuildContext context, String key) {
    const map = {
      'all': 'feed.forYou',
      'impact': 'feed.impact',
      'program': 'feed.programs',
      'evidence': 'feed.evidence',
      'story': 'feed.impact',
      'opportunity': 'opportunities.title',
      'recognition': 'post.recognition',
    };
    return MasarenLocalizations.of(context, map[key] ?? 'feed.title');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isActive = f == active;
          return ChoiceChip(
            label: Text(_label(context, f)),
            selected: isActive,
            onSelected: (_) => onSelect(f),
            selectedColor: cs.primary,
            labelStyle: TextStyle(
                color: isActive ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13),
          );
        },
      ),
    );
  }
}

class _FeedModeBar extends StatelessWidget {
  final List<(String, String, IconData)> modes;
  final String active;
  final ValueChanged<String> onSelect;
  const _FeedModeBar(
      {required this.modes, required this.active, required this.onSelect});

  static String _label(BuildContext context, String key, String fallback) {
    const map = {
      'for_you': 'feed.forYou',
      'following': 'feed.following',
      'latest': 'feed.latest',
      'impact': 'feed.impact',
    };
    final l10nKey = map[key];
    return l10nKey == null
        ? fallback
        : MasarenLocalizations.of(context, l10nKey);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Row(
          children: modes.map((m) {
            final isActive = m.$1 == active;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelect(m.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? cs.primary : cs.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: isActive ? cs.primary : cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(m.$3,
                          size: 15,
                          color: isActive ? cs.onPrimary : cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(_label(context, m.$1, m.$2),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? cs.onPrimary : cs.onSurface)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RecognitionBanner extends StatelessWidget {
  final List<Map<String, String>> items;
  final ValueChanged<String> onTap;
  const _RecognitionBanner({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Esteemed Recognition',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((it) => InkWell(
                onTap: () => onTap(it['id']!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(it['name']![0],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it['name']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(it['note']!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(it['badge']!,
                            style: TextStyle(
                                color: cs.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final User user;
  final VoidCallback onTap;
  const _Composer({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        padding: const EdgeInsets.all(14),
        color: cs.surface,
        child: Row(
          children: [
            AppAvatar(name: user.fullName, url: user.avatarUrl, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                MasarenLocalizations.of(context, 'feed.composer'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              ),
            ),
            Icon(Icons.add_circle, color: cs.primary, size: 28),
          ],
        ),
      ),
    );
  }
}

class SdgBadge extends StatelessWidget {
  final int sdg;
  const SdgBadge({super.key, required this.sdg});

  static const _sdgColors = {
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

  static const _sdgLabels = {
    1: 'No Poverty',
    2: 'Zero Hunger',
    3: 'Good Health',
    4: 'Quality Education',
    5: 'Gender Equality',
    6: 'Clean Water',
    7: 'Affordable Energy',
    8: 'Decent Work',
    9: 'Industry & Innovation',
    10: 'Reduced Inequalities',
    11: 'Sustainable Cities',
    12: 'Responsible Consumption',
    13: 'Climate Action',
    14: 'Life Below Water',
    15: 'Life on Land',
    16: 'Peace & Justice',
    17: 'Partnerships',
  };

  @override
  Widget build(BuildContext context) {
    final color = _sdgColors[sdg] ?? Colors.blueGrey;
    final label = _sdgLabels[sdg] ?? 'SDG $sdg';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'SDG $sdg: $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final User currentUser;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onComment;
  final VoidCallback onImpact;
  final VoidCallback onShare;
  final ValueChanged<String>? onImageTap;
  final VoidCallback onAuthor;
  final VoidCallback onOpen;
  const _PostCard({
    required this.post,
    required this.currentUser,
    required this.onLike,
    required this.onBookmark,
    required this.onComment,
    required this.onImpact,
    required this.onShare,
    this.onImageTap,
    required this.onAuthor,
    required this.onOpen,
  });

  Color get _typeColor {
    final kind = post.kind ?? '';
    switch (kind) {
      case 'recognition':
        return const Color(0xFFF59E0B);
      case 'opportunity':
        return const Color(0xFF3B82F6);
      case 'announcement':
        return const Color(0xFF8B5CF6);
      case 'interview':
        return const Color(0xFF10B981);
      case 'program':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF6366F1);
    }
  }

  IconData get _typeIcon {
    final kind = post.kind ?? '';
    switch (kind) {
      case 'recognition':
        return Icons.emoji_events;
      case 'opportunity':
        return Icons.work_outline;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'interview':
        return Icons.mic;
      case 'program':
        return Icons.school_outlined;
      default:
        return Icons.auto_awesome;
    }
  }

  String get _typeLabel {
    final kind = post.kind ?? '';
    switch (kind) {
      case 'recognition':
        return 'Recognition';
      case 'opportunity':
        return 'Opportunity';
      case 'announcement':
        return 'Announcement';
      case 'interview':
        return 'Interview';
      case 'program':
        return 'Program';
      case 'evidence':
        return 'Evidence';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _typeColor;
    final isPlatform =
        post.kind == 'announcement' || post.kind == 'opportunity';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_typeLabel.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  Icon(_typeIcon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(_typeLabel.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  if (isPlatform) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('MASAREEN',
                          style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                AppAvatar(
                    name: post.author.name,
                    url: post.author.avatarUrl,
                    size: 40,
                    onTap: onAuthor),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onAuthor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(post.author.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: cs.onSurface)),
                            ),
                            if (post.author.verified)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified,
                                    size: 15, color: cs.primary),
                              ),
                          ],
                        ),
                        if (post.programTag != null)
                          Text(post.programTag!,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                        if (post.rankingReason != null &&
                            post.rankingReason!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 12, color: cs.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(post.rankingReason!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: cs.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (post.kind == 'recognition')
                  Icon(Icons.emoji_events,
                      color: Colors.amber.shade700, size: 20)
                else if (post.kind == 'opportunity')
                  Icon(Icons.work_outline, color: Colors.blue, size: 20)
                else if (post.kind == 'interview')
                  Icon(Icons.mic, color: Colors.green, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (post.type == 'ARTICLE')
                  _PostBadge(
                    label:
                        MasarenLocalizations.of(context, 'post.verifiedNews'),
                    icon: Icons.verified,
                    color: Colors.blue,
                  ),
                if (post.kind == 'recognition')
                  _PostBadge(
                    label: 'Recognition',
                    icon: Icons.emoji_events,
                    color: Colors.amber.shade700,
                  ),
                if (post.kind == 'interview')
                  _PostBadge(
                    label: 'Interview',
                    icon: Icons.mic,
                    color: Colors.green.shade600,
                  ),
                if (post.confidenceLabel != null)
                  _PostBadge(
                    label: post.confidenceLabel!,
                    icon: Icons.shield_outlined,
                    color: _confidenceColor(post.confidenceScore),
                  ),
                if (post.likes > 10)
                  _PostBadge(
                    label: 'Trending',
                    icon: Icons.trending_up,
                    color: Colors.deepOrange,
                  ),
                if (post.impactValue != null && post.impactValue! > 0)
                  _PostBadge(
                    label:
                        '${MasarenLocalizations.of(context, 'feed.impact')} ${post.impactValue!.toStringAsFixed(1)}',
                    icon: Icons.verified,
                    color: cs.primary,
                  ),
              ],
            ),
          ),
          if (post.sdg != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SdgBadge(sdg: post.sdg!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(post.text,
                style: TextStyle(color: cs.onSurface, height: 1.4)),
          ),
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PostMediaGallery(
                media: post.media,
                videoHlsUrl: post.videoHlsUrl,
                videoPosterUrl: post.videoPosterUrl,
                onImageTap: onImageTap,
              ),
            ),
          if (post.impactValue != null && post.impactValue! > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${MasarenLocalizations.of(context, 'post.impactScore')}: ${post.impactValue!.toStringAsFixed(1)} ${post.impactLabel ?? ""}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Action(
                  icon: Icons.favorite,
                  active: post.likedByMe,
                  activeColor: Colors.redAccent,
                  label: '${post.likes}',
                  onTap: onLike,
                ),
                _Action(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.comments}',
                  onTap: onComment,
                ),
                _Action(
                  icon: Icons.fact_check_outlined,
                  label: MasarenLocalizations.of(context, 'post.rateImpact'),
                  onTap: onImpact,
                ),
                _Action(
                  icon: Icons.share_outlined,
                  label: '${post.shares}',
                  onTap: onShare,
                ),
                _Action(
                  icon: post.bookmarkedByMe
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  active: post.bookmarkedByMe,
                  activeColor: cs.primary,
                  label: post.bookmarkedByMe
                      ? MasarenLocalizations.of(context, 'post.saved')
                      : MasarenLocalizations.of(context, 'post.save'),
                  onTap: onBookmark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactSheet extends StatefulWidget {
  final Post post;
  const _ImpactSheet({required this.post});

  @override
  State<_ImpactSheet> createState() => _ImpactSheetState();
}

class _ImpactSheetState extends State<_ImpactSheet> {
  int _stars = 4;
  bool _saving = false;
  String? _error;
  final _note = TextEditingController();
  final Set<String> _cats = {};

  static const _categories = {
    'verified_evidence': 'Verified evidence',
    'community_voice': 'Community voice',
    'policy_change': 'Policy change',
    'innovation': 'Innovation',
    'scale': 'Scale',
    'transparency': 'Transparency',
  };

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await AuthApi.rateImpact(
        widget.post.id,
        stars: _stars,
        categories: _cats.toList(),
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop(res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rate this impact',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  'Your rating updates the verified impact score for everyone.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  return IconButton(
                    onPressed:
                        _saving ? null : () => setState(() => _stars = value),
                    icon: Icon(
                      value <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 38,
                      color:
                          value <= _stars ? Colors.amber.shade600 : cs.outline,
                    ),
                    tooltip: '$value of 5',
                  );
                }),
              ),
              Center(
                child: Text(
                  const [
                    '',
                    'Weak signal',
                    'Some evidence',
                    'Solid evidence',
                    'Strong evidence',
                    'Verified, high impact'
                  ][_stars],
                  style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Text('What makes it credible?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries.map((e) {
                  final on = _cats.contains(e.key);
                  return FilterChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: on,
                    onSelected: _saving
                        ? null
                        : (_) => setState(
                            () => on ? _cats.remove(e.key) : _cats.add(e.key)),
                    selectedColor: cs.primaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 300,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional: what did you see or verify?',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: TextStyle(color: cs.error, fontSize: 12)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_outlined),
                  label: Text(_saving ? 'Saving…' : 'Submit impact rating'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    this.active = false,
    this.activeColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (activeColor ?? cs.primary).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: active ? 20 : 18,
                color:
                    active ? (activeColor ?? cs.primary) : cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? (activeColor ?? cs.primary)
                        : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PostBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _PostBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Color _confidenceColor(double? score) {
  if (score == null) return Colors.grey;
  if (score >= 0.8) return Colors.green;
  if (score >= 0.6) return Colors.teal;
  if (score >= 0.4) return Colors.orange;
  return Colors.redAccent;
}
