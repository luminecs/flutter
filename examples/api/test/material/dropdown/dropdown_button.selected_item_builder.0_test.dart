import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/dropdown/dropdown_button.selected_item_builder.0.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Select an item from DropdownButton', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: example.DropdownButtonApp(),
        ),
      ),
    );

    expect(find.text('NYC'), findsOneWidget);

    await tester.tap(find.text('NYC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('San Francisco').last);
    await tester.pumpAndSettle();
    expect(find.text('SF'), findsOneWidget);
  });
}