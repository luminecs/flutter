import 'package:flutter_test/flutter_test.dart';

import '../../../widgets/hello_world.dart' as demo;

void main() {
  testWidgets('layers smoketest for widgets/hello_world.dart',
      (WidgetTester tester) async {
    demo.main();
  });
}
