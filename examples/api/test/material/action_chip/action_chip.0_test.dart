
import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/action_chip/action_chip.0.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ActionChip updates avatar when tapped', (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.ChipApp(),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}