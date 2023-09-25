
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsWithLeakTracking('can press', (WidgetTester tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextSelectionToolbarButton(
            child: const Text('Tap me'),
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    expect(pressed, false);

    await tester.tap(find.byType(CupertinoTextSelectionToolbarButton));
    expect(pressed, true);
  });

  testWidgetsWithLeakTracking('background darkens when pressed', (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoTextSelectionToolbarButton(
            child: const Text('Tap me'),
            onPressed: () { },
          ),
        ),
      ),
    );

    // Original with transparent background.
    DecoratedBox decoratedBox = tester.widget(find.descendant(
      of: find.byType(CupertinoButton),
      matching: find.byType(DecoratedBox),
    ));
    BoxDecoration boxDecoration = decoratedBox.decoration as BoxDecoration;
    expect(boxDecoration.color, const Color(0x00000000));

    // Make a "down" gesture on the button.
    final Offset center = tester.getCenter(find.byType(CupertinoTextSelectionToolbarButton));
    final TestGesture gesture = await tester.startGesture(center);
    await tester.pumpAndSettle();

    // When pressed, the background darkens.
    decoratedBox = tester.widget(find.descendant(
      of: find.byType(CupertinoTextSelectionToolbarButton),
      matching: find.byType(DecoratedBox),
    ));
    boxDecoration = decoratedBox.decoration as BoxDecoration;
    expect(boxDecoration.color!.value, const Color(0x10000000).value);

    // Release the down gesture.
    await gesture.up();
    await tester.pumpAndSettle();

    // Color is back to transparent.
    decoratedBox = tester.widget(find.descendant(
      of: find.byType(CupertinoTextSelectionToolbarButton),
      matching: find.byType(DecoratedBox),
    ));
    boxDecoration = decoratedBox.decoration as BoxDecoration;
    expect(boxDecoration.color, const Color(0x00000000));
  });

  testWidgetsWithLeakTracking('passing null to onPressed disables the button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CupertinoTextSelectionToolbarButton(
            child: Text('Tap me'),
          ),
        ),
      ),
    );

    expect(find.byType(CupertinoButton), findsOneWidget);
    final CupertinoButton button = tester.widget(find.byType(CupertinoButton));
    expect(button.enabled, isFalse);
  });
}