import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isWeb is false for flutter tester', () {
    expect(kIsWeb, false);
  }, skip: kIsWeb); // [intended] kIsWeb is what we are testing here.
}
