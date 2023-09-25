
import 'package:flutter/foundation.dart';

// Any changes to this file should be reflected in the debugAssertAllSchedulerVarsUnset()
// function below.

bool debugPrintBeginFrameBanner = false;

bool debugPrintEndFrameBanner = false;

bool debugPrintScheduleFrameStacks = false;

bool debugAssertAllSchedulerVarsUnset(String reason) {
  assert(() {
    if (debugPrintBeginFrameBanner ||
        debugPrintEndFrameBanner) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}