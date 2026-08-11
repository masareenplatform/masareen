import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme.dart';
import 'package:masaren/theme_provider.dart';
import 'package:masaren/services/notification_service.dart';
import 'package:masaren/services/polling_service.dart';
import 'package:masaren/screens/splash_screen.dart';
import 'package:masaren/screens/onboarding_screen.dart';
import 'package:masaren/screens/login_screen.dart';
import 'package:masaren/screens/register_screen.dart';
import 'package:masaren/screens/feed_screen.dart';
import 'package:masaren/screens/opportunities_screen.dart';
// programs_screen imported where used (programs tab in HomeShell)
import 'package:masaren/screens/profile_screen.dart';
import 'package:masaren/screens/courses_screen.dart';
import 'package:masaren/screens/projects_screen.dart';
import 'package:masaren/screens/verification_screen.dart';
import 'package:masaren/screens/admin_screen.dart';
import 'package:masaren/screens/ads_screen.dart';
import 'package:masaren/screens/wallet_screen.dart';
import 'package:masaren/screens/notifications_screen.dart';
import 'package:masaren/screens/create_post_screen.dart';
import 'package:masaren/widgets.dart';
import 'package:masaren/l10n.dart';

const _tokenKey = 'masaren_jwt';
const _onboardingKey = 'masaren_onboarded';
const _localeKey = 'masaren_locale';

const _secureStorage = FlutterSecureStorage();

Future<String?> _readToken() async {
  final token = await _secureStorage.read(key: _tokenKey);
  if (token != null && token.isNotEmpty) return token;
  final prefs = await SharedPreferences.getInstance();
  final legacy = prefs.getString(_tokenKey);
  if (legacy != null && legacy.isNotEmpty) {
    await _secureStorage.write(key: _tokenKey, value: legacy);
    await prefs.remove(_tokenKey);
    return legacy;
  }
  return null;
}

Future<void> _writeToken(String? token) async {
  if (token == null) {
    await _secureStorage.delete(key: _tokenKey);
  } else {
    await _secureStorage.write(key: _tokenKey, value: token);
  }
}

Future<void> _deleteToken() async {
  await _secureStorage.delete(key: _tokenKey);
}

void main() {
  FlutterError.onError = (details) => debugPrint('FlutterError: ${details.exception}');
  ErrorWidget.builder = (details) => Material(
    color: Colors.transparent,
    child: Center(child: Text(details.exception.toString(),
        style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center)),
  );
  runZonedGuarded(() => runApp(const MasarenApp()), (error, stack) => debugPrint('Uncaught: $error'));
}

class MasarenApp extends StatefulWidget {
  const MasarenApp({super.key});
  @override
  State<MasarenApp> createState() => _MasarenAppState();
}

class _MasarenAppState extends State<MasarenApp> {
  final ThemeProvider _theme = ThemeProvider();
  _AppPhase _phase = _AppPhase.splash;
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLocale();
    _bootstrap();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? 'en';
    if (mounted) setState(() => _locale = Locale(code));
  }

  void toggleLocale() async {
    final next = _locale.languageCode == 'en' ? 'ar' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, next);
    if (mounted) setState(() => _locale = Locale(next));
  }

  Future<void> _bootstrap() async {
    await _requestPermissions();
    // Splash is showing, wait then check onboarding/auth
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(_onboardingKey) ?? false;
    if (!onboarded) {
      setState(() => _phase = _AppPhase.onboarding);
      return;
    }

    await _checkAuth();
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.location,
        Permission.camera,
        Permission.microphone,
        Permission.photos,
      ].request();
    } catch (_) {}
    // Request notification permission separately so failures are visible
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  Future<void> _checkAuth() async {
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      api.setToken(token);
      try {
        final me = await AuthApi.me();
        await NotificationService.instance.init();
        PollingService.instance.start(me.id);
        if (mounted) setState(() => _phase = _AppPhase.home);
        return;
      } catch (_) {
        api.setToken(null);
        await _deleteToken();
      }
    }
    if (mounted) setState(() => _phase = _AppPhase.login);
  }

  void setSession(String token, User user) async {
    api.setToken(token);
    await _writeToken(token);
    await NotificationService.instance.init();
    NotificationService.instance.setBadgeCount(0);
    PollingService.instance.start(user.id);
    if (mounted) setState(() => _phase = _AppPhase.home);
  }

  void logout() async {
    api.setToken(null);
    await _deleteToken();
    PollingService.instance.stop();
    NotificationService.instance.clearBadge();
    if (mounted) setState(() => _phase = _AppPhase.login);
  }

  void _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    await _checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: _theme,
      child: Consumer<ThemeProvider>(
        builder: (ctx, themeProv, _) => MaterialApp(
          title: 'MASAREEN',
          debugShowCheckedModeBanner: false,
          theme: themeProv.theme,
          themeMode: themeProv.dark ? ThemeMode.dark : ThemeMode.light,
          locale: _locale,
          localizationsDelegates: const [
            MasarenLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: _buildPhase(themeProv),
          onGenerateRoute: (settings) {
            if (settings.name == '/login') {
              return MaterialPageRoute(builder: (_) => LoginScreen(onAuthenticated: setSession));
            }
            if (settings.name == '/register') {
              return MaterialPageRoute(builder: (_) => RegisterScreen(onRegistered: setSession));
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildPhase(ThemeProvider themeProv) {
    switch (_phase) {
      case _AppPhase.splash:
        return SplashScreen(onComplete: () {});
      case _AppPhase.onboarding:
        return OnboardingScreen(onComplete: _onOnboardingComplete);
      case _AppPhase.login:
        return LoginScreen(onAuthenticated: setSession);
      case _AppPhase.home:
        return HomeShell(
          onLogout: logout,
          onToggleTheme: () => themeProv.toggle(),
          onToggleLocale: toggleLocale,
        );
    }
  }
}

enum _AppPhase { splash, onboarding, login, home }

PageRouteBuilder<T> _route<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1, 0);
        const end = Offset.zero;
        const curve = Curves.easeOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );

class HomeShell extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onToggleLocale;
  const HomeShell({super.key, required this.onLogout, this.onToggleTheme, this.onToggleLocale});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  User? _user;
  bool _loadingUser = true;
  int _unreadNotifications = 0;
  final _feedKey = GlobalKey<FeedScreenState>();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _startNotificationPolling();
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
      _user = await AuthApi.me();
    } catch (_) {}
    if (mounted) setState(() => _loadingUser = false);
  }

  void _showCreateSheet() {
    if (_user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(user: _user!),
    );
  }

  void _showMoreSheet() {
    final cs = Theme.of(context).colorScheme;
    final u = _user;
    final loc = MasarenLocalizations.of;
    final items = [
      _MoreItem(Icons.notifications_outlined, loc(context, 'nav.notifications'), () {
        if (_user != null) Navigator.of(context).push(_route(NotificationsScreen(userId: _user!.id)));
      }, badge: _unreadNotifications),
      _MoreItem(Icons.school_outlined, loc(context, 'nav.courses'), () => Navigator.of(context).push(_route(CoursesScreen(user: u!)))),
      _MoreItem(Icons.handshake_outlined, loc(context, 'nav.projects'), () => Navigator.of(context).push(_route(ProjectsScreen(user: u!)))),
      _MoreItem(Icons.verified_user_outlined, loc(context, 'nav.verification'), () => Navigator.of(context).push(_route(VerificationScreen(user: u!)))),
      _MoreItem(Icons.account_balance_wallet_outlined, loc(context, 'nav.wallet'), () => Navigator.of(context).push(_route(WalletScreen(user: u!)))),
      _MoreItem(Icons.campaign_outlined, loc(context, 'nav.ads'), () => Navigator.of(context).push(_route(AdsScreen(user: u!)))),
      _MoreItem(Icons.admin_panel_settings_outlined, loc(context, 'nav.admin'), () => Navigator.of(context).push(_route(AdminScreen(user: u!)))),
       _MoreItem(
          Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          loc(context, 'nav.theme'), widget.onToggleTheme ?? () {},
        ),
        _MoreItem(
          Icons.language_outlined,
          Localizations.localeOf(context).languageCode == 'en' ? 'العربية' : 'English',
          () {
            Navigator.pop(context);
            widget.onToggleLocale?.call();
          },
        ),
        _MoreItem(Icons.logout_outlined, loc(context, 'nav.signout'), widget.onLogout),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                if (u != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        AppAvatar(name: u.fullName, url: u.avatarUrl, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.fullName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                              Text(u.email, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Divider(height: 1, color: cs.outlineVariant),
                ...items.map((item) => ListTile(
                      leading: Icon(item.icon,
                          color: item.icon == Icons.logout_outlined ? AppColors.warm : cs.onSurfaceVariant, size: 22),
                      title: Row(children: [
                        Expanded(child: Text(item.label, style: TextStyle(
                          fontSize: 14, color: item.icon == Icons.logout_outlined ? AppColors.warm : cs.onSurface,
                        ))),
                        if (item.badge > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.warm, borderRadius: BorderRadius.circular(10)),
                            child: Text('${item.badge}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                      ]),
                      onTap: () { Navigator.pop(ctx); item.onTap(); },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      visualDensity: const VisualDensity(vertical: -1),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_user == null) return const Center(child: CircularProgressIndicator());
    switch (_tab) {
      case 0:
        return FeedScreen(
          key: _feedKey,
          user: _user!,
          onNotifications: () => Navigator.of(context).push(_route(NotificationsScreen(userId: _user!.id))),
          onMore: _showMoreSheet,
        );
      case 1:
        return OpportunitiesScreen(user: _user!);
      case 2:
        return CoursesScreen(user: _user!);
      case 3:
        return ProfileScreen(
          user: _user!,
          onLogout: widget.onLogout,
          onToggleTheme: widget.onToggleTheme,
        );
      default:
        return FeedScreen(
          key: _feedKey,
          user: _user!,
          onNotifications: () => Navigator.of(context).push(_route(NotificationsScreen(userId: _user!.id))),
          onMore: _showMoreSheet,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loadingUser) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            if (i == 4) _showMoreSheet();
            else if (i == 2) _showCreateSheet();
            else if (i != _tab) setState(() => _tab = i);
          },
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          indicatorColor: cs.primaryContainer,
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          destinations: [
            NavigationDestination(icon: Icon(Icons.home_outlined, color: cs.onSurfaceVariant), selectedIcon: Icon(Icons.home, color: cs.primary), label: ''),
            NavigationDestination(icon: Icon(Icons.explore_outlined, color: cs.onSurfaceVariant), selectedIcon: Icon(Icons.explore, color: cs.primary), label: ''),
            NavigationDestination(
              icon: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              selectedIcon: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              label: '',
            ),
            NavigationDestination(icon: Icon(Icons.school_outlined, color: cs.onSurfaceVariant), selectedIcon: Icon(Icons.school, color: cs.primary), label: ''),
            NavigationDestination(icon: Icon(Icons.menu_outlined, color: cs.onSurfaceVariant), selectedIcon: Icon(Icons.menu, color: cs.primary), label: ''),
          ],
        ),
      ),
    );
  }
}

class _CreatePostSheet extends StatelessWidget {
  final User user;
  const _CreatePostSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = MasarenLocalizations.of;
    final types = [
      _PostType('story', loc(context, 'post.story'), '', Icons.auto_stories, cs.primary),
      _PostType('recognition', loc(context, 'post.recognition'), '', Icons.emoji_events, cs.secondary),
      _PostType('news', loc(context, 'post.news'), '', Icons.newspaper, const Color(0xFFE67C00)),
      _PostType('video', loc(context, 'post.video'), '', Icons.videocam, cs.tertiary),
      _PostType('evidence', loc(context, 'post.evidence'), '', Icons.eco, const Color(0xFF0F9D58)),
      _PostType('announcement', loc(context, 'post.announcement'), '', Icons.campaign, const Color(0xFFF4B400)),
      _PostType('synergy', loc(context, 'post.synergy'), '', Icons.handshake, const Color(0xFF8E24AA)),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
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
                      Text(user.fullName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                      Text(loc(context, 'action.createPost'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
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
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: types.length,
              itemBuilder: (_, i) {
                final t = types[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    final capturedContext = context;
                    Navigator.of(context).push<bool>(MaterialPageRoute(
                        builder: (_) => CreatePostScreen(user: user, initialKind: t.kind))).then((result) {
                      if (result == true) {
                        // Refresh feed
                        final appState = capturedContext.findAncestorStateOfType<_HomeShellState>();
                        appState?._feedKey.currentState?.refresh();
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.color.withValues(alpha: 0.15)),
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
                          Text(t.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(t.desc, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
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

class _PostType {
  final String kind;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  const _PostType(this.kind, this.label, this.desc, this.icon, this.color);
}

class _MoreItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  const _MoreItem(this.icon, this.label, this.onTap, {this.badge = 0});
}
