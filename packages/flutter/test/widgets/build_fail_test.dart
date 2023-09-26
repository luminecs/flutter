import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  testWidgets('Build method that returns context.widget throws FlutterError',
      (WidgetTester tester) async {
    // Regression test for: https://github.com/flutter/flutter/issues/25041
    await tester.pumpWidget(
      Builder(builder: (BuildContext context) => context.widget),
    );
    expect(tester.takeException(), isFlutterError);
  });
}
