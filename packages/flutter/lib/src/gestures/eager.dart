// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'recognizer.dart';

export 'dart:ui' show PointerDeviceKind;

export 'events.dart' show PointerDownEvent, PointerEvent;

class EagerGestureRecognizer extends OneSequenceGestureRecognizer {
  EagerGestureRecognizer({
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
    stopTrackingPointer(event.pointer);
  }

  @override
  String get debugDescription => 'eager';

  @override
  void didStopTrackingLastPointer(int pointer) { }

  @override
  void handleEvent(PointerEvent event) { }
}