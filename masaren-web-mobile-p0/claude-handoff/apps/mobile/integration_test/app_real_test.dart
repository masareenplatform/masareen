// MASAREN Mobile — REAL backend end-to-end integration test.
//
// Runs on the Android emulator (emulator-5554) against the SAME combined
// backend the web app was tested against (host :8080, reached from the
// emulator at 10.0.2.2:8080/api/v1 — the app's default Dio baseUrl).
//
// The test credentials are injected at build time:
//   flutter test integration_test/app_real_test.dart -d emulator-5554 \
//     --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...
//
// (A fresh E2E user is created + DB-verified from the host before running —
// see testing/mobile/run_real_e2e.ps1.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:masaren/main.dart' as app;

const String e2eEmail = String.fromEnvironment('E2E_EMAIL', defaultValue: '');
const String e2ePassword = String.fromEnvironment('E2E_PASSWORD', defaultValue: '');

/// Render a few frames without requiring animations to fully settle (some
/// screens may keep a spinner while a slow endpoint responds).
Future<void> _render(tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

Future<void> _login(tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 4));
  expect(find.text('Sign In'), findsOneWidget, reason: 'login screen visible');

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), e2eEmail);
  await tester.enterText(fields.at(1), e2ePassword);
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // Social shell is up: bottom navigation present, brand wordmark visible.
  expect(find.byType(NavigationBar), findsOneWidget, reason: 'app shell (NavigationBar) present');
  expect(find.text('MASAREEN'), findsWidgets, reason: 'brand wordmark present');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('e2e (real backend): login succeeds and social shell renders', (tester) async {
    expect(e2eEmail.isNotEmpty && e2ePassword.isNotEmpty, isTrue,
        reason: 'E2E_EMAIL / E2E_PASSWORD must be provided via --dart-define');
    await _login(tester);
    // Home tab content rendered without a crash.
    expect(tester.takeException(), isNull);
  });

  testWidgets('e2e (real backend): compose a post (optimistic) appears in feed', (tester) async {
    await _login(tester);
    // Open the compose FAB (only shown on the Home tab).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Create a post'), findsOneWidget, reason: 'compose sheet opened');

    final caption = 'Flutter E2E real-backend post ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byType(TextField).first, caption);
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text(caption), findsWidgets, reason: 'new post rendered at top of feed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('e2e (real backend): all 5 bottom-nav tabs render without error', (tester) async {
    await _login(tester);
    final tabs = ['Explore', 'Tasks', 'Alerts', 'Profile', 'Home'];
    for (final label in tabs) {
      final dest = find.ancestor(
        of: find.text(label),
        matching: find.byType(NavigationDestination),
      );
      await tester.tap(dest);
      await _render(tester);
      expect(tester.takeException(), isNull, reason: 'no exception on tab "$label"');
    }
  });

  testWidgets('e2e (real backend): overflow menu surfaces open without error', (tester) async {
    await _login(tester);
    const items = [
      'Dashboard', 'Programs', 'Evidence', 'Impact Passport', 'Collaborate',
      'MASAREN Coin', 'Ads Manager', 'Payments', 'Platform Revenue & Fees',
    ];
    for (final label in items) {
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text(label));
      await _render(tester);
      expect(tester.takeException(), isNull, reason: 'no exception opening "$label"');
      // Menu should have navigated away (sheet closed).
      expect(find.text(label), findsNothing, reason: 'menu closed after opening "$label"');
      // Return to the shell.
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  });
}
