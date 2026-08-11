import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    observers: [UiNavObserver()],
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



