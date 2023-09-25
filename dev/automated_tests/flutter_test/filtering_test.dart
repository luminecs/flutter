
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  test('included', () {
    expect(2 + 2, 4);
  });
  test('excluded', () {
    throw 'this test should have been filtered out';
  });
}