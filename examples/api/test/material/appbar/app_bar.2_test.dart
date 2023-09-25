import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/app_bar/app_bar.2.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Appbar and actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.AppBarApp(),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Action 1'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Action 2'), findsOneWidget);
  });
}