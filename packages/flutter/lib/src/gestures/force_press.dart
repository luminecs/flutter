// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show clampDouble;

import 'events.dart';
import 'recognizer.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'events.dart' show PointerDownEvent, PointerEvent;

enum _ForceState {
  // No pointer has touched down and the detector is ready for a pointer down to occur.
  ready,

  // A pointer has touched down, but a force press gesture has not yet been detected.
  possible,

  // A pointer is down and a force press gesture has been detected. However, if
  // the ForcePressGestureRecognizer is the only recognizer in the arena, thus
  // accepted as soon as the gesture state is possible, the gesture will not
  // yet have started.
  accepted,

  // A pointer is down and the gesture has started, ie. the pressure of the pointer
  // has just become greater than the ForcePressGestureRecognizer.startPressure.
  started,

  // A pointer is down and the pressure of the pointer has just become greater
  // than the ForcePressGestureRecognizer.peakPressure. Even after a pointer
  // crosses this threshold, onUpdate callbacks will still be sent.
  peaked,
}

class ForcePressDetails {
  ForcePressDetails({
    required this.globalPosition,
    Offset? localPosition,
    required this.pressure,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;

  final double pressure;
}

typedef GestureForcePressStartCallback = void Function(ForcePressDetails details);

typedef GestureForcePressPeakCallback = void Function(ForcePressDetails details);

typedef GestureForcePressUpdateCallback = void Function(ForcePressDetails details);

typedef GestureForcePressEndCallback = void Function(ForcePressDetails details);

typedef GestureForceInterpolation = double Function(double pressureMin, double pressureMax, double pressure);

class ForcePressGestureRecognizer extends OneSequenceGestureRecognizer {
  ForcePressGestureRecognizer({
    this.startPressure = 0.4,
    this.peakPressure = 0.85,
    this.interpolation = _inverseLerp,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  }) : assert(peakPressure > startPressure);

  GestureForcePressStartCallback? onStart;

  GestureForcePressUpdateCallback? onUpdate;

  GestureForcePressPeakCallback? onPeak;

  GestureForcePressEndCallback? onEnd;

  final double startPressure;

  final double peakPressure;

  final GestureForceInterpolation interpolation;

  late OffsetPair _lastPosition;
  late double _lastPressure;
  _ForceState _state = _ForceState.ready;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // If the device has a maximum pressure of less than or equal to 1, it
    // doesn't have touch pressure sensing capabilities. Do not participate
    // in the gesture arena.
    if (event.pressureMax <= 1.0) {
      resolve(GestureDisposition.rejected);
    } else {
      super.addAllowedPointer(event);
      if (_state == _ForceState.ready) {
        _state = _ForceState.possible;
        _lastPosition = OffsetPair.fromEventPosition(event);
      }
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _ForceState.ready);
    // A static pointer with changes in pressure creates PointerMoveEvent events.
    if (event is PointerMoveEvent || event is PointerDownEvent) {
      final double pressure = interpolation(event.pressureMin, event.pressureMax, event.pressure);
      assert(
        (pressure >= 0.0 && pressure <= 1.0) || // Interpolated pressure must be between 1.0 and 0.0...
        pressure.isNaN, // and interpolation may return NaN for values it doesn't want to support...
      );

      _lastPosition = OffsetPair.fromEventPosition(event);
      _lastPressure = pressure;

      if (_state == _ForceState.possible) {
        if (pressure > startPressure) {
          _state = _ForceState.started;
          resolve(GestureDisposition.accepted);
        } else if (event.delta.distanceSquared > computeHitSlop(event.kind, gestureSettings)) {
          resolve(GestureDisposition.rejected);
        }
      }
      // In case this is the only gesture detector we still don't want to start
      // the gesture until the pressure is greater than the startPressure.
      if (pressure > startPressure && _state == _ForceState.accepted) {
        _state = _ForceState.started;
        if (onStart != null) {
          invokeCallback<void>('onStart', () => onStart!(ForcePressDetails(
            pressure: pressure,
            globalPosition: _lastPosition.global,
            localPosition: _lastPosition.local,
          )));
        }
      }
      if (onPeak != null && pressure > peakPressure &&
         (_state == _ForceState.started)) {
        _state = _ForceState.peaked;
        if (onPeak != null) {
          invokeCallback<void>('onPeak', () => onPeak!(ForcePressDetails(
            pressure: pressure,
            globalPosition: event.position,
            localPosition: event.localPosition,
          )));
        }
      }
      if (onUpdate != null &&  !pressure.isNaN &&
         (_state == _ForceState.started || _state == _ForceState.peaked)) {
        if (onUpdate != null) {
          invokeCallback<void>('onUpdate', () => onUpdate!(ForcePressDetails(
            pressure: pressure,
            globalPosition: event.position,
            localPosition: event.localPosition,
          )));
        }
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {
    if (_state == _ForceState.possible) {
      _state = _ForceState.accepted;
    }

    if (onStart != null && _state == _ForceState.started) {
      invokeCallback<void>('onStart', () => onStart!(ForcePressDetails(
        pressure: _lastPressure,
        globalPosition: _lastPosition.global,
        localPosition: _lastPosition.local,
      )));
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final bool wasAccepted = _state == _ForceState.started || _state == _ForceState.peaked;
    if (_state == _ForceState.possible) {
      resolve(GestureDisposition.rejected);
      return;
    }
    if (wasAccepted && onEnd != null) {
      if (onEnd != null) {
        invokeCallback<void>('onEnd', () => onEnd!(ForcePressDetails(
          pressure: 0.0,
          globalPosition: _lastPosition.global,
          localPosition: _lastPosition.local,
        )));
      }
    }
    _state = _ForceState.ready;
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    didStopTrackingLastPointer(pointer);
  }

  static double _inverseLerp(double min, double max, double t) {
    assert(min <= max);
    double value = (t - min) / (max - min);

    // If the device incorrectly reports a pressure outside of pressureMin
    // and pressureMax, we still want this recognizer to respond normally.
    if (!value.isNaN) {
      value = clampDouble(value, 0.0, 1.0);
    }
    return value;
  }

  @override
  String get debugDescription => 'force press';
}