import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/native_assets_test.dart';

Future<void> main() async {
  await task(() async {
    deviceOperatingSystem = DeviceOperatingSystem.ios;
    return createNativeAssetsTest()();
  });
}
