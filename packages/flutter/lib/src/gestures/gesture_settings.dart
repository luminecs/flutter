
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

export 'dart:ui' show FlutterView;

@immutable
class DeviceGestureSettings {
  const DeviceGestureSettings({
    this.touchSlop,
  });

  factory DeviceGestureSettings.fromView(ui.FlutterView view) {
    final double? physicalTouchSlop = view.gestureSettings.physicalTouchSlop;
    return DeviceGestureSettings(
      touchSlop: physicalTouchSlop == null ? null : physicalTouchSlop / view.devicePixelRatio
    );
  }

  final double? touchSlop;

  double? get panSlop => touchSlop != null ? (touchSlop! * 2) : null;

  @override
  int get hashCode => Object.hash(touchSlop, 23);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DeviceGestureSettings
      && other.touchSlop == touchSlop;
  }

  @override
  String toString() => 'DeviceGestureSettings(touchSlop: $touchSlop)';
}