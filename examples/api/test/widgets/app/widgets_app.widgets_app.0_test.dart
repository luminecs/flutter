import 'package:flutter_api_samples/widgets/app/widgets_app.widgets_app.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WidgetsApp test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.WidgetsAppExampleApp(),
    );

    expect(find.text('Hello World'), findsOneWidget);
  });
}
