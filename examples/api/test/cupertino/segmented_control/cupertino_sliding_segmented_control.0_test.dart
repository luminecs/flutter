import 'package:flutter_api_samples/cupertino/segmented_control/cupertino_sliding_segmented_control.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Can change a selected segmented control',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.SegmentedControlApp(),
    );

    expect(find.text('Selected Segment: midnight'), findsOneWidget);
    await tester.tap(find.text('Cerulean'));
    await tester.pumpAndSettle();
    expect(find.text('Selected Segment: cerulean'), findsOneWidget);
  });
}
