import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'semantics_tester.dart';

void main() {
  testWidgetsWithLeakTracking('AbsorbPointers do not block siblings',
      (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () => tapped = true,
            ),
          ),
          const Expanded(
            child: AbsorbPointer(),
          ),
        ],
      ),
    );
    await tester.tap(find.byType(GestureDetector));
    expect(tapped, true);
  });

  group('AbsorbPointer semantics', () {
    testWidgetsWithLeakTracking('does not change semantics when not absorbing',
        (WidgetTester tester) async {
      final UniqueKey key = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: AbsorbPointer(
            absorbing: false,
            child: ElevatedButton(
              key: key,
              onPressed: () {},
              child: const Text('button'),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byKey(key)),
        matchesSemantics(
          label: 'button',
          hasTapAction: true,
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });

    testWidgetsWithLeakTracking(
        'drops semantics when its ignoreSemantics is true',
        (WidgetTester tester) async {
      final SemanticsTester semantics = SemanticsTester(tester);
      final UniqueKey key = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: AbsorbPointer(
            ignoringSemantics: true,
            child: ElevatedButton(
              key: key,
              onPressed: () {},
              child: const Text('button'),
            ),
          ),
        ),
      );
      expect(semantics, isNot(includesNodeWith(label: 'button')));
      semantics.dispose();
    });

    testWidgetsWithLeakTracking('ignores user interactions',
        (WidgetTester tester) async {
      final UniqueKey key = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          home: AbsorbPointer(
            child: ElevatedButton(
              key: key,
              onPressed: () {},
              child: const Text('button'),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byKey(key)),
        // Tap action is blocked.
        matchesSemantics(
          label: 'button',
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });
  });
}
