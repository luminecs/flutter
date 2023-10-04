import 'dart:io';

import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/new_gallery.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  deviceOperatingSystem = DeviceOperatingSystem.android;

  final Directory galleryParentDir =
      Directory.systemTemp.createTempSync('flutter_new_gallery_test.');
  final Directory galleryDir =
      Directory(path.join(galleryParentDir.path, 'gallery'));

  try {
    await task(NewGalleryPerfTest(galleryDir,
            enableImpeller: true, forceOpenGLES: true)
        .run);
  } finally {
    rmTree(galleryParentDir);
  }
}
