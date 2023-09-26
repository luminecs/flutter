import 'package:flutter/material.dart';
import 'package:flutter_api_samples/widgets/scrollbar/raw_scrollbar.desktop.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Can hide default scrollbar on desktop',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.ScrollbarApp(),
    );

    // Two from left list view where scroll configuration is not set.
    // One from right list view where scroll configuration is set.
    expect(find.byType(Scrollbar), findsNWidgets(3));
  });
}
