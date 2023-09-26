import 'package:a11y_assessments/use_cases/use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpsUseCase(WidgetTester tester, UseCase useCase) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (BuildContext context) {
        return useCase.build(context);
      },
    ),
  ));
}
