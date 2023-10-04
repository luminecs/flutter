@TestOn('!chrome')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'common.dart';

void main() {
  group('Non-web UrlStrategy', () {
    late TestPlatformLocation location;

    setUp(() {
      location = TestPlatformLocation();
    });

    test('Can create and set a $HashUrlStrategy', () {
      expect(() {
        final HashUrlStrategy strategy = HashUrlStrategy(location);
        setUrlStrategy(strategy);
      }, returnsNormally);
    });

    test('Can create and set a $PathUrlStrategy', () {
      expect(() {
        final PathUrlStrategy strategy = PathUrlStrategy(location);
        setUrlStrategy(strategy);
      }, returnsNormally);
    });

    test('Can usePathUrlStrategy', () {
      expect(() {
        usePathUrlStrategy();
      }, returnsNormally);
    });
  });
}
