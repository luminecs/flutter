
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clampDouble', () {
    expect(clampDouble(-1.0, 0.0, 1.0), equals(0.0));
    expect(clampDouble(2.0, 0.0, 1.0), equals(1.0));
    expect(clampDouble(double.infinity, 0.0, 1.0), equals(1.0));
    expect(clampDouble(-double.infinity, 0.0, 1.0), equals(0.0));
    expect(clampDouble(double.nan, 0.0, double.infinity), equals(double.infinity));
  });
}