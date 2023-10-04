import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../widgets/spinning_mixed.dart' as demo;

void main() {
  test('layers smoketest for widgets/spinning_mixed.dart', () {
    FlutterError.onError = (FlutterErrorDetails details) {
      throw details.exception;
    };
    demo.main();
  });
}
