import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/progress_indicator/circular_progress_indicator.1.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Finds CircularProgressIndicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.ProgressIndicatorApp(),
    );

    expect(
      find.bySemanticsLabel('Circular progress indicator').first,
      findsOneWidget,
    );

    // Test if CircularProgressIndicator is animating.
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);

    // Test determinate mode button.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
  });
}
