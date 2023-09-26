import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/gallery.dart';

Future<void> main(List<String> args) async {
  deviceOperatingSystem = DeviceOperatingSystem.ios;
  await task(createGalleryTransitionE2EBuildTest(args));
}
