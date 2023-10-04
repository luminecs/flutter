import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debugFormatDouble formats doubles', () {
    expect(debugFormatDouble(1), '1.0');
    expect(debugFormatDouble(1.1), '1.1');
    expect(debugFormatDouble(null), 'null');
  });

  test('debugDoublePrecision can control double precision', () {
    debugDoublePrecision = 3;
    expect(debugFormatDouble(1), '1.00');
    debugDoublePrecision = null;
  });
}
