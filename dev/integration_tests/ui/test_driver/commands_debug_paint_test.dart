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

  test('check that we are painting in debugPaintSize mode', () async {
    expect(await driver.requestData('status'), 'log: paint debugPaintSize');
  }, timeout: Timeout.none);
}
