import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/navigation_drawer/navigation_drawer.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Navigation bar updates destination on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.NavigationDrawerApp(),
    );

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    final NavigationDrawer navigationDrawerWidget =
        tester.firstWidget(find.byType(NavigationDrawer));

    expect(find.text('Messages'), findsNWidgets(2));
    expect(find.text('Profile'), findsNWidgets(2));
    expect(find.text('Settings'), findsNWidgets(2));

    expect(navigationDrawerWidget.selectedIndex, 0);
    expect(find.text('Page Index = 0'), findsOneWidget);

    await tester.tap(find.ancestor(
        of: find.text('Profile'), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(find.text('Page Index = 1'), findsOneWidget);

    await tester.tap(find.ancestor(
        of: find.text('Settings'), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(find.text('Page Index = 2'), findsOneWidget);
  });
}
