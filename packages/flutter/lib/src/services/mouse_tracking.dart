// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'mouse_cursor.dart';

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;
export 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent, PointerHoverEvent;

export 'mouse_cursor.dart' show MouseCursor;

typedef PointerEnterEventListener = void Function(PointerEnterEvent event);

typedef PointerExitEventListener = void Function(PointerExitEvent event);

typedef PointerHoverEventListener = void Function(PointerHoverEvent event);

class MouseTrackerAnnotation with Diagnosticable {
  const MouseTrackerAnnotation({
    this.onEnter,
    this.onExit,
    this.cursor = MouseCursor.defer,
    this.validForMouseTracker = true,
  });

  final PointerEnterEventListener? onEnter;

  final PointerExitEventListener? onExit;

  final MouseCursor cursor;

  final bool validForMouseTracker;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagsSummary<Function?>(
      'callbacks',
      <String, Function?> {
        'enter': onEnter,
        'exit': onExit,
      },
      ifEmpty: '<none>',
    ));
    properties.add(DiagnosticsProperty<MouseCursor>('cursor', cursor, defaultValue: MouseCursor.defer));
  }
}