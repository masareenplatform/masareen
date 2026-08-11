// MASAREN Mobile — end-to-end integration audit (runs on the emulator).
//
// Walks the FULL social app against the mock gateway
// (testing/mobile/mock_gateway.mjs, reachable from the emulator at
// 10.0.2.2:8080) and asserts every primary tab, every overflow-menu surface
// and the monetisation/brokerage flows render correctly.
//
// Run:
//   node testing/mobile/mock_gateway.mjs          # host :8080
//   flutter test integration_test/app_test.dart -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:masaren/main.dart' as app;

/// Tap a bottom-navigation tab by its label (Home / Explore / Tasks / Alerts / Profile).
Future<void> _tapTab(tester, String label) async {
  final dest = find.ancestor(of: find.text(label), matching: find.byType(NavigationDestination));
  await tester.tap(dest);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Open the overflow menu and navigate to a secondary surface by its label.
Future<void> _openMenuAndVisit(tester, String label, String expectText) async {
  await tester.tap(find.byIcon(Icons.menu_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text(expectText), findsWidgets, reason: 'expected "$expectText" on $label');
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> _login(tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Sign In'), findsOneWidget);
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'admin@masaren.org');
  await tester.enterText(fields.at(1), 'password');
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  // Social shell is up: bottom navigation present, Home tab reachable.
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.text('Home'), findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('e2e: login -> social home renders (feed + bottom nav)', (tester) async {
    await _login(tester);
    expect(find.text('MASAREN'), findsWidgets); // brand wordmark in the top bar
  });

  testWidgets('e2e: compose a post + like toggle (optimistic, offline-safe)', (tester) async {
    await _login(tester);
    // Open the compose FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Create a post'), findsOneWidget);
    final caption = 'E2E audit post ${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byType(TextField).first, caption);
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // The new post appears at the top of the feed.
    expect(find.text(caption), findsOneWidget);
    // Like it.
    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
  });

  testWidgets('e2e: all bottom-nav tabs render', (tester) async {
    await _login(tester);
    await _tapTab(tester, 'Explore');
    expect(find.text('Opportunities'), findsWidgets);
    await _tapTab(tester, 'Tasks');
    expect(find.text('My Tasks'), findsWidgets);
    await _tapTab(tester, 'Alerts');
    expect(find.text('Alerts'), findsWidgets);
    await _tapTab(tester, 'Profile');
    expect(find.text('Profile'), findsWidgets);
    await _tapTab(tester, 'Home');
    expect(find.text('MASAREN'), findsWidgets);
  });

  testWidgets('e2e: all overflow-menu surfaces render', (tester) async {
    await _login(tester);
    await _openMenuAndVisit(tester, 'Dashboard', 'Members');
    await _openMenuAndVisit(tester, 'Programs', 'Members');
    await _openMenuAndVisit(tester, 'Evidence', 'Capture Evidence');
    await _openMenuAndVisit(tester, 'Impact Passport', 'Impact Passport');
    await _openMenuAndVisit(tester, 'Collaborate', 'Collaborate');
    await _openMenuAndVisit(tester, 'MASAREN Coin', 'MASAREN Coin Wallet');
    await _openMenuAndVisit(tester, 'Ads Manager', 'Ads Manager');
    await _openMenuAndVisit(tester, 'Payments', 'Payments');
    await _openMenuAndVisit(tester, 'Platform Revenue & Fees', 'Platform Revenue & Fees');
  });

  testWidgets('e2e: admin reaches the home feed (no gate)', (tester) async {
    await _login(tester); // admin@masaren.org is ADMIN
    expect(find.text('Home'), findsWidgets);
    await _tapTab(tester, 'Home');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('e2e: wallet convert applies the platform brokerage fee', (tester) async {
    await _login(tester);
    // Navigate into the wallet (no pop back — we act on this screen next).
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MASAREN Coin'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('MASAREN Coin Wallet'), findsWidgets);
    await tester.tap(find.text('Convert (EGP ⇄ MRC)'));
    await tester.pumpAndSettle();
    final fiat = find.byType(TextField);
    await tester.enterText(fiat.first, '100');
    await tester.tap(find.text('Convert'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('Platform fee (brokerage)'), findsOneWidget);
  });
}
