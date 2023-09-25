
import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

Future<void> main() async {
  // TODO(vashworth): Remove after Xcode 15 and iOS 17 are in CI (https://github.com/flutter/flutter/issues/132128)
  // XcodeDebug workflow is used for CoreDevices (iOS 17+ and Xcode 15+). Use
  // FORCE_XCODE_DEBUG environment variable to force the use of XcodeDebug
  // workflow in CI to test from older versions since devicelab has not yet been
  // updated to iOS 17 and Xcode 15.
  deviceOperatingSystem = DeviceOperatingSystem.ios;
  await task(createFlutterGalleryStartupTest(
    runEnvironment: <String, String>{
      'FORCE_XCODE_DEBUG': 'true',
    },
  ));
}