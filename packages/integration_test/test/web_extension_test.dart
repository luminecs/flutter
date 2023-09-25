@Tags(<String>['web'])
library;

import 'dart:js' as js;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding();

  test('IntegrationTestWidgetsFlutterBinding on the web should register certain global properties', () {
    expect(js.context.hasProperty(r'$flutterDriver'), true);
    expect(js.context[r'$flutterDriver'], isNotNull);

    expect(js.context.hasProperty(r'$flutterDriverResult'), true);
    expect(js.context[r'$flutterDriverResult'], isNull);
  });
}