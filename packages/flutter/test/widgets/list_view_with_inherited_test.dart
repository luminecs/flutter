
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

List<String> items = <String>[
  'one',
  'two',
  'three',
  'four',
  'five',
];

Widget buildCard(BuildContext context, int index) {
  // We still want to populate the list with items beyond the list
  // provided.
  if (index >= items.length) {
    return const SizedBox(height: 100);
  }

  return SizedBox(
    key: ValueKey<String>(items[index]),
    height: 100.0,
    child: DefaultTextStyle(
      style: TextStyle(fontSize: 2.0 + items.length.toDouble()),
      child: Text(items[index], textDirection: TextDirection.ltr),
    ),
  );
}

Widget buildFrame() {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ListView.builder(
      itemBuilder: buildCard,
    ),
  );
}

void main() {
  testWidgetsWithLeakTracking('ListView is a build function (smoketest)', (WidgetTester tester) async {
    await tester.pumpWidget(buildFrame());
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsOneWidget);
    expect(find.text('four'), findsOneWidget);
    items.removeAt(2);
    await tester.pumpWidget(buildFrame());
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsNothing);
    expect(find.text('four'), findsOneWidget);
  });
}