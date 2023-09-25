
import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/run_tests.dart';

void main() {
  deviceOperatingSystem = DeviceOperatingSystem.macos;
  task(createMacOSRunReleaseTest());
}