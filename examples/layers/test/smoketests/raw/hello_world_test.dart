import 'package:flutter_test/flutter_test.dart' hide TypeMatcher, isInstanceOf;

import '../../../raw/hello_world.dart' as demo;

void main() {
  test('layers smoketest for raw/hello_world.dart', () {
    demo.main();
  });
}
