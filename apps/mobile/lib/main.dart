import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_links/app_links.dart';
import 'package:masaren/shell/home_shell.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/theme_provider.dart';
import 'package:masaren/services/notification_service.dart';
import 'package:masaren/services/polling_service.dart';
import 'package:masaren/services/video_playback.dart';
import 'package:masaren/screens/splash_screen.dart';
import 'package:masaren/screens/onboarding_screen.dart';
import 'package:masaren/screens/login_screen.dart';
import 'package:masaren/screens/register_screen.dart';
import 'package:masaren/services/app_link_router.dart';
import 'package:masaren/l10n.dart';

const _tokenKey = 'masaren_jwt';
const _onboardingKey = 'masaren_onboarded';
const _localeKey = 'masaren_locale';

const _secureStorage = FlutterSecureStorage();
final _navigatorKey = AppLinkRouter.navigatorKey;

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
  FlutterError.onError =
      (details) => debugPrint('FlutterError: ${details.exception}');
  ErrorWidget.builder = (details) => Material(
        color: Colors.transparent,
        child: Center(
            child: Text(details.exception.toString(),
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center)),
      );
  runZonedGuarded(() => runApp(const MasarenApp()),
      (error, stack) => debugPrint('Uncaught: $error'));
}

class MasarenApp extends StatefulWidget {
  const MasarenApp({super.key});
  @override
  State<MasarenApp> createState() => _MasarenAppState();
}

class _MasarenAppState extends State<MasarenApp>
    with WidgetsBindingObserver {
  final ThemeProvider _theme = ThemeProvider();
  _AppPhase _phase = _AppPhase.splash;
  Locale _locale = const Locale('ar');
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VideoPlaybackController.instance.init();
    _loadLocale();
    _initAuthLinks();
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      VideoPlaybackController.instance.pauseAll();
    }
  }

  Future<void> _initAuthLinks() async {
    _linkSub = _appLinks.uriLinkStream.listen(_handleAuthLink, onError: (_) {});
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleAuthLink(initial);
    } catch (_) {}
  }

  Future<void> _handleAuthLink(Uri uri) async {
    if (uri.scheme != 'masaren' || uri.host != 'auth') return;
    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      api.setToken(token);
      try {
        final me = await AuthApi.me();
        setSession(token, me);
      } catch (_) {
        api.setToken(null);
        await _deleteToken();
        if (mounted) setState(() => _phase = _AppPhase.login);
      }
      return;
    }
    if (uri.path == '/verified' && api.token != null) {
      try {
        final me = await AuthApi.me();
        setSession(api.token!, me);
      } catch (_) {}
    }
  }

  Future<void> _handleNotificationTap(String? payload) async {
    await AppLinkRouter.handle(payload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? 'ar';
    if (mounted) setState(() => _locale = Locale(code));
  }

  void toggleLocale() async {
    final next = _locale.languageCode == 'en' ? 'ar' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, next);
    if (mounted) setState(() => _locale = Locale(next));
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(_onboardingKey) ?? false;
    if (!onboarded) {
      setState(() => _phase = _AppPhase.onboarding);
      return;
    }

    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      api.setToken(token);
      try {
        final me = await AuthApi.me();
        await NotificationService.instance.init(onTap: _handleNotificationTap);
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
    await NotificationService.instance.init(onTap: _handleNotificationTap);
    NotificationService.instance.setBadgeCount(0);
    PollingService.instance.start(user.id);
    if (mounted) setState(() => _phase = _AppPhase.home);
  }

  void logout() async {
    api.setToken(null);
    await _deleteToken();
    PollingService.instance.stop();
    NotificationService.instance.clearBadge();
    NotificationService.instance.cancelAll();
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
          navigatorKey: _navigatorKey,
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
              return MaterialPageRoute(
                  builder: (_) => LoginScreen(onAuthenticated: setSession));
            }
            if (settings.name == '/register') {
              return MaterialPageRoute(
                  builder: (_) => RegisterScreen(onRegistered: setSession));
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
        return const SplashScreen();
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

