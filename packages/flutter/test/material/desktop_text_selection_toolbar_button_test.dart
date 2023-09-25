import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithLeakTracking('can press', (WidgetTester tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: DesktopTextSelectionToolbarButton(
            onPressed: () {
              pressed = true;
            },
            child: const Text('Tap me'),
          ),
        ),
      ),
    );

    expect(pressed, false);

    await tester.tap(find.byType(DesktopTextSelectionToolbarButton));
    expect(pressed, true);
  });

  testWidgetsWithLeakTracking('passing null to onPressed disables the button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: DesktopTextSelectionToolbarButton(
            onPressed: null,
            child: Text('Cannot tap me'),
          ),
        ),
      ),
    );

    expect(find.byType(TextButton), findsOneWidget);
    final TextButton button = tester.widget(find.byType(TextButton));
    expect(button.enabled, isFalse);
  });
}