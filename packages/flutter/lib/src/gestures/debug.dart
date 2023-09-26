import 'package:flutter/foundation.dart';

// Any changes to this file should be reflected in the debugAssertAllGesturesVarsUnset()
// function below.

bool debugPrintHitTestResults = false;

bool debugPrintMouseHoverEvents = false;

bool debugPrintGestureArenaDiagnostics = false;

bool debugPrintRecognizerCallbacksTrace = false;

bool debugPrintResamplingMargin = false;

bool debugAssertAllGesturesVarsUnset(String reason) {
  assert(() {
    if (debugPrintHitTestResults ||
        debugPrintGestureArenaDiagnostics ||
        debugPrintRecognizerCallbacksTrace ||
        debugPrintResamplingMargin) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}
