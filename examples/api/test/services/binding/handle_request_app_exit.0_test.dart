import 'package:flutter_api_samples/services/binding/handle_request_app_exit.0.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Application Exit example', (WidgetTester tester) async {
    await tester.pumpWidget(
      const example.ApplicationExitExample(),
    );

    expect(find.text('No exit requested yet'), findsOneWidget);
    expect(find.text('Do Not Allow Exit'), findsOneWidget);
    expect(find.text('Allow Exit'), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);
    await tester.tap(find.text('Quit'));
    await tester.pump();
    expect(find.text('App requesting cancelable exit'), findsOneWidget);
  });
}