import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masaren/widgets/animations.dart';

void main() {
  testWidgets('CountUpNumber renders the target as text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: CountUpNumber(target: 4))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('Instance of'), findsNothing);
  });

  testWidgets('CountUpNumber supports prefix and suffix', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: Center(
              child: CountUpNumber(target: 12, prefix: '+', suffix: ' MRC'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('+12 MRC'), findsOneWidget);
    expect(find.textContaining('Instance of'), findsNothing);
  });
}


