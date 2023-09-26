import 'package:flavors/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flavor Test', () {
    testWidgets('check flavor', (WidgetTester tester) async {
      app.runMainApp();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('paid'), findsOneWidget);
    });
  });
}
