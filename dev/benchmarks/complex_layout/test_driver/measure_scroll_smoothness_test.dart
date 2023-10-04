import 'dart:async';

import 'package:integration_test/integration_test_driver.dart' as driver;

Future<void> main() => driver.integrationDriver(
        responseDataCallback: (Map<String, dynamic>? data) async {
      await driver.writeResponseData(
        data,
        testOutputFilename: 'scroll_smoothness_test',
      );
    });
