import 'package:flutter_api_samples/material/progress_indicator/linear_progress_indicator.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Finds LinearProgressIndicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.ProgressIndicatorApp(),
    );

    expect(
      find.bySemanticsLabel('Linear progress indicator'),
      findsOneWidget,
    );

    // Test if LinearProgressIndicator is animating.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isTrue);
  });
}