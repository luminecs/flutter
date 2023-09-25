
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart' as common;
import 'package:test/test.dart';


Future<void> main() async {
  test('fails gracefully', () async {
    final FlutterDriver driver = await FlutterDriver.connect();
    final String jsonResult =
        await driver.requestData(null, timeout: const Duration(minutes: 1));
    final common.Response response = common.Response.fromJson(jsonResult);
    await driver.close();
    expect(response.allTestsPassed, isFalse);
    expect(response.failureDetails, hasLength(2));
    expect(response.failureDetails![0].methodName, 'failure 1');
    expect(response.failureDetails![1].methodName, 'failure 2');
  }, timeout: Timeout.none);
}