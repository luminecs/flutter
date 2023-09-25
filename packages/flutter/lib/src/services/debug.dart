import 'package:flutter/foundation.dart';

import 'hardware_keyboard.dart';

export 'hardware_keyboard.dart' show KeyDataTransitMode;

KeyDataTransitMode? debugKeyEventSimulatorTransitModeOverride;

bool debugPrintKeyboardEvents = false;

bool debugAssertAllServicesVarsUnset(String reason) {
  assert(() {
    if (debugKeyEventSimulatorTransitModeOverride != null) {
      throw FlutterError(reason);
    }
    if (debugPrintKeyboardEvents) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}