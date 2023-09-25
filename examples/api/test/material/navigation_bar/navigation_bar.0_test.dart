import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/navigation_bar/navigation_bar.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Navigation bar updates destination on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.NavigationBarApp(),
    );
    final NavigationBar navigationBarWidget = tester.firstWidget(find.byType(NavigationBar));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    final Badge notificationBadge = tester.firstWidget(find.ancestor(
      of: find.byIcon(Icons.notifications_sharp),
      matching: find.byType(Badge),
    ));
    expect(notificationBadge.label, null);

    final Badge messagesBadge = tester.firstWidget(find.ancestor(
      of: find.byIcon(Icons.messenger_sharp),
      matching: find.byType(Badge),
    ));
    expect(messagesBadge.label, isNotNull);

    expect(navigationBarWidget.selectedIndex, 0);
    expect(find.text('Home page'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('This is a notification'), findsNWidgets(2));

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Hi!'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}