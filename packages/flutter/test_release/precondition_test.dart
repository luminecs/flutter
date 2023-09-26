import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// This test verifies that the test_release shard is configured correctly.
// See README.md in this directory for more information.
void main() {
  test('kReleaseMode is set to true', () {
    expect(kReleaseMode, true);
  });
}
