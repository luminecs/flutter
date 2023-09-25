import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart defines can be provided', () {
    expect(const String.fromEnvironment('flutter.test.foo'), 'bar');
  });
}