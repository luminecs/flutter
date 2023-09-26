import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isCanvasKit returns false in HTML mode',
      (WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(isCanvasKit, false);
  });
}
