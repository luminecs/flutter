import '../test/common.dart';

void main() {
  // Intentionally fail the test. We want to see driver return a non-zero exit
  // code when this happens.
  test('it fails a test', () {
    expect(true, isFalse);
  });
}