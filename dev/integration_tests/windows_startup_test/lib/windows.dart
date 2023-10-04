import 'dart:typed_data';

import 'package:flutter/services.dart';

const MethodChannel _kMethodChannel =
    MethodChannel('tests.flutter.dev/windows_startup_test');

Future<bool> isWindowVisible() async {
  final bool? visible =
      await _kMethodChannel.invokeMethod<bool?>('isWindowVisible');
  if (visible == null) {
    throw 'Method channel unavailable';
  }

  return visible;
}

Future<bool> isAppDarkModeEnabled() async {
  final bool? enabled =
      await _kMethodChannel.invokeMethod<bool?>('isAppDarkModeEnabled');
  if (enabled == null) {
    throw 'Method channel unavailable';
  }

  return enabled;
}

Future<bool> isSystemDarkModeEnabled() async {
  final bool? enabled =
      await _kMethodChannel.invokeMethod<bool?>('isSystemDarkModeEnabled');
  if (enabled == null) {
    throw 'Method channel unavailable';
  }

  return enabled;
}

Future<String> testStringConversion(Int32List twoByteCodes) async {
  final String? converted = await _kMethodChannel.invokeMethod<String?>(
      'convertString', twoByteCodes);
  if (converted == null) {
    throw 'Method channel unavailable.';
  }

  return converted;
}
