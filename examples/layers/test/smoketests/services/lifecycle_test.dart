import 'package:flutter_test/flutter_test.dart';

import '../../../services/lifecycle.dart' as demo;

void main() {
  testWidgets('layers smoketest for services/lifecycle.dart',
      (WidgetTester tester) async {
    demo.main();
  });
}
