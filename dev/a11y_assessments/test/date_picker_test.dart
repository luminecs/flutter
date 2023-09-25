
import 'package:a11y_assessments/use_cases/date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('date picker can run', (WidgetTester tester) async {
    await pumpsUseCase(tester, DatePickerUseCase());
    expect(find.text('Show Date Picker'), findsOneWidget);

    await tester.tap(find.text('Show Date Picker'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}