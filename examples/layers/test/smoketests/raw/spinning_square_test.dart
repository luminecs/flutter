import 'package:flutter_test/flutter_test.dart' hide TypeMatcher, isInstanceOf;

import '../../../raw/spinning_square.dart' as demo;

void main() {
  test('layers smoketest for raw/spinning_square.dart', () {
    demo.main();
  });
}
