import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/ios.dart';
import 'package:flutter_devicelab/framework/task_result.dart';
import 'package:flutter_devicelab/tasks/native_assets_test.dart';

Future<void> main() async {
  await task(() async {
    deviceOperatingSystem = DeviceOperatingSystem.ios;
    String? simulatorDeviceId;
    try {
      await testWithNewIOSSimulator(
        'TestNativeAssetsSim',
        (String deviceId) async {
          simulatorDeviceId = deviceId;
          await createNativeAssetsTest(
            deviceIdOverride: deviceId,
            isIosSimulator: true,
          )();
        },
      );
    } finally {
      await removeIOSimulator(simulatorDeviceId);
    }
    return TaskResult.success(null);
  });
}