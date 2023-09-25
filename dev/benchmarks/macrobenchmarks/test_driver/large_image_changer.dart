
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:macrobenchmarks/common.dart';
import 'package:macrobenchmarks/main.dart';

Future<void> main() async {
  enableFlutterDriverExtension(handler: (String? message) async {
    if (message == 'getTargetPlatform') {
      return defaultTargetPlatform.toString();
    }
    throw UnsupportedError('Message $message unsupported');
  });
  runApp(const MacrobenchmarksApp(initialRoute: kLargeImageChangerRouteName));
}