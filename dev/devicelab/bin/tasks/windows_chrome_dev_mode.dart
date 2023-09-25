import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/web_dev_mode_tests.dart';

Future<void> main() async {
  await task(createWebDevModeTest(WebDevice.webServer, false));
}