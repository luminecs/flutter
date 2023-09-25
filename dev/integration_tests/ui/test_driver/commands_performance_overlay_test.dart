import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  late FlutterDriver driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  tearDownAll(() async {
    await driver.close();
  });

  test('check that we are showing the performance overlay', () async {
    await driver.requestData('status'); // force a reassemble
    await driver.waitFor(find.byType('PerformanceOverlay'));
  }, timeout: Timeout.none);
}