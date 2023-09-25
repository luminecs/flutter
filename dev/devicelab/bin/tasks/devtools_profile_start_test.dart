import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

Future<void> main() async {
  deviceOperatingSystem = DeviceOperatingSystem.android;
  await task(DevtoolsStartupTest(
    '${flutterDirectory.path}/examples/hello_world',
  ).run);
}