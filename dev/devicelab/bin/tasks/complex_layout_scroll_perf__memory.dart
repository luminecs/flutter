import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

Future<void> main() async {
  deviceOperatingSystem = DeviceOperatingSystem.android;
  await task(MemoryTest(
    '${flutterDirectory.path}/dev/benchmarks/complex_layout',
    'test_memory/scroll_perf.dart',
    'com.yourcompany.complexLayout',
  ).run);
}
