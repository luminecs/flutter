
import '../config_test_utils.dart';

void main() {
  testConfig(
    'cwd config takes precedence over parent config',
    '/test_config/nested_config',
    otherExpectedValues: <Type, dynamic>{int: 123},
  );
}