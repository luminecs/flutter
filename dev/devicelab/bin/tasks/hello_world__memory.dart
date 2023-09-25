import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

class HelloWorldMemoryTest extends MemoryTest {
  HelloWorldMemoryTest() : super(
    '${flutterDirectory.path}/examples/hello_world',
    'lib/main.dart',
    'io.flutter.examples.hello_world',
  );

  @override
  Future<void> useMemory() async {
    print('launching $project$test on device...');
    await flutter('run', options: <String>[
      '--verbose',
      '--release',
      '--no-resident',
      '-d', device!.deviceId,
      test,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await recordStart();
    await Future<void>.delayed(const Duration(milliseconds: 3000));
    await recordEnd();
  }
}

Future<void> main() async {
  await task(HelloWorldMemoryTest().run);
}