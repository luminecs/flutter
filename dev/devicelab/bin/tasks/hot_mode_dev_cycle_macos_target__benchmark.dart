import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/hot_mode_tests.dart';

Future<void> main() async {
  await task(createHotModeTest(deviceIdOverride: 'macos', checkAppRunningOnLocalDevice: true));
}