import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Can build widget tree in profile mode with asserts enabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('Hello World')))));

    expect(tester.takeException(), isNull);
  });
}
