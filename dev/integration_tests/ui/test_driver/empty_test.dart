import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

// Connect and disconnect from the empty app.
void main() {
  group('FlutterDriver', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('empty', () async {}, timeout: Timeout.none);
  });
}
