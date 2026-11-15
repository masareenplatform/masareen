import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/widgets/animations.dart';
import 'package:masaren/widgets/engagement_tools.dart';
import 'package:masaren/models.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/widgets/ad_feed_card.dart';
import 'package:masaren/widgets/post_media_gallery.dart';
import 'package:masaren/widgets/role_badge.dart';
import 'package:masaren/profile_router.dart';
import 'package:masaren/screens/institution_profile_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/create_post_screen.dart';
import 'package:masaren/screens/search_screen.dart';
import 'package:masaren/screens/event_hub_screen.dart';
import 'package:masaren/screens/program_detail_screen.dart';
import 'package:masaren/screens/podcast_screen.dart';
import 'package:masaren/screens/vod_screen.dart';
import 'package:masaren/widgets/smart_image.dart';
import 'package:masaren/widgets/festive_burst.dart';
import 'package:masaren/screens/wallet_screen.dart';
import 'package:masaren/screens/courses_screen.dart';
import 'package:masaren/screens/opportunities_screen.dart';
import 'package:masaren/screens/passport_screen.dart';
import 'package:masaren/screens/pro_screen.dart';
import 'package:masaren/screens/programs_screen.dart';
import 'package:masaren/screens/projects_screen.dart';
import 'package:masaren/screens/verification_screen.dart';
import 'package:masaren/services/live_sync_service.dart';
import 'package:masaren/services/analytics_service.dart';
import 'package:masaren/services/share_policy.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FeedScreen extends StatefulWidget {
  final User user;
  final VoidCallback onNotifications;
  final VoidCallback onMore;
  final VoidCallback? onToggleTheme;
  final bool isDark;
  final int unreadNotifications;
  const FeedScreen({
    super.key,
    required this.user,
    required this.onNotifications,
    required this.onMore,
    this.onToggleTheme,
    this.isDark = false,
    this.unreadNotifications = 0,
  });

  @override
  FeedScreenState createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  List<DiscoveryItem> _discoveries = [];
  int _discoveryOffset = 0;
  String _discoverySeed = DateTime.now().microsecondsSinceEpoch.toString();
  bool _discoveryHasMore = true;
  bool _discoveryLoading = false;
  int _discoveryGeneration = 0;
  bool _loading = true;
  bool _requestInFlight = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  int _generation = 0;
  String _feedSeed = DateTime.now().microsecondsSinceEpoch.toString();
  final int _limit = 20;
  String _filter = 'all';
  String _mode = 'for_you';
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollReportTimer;
  DateTime? _scrollStartedAt;
  double _maxScrollSeen = 0;
  double? _walletBalance;
  List<Campaign> _ads = [];
  bool _adsLoaded = false;
  final List<String> _introSections = [
    'verify',
    'passport',
    'wallet',
    'courses',
    'opportunities',
    'pro',
    'programs',
  ]..shuffle();
  int _introIndex = 0;

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
    _scrollController.addListener(_onScroll);
    _scrollStartedAt = DateTime.now();
    AnalyticsService.instance.track('feed_open');
    LiveSyncService.instance.addListener(_onLiveSync);
    LiveSyncService.instance.start();
    _load();
    _loadDiscovery(reset: true);
    _loadWallet();
    _loadAds();
  }

  @override
  void dispose() {
    LiveSyncService.instance.removeListener(_onLiveSync);
    LiveSyncService.instance.unwatch(this);
    _scrollReportTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLiveSync() {
    if (!mounted || _posts.isEmpty) return;
    var changed = false;
    final next = _posts.map((p) {
      final stats = LiveSyncService.instance.statsFor(p.id);
      if (stats == null) return p;
      if (p.likes == stats.likes &&
          p.comments == stats.comments &&
          p.shares == stats.shares &&
          p.likedByMe == stats.likedByMe &&
          p.bookmarkedByMe == stats.bookmarkedByMe &&
          (p.impactValue ?? 0) == (stats.impactValue ?? 0) &&
          (p.confidenceScore ?? 0) == (stats.confidenceScore ?? 0)) {
        return p;
      }
      changed = true;
      return p.copyWith(
        likes: stats.likes,
        comments: stats.comments,
        shares: stats.shares,
        likedByMe: stats.likedByMe,
        bookmarkedByMe: stats.bookmarkedByMe,
        impactValue: stats.impactValue ?? p.impactValue,
        confidenceScore: stats.confidenceScore ?? p.confidenceScore,
      );
    }).toList();
    if (changed) setState(() => _posts = next);
  }

  void _watchVisiblePosts() {
    LiveSyncService.instance
        .watch(this, _posts.map((post) => post.id).toList());
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final extent = position.maxScrollExtent;
      final depth = extent <= 0
          ? 100.0
          : ((position.pixels + position.viewportDimension) / extent * 100)
              .clamp(0.0, 100.0);
      if (depth > _maxScrollSeen) _maxScrollSeen = depth;
      _scrollReportTimer?.cancel();
      _scrollReportTimer =
          Timer(const Duration(milliseconds: 1400), _reportScroll);
    }
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      if (_hasMore) {
        _load();
      } else {
        _loadDiscovery();
      }
    }
  }

  void _reportScroll() {
    final started = _scrollStartedAt;
    if (started == null) return;
    final duration = DateTime.now().difference(started).inMilliseconds;
    if (duration < 400 && _maxScrollSeen < 2) return;
    AnalyticsService.instance.track('feed_scroll',
        value: double.parse(_maxScrollSeen.toStringAsFixed(1)),
        durationMs: duration,
        metadata: {'tab': _mode, 'posts': _posts.length});
    _scrollStartedAt = DateTime.now();
    _maxScrollSeen = 0;
  }

  /// Loads another page when the first page (or the active filter) does not
  /// fill the viewport, so infinite scrolling also works on tall screens and
  /// when a filter hides most of the loaded posts.
  void _maybeLoadMoreIfShort() {
    if (!mounted || _loading || _loadingMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _loadingMore) return;
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      if (position.maxScrollExtent <= 0 || position.extentAfter < 500) {
        if (_hasMore) {
          _load();
        } else {
          _loadDiscovery();
        }
      }
    });
  }

  Future<void> _loadDiscovery({bool reset = false}) async {
    if (reset) {
      _discoveryGeneration++;
      _discoveries = [];
      _discoveryOffset = 0;
      _discoverySeed = DateTime.now().microsecondsSinceEpoch.toString();
      _discoveryHasMore = true;
    }
    if (_discoveryLoading) return;
    _discoveryLoading = true;
    final gen = _discoveryGeneration;
    try {
      final data = await AuthApi.discoveryFeed(
          limit: 10, offset: _discoveryOffset, seed: _discoverySeed);
      if (!mounted || gen != _discoveryGeneration) return;
      final raw = data['items'] is List ? data['items'] as List : const [];
      final items = raw
          .whereType<Map>()
          .map((e) => DiscoveryItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      setState(() {
        _discoveries.addAll(items);
        _discoveryOffset += items.length;
        _discoveryHasMore = data['has_more'] == true;
      });
      if (!_discoveryHasMore) {
        _discoveryOffset = 0;
        _discoverySeed = DateTime.now().microsecondsSinceEpoch.toString();
        _discoveryHasMore = true;
      }
    } catch (_) {
      // Discovery is additive; never block the post feed on it.
    } finally {
      _discoveryLoading = false;
    }
  }
  Future<void> _loadWallet() async {
    try {
      final wallet = await AuthApi.wallet(widget.user.id);
      if (mounted) setState(() => _walletBalance = wallet.balance);
    } catch (_) {}
  }

  Future<void> _openWallet() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WalletScreen(user: widget.user)));
    await _loadWallet();
  }

  Future<void> _loadAds({bool force = false}) async {
    if (_adsLoaded && !force) return;
    try {
      final ads = await AuthApi.feedAds(limit: 3);
      if (mounted) {
        setState(() {
          _ads = ads;
          _adsLoaded = true;
        });
      }
    } catch (_) {
      _adsLoaded = true;
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      // Cancel any page still in flight so its result cannot be appended
      // after the refresh / mode switch.
      _generation++;
      _feedSeed = DateTime.now().microsecondsSinceEpoch.toString();
      _offset = 0;
      _hasMore = true;
      _loadingMore = false;
      _loadDiscovery(reset: true);
      _loadAds(force: true);
    } else {
      if (_requestInFlight || _loadingMore || !_hasMore) return;
    }
    _requestInFlight = true;
    final gen = _generation;
    setState(() {
      // Keep the current posts visible while a pull-to-refresh runs.
      _loading = _posts.isEmpty;
      if (!reset && _posts.isNotEmpty) _loadingMore = true;
    });
    try {
      final data = await AuthApi.feed(
          limit: _limit, offset: _offset, mode: _mode, seed: _feedSeed);
      if (!mounted || gen != _generation) return;
      if (reset) {
        _posts = data;
      } else {
        final ids = _posts.map((post) => post.id).toSet();
        _posts.addAll(data.where((post) => !ids.contains(post.id)));
      }
      _hasMore = data.length == _limit;
      // Advance by the server page size, not by the deduplicated count.
      _offset += data.length;
      _error = null;
    } on ApiException catch (e) {
      if (gen == _generation) _error = e.message;
    } catch (e) {
      if (gen == _generation) _error = e.toString();
    } finally {
      if (mounted && gen == _generation) {
        _requestInFlight = false;
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        _watchVisiblePosts();
        _maybeLoadMoreIfShort();
      }
    }
  }

  void refresh() => _load(reset: true);

  void refreshToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
    _load(reset: true);
  }

  void _setMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _posts = [];
      _filter = 'all';
    });
    _load(reset: true);
  }

  void _openDiscovery(DiscoveryItem item) {
    Widget screen;
    switch (item.type) {
      case 'EVENT':
        screen = EventHubScreen(eventId: item.id, user: widget.user);
        break;
      case 'PROGRAM':
        screen = ProgramDetailScreen(programId: item.id);
        break;
      case 'PROJECT':
        screen = ProjectsScreen(user: widget.user);
        break;
      case 'OPPORTUNITY':
        screen = OpportunitiesScreen(user: widget.user);
        break;
      case 'PODCAST':
        screen = PodcastShowScreen(showId: item.id, user: widget.user);
        break;
      case 'VOD':
        screen = VodPlayerScreen(videoId: item.id, user: widget.user);
        break;
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
  Future<void> _onShare(Post p) async {
    if (!SharePolicy.post(p)) {
      SharePolicy.deny(context);
      return;
    }
    await Clipboard.setData(
        ClipboardData(text: 'https://masareen.com/p/${p.id}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(MasarenLocalizations.of(context, 'post.linkCopied'))));
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
      final score = _posts[i].impactValue?.toStringAsFixed(1) ?? '—';
      final message = MasarenLocalizations.of(context, 'post.impactSaved')
          .replaceAll('{score}', score);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
    openEntityAuthor(context, author: a, currentUser: widget.user);
  }

  Widget _introCard(BuildContext context, String section) {
    final cs = Theme.of(context).colorScheme;
    String t(String key, String fallback) {
      final value = MasarenLocalizations.of(context, key);
      return value == key ? fallback : value;
    }

    final icon = switch (section) {
      'verify' => Icons.verified_user_outlined,
      'passport' => Icons.badge_outlined,
      'wallet' => Icons.account_balance_wallet_outlined,
      'courses' => Icons.school_outlined,
      'opportunities' => Icons.work_outline,
      'pro' => Icons.workspace_premium_outlined,
      _ => Icons.hub_outlined,
    };
    final color = switch (section) {
      'verify' => cs.primary,
      'passport' => const Color(0xFF6A4CB0),
      'wallet' => const Color(0xFFB08D2E),
      'courses' => const Color(0xFF2C6E8F),
      'opportunities' => const Color(0xFF2E7D32),
      'pro' => const Color(0xFF8E24AA),
      _ => const Color(0xFF4B5D67),
    };
    return SlideInWidget(
      delay: const Duration(milliseconds: 60),
      slideOffset: const Offset(0, 0.08),
      child: IntroCard(
        title: t('intro.$section.title', section),
        body: t('intro.$section.body', ''),
        icon: icon,
        color: color,
        cta: t('intro.cta', 'Explore'),
        onOpen: () => _openIntroSection(section),
      ),
    );
  }

  void _openIntroSection(String section) {
    Widget? screen;
    switch (section) {
      case 'verify':
        screen = VerificationScreen(user: widget.user);
        break;
      case 'passport':
        screen = PassportScreen(user: widget.user);
        break;
      case 'wallet':
        screen = WalletScreen(user: widget.user);
        break;
      case 'courses':
        screen = CoursesScreen(user: widget.user);
        break;
      case 'opportunities':
        screen = OpportunitiesScreen(user: widget.user);
        break;
      case 'pro':
        screen = ProScreen(user: widget.user);
        break;
      case 'programs':
        screen = ProgramsScreen(user: widget.user);
        break;
    }
    if (screen == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
  }

  List<Widget> _feedItems(BuildContext context) {
    final posts = _visiblePosts;
    final items = <Widget>[];
    var adIndex = 0;
    var discoveryIndex = 0;
    if (posts.isEmpty) {
      for (final item in _discoveries) {
        items.add(_DiscoveryCard(item: item, onTap: () => _openDiscovery(item)));
      }
      return items;
    }
    for (var i = 0; i < posts.length; i++) {
      if (i > 0 && i % 6 == 0 && _ads.isNotEmpty && adIndex < _ads.length) {
        items.add(SlideInWidget(
          delay: const Duration(milliseconds: 80),
          slideOffset: const Offset(0, 0.08),
          child: AdFeedCard(campaign: _ads[adIndex++]),
        ));
      }
      if (_filter == 'all' && i > 0 && i % 12 == 0) {
        final section = _introSections[_introIndex++ % _introSections.length];
        items.add(_introCard(context, section));
      }
      final p = posts[i];
      items.add(SlideInWidget(
        delay: Duration(milliseconds: 120 * (i % 8)),
        slideOffset: const Offset(0, 0.08),
        child: _TrackedPostCard(
          key: ValueKey('tracked-${p.id}'),
          postId: p.id,
          child: _PostCard(
            post: p,
            currentUser: widget.user,
            onLike: () => _onLike(p),
            onBookmark: () => _onBookmark(p),
            onComment: () => _openPost(p),
            onImpact: () => _onImpact(p),
            onShare: () => _onShare(p),
            onImageTap: p.media.any((m) => !m.isVideo)
                ? (url) => showEnlargedImage(context, url)
                : null,
            onAuthor: () => _openAuthor(p.author),
            onFollow: () => _onFollow(p),
            onOpen: () => _openPost(p),
          ),
        ),
      ));
      if (i > 0 && i % 2 == 0 && discoveryIndex < _discoveries.length) {
        final item = _discoveries[discoveryIndex++];
        items.add(_DiscoveryCard(
          item: item,
          onTap: () => _openDiscovery(item),
        ));
      }
    }
    for (var j = discoveryIndex; j < _discoveries.length; j++) {
      final item = _discoveries[j];
      items.add(_DiscoveryCard(
        item: item,
        onTap: () => _openDiscovery(item),
      ));
    }
    return items;
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
          Badge(
            isLabelVisible: widget.unreadNotifications > 0,
            label: Text(widget.unreadNotifications > 99
                ? '99+'
                : '${widget.unreadNotifications}'),
            child: IconButton(
              tooltip: MasarenLocalizations.of(context, 'nav.notifications'),
              icon: Icon(Icons.notifications_outlined, color: cs.onSurface),
              onPressed: widget.onNotifications,
            ),
          ),
          if (_walletBalance != null)
            Tooltip(
              message: MasarenLocalizations.of(context, 'nav.wallet'),
              child: TextButton(
                onPressed: _openWallet,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.token, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _walletBalance!.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(
                widget.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: cs.onSurface),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: MasarenLocalizations.of(context, 'nav.more'),
            icon: Icon(Icons.menu_open, color: cs.onSurface),
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
                    controller: _scrollController,
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
                                    institutionId: id, user: widget.user))),
                      ),
                      const ImpactToolsSection(),
                      SectionTitle(
                          title:
                              MasarenLocalizations.of(context, 'feed.title')),
                      if (_visiblePosts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: _hasMore
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    MasarenLocalizations.of(
                                        context, 'feed.empty'),
                                    style:
                                        TextStyle(color: cs.onSurfaceVariant),
                                  ),
                          ),
                        ),
                      ..._feedItems(context),
                      if (_discoveryLoading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Future<void> _onFollow(Post p) async {
    if (p.author.id == widget.user.id) return;
    final i = _posts.indexWhere((e) => e.id == p.id);
    if (i == -1) return;
    final was = p.author.isFollowing;
    AnalyticsService.instance.track('follow_toggle',
        targetType: 'user',
        targetId: p.author.id,
        metadata: {'following': !was});
    _posts[i] = p.copyWith(author: p.author.copyWith(isFollowing: !was));
    if (mounted) setState(() {});
    try {
      final res = await AuthApi.toggleFollow(p.author.id);
      final following = res['following'] == true;
      if (following && mounted) {
        unawaited(FestiveBurst.show(context,
            message: 'Following ${p.author.name}',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF0E6B5C)));
      }
      final j = _posts.indexWhere((e) => e.id == p.id);
      if (j != -1) {
        _posts[j] = _posts[j].copyWith(
            author: _posts[j].author.copyWith(isFollowing: following));
      }
    } catch (_) {
      final j = _posts.indexWhere((e) => e.id == p.id);
      if (j != -1) {
        _posts[j] = _posts[j]
            .copyWith(author: _posts[j].author.copyWith(isFollowing: was));
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _onBookmark(Post p) async {
    final i = _posts.indexWhere((e) => e.id == p.id);
    if (i == -1) return;
    final was = p.bookmarkedByMe;
    AnalyticsService.instance.track(was ? 'post_unbookmark' : 'post_bookmark',
        targetType: 'post', targetId: p.id, postId: int.tryParse(p.id));
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
    AnalyticsService.instance.track(wasLiked ? 'post_unlike' : 'post_like',
        targetType: 'post', targetId: p.id, postId: int.tryParse(p.id));
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
    if (mounted) {
      setState(() {});
      if (!wasLiked) {
        unawaited(FestiveBurst.show(context,
            message: 'Impact amplified',
            icon: Icons.favorite_rounded,
            color: const Color(0xFFE36A4A)));
      }
    }
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
                          decoration: const BoxDecoration(
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
                                    color: Colors.white.withValues(alpha: 0.2),
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
                                  const Icon(Icons.favorite,
                                      size: 14, color: Colors.redAccent),
                                  const SizedBox(width: 4),
                                  Text('${p.likes}',
                                      style: const TextStyle(
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
                    : cs.onSurfaceVariant.withValues(alpha: 0.3),
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
              const Icon(Icons.verified, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(MasarenLocalizations.of(context, 'feed.recognitionTitle'),
                  style: const TextStyle(
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

class _ReactionMedia extends StatefulWidget {
  final Widget child;
  final bool liked;
  final VoidCallback onLike;
  const _ReactionMedia(
      {required this.child, required this.liked, required this.onLike});

  @override
  State<_ReactionMedia> createState() => _ReactionMediaState();
}

class _ReactionMediaState extends State<_ReactionMedia>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _doubleTap() {
    if (!widget.liked) widget.onLike();
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _doubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                if (t == 0) return const SizedBox.shrink();
                final scale = 0.45 + Curves.easeOutBack.transform(t) * 0.9;
                final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: Icon(Icons.favorite_rounded,
                        color: Colors.redAccent.withValues(alpha: 0.92),
                        size: 92),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackedPostCard extends StatefulWidget {
  final String postId;
  final Widget child;
  const _TrackedPostCard(
      {super.key, required this.postId, required this.child});

  @override
  State<_TrackedPostCard> createState() => _TrackedPostCardState();
}

class _TrackedPostCardState extends State<_TrackedPostCard> {
  bool _visible = false;
  bool _impressionSent = false;
  DateTime? _visibleSince;
  Timer? _impressionTimer;

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.5;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _visibleSince = DateTime.now();
      if (!_impressionSent) {
        _impressionTimer?.cancel();
        _impressionTimer =
            Timer(const Duration(milliseconds: 700), _sendImpression);
      }
    } else {
      _impressionTimer?.cancel();
      _flushDwell();
    }
  }

  void _sendImpression() {
    if (_impressionSent || !_visible) return;
    _impressionSent = true;
    AnalyticsService.instance.track('feed_impression',
        targetType: 'post',
        targetId: widget.postId,
        postId: int.tryParse(widget.postId));
  }

  void _flushDwell() {
    final since = _visibleSince;
    _visibleSince = null;
    if (since == null) return;
    final ms = DateTime.now().difference(since).inMilliseconds;
    if (ms >= 1000) {
      AnalyticsService.instance.track('post_dwell',
          targetType: 'post',
          targetId: widget.postId,
          postId: int.tryParse(widget.postId),
          durationMs: ms);
    }
  }

  @override
  void dispose() {
    _impressionTimer?.cancel();
    _flushDwell();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('post-impression-${widget.postId}'),
      onVisibilityChanged: _onVisibility,
      child: widget.child,
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
  final VoidCallback onFollow;
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
    required this.onFollow,
    required this.onOpen,
  });

  Widget _leaderboardCard(BuildContext context, Map<String, dynamic> data) {
    final cs = Theme.of(context).colorScheme;
    final rankings = (data['rankings'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .take(5)
        .toList();
    if (rankings.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.12),
            cs.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${data['scope'] ?? 'Leaderboard'} · ${data['period'] ?? ''}',
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rankings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      i == 0
                          ? '🥇'
                          : i == 1
                              ? '🥈'
                              : i == 2
                                  ? '🥉'
                                  : '#${i + 1}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rankings[i]['name']?.toString() ?? 'Member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${rankings[i]['score'] ?? 0}',
                    style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
      case 'leaderboard':
        return Icons.leaderboard_rounded;
      default:
        return Icons.auto_awesome;
    }
  }

  String _typeLabel(BuildContext context) {
    switch (post.kind ?? '') {
      case 'recognition':
        return MasarenLocalizations.of(context, 'post.recognition');
      case 'opportunity':
        return MasarenLocalizations.of(context, 'post.opportunity');
      case 'announcement':
        return MasarenLocalizations.of(context, 'post.announcement');
      case 'interview':
        return MasarenLocalizations.of(context, 'post.interview');
      case 'program':
        return MasarenLocalizations.of(context, 'post.program');
      case 'leaderboard':
        return MasarenLocalizations.of(context, 'post.leaderboard');
      case 'evidence':
        return MasarenLocalizations.of(context, 'post.evidence');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _typeColor;
    final typeLabel = _typeLabel(context);
    final isPlatform =
        post.kind == 'announcement' || post.kind == 'opportunity';
    final highImpact = (post.impactValue ?? 0) >= 6.5;

    return Container(
      decoration: BoxDecoration(
        color: highImpact ? null : cs.surface,
        gradient: highImpact
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.075),
                  cs.surface,
                  cs.surface,
                ],
              )
            : null,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
          left: highImpact
              ? BorderSide(color: cs.primary.withValues(alpha: 0.55), width: 3)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (typeLabel.isNotEmpty)
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
                  Text(typeLabel.toUpperCase(),
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
                      child: Text(
                          MasarenLocalizations.of(context, 'post.masareen'),
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
                            RoleBadge(role: post.author.role),
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
                if (post.author.id != currentUser.id &&
                    post.kind != 'announcement')
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: post.author.isFollowing
                          ? MasarenLocalizations.of(context, 'post.following')
                          : MasarenLocalizations.of(context, 'post.follow'),
                      child: IconButton(
                        onPressed: onFollow,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                          backgroundColor: post.author.isFollowing
                              ? cs.surfaceContainerHighest
                              : cs.primary.withValues(alpha: 0.10),
                          side: BorderSide(
                              color: post.author.isFollowing
                                  ? cs.outlineVariant
                                  : cs.primary.withValues(alpha: 0.35)),
                        ),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            post.author.isFollowing
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            key: ValueKey(post.author.isFollowing),
                            size: 18,
                            color: post.author.isFollowing
                                ? cs.onSurfaceVariant
                                : cs.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (post.kind == 'recognition')
                  Icon(Icons.emoji_events,
                      color: Colors.amber.shade700, size: 20)
                else if (post.kind == 'opportunity')
                  const Icon(Icons.work_outline, color: Colors.blue, size: 20)
                else if (post.kind == 'interview')
                  const Icon(Icons.mic, color: Colors.green, size: 20),
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
                    label: MasarenLocalizations.of(context, 'post.recognition'),
                    icon: Icons.emoji_events,
                    color: Colors.amber.shade700,
                  ),
                if (post.kind == 'interview')
                  _PostBadge(
                    label: MasarenLocalizations.of(context, 'post.interview'),
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
                    label: MasarenLocalizations.of(context, 'post.trending'),
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
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(post.text,
                  style: TextStyle(color: cs.onSurface, height: 1.4)),
            ),
          ),
          if (post.structured?['rankings'] is List)
            _leaderboardCard(context, post.structured!),
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ReactionMedia(
                liked: post.likedByMe,
                onLike: onLike,
                child: PostMediaGallery(
                  media: post.media,
                  videoId: post.id,
                  videoHlsUrl: post.videoHlsUrl,
                  videoPosterUrl: post.videoPosterUrl,
                  onImageTap: onImageTap,
                ),
              ),
            ),
          if (post.files.isNotEmpty) PostFilesList(files: post.files),
          if (post.linkUrl != null && post.linkUrl!.isNotEmpty)
            PostLinkCard(url: post.linkUrl!),
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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: Icons.favorite,
                    active: post.likedByMe,
                    activeColor: Colors.redAccent,
                    label: _compactCount(post.likes),
                    tooltip: MasarenLocalizations.of(context, 'post.likes'),
                    onTap: onLike,
                  ),
                ),
                Expanded(
                  child: _Action(
                    icon: Icons.mode_comment_outlined,
                    label: _compactCount(post.comments),
                    tooltip: MasarenLocalizations.of(context, 'post.comments'),
                    onTap: onComment,
                  ),
                ),
                Expanded(
                  child: _Action(
                    icon: Icons.fact_check_outlined,
                    label: MasarenLocalizations.of(context, 'feed.impact'),
                    tooltip:
                        MasarenLocalizations.of(context, 'post.rateImpact'),
                    onTap: onImpact,
                  ),
                ),
                Expanded(
                  child: _Action(
                    icon: Icons.share_outlined,
                    label: _compactCount(post.shares),
                    tooltip: MasarenLocalizations.of(context, 'post.shares'),
                    onTap: onShare,
                  ),
                ),
                Expanded(
                  child: _Action(
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
                ),
              ],
            ),
          ),
          if (post.topComments.isNotEmpty)
            InkWell(
              onTap: onComment,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in post.topComments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppAvatar(
                                name: c.authorName ?? 'Member',
                                url: c.authorPicture,
                                size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12.5,
                                      height: 1.3),
                                  children: [
                                    TextSpan(
                                        text: '${c.authorName ?? 'Member'} ',
                                        style: TextStyle(
                                            color: cs.onSurface,
                                            fontWeight: FontWeight.w700)),
                                    TextSpan(text: c.text),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (post.comments > post.topComments.length)
                      Text(
                        MasarenLocalizations.of(context, 'post.viewAllComments')
                            .replaceAll('{count}', '${post.comments}'),
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
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
    'verified_evidence': 'impact.cat.verified_evidence',
    'community_voice': 'impact.cat.community_voice',
    'policy_change': 'impact.cat.policy_change',
    'innovation': 'impact.cat.innovation',
    'scale': 'impact.cat.scale',
    'transparency': 'impact.cat.transparency',
  };

  static const _starKeys = [
    'impact.star1',
    'impact.star2',
    'impact.star3',
    'impact.star4',
    'impact.star5',
  ];

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
                    child: Text(
                        MasarenLocalizations.of(context, 'impact.title'),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(MasarenLocalizations.of(context, 'impact.body'),
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
                    tooltip: MasarenLocalizations.of(context, 'impact.stars')
                        .replaceAll('{value}', '$value'),
                  );
                }),
              ),
              Center(
                child: Text(
                  MasarenLocalizations.of(context, _starKeys[_stars - 1]),
                  style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Text(MasarenLocalizations.of(context, 'impact.credible'),
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries.map((e) {
                  final on = _cats.contains(e.key);
                  return FilterChip(
                    label: Text(MasarenLocalizations.of(context, e.value),
                        style: const TextStyle(fontSize: 12)),
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
                  hintText: MasarenLocalizations.of(context, 'impact.noteHint'),
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
                  label: Text(_saving
                      ? MasarenLocalizations.of(context, 'impact.saving')
                      : MasarenLocalizations.of(context, 'impact.submit')),
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
  final String? tooltip;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    this.tooltip,
    this.active = false,
    this.activeColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? (activeColor ?? cs.primary) : cs.onSurfaceVariant;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (activeColor ?? cs.primary).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: active ? 20 : 18, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
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

String _compactCount(int value) {
  String trim(String text) =>
      text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  if (value >= 1000000) {
    return '${trim((value / 1000000).toStringAsFixed(1))}M';
  }
  if (value >= 1000) {
    return '${trim((value / 1000).toStringAsFixed(1))}K';
  }
  return '$value';
}

Color _confidenceColor(double? score) {
  if (score == null) return Colors.grey;
  if (score >= 0.8) return Colors.green;
  if (score >= 0.6) return Colors.teal;
  if (score >= 0.4) return Colors.orange;
  return Colors.redAccent;
}

class _DiscoveryCard extends StatelessWidget {
  final DiscoveryItem item;
  final VoidCallback onTap;
  const _DiscoveryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = item.verified ? cs.primary : AppColors.azure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Material(
        color: dark ? AppColors.darkSurface : cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: dark ? .35 : .8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: SmartImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: _iconFor(item.type),
                    accent: accent,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(item.type,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: accent)),
                            ),
                            if (item.verified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified,
                                  size: 13, color: cs.primary),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: .14),
                                  borderRadius: BorderRadius.circular(99)),
                              child: Text('${item.impactPercent}%',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.accent)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.25,
                                fontWeight: FontWeight.w800)),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5, color: cs.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.arrow_forward,
                                size: 13, color: accent),
                            const SizedBox(width: 3),
                            Text('Open',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'EVENT':
        return Icons.event_outlined;
      case 'PROGRAM':
        return Icons.hub_outlined;
      case 'PROJECT':
        return Icons.folder_outlined;
      case 'OPPORTUNITY':
        return Icons.work_outline;
      case 'PODCAST':
        return Icons.podcasts;
      case 'VOD':
        return Icons.video_library_outlined;
      default:
        return Icons.public;
    }
  }
}