import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/admin_screen.dart';
import 'package:masaren/screens/ads_screen.dart';
import 'package:masaren/screens/courses_screen.dart';
import 'package:masaren/screens/create_post_screen.dart';
import 'package:masaren/screens/create_leaderboard_screen.dart';
import 'package:masaren/screens/event_dashboard_screen.dart';
import 'package:masaren/screens/events_screen.dart';
import 'package:masaren/screens/feed_screen.dart';
import 'package:masaren/screens/feedback_screen.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/market_screen.dart';
import 'package:masaren/screens/newsroom_screen.dart';
import 'package:masaren/screens/notifications_screen.dart';
import 'package:masaren/screens/opportunities_screen.dart';
import 'package:masaren/screens/live_tv_screen.dart';
import 'package:masaren/screens/passport_screen.dart';
import 'package:masaren/screens/podcast_screen.dart';
import 'package:masaren/screens/profile_screen.dart';
import 'package:masaren/screens/vod_screen.dart';
import 'package:masaren/screens/pro_screen.dart';
import 'package:masaren/screens/programs_screen.dart';
import 'package:masaren/screens/projects_screen.dart';
import 'package:masaren/screens/research_hub_screen.dart';
import 'package:masaren/screens/saved_posts_screen.dart';
import 'package:masaren/screens/universities_screen.dart';
import 'package:masaren/screens/search_screen.dart';
import 'package:masaren/screens/settings_screen.dart';
import 'package:masaren/screens/help_center_screen.dart';
import 'package:masaren/screens/verification_screen.dart';
import 'package:masaren/screens/wallet_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masaren/services/analytics_service.dart';
import 'package:masaren/services/app_updater.dart';
import 'package:masaren/services/notification_service.dart';
import 'package:masaren/services/polling_service.dart';
import 'package:masaren/shell/shell_navigation.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/widgets.dart';

const String _appVersion = '0.4.8+13';

PageRouteBuilder<T> _shellRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(begin: const Offset(0.04, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child:
              SlideTransition(position: animation.drive(tween), child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    );

class HomeShell extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleLocale;
  const HomeShell(
      {super.key,
      required this.onLogout,
      this.onToggleTheme,
      this.onToggleLocale});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Index 2 is the create action, not a page. Valid pages are 0, 1, 3 and 4.
  static const _tabs = <int>[0, 1, 3, 4];

  int _tab = 0;
  String _webActive = 'home';
  User? _user;
  bool _loadingUser = true;
  bool _announcementChecked = false;
  int _unreadNotifications = 0;
  int _unreadMessages = 0;
  double? _balance;
  DateTime? _lastBack;

  final _feedKey = GlobalKey<FeedScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _webNavKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  final Map<int, GlobalKey<NavigatorState>> _navKeys = {
    for (final i in _tabs) i: GlobalKey<NavigatorState>(),
  };

  NavigatorState? get _tabNavigator => _navKeys[_tab]?.currentState;
  bool get _wideWeb =>
      kIsWeb && MediaQuery.sizeOf(context).width >= 1024;

  @override
  void initState() {
    super.initState();
    shellPush = pushInTab;
    _loadUser();
    AnalyticsService.instance.start();
    _startNotificationPolling();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) await AppUpdater.checkAndPrompt(context);
  }

  @override
  void dispose() {
    AnalyticsService.instance.flush();
    if (shellPush != null) shellPush = null;
    _tabNotifier.dispose();
    super.dispose();
  }

  void _startNotificationPolling() {
    PollingService.instance.onNewNotification = (count) {
      if (mounted) {
        setState(() => _unreadNotifications = count);
        NotificationService.instance.setBadgeCount(count);
      }
    };
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthApi.me();
      final messages = await AuthApi.unreadMessages();
      var notifications = _unreadNotifications;
      try {
        notifications = await AuthApi.unreadNotificationCount();
      } catch (_) {}
      double? balance;
      try {
        balance = (await AuthApi.wallet(user.id)).balance;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _user = user;
          _unreadMessages = messages;
          _unreadNotifications = notifications;
          _balance = balance;
        });
        NotificationService.instance.setBadgeCount(notifications);
      }
      _maybeShowAnnouncement();
      try {
        final settings = await AuthApi.settings();
        NotificationService.instance.configure(
          pushEnabled: settings.pushEnabled,
          quietStart: settings.quietStart,
          quietEnd: settings.quietEnd,
        );
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loadingUser = false);
  }

  Future<void> _maybeShowAnnouncement() async {
    if (_announcementChecked) return;
    _announcementChecked = true;
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    try {
      final items = await AuthApi.announcements();
      final active = items.where((a) => !a.dismissed).toList();
      if (active.isEmpty || !mounted) return;
      final a = active.first;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (a.imageUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26)),
                        child: Image.network(
                          a.imageUrl!,
                          height: 170,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.campaign_outlined,
                                  color: cs.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(a.title,
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(a.body,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  height: 1.45,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (a.linkUrl != null && a.linkUrl!.isNotEmpty)
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'cta'),
                  child: Text(a.ctaLabel?.isNotEmpty == true
                      ? a.ctaLabel!
                      : MasarenLocalizations.of(
                          ctx, 'announcements.ctaFallback')),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'dismiss'),
                child:
                    Text(MasarenLocalizations.of(ctx, 'announcements.dismiss')),
              ),
            ],
          );
        },
      );
      if (action == 'cta' && a.linkUrl != null) {
        final uri = Uri.tryParse(a.linkUrl!);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      await AuthApi.dismissAnnouncement(a.id);
    } catch (_) {}
  }

  Future<void> _refreshBadges() async {
    try {
      final results = await Future.wait([
        AuthApi.unreadMessages(),
        AuthApi.unreadNotificationCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _unreadMessages = results[0];
        _unreadNotifications = results[1];
      });
    } catch (_) {}
  }

  void _openDrawer() {
    if (_wideWeb && _user != null) {
      _openWeb(SearchScreen(user: _user!));
      return;
    }
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _switchTab(int index) {
    if (index == 2) {
      _showCreateSheet();
      return;
    }
    if (!_tabs.contains(index)) return;
    HapticFeedback.selectionClick();
    if (index == _tab) {
      _navKeys[index]?.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _tab = index);
    _tabNotifier.value = index;
    if (index == 4) _profileKey.currentState?.refresh();
  }

  void _goToProfile() {
    if (_wideWeb && mounted) {
      setState(() => _webActive = 'profile');
    }
    if (_tab == 4) {
      _webNavKey.currentState?.popUntil((r) => r.isFirst);
      _navKeys[4]?.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _tab = 4);
    _tabNotifier.value = 4;
  }

  Future<T?> pushInTab<T>(Widget screen) async {
    if (_wideWeb) {
      final web = _webNavKey.currentState;
      if (web != null) return web.push<T>(_shellRoute(screen));
    }
    final nav = _tabNavigator;
    if (nav == null) return null;
    return nav.push<T>(_shellRoute(screen));
  }

  void _openWeb(Widget screen) {
    final web = _webNavKey.currentState;
    if (web == null) return;
    setState(() => _webActive = _webKeyFor(screen));
    web.popUntil((r) => r.isFirst);
    web.push(_shellRoute(screen));
  }

  String _webKeyFor(Widget screen) {
    if (screen is MarketScreen) return 'market';
    if (screen is NewsroomScreen) return 'news';
    if (screen is EventsScreen) return 'events';
    if (screen is MessagesScreen) return 'messages';
    if (screen is NotificationsScreen) return 'notifications';
    if (screen is SearchScreen) return 'search';
    if (screen is WalletScreen) return 'wallet';
    if (screen is ProScreen) return 'pro';
    if (screen is AdsScreen) return 'ads';
    if (screen is SavedPostsScreen) return 'saved';
    if (screen is ProgramsScreen) return 'programs';
    if (screen is ProjectsScreen) return 'projects';
    if (screen is OpportunitiesScreen) return 'opportunities';
    if (screen is LiveTvScreen) return 'live';
    if (screen is PodcastHubScreen) return 'podcasts';
    if (screen is VodHubScreen) return 'vod';
    if (screen is PassportScreen) return 'passport';
    if (screen is VerificationScreen) return 'verification';
    if (screen is AdminScreen) return 'admin';
    if (screen is SettingsScreen) return 'settings';
    return _webActive;
  }

  void _webTab(int index) {
    final web = _webNavKey.currentState;
    web?.popUntil((r) => r.isFirst);
    setState(() {
      _webActive = index == 0
          ? 'home'
          : index == 1
              ? 'explore'
              : index == 3
                  ? 'courses'
                  : 'profile';
    });
    _switchTab(index);
  }

  void _handleBack() {
    final nav = _tabNavigator;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (_tab != 0) {
      setState(() => _tab = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBack == null ||
        now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      _feedKey.currentState?.refreshToTop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Feed refreshed. Press back again to exit.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    SystemNavigator.pop();
  }

  void _showCreateSheet() {
    final user = _user;
    if (user == null) return;
    final sheet = _CreatePostSheet(
      user: user,
      navigator: _wideWeb ? _webNavKey.currentState : _tabNavigator,
      onPosted: () {
        _feedKey.currentState?.refresh();
        if (mounted) {
          setState(() => _tab = 0);
          _tabNotifier.value = 0;
        }
      },
    );
    if (_wideWeb) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(28),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: sheet,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  Widget _navRoot(int index, Widget child) {
    return Navigator(
      key: _navKeys[index],
      onGenerateRoute: (_) => _shellRoute(child),
      onDidRemovePage: (page) {},
    );
  }

  Widget _buildBody() {
    final user = _user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    return IndexedStack(
      index: _tab,
      children: [
        _navRoot(
          0,
          FeedScreen(
            key: _feedKey,
            user: user,
            unreadNotifications: _unreadNotifications,
            onToggleTheme: widget.onToggleTheme,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onNotifications: () =>
                pushInTab(NotificationsScreen(userId: user.id))
                    .then((_) => _refreshBadges()),
            onMore: _openDrawer,
          ),
        ),
        _navRoot(1, OpportunitiesScreen(user: user, onMenu: _openDrawer)),
        const SizedBox.shrink(),
        _navRoot(3, CoursesScreen(user: user, onMenu: _openDrawer)),
        _navRoot(
          4,
          ProfileScreen(
            key: _profileKey,
            user: user,
            onLogout: widget.onLogout,
            onToggleTheme: widget.onToggleTheme,
            onMenu: _openDrawer,
          ),
        ),
      ],
    );
  }

  Widget _webRoot() => ValueListenableBuilder<int>(
        valueListenable: _tabNotifier,
        builder: (_, tab, ___) {
          final maxWidth = tab == 0 ? 720.0 : 980.0;
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SizedBox.expand(child: _buildBody()),
              ),
            ),
          );
        },
      );

  Widget _buildWebShell(User user) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final showRail = width >= 1380;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WebSidebar(
            user: user,
            balance: _balance,
            activeKey: _webActive,
            unreadMessages: _unreadMessages,
            unreadNotifications: _unreadNotifications,
            isDark: Theme.of(context).brightness == Brightness.dark,
            isArabic:
                Localizations.localeOf(context).languageCode == 'ar',
            onTab: _webTab,
            onProfile: () {
              _webNavKey.currentState?.popUntil((r) => r.isFirst);
              _goToProfile();
            },
            onCreate: _showCreateSheet,
            onOpen: _openWeb,
            onToggleTheme: widget.onToggleTheme,
            onToggleLocale: widget.onToggleLocale,
            onCheckUpdates: () => AppUpdater.checkAndPrompt(context,
                silent: false),
            onLogout: widget.onLogout,
          ),
          Expanded(
            child: ColoredBox(
              color: cs.surfaceContainerLow,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: SizedBox.expand(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        border: BorderDirectional(
                          start: BorderSide(
                              color:
                                  cs.outlineVariant.withValues(alpha: .45)),
                          end: BorderSide(
                              color:
                                  cs.outlineVariant.withValues(alpha: .45)),
                        ),
                      ),
                      child: Navigator(
                        key: _webNavKey,
                        onGenerateRoute: (_) => _shellRoute(_webRoot()),
                        onDidRemovePage: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showRail)
            _WebRightRail(
              user: user,
              balance: _balance,
              onSearch: () => _openWeb(SearchScreen(user: user)),
              onMarket: () => _openWeb(MarketScreen(user: user)),
              onNews: () => _openWeb(NewsroomScreen(user: user)),
              onProfile: () {
                _webNavKey.currentState?.popUntil((r) => r.isFirst);
                _goToProfile();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = _user;
    if (_wideWeb && user != null) return _buildWebShell(user);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        body: _buildBody(),
        endDrawer: user == null
            ? null
            : _ShellDrawer(
                user: user,
                balance: _balance,
                unreadMessages: _unreadMessages,
                unreadNotifications: _unreadNotifications,
                isDark: Theme.of(context).brightness == Brightness.dark,
                isArabic: Localizations.localeOf(context).languageCode == 'ar',
                onProfile: () {
                  Navigator.of(context).pop();
                  _goToProfile();
                },
                onPush: pushInTab,
                onRefresh: _refreshBadges,
                onRefreshUser: _loadUser,
                onToggleTheme: widget.onToggleTheme,
                onToggleLocale: widget.onToggleLocale,
                onCheckUpdates: () =>
                    AppUpdater.checkAndPrompt(context, silent: false),
                onLogout: widget.onLogout,
              ),
        bottomNavigationBar: _MasarenNavBar(
          selected: _tab,
          user: user,
          unreadMessages: _unreadMessages,
          unreadNotifications: _unreadNotifications,
          onSelect: _switchTab,
          onCreate: _showCreateSheet,
        ),
        backgroundColor: cs.surface,
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Sliding menu (end drawer)                                           */
/* ------------------------------------------------------------------ */

class _ShellDrawer extends StatelessWidget {
  final User user;
  final double? balance;
  final int unreadMessages;
  final int unreadNotifications;
  final bool isDark;
  final bool isArabic;
  final VoidCallback onProfile;
  final Future<dynamic> Function(Widget) onPush;
  final VoidCallback? onRefresh;
  final VoidCallback? onRefreshUser;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleLocale;
  final VoidCallback onCheckUpdates;
  final VoidCallback onLogout;

  const _ShellDrawer({
    required this.user,
    required this.balance,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.isDark,
    required this.isArabic,
    required this.onProfile,
    required this.onPush,
    this.onRefresh,
    this.onRefreshUser,
    this.onToggleTheme,
    this.onToggleLocale,
    required this.onCheckUpdates,
    required this.onLogout,
  });

  String _t(BuildContext context, String key, String fallback) {
    final value = MasarenLocalizations.of(context, key);
    return value == key ? fallback : value;
  }

  void _open(BuildContext context, Widget screen, {bool refresh = false}) {
    Navigator.of(context).pop();
    final future = onPush(screen);
    if (refresh) {
      future.then((_) {
        onRefresh?.call();
        onRefreshUser?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = user.isAdmin || user.role.toUpperCase() == 'ADMIN';
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width > 420 ? 340 : width * 0.88,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          start: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _header(context, cs),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _section(
                  cs,
                  _t(context, 'menu.account', 'Account'),
                  [
                    _tile(context,
                        icon: Icons.person_outline,
                        label: _t(context, 'nav.profile', 'Profile'),
                        onTap: onProfile),
                    _tile(context,
                        icon: Icons.forum_outlined,
                        label: _t(context, 'nav.messages', 'Messages'),
                        badge: unreadMessages,
                        onTap: () => _open(context, MessagesScreen(user: user),
                            refresh: true)),
                    _tile(context,
                        icon: Icons.support_agent,
                        label: _t(
                            context, 'support.message', 'Message the platform'),
                        onTap: () async {
                      try {
                        final conversation =
                            await AuthApi.supportConversation();
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChatScreen(
                                conversation: conversation, user: user)));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(MasarenLocalizations.of(
                                    context, 'common.failed')
                                .replaceAll('{error}', ''))));
                      }
                    }),
                    _tile(context,
                        icon: Icons.notifications_outlined,
                        label:
                            _t(context, 'nav.notifications', 'Notifications'),
                        badge: unreadNotifications,
                        onTap: () => _open(
                            context, NotificationsScreen(userId: user.id),
                            refresh: true)),
                    _tile(context,
                        icon: Icons.bookmark_border,
                        label: _t(context, 'nav.saved', 'Saved'),
                        onTap: () =>
                            _open(context, SavedPostsScreen(user: user))),
                    _tile(context,
                        icon: Icons.search,
                        label: _t(context, 'nav.search', 'Search'),
                        onTap: () => _open(context, SearchScreen(user: user))),
                  ],
                ),
                _section(
                  cs,
                  _t(context, 'menu.platform', 'Platform'),
                  [
                    _tile(context,
                        icon: Icons.school_outlined,
                        label: _t(context, 'nav.courses', 'Courses'),
                        onTap: () => _open(context, CoursesScreen(user: user))),
                    _tile(context,
                        icon: Icons.event_outlined,
                        label: _t(context, 'nav.events', 'Events'),
                        onTap: () => _open(context, EventsScreen(user: user))),
                    _tile(context,
                        icon: Icons.insights_outlined,
                        label: _t(context, 'nav.eventDashboard',
                            'Event enterprise dashboard'),
                        onTap: () =>
                            _open(context, EventDashboardScreen(user: user))),
                    _tile(context,
                        icon: Icons.account_balance_outlined,
                        label: _t(context, 'nav.universities', 'Universities'),
                        onTap: () =>
                            _open(context, UniversitiesScreen(user: user))),
                    _tile(context,
                        icon: Icons.science_outlined,
                        label: _t(context, 'nav.research', 'Research hub'),
                        onTap: () =>
                            _open(context, ResearchHubScreen(user: user))),
                    _tile(context,
                        icon: Icons.newspaper_outlined,
                        label: 'Newsroom',
                        onTap: () =>
                            _open(context, NewsroomScreen(user: user))),
                    _tile(context,
                        icon: Icons.candlestick_chart_outlined,
                        label: 'Impact Market',
                        onTap: () =>
                            _open(context, MarketScreen(user: user))),
                    _tile(context,
                        icon: Icons.leaderboard_outlined,
                        label: _t(context, 'nav.leaderboards', 'Leaderboards'),
                        onTap: () => _open(
                            context, CreateLeaderboardScreen(user: user))),
                    _tile(context,
                        icon: Icons.hub_outlined,
                        label: _t(context, 'nav.programs', 'Programs'),
                        onTap: () =>
                            _open(context, ProgramsScreen(user: user))),
                    _tile(context,
                        icon: Icons.handshake_outlined,
                        label: _t(context, 'nav.projects', 'Projects'),
                        onTap: () =>
                            _open(context, ProjectsScreen(user: user))),
                    _tile(context,
                        icon: Icons.work_outline,
                        label:
                            _t(context, 'nav.opportunities', 'Opportunities'),
                        onTap: () =>
                            _open(context, OpportunitiesScreen(user: user))),
                    _tile(context,
                        icon: Icons.live_tv_outlined,
                        label: _t(context, 'nav.liveTv', 'MASAREEN Live TV'),
                        onTap: () => _open(context, const LiveTvScreen())),
                    _tile(context,
                        icon: Icons.podcasts,
                        label: _t(context, 'nav.podcasts', 'Podcasts'),
                        onTap: () =>
                            _open(context, PodcastHubScreen(user: user))),
                    _tile(context,
                        icon: Icons.video_library_outlined,
                        label: _t(context, 'nav.vod', 'VOD & replays'),
                        onTap: () => _open(context, VodHubScreen(user: user))),
                    _tile(context,
                        icon: Icons.verified_user_outlined,
                        label: _t(context, 'nav.verification', 'Verification'),
                        onTap: () =>
                            _open(context, VerificationScreen(user: user))),
                    _tile(context,
                        icon: Icons.badge_outlined,
                        label: _t(context, 'nav.passport', 'Impact passport'),
                        onTap: () =>
                            _open(context, PassportScreen(user: user))),
                  ],
                ),
                _section(
                  cs,
                  _t(context, 'menu.finance', 'Finance'),
                  [
                    _tile(context,
                        icon: Icons.account_balance_wallet_outlined,
                        label: _t(context, 'nav.wallet', 'Wallet'),
                        trailing: balance == null
                            ? null
                            : Text('${balance!.toStringAsFixed(2)} MRC',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary)),
                        onTap: () => _open(context, WalletScreen(user: user),
                            refresh: true)),
                    _tile(context,
                        icon: Icons.workspace_premium_outlined,
                        label: _t(context, 'nav.pro', 'MASAREEN Pro'),
                        onTap: () => _open(context, ProScreen(user: user))),
                    _tile(context,
                        icon: Icons.campaign_outlined,
                        label: _t(context, 'nav.ads', 'Ads Manager'),
                        onTap: () => _open(context, AdsScreen(user: user))),
                  ],
                ),
                if (isAdmin)
                  _section(
                    cs,
                    _t(context, 'menu.admin', 'Administration'),
                    [
                      _tile(context,
                          icon: Icons.admin_panel_settings_outlined,
                          label: _t(context, 'nav.admin', 'Admin'),
                          onTap: () => _open(context, AdminScreen(user: user))),
                    ],
                  ),
                _section(
                  cs,
                  _t(context, 'menu.system', 'System'),
                  [
                    _tile(context,
                        icon: Icons.help_outline,
                        label: 'Help center',
                        onTap: () =>
                            _open(context, const HelpCenterScreen())),
                    _tile(context,
                        icon: Icons.feedback_outlined,
                        label: _t(context, 'feedback.title', 'Send feedback'),
                        onTap: () =>
                            _open(context, FeedbackScreen(user: user))),
                    _tile(context,
                        icon: Icons.settings_outlined,
                        label: _t(context, 'nav.settings', 'Settings'),
                        onTap: () => _open(
                              context,
                              SettingsScreen(user: user, onLogout: onLogout),
                              refresh: true,
                            )),
                    _tile(
                      context,
                      icon: Icons.system_update_alt,
                      label: _t(context, 'update.check', 'Check for updates'),
                      onTap: () {
                        Navigator.of(context).pop();
                        onCheckUpdates();
                      },
                    ),
                    _tile(
                      context,
                      icon: isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      label: _t(context, 'nav.theme', 'Theme'),
                      trailing: Switch(
                        value: isDark,
                        onChanged: (_) => onToggleTheme?.call(),
                      ),
                      onTap: onToggleTheme,
                    ),
                    _tile(
                      context,
                      icon: Icons.language_outlined,
                      label: isArabic ? 'English' : 'العربية',
                      trailing: Icon(Icons.swap_horiz,
                          size: 18, color: cs.onSurfaceVariant),
                      onTap: onToggleLocale,
                    ),
                    _tile(
                      context,
                      icon: Icons.logout_outlined,
                      label: _t(context, 'nav.signout', 'Sign Out'),
                      danger: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        onLogout();
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                      'MASAREEN · ${_t(context, 'menu.version', 'Version')} $_appVersion',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme cs) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadiusDirectional.only(
          bottomStart: Radius.circular(24),
          bottomEnd: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/images/masaren_logo_white.png',
                    height: 24, fit: BoxFit.contain),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onProfile,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2),
                      ),
                      child: AppAvatar(
                          name: user.fullName, url: user.avatarUrl, size: 52),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            user.role
                                .replaceAll('_', ' ')
                                .toLowerCase()
                                .split(' ')
                                .map((e) => e.isEmpty
                                    ? e
                                    : '${e[0].toUpperCase()}${e.substring(1)}')
                                .join(' '),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12),
                          ),
                          Text(user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.white.withValues(alpha: 0.8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).pop();
                onPush(WalletScreen(user: user))
                    .then((_) => onRefreshUser?.call());
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.toll_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_t(context, 'menu.balance', 'Coin balance'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12)),
                    ),
                    Text(
                      balance == null
                          ? '—'
                          : '${balance!.toStringAsFixed(2)} MRC',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ColorScheme cs, String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75)),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Widget? trailing,
    int badge = 0,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? AppColors.warm : cs.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minLeadingWidth: 24,
      visualDensity: const VisualDensity(vertical: -1.5),
      leading: Icon(icon,
          size: 21, color: danger ? AppColors.warm : cs.onSurfaceVariant),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: danger ? FontWeight.w600 : FontWeight.w500)),
      trailing: badge > 0
          ? _badge(cs, badge)
          : trailing ??
              Icon(Icons.chevron_right,
                  size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      onTap: onTap,
    );
  }

  Widget _badge(ColorScheme cs, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.warm, borderRadius: BorderRadius.circular(10)),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Bottom navigation                                                   */
/* ------------------------------------------------------------------ */

class _MasarenNavBar extends StatelessWidget {
  final int selected;
  final User? user;
  final int unreadMessages;
  final int unreadNotifications;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  const _MasarenNavBar({
    required this.selected,
    required this.user,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String l(String key, String fallback) {
      final value = MasarenLocalizations.of(context, key);
      return value == key ? fallback : value;
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;

    final items = <Widget>[
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l('nav.home', 'Home'),
        selected: selected == 0,
        badge: unreadNotifications,
        onTap: () => onSelect(0),
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        label: l('nav.explore', 'Explore'),
        selected: selected == 1,
        onTap: () => onSelect(1),
      ),
      _CreateNavItem(
        label: l('nav.create', 'Create'),
        onTap: onCreate,
      ),
      _NavItem(
        icon: Icons.school_outlined,
        selectedIcon: Icons.school_rounded,
        label: l('nav.courses', 'Courses'),
        selected: selected == 3,
        onTap: () => onSelect(3),
      ),
      _NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person_rounded,
        label: l('nav.profile', 'Profile'),
        selected: selected == 4,
        avatar: user == null
            ? null
            : AppAvatar(name: user!.fullName, url: user!.avatarUrl, size: 22),
        badge: unreadMessages,
        onTap: () => onSelect(4),
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : cs.primary)
                    .withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: SizedBox(
              height: 68,
              child: Row(
                children: (rtl ? items.reversed.toList() : items)
                    .map((e) => Expanded(child: e))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badge;
  final Widget? avatar;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    avatar == null
                        ? Icon(selected ? selectedIcon : icon,
                            size: 22, color: color)
                        : Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selected
                                      ? cs.primary
                                      : Colors.transparent,
                                  width: 1.6),
                            ),
                            child: avatar,
                          ),
                    if (badge > 0)
                      PositionedDirectional(
                        top: -4,
                        end: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warm,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cs.surface, width: 1.2),
                          ),
                          child: Text(badge > 99 ? '99+' : '$badge',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateNavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CreateNavItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* Create sheet                                                        */
/* ------------------------------------------------------------------ */

class _CreatePostSheet extends StatelessWidget {
  final User user;
  final NavigatorState? navigator;
  final VoidCallback? onPosted;
  const _CreatePostSheet({required this.user, this.navigator, this.onPosted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const loc = MasarenLocalizations.of;
    final types = [
      _PostType('story', loc(context, 'post.story'), '', Icons.auto_stories,
          cs.primary),
      _PostType('recognition', loc(context, 'post.recognition'), '',
          Icons.emoji_events, cs.secondary),
      _PostType('news', loc(context, 'post.news'), '', Icons.newspaper,
          const Color(0xFFE67C00)),
      _PostType(
          'video', loc(context, 'post.video'), '', Icons.videocam, cs.tertiary),
      _PostType('evidence', loc(context, 'post.evidence'), '', Icons.eco,
          const Color(0xFF0F9D58)),
      _PostType('announcement', loc(context, 'post.announcement'), '',
          Icons.campaign, const Color(0xFFF4B400)),
      _PostType('synergy', loc(context, 'post.synergy'), '', Icons.handshake,
          const Color(0xFF8E24AA)),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                AppAvatar(name: user.fullName, url: user.avatarUrl, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface)),
                      Text(loc(context, 'action.createPost'),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 620 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cols == 3 ? 1.42 : 1.15,
                  ),
                  itemCount: types.length,
                  itemBuilder: (_, i) {
                    final t = types[i];
                return Clickable(
                  onTap: () {
                    final nav = navigator ?? Navigator.of(context);
                    Navigator.of(context).pop();
                    nav
                        .push<bool>(_shellRoute(
                            CreatePostScreen(user: user, initialKind: t.kind)))
                        .then((result) {
                      if (result == true) onPosted?.call();
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: t.color.withValues(alpha: 0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: t.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(t.icon, color: t.color, size: 22),
                          ),
                          const Spacer(),
                          Text(t.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(t.desc,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostType {
  final String kind;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  const _PostType(this.kind, this.label, this.desc, this.icon, this.color);
}

/* ------------------------------------------------------------------ */
/* Desktop web shell                                                   */
/* ------------------------------------------------------------------ */

class _WebSidebar extends StatelessWidget {
  final User user;
  final double? balance;
  final String activeKey;
  final int unreadMessages;
  final int unreadNotifications;
  final bool isDark;
  final bool isArabic;
  final ValueChanged<int> onTab;
  final VoidCallback onProfile;
  final VoidCallback onCreate;
  final void Function(Widget) onOpen;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleLocale;
  final VoidCallback onCheckUpdates;
  final VoidCallback onLogout;

  const _WebSidebar({
    required this.user,
    required this.balance,
    required this.activeKey,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.isDark,
    required this.isArabic,
    required this.onTab,
    required this.onProfile,
    required this.onCreate,
    required this.onOpen,
    this.onToggleTheme,
    this.onToggleLocale,
    required this.onCheckUpdates,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final admin = user.isAdmin || user.role.toUpperCase() == 'ADMIN';
    return Container(
      width: 258,
      color: cs.surface,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/masaren_logo.png', height: 30),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('WEB',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                            color: cs.primary)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onProfile,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: .5)),
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                          name: user.fullName, url: user.avatarUrl, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800)),
                            Text(
                                balance == null
                                    ? user.role.toLowerCase()
                                    : '${balance!.toStringAsFixed(0)} MRC',
                                style: TextStyle(
                                    fontSize: 10.5, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(Icons.more_horiz,
                          size: 18, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: cs.primary.withValues(alpha: .22),
                          blurRadius: 18,
                          offset: const Offset(0, 7)),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onCreate,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 7),
                          Text('Create',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                children: [
                  _webSection(context, 'WORKSPACE'),
                  _webItem(context, Icons.home_outlined, Icons.home_rounded,
                      'Home', selected: activeKey == 'home',
                      onTap: () => onTab(0)),
                  _webItem(context, Icons.explore_outlined, Icons.explore_rounded,
                      'Explore', selected: activeKey == 'explore',
                      onTap: () => onTab(1)),
                  _webItem(context, Icons.candlestick_chart_outlined,
                      Icons.candlestick_chart, 'Impact Market',
                      onTap: () => onOpen(MarketScreen(user: user))),
                  _webItem(context, Icons.newspaper_outlined,
                      Icons.newspaper, 'Newsroom',
                      onTap: () => onOpen(NewsroomScreen(user: user))),
                  _webItem(context, Icons.event_outlined, Icons.event,
                      'Events',
                      onTap: () => onOpen(EventsScreen(user: user))),
                  _webItem(context, Icons.school_outlined, Icons.school,
                      'Courses', selected: activeKey == 'courses',
                      onTap: () => onTab(3)),
                  const SizedBox(height: 8),
                  _webSection(context, 'COMMUNITY'),
                  _webItem(context, Icons.forum_outlined, Icons.forum,
                      'Messages', badge: unreadMessages, selected: activeKey == 'messages',
                      onTap: () => onOpen(MessagesScreen(user: user))),
                  _webItem(context, Icons.notifications_outlined,
                      Icons.notifications, 'Notifications',
                      badge: unreadNotifications,
                      onTap: () =>
                          onOpen(NotificationsScreen(userId: user.id))),
                  _webItem(context, Icons.bookmark_border, Icons.bookmark,
                      'Saved posts',
                      onTap: () => onOpen(SavedPostsScreen(user: user))),
                  _webItem(context, Icons.search, Icons.search_rounded, 'Search',
                      onTap: () => onOpen(SearchScreen(user: user))),
                  _webItem(context, Icons.person_outline, Icons.person,
                      'My profile', selected: activeKey == 'profile',
                      onTap: onProfile),
                  const SizedBox(height: 8),
                  _webSection(context, 'GROW'),
                  _webItem(context, Icons.hub_outlined, Icons.hub, 'Programs',
                      onTap: () => onOpen(ProgramsScreen(user: user))),
                  _webItem(context, Icons.handshake_outlined, Icons.handshake,
                      'Projects',
                      onTap: () => onOpen(ProjectsScreen(user: user))),
                  _webItem(context, Icons.work_outline, Icons.work,
                      'Opportunities',
                      onTap: () => onOpen(OpportunitiesScreen(user: user))),
                  _webItem(context, Icons.live_tv_outlined, Icons.live_tv,
                      'Live TV', onTap: () => onOpen(const LiveTvScreen())),
                  _webItem(context, Icons.podcasts, Icons.podcasts,
                      'Podcasts', onTap: () => onOpen(PodcastHubScreen(user: user))),
                  _webItem(context, Icons.video_library_outlined,
                      Icons.video_library, 'VOD',
                      onTap: () => onOpen(VodHubScreen(user: user))),
                  _webItem(context, Icons.account_balance_wallet_outlined,
                      Icons.account_balance_wallet, 'Wallet',
                      onTap: () => onOpen(WalletScreen(user: user))),
                  _webItem(context, Icons.workspace_premium_outlined,
                      Icons.workspace_premium, 'MASAREEN Pro',
                      onTap: () => onOpen(ProScreen(user: user))),
                  _webItem(context, Icons.campaign_outlined, Icons.campaign,
                      'Ads Manager', onTap: () => onOpen(AdsScreen(user: user))),
                  _webItem(context, Icons.badge_outlined, Icons.badge,
                      'Impact passport',
                      onTap: () => onOpen(PassportScreen(user: user))),
                  _webItem(context, Icons.verified_user_outlined,
                      Icons.verified_user, 'Verification',
                      onTap: () => onOpen(VerificationScreen(user: user))),
                  if (admin)
                    _webItem(context, Icons.admin_panel_settings_outlined,
                        Icons.admin_panel_settings, 'Administration',
                        onTap: () => onOpen(AdminScreen(user: user))),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: .5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  _webIconButton(
                      context,
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      'Theme',
                      () => onToggleTheme?.call()),
                  _webIconButton(context, Icons.language_outlined,
                      'Language', () => onToggleLocale?.call()),
                  _webIconButton(context, Icons.settings_outlined, 'Settings',
                      () => onOpen(SettingsScreen(user: user, onLogout: onLogout))),
                  const Spacer(),
                  _webIconButton(context, Icons.logout_outlined, 'Sign out',
                      onLogout, danger: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webSection(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
        child: Text(label,
            style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: .7))),
      );

  Widget _webItem(
    BuildContext context,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool selected = false,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withValues(alpha: .10) : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(selected ? activeIcon : icon,
                  size: 19,
                  color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 11),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? cs.primary : cs.onSurface)),
              ),
              if (badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.warm,
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webIconButton(BuildContext context, IconData icon, String tooltip,
      VoidCallback onTap,
      {bool danger = false}) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 19,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon,
          color: danger ? AppColors.warm : cs.onSurfaceVariant),
    );
  }
}

class _WebRightRail extends StatefulWidget {
  final User user;
  final double? balance;
  final VoidCallback onSearch;
  final VoidCallback onMarket;
  final VoidCallback onNews;
  final VoidCallback onProfile;

  const _WebRightRail({
    required this.user,
    required this.balance,
    required this.onSearch,
    required this.onMarket,
    required this.onNews,
    required this.onProfile,
  });

  @override
  State<_WebRightRail> createState() => _WebRightRailState();
}

class _WebRightRailState extends State<_WebRightRail> {
  List<Map<String, dynamic>> _markets = [];
  List<Map<String, dynamic>> _news = [];
  Map<String, dynamic>? _advantage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        AuthApi.marketList(),
        AuthApi.newsList(),
        AuthApi.marketAdvantage(),
      ]);
      if (!mounted) return;
      setState(() {
        _markets = results[0] as List<Map<String, dynamic>>;
        _news = results[1] as List<Map<String, dynamic>>;
        _advantage = results[2] as Map<String, dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final discount = _advantage?['discount_percent'] ?? 0;
    final pro = _advantage?['pro_yearly_price_mrc'];
    final markets = _markets.take(5).toList();
    final news = _news.take(2).toList();
    return Container(
      width: 316,
      color: cs.surface,
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onSearch,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: .55))),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 19, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text('Search MASAREEN',
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _panel(
              context,
              gradient: brandGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR IMPACT ADVANTAGE',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontSize: 9.5,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('$discount% off',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900)),
                  Text(
                      pro == null
                          ? 'Based on verified impact and holdings'
                          : 'Pro yearly ${(pro as num).toInt()} MRC',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .8),
                          fontSize: 11)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _pill('Balance',
                          '${widget.balance?.toStringAsFixed(0) ?? '-'} MRC'),
                      const SizedBox(width: 8),
                      _pill('Role', widget.user.role.toLowerCase()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _heading(context, 'TRENDING MARKETS', 'See all', widget.onMarket),
            const SizedBox(height: 6),
            if (markets.isEmpty)
              _muted(context, 'Market data is loading...')
            else
              ...markets.map((m) => _marketRow(context, m)),
            const SizedBox(height: 18),
            _heading(context, 'VERIFIED NEWSROOM', 'Open', widget.onNews),
            const SizedBox(height: 6),
            if (news.isEmpty)
              _muted(context, 'No published news yet.')
            else
              ...news.map((n) => _newsRow(context, n)),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onProfile,
              child: _panel(
                context,
                child: Row(
                  children: [
                    AppAvatar(
                        name: widget.user.fullName,
                        url: widget.user.avatarUrl,
                        size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                              widget.user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
                'MASAREEN Web 0.4.13  |  one engine, every screen',
                style: TextStyle(
                    fontSize: 9.5,
                    color: cs.onSurfaceVariant.withValues(alpha: .7))),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String title, String action,
      VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(action,
              style: TextStyle(fontSize: 10.5, color: cs.primary)),
        ),
      ],
    );
  }

  Widget _muted(BuildContext context, String text) => Text(text,
      style: TextStyle(
          fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant));

  Widget _panel(BuildContext context,
      {required Widget child, Gradient? gradient}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? cs.surfaceContainerLow : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: gradient == null
                  ? cs.outlineVariant.withValues(alpha: .55)
                  : Colors.transparent)),
      child: child,
    );
  }

  Widget _pill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(20)),
        child: Text('$label $value',
            style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontSize: 9.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _marketRow(BuildContext context, Map<String, dynamic> m) {
    final cs = Theme.of(context).colorScheme;
    final change = (m['change_percent'] as num?)?.toDouble() ?? 0;
    final positive = change >= 0;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onMarket,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9)),
              child: Text((m['symbol'] ?? 'M').toString().split('-').last,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: cs.primary)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((m['name'] ?? '').toString(),
                      textDirection: textDirectionFor((m['name'] ?? '').toString()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text('${(m['price_mrc'] as num).toStringAsFixed(1)} MRC',
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Text('${positive ? '+' : ''}${change.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: positive ? const Color(0xFF0F9D58) : AppColors.warm)),
          ],
        ),
      ),
    );
  }

  Widget _newsRow(BuildContext context, Map<String, dynamic> n) {
    final cs = Theme.of(context).colorScheme;
    final verified = (n['verification_status'] ?? '') == 'VERIFIED';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onNews,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((n['title'] ?? '').toString(),
                textDirection: textDirectionFor((n['title'] ?? '').toString()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(verified ? Icons.verified : Icons.schedule,
                    size: 12,
                    color: verified ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                      '${n['outlet_name'] ?? 'Newsroom'}  |  ${n['rating_avg'] ?? 0} stars',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9.5, color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
