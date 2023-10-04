import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  test('Trivial test', () {
    expect(42, 42);
  });
}
