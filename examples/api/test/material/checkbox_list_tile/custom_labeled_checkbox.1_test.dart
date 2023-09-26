import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/checkbox_list_tile/custom_labeled_checkbox.1.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tapping LabeledCheckbox toggles the checkbox',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.LabeledCheckboxApp(),
    );

    // Checkbox is initially unchecked.
    Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isFalse);

    // Tap the LabeledCheckBoxApp to toggle the checkbox.
    await tester.tap(find.byType(example.LabeledCheckbox));
    await tester.pumpAndSettle();

    // Checkbox is now checked.
    checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });
}
