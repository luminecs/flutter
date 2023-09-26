import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  group('flavors suite', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    test('check flavor', () async {
      final SerializableFinder flavorField = find.byValueKey('flavor');
      final String flavor = await driver.getText(flavorField);
      expect(flavor, 'paid');
    }, timeout: Timeout.none);

    tearDownAll(() async {
      driver.close();
    });
  });
}
