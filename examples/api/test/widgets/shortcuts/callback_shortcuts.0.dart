import 'package:flutter/services.dart';
import 'package:flutter_api_samples/widgets/shortcuts/callback_shortcuts.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CallbackShortcutsApp increments and decrements',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.CallbackShortcutsApp(),
    );

    expect(find.text('count: 0'), findsOneWidget);

    // Increment the counter.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(find.text('count: 1'), findsOneWidget);

    // Decrement the counter.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.text('count: 0'), findsOneWidget);
  });
}
