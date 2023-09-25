// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show Brightness;

import 'assertions.dart';
import 'platform.dart';
import 'print.dart';

export 'dart:ui' show Brightness;

export 'print.dart' show DebugPrintCallback;

bool debugAssertAllFoundationVarsUnset(String reason, { DebugPrintCallback debugPrintOverride = debugPrintThrottled }) {
  assert(() {
    if (debugPrint != debugPrintOverride ||
        debugDefaultTargetPlatformOverride != null ||
        debugDoublePrecision != null ||
        debugBrightnessOverride != null) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}

bool debugInstrumentationEnabled = false;

Future<T> debugInstrumentAction<T>(String description, Future<T> Function() action) async {
  bool instrument = false;
  assert(() {
    instrument = debugInstrumentationEnabled;
    return true;
  }());
  if (instrument) {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      debugPrint('Action "$description" took ${stopwatch.elapsed}');
    }
  } else {
    return action();
  }
}

int? debugDoublePrecision;

String debugFormatDouble(double? value) {
  if (value == null) {
    return 'null';
  }
  if (debugDoublePrecision != null) {
    return value.toStringAsPrecision(debugDoublePrecision!);
  }
  return value.toStringAsFixed(1);
}

ui.Brightness? debugBrightnessOverride;

String? activeDevToolsServerAddress;

String? connectedVmServiceUri;