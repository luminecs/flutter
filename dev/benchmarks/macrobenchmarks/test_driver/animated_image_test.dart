import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

Future<void> main() async {
  const String fileName = 'animated_image';

  test('Animate for 250 frames', () async {
    final FlutterDriver driver = await FlutterDriver.connect();
    await driver.forceGC();


    final Timeline timeline = await driver.traceAction(() async {
      await driver.requestData('waitForAnimation');
    });
    final TimelineSummary summary = TimelineSummary.summarize(timeline);
    await summary.writeTimelineToFile(fileName, pretty: true);

    await driver.close();
  }, timeout: Timeout.none);
}