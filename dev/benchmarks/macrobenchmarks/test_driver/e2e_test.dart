import 'package:integration_test/integration_test_driver.dart' as driver;

Future<void> main() => driver.integrationDriver(
        responseDataCallback: (Map<String, dynamic>? data) async {
      await driver.writeResponseData(
        data?['performance'] as Map<String, dynamic>,
        testOutputFilename: 'e2e_perf_summary',
      );
    });
