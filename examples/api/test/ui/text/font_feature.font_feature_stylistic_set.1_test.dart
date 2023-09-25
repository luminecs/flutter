
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_api_samples/ui/text/font_feature.font_feature_stylistic_set.1.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows font features', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: example.ExampleWidget(),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    expect((tester.widget(find.byType(Text).first) as Text).style!.fontFamily, equals('Piazzolla'));
    expect(
      (tester.widget(find.byType(Text).first) as Text).style!.fontFeatures,
      equals(
        <FontFeature>[
          FontFeature.stylisticSet(1),
          FontFeature.stylisticSet(2),
        ],
      ),
    );
  });
}