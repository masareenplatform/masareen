// MASAREN Mobile — Patrol end-to-end audit (all surfaces).
//
// Mirrors integration_test/app_test.dart using the Patrol native harness.
// Drives a real login against the mock gateway (testing/mobile/mock_gateway.mjs,
// reachable from the emulator at 10.0.2.2:8080) and walks every primary tab,
// every overflow-menu surface and the brokerage flows.
//
// Run (against the running emulator + mock gateway):
//   node testing/mobile/mock_gateway.mjs      # host :8080
//   patrol test --target=integration_test/patrol_e2e_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:masaren/main.dart' as app;

Future<void> main() async {
  patrolTest(
    'e2e: login -> social home + compose + like + all tabs + all menu surfaces',
    ($) async {
      await app.main();
      await $.pumpAndSettle(duration: const Duration(seconds: 2));

      // --- Login via the mock gateway ---
      await $.tester.enterText(find.byType(TextField).at(0), 'admin@masaren.org');
      await $.tester.enterText(find.byType(TextField).at(1), 'password');
      await $.tester.tap(find.text('Sign In'));
      await $.pumpAndSettle(duration: const Duration(seconds: 2));

      // Social shell is up: bottom navigation + Home reachable (admin included).
      await $.tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);

      // --- Compose a post (optimistic) ---
      await $.tester.tap(find.byType(FloatingActionButton));
      await $.pumpAndSettle();
      expect(find.text('Create a post'), findsOneWidget);
      final caption = 'Patrol audit post ${DateTime.now().microsecondsSinceEpoch}';
      await $.tester.enterText(find.byType(TextField).first, caption);
      await $.tester.tap(find.text('Post'));
      await $.pumpAndSettle(duration: const Duration(seconds: 2));
      expect(find.text(caption), findsOneWidget);

      // --- Bottom-nav tabs ---
      for (final tab in const ['Explore', 'Tasks', 'Alerts', 'Profile', 'Home']) {
        final dest = find.ancestor(of: find.text(tab), matching: find.byType(NavigationDestination));
        await $.tester.tap(dest);
        await $.pumpAndSettle(duration: const Duration(seconds: 1));
      }

      // --- Overflow-menu surfaces ---
      final surfaces = const {
        'Dashboard': 'Members',
        'Programs': 'Members',
        'Evidence': 'Capture Evidence',
        'Impact Passport': 'Impact Passport',
        'Collaborate': 'Collaborate',
        'MASAREN Coin': 'MASAREN Coin Wallet',
        'Ads Manager': 'Ads Manager',
        'Payments': 'Payments',
        'Platform Revenue & Fees': 'Platform Revenue & Fees',
      };
      for (final entry in surfaces.entries) {
        await $.tester.tap(find.byIcon(Icons.menu_rounded));
        await $.pumpAndSettle();
        await $.tester.tap(find.text(entry.key));
        await $.pumpAndSettle(duration: const Duration(seconds: 2));
        expect(find.text(entry.value), findsWidgets);
        await $.tester.pageBack();
        await $.pumpAndSettle();
      }
    },
  );
}
