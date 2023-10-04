import 'dart:io';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  test('working directory is the root of this package', () {
    expect(Directory.current.path, endsWith('automated_tests'));
  });
}
