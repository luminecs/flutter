import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking('Can dispose without keyboard',
      (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester
        .pumpWidget(KeyboardListener(focusNode: focusNode, child: Container()));
    await tester
        .pumpWidget(KeyboardListener(focusNode: focusNode, child: Container()));
    await tester.pumpWidget(Container());
  });

  testWidgetsWithLeakTracking('Fuchsia key event', (WidgetTester tester) async {
    final List<KeyEvent> events = <KeyEvent>[];

    final FocusNode focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: events.add,
        child: Container(),
      ),
    );

    focusNode.requestFocus();
    await tester.idle();

    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.idle();

    expect(events.length, 2);
    expect(events[0], isA<KeyDownEvent>());
    expect(events[0].physicalKey, PhysicalKeyboardKey.metaLeft);
    expect(events[0].logicalKey, LogicalKeyboardKey.metaLeft);

    await tester.pumpWidget(Container());
  }, skip: isBrowser); // [intended] This is a Fuchsia-specific test.

  testWidgetsWithLeakTracking('Web key event', (WidgetTester tester) async {
    final List<KeyEvent> events = <KeyEvent>[];

    final FocusNode focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: events.add,
        child: Container(),
      ),
    );

    focusNode.requestFocus();
    await tester.idle();

    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft);
    await tester.idle();

    expect(events.length, 2);
    expect(events[0], isA<KeyDownEvent>());
    expect(events[0].physicalKey, PhysicalKeyboardKey.metaLeft);
    expect(events[0].logicalKey, LogicalKeyboardKey.metaLeft);

    await tester.pumpWidget(Container());
  });

  testWidgetsWithLeakTracking('Defunct listeners do not receive events',
      (WidgetTester tester) async {
    final List<KeyEvent> events = <KeyEvent>[];

    final FocusNode focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: events.add,
        child: Container(),
      ),
    );

    focusNode.requestFocus();
    await tester.idle();

    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');
    await tester.idle();

    expect(events.length, 2);
    events.clear();

    await tester.pumpWidget(Container());

    await tester.sendKeyEvent(LogicalKeyboardKey.metaLeft, platform: 'fuchsia');

    await tester.idle();

    expect(events.length, 0);

    await tester.pumpWidget(Container());
  });
}
