import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_api_samples/ui/text/font_feature.font_feature_swash.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows font features', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: example.ExampleWidget(),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    expect((tester.widget(find.byType(Text).first) as Text).style!.fontFamily,
        equals('BioRhyme Expanded'));
    expect(
      (tester.widget(find.byType(Text).first) as Text).style!.fontFeatures,
      equals(const <FontFeature>[FontFeature.swash()]),
    );
  });
}
