import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking(
      'ListView.builder() fixed itemExtent, scroll to end, append, scroll',
      (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/9506

    Widget buildFrame(int itemCount) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ListView.builder(
          dragStartBehavior: DragStartBehavior.down,
          itemExtent: 200.0,
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) => Text('item $index'),
        ),
      );
    }

    await tester.pumpWidget(buildFrame(3));
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget);

    await tester.pumpWidget(buildFrame(4));
    expect(find.text('item 3'), findsNothing);
    final TestGesture gesture =
        await tester.startGesture(const Offset(0.0, 300.0));
    await gesture.moveBy(const Offset(0.0, -200.0));
    await tester.pumpAndSettle();
    expect(find.text('item 3'), findsOneWidget);
  });

  testWidgetsWithLeakTracking(
      'ListView.builder() fixed itemExtent, scroll to end, append, scroll',
      (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/9506

    Widget buildFrame(int itemCount) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ListView.builder(
          dragStartBehavior: DragStartBehavior.down,
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            return SizedBox(
              height: 200.0,
              child: Text('item $index'),
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildFrame(3));
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget);

    await tester.pumpWidget(buildFrame(4));
    final TestGesture gesture =
        await tester.startGesture(const Offset(0.0, 300.0));
    await gesture.moveBy(const Offset(0.0, -200.0));
    await tester.pumpAndSettle();
    expect(find.text('item 3'), findsOneWidget);
  });
}
