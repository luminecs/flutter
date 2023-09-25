import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_ui/overflow.dart' as app;

void main() {
  group('Integration Test', () {
    testWidgets('smoke test', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        expect(find.byType(SizedBox), findsOneWidget);
      });
  });
}