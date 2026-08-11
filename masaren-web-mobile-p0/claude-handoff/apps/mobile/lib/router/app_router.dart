import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:masaren/di/injection.dart';
import 'package:masaren/services/api_service.dart';
import 'package:masaren/features/landing/screens/landing_screen.dart';
import 'package:masaren/features/auth/screens/login_screen.dart';
import 'package:masaren/features/auth/screens/register_screen.dart';
import 'package:masaren/features/dashboard/screens/dashboard_screen.dart';
import 'package:masaren/features/tasks/screens/task_list_screen.dart';
import 'package:masaren/features/tasks/screens/task_detail_screen.dart';
import 'package:masaren/features/evidence/screens/evidence_capture_screen.dart';
import 'package:masaren/features/passport/screens/impact_passport_screen.dart';
import 'package:masaren/features/opportunities/screens/opportunities_screen.dart';
import 'package:masaren/features/profile/screens/profile_screen.dart';
import 'package:masaren/features/admin/screens/admin_screen.dart';
import 'package:masaren/features/collaborate/screens/collaborate_screen.dart';
import 'package:masaren/features/wallet/screens/wallet_screen.dart';
import 'package:masaren/features/ads/screens/ads_screen.dart';
import 'package:masaren/features/payments/screens/payments_screen.dart';
import 'package:masaren/features/admin/screens/admin_revenue_screen.dart';
import 'package:masaren/features/shell/app_shell.dart';
import 'package:masaren/features/splash/screens/splash_screen.dart';
import 'package:masaren/features/onboarding/screens/onboarding_screen.dart';
import 'package:masaren/features/settings/screens/settings_screen.dart';
import 'package:masaren/features/settings/screens/ui_log_screen.dart';
import 'package:masaren/core/logging/ui_logger.dart';

/// Routes reachable without a session. Everything else requires a valid
/// access token -- deep links (push notifications, shared URLs, restored
/// app state) previously skipped straight to protected screens because
/// only SplashScreen's one-time check gated normal cold-start navigation.
const _publicPaths = <String>{'/', '/onboarding', '/landing', '/login', '/register'};

/// Screens that additionally require an admin/super-admin role.
const _adminPaths = <String>{'/admin', '/admin/revenue'};

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    observers: [UiNavObserver()],
    // Re-evaluates `redirect` whenever a session expires mid-use (e.g. the
    // refresh token was rejected -- see ApiService.sessionExpired).
    refreshListenable: getIt<ApiService>().sessionExpired,
    redirect: (context, state) async {
      final path = state.matchedLocation;
      if (_publicPaths.contains(path)) return null;

      final token = await getIt<FlutterSecureStorage>().read(key: 'access_token');
      if (token == null || token.isEmpty) {
        return '/login';
      }

      if (_adminPaths.contains(path)) {
        final role = await getIt<FlutterSecureStorage>().read(key: 'user_role');
        if (role != 'ADMIN' && role != 'SUPER_ADMIN') {
          return '/dashboard';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/',               builder: (c,s) => const SplashScreen()),
      GoRoute(path: '/onboarding',     builder: (c,s) => const OnboardingScreen()),
      GoRoute(path: '/landing',        builder: (c,s) => const LandingScreen()),
      GoRoute(path: '/login',          builder: (c,s) => const LoginScreen()),
      GoRoute(path: '/register',       builder: (c,s) => const RegisterScreen()),
      GoRoute(path: '/home',           builder: (c,s) => const AppShell()),
      GoRoute(path: '/settings',       builder: (c,s) => const SettingsScreen()),
      GoRoute(path: '/log',            builder: (c,s) => const UiLogScreen()),
      GoRoute(path: '/dashboard',      builder: (c,s) => const DashboardScreen()),
      GoRoute(path: '/programs',       builder: (c,s) => const DashboardScreen()),
      GoRoute(path: '/tasks',          builder: (c,s) => const TaskListScreen(), routes: [
        GoRoute(path: 'detail',        builder: (c,s) => TaskDetailScreen(task: s.extra as Map<String, dynamic>?)),
      ]),
      GoRoute(path: '/evidence',       builder: (c,s) => const EvidenceCaptureScreen()),
      GoRoute(path: '/passport',       builder: (c,s) => const ImpactPassportScreen()),
      GoRoute(path: '/opportunities',  builder: (c,s) => const OpportunitiesScreen()),
      GoRoute(path: '/profile',        builder: (c,s) => const ProfileScreen()),
      GoRoute(path: '/admin',          builder: (c,s) => const AdminScreen()),
      GoRoute(path: '/collaborate',    builder: (c,s) => const CollaborateScreen()),
      GoRoute(path: '/wallet',         builder: (c,s) => const WalletScreen()),
      GoRoute(path: '/ads',            builder: (c,s) => const AdsScreen()),
      GoRoute(path: '/payments',       builder: (c,s) => const PaymentsScreen()),
      GoRoute(path: '/admin/revenue',  builder: (c,s) => const AdminRevenueScreen()),
    ],
  );
}

/// Logs every route change to the UI event log for debugging / E2E forensics.
class UiNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    UiLogger.instance.nav(route.settings.name ?? route.toString());
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    UiLogger.instance.nav('pop -> ${previousRoute?.settings.name ?? '?'}');
  }
}



