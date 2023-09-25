// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'constants.dart';
import 'events.dart';
import 'recognizer.dart';
import 'velocity_tracker.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'events.dart' show PointerDownEvent, PointerEvent, PointerPanZoomStartEvent;
export 'recognizer.dart' show DragStartBehavior;
export 'velocity_tracker.dart' show Velocity;

const double kDefaultMouseScrollToScaleFactor = 200;

const Offset kDefaultTrackpadScrollToScaleFactor = Offset(0, -1/kDefaultMouseScrollToScaleFactor);

enum _ScaleState {
  ready,

  possible,

  accepted,

  started,
}

class _PointerPanZoomData {
  _PointerPanZoomData.fromStartEvent(
    this.parent,
    PointerPanZoomStartEvent event
  ) : _position = event.position,
      _pan = Offset.zero,
      _scale = 1,
      _rotation = 0;

  _PointerPanZoomData.fromUpdateEvent(
    this.parent,
    PointerPanZoomUpdateEvent event
  ) : _position = event.position,
      _pan = event.pan,
      _scale = event.scale,
      _rotation = event.rotation;

  final ScaleGestureRecognizer parent;
  final Offset _position;
  final Offset _pan;
  final double _scale;
  final double _rotation;

  Offset get focalPoint {
    if (parent.trackpadScrollCausesScale) {
      return _position;
    }
    return _position + _pan;
  }

  double get scale {
    if (parent.trackpadScrollCausesScale) {
      return _scale * math.exp(
        (_pan.dx * parent.trackpadScrollToScaleFactor.dx) +
        (_pan.dy * parent.trackpadScrollToScaleFactor.dy)
      );
    }
    return _scale;
  }

  double get rotation => _rotation;

  @override
  String toString() => '_PointerPanZoomData(parent: $parent, _position: $_position, _pan: $_pan, _scale: $_scale, _rotation: $_rotation)';
}

class ScaleStartDetails {
  ScaleStartDetails({
    this.focalPoint = Offset.zero,
    Offset? localFocalPoint,
    this.pointerCount = 0,
  }) : localFocalPoint = localFocalPoint ?? focalPoint;

  final Offset focalPoint;

  final Offset localFocalPoint;

  final int pointerCount;

  @override
  String toString() => 'ScaleStartDetails(focalPoint: $focalPoint, localFocalPoint: $localFocalPoint, pointersCount: $pointerCount)';
}

class ScaleUpdateDetails {
  ScaleUpdateDetails({
    this.focalPoint = Offset.zero,
    Offset? localFocalPoint,
    this.scale = 1.0,
    this.horizontalScale = 1.0,
    this.verticalScale = 1.0,
    this.rotation = 0.0,
    this.pointerCount = 0,
    this.focalPointDelta = Offset.zero,
  }) : assert(scale >= 0.0),
       assert(horizontalScale >= 0.0),
       assert(verticalScale >= 0.0),
       localFocalPoint = localFocalPoint ?? focalPoint;

  final Offset focalPointDelta;

  final Offset focalPoint;

  final Offset localFocalPoint;

  final double scale;

  final double horizontalScale;

  final double verticalScale;

  final double rotation;

  final int pointerCount;

  @override
  String toString() => 'ScaleUpdateDetails('
    'focalPoint: $focalPoint,'
    ' localFocalPoint: $localFocalPoint,'
    ' scale: $scale,'
    ' horizontalScale: $horizontalScale,'
    ' verticalScale: $verticalScale,'
    ' rotation: $rotation,'
    ' pointerCount: $pointerCount,'
    ' focalPointDelta: $focalPointDelta)';
}

class ScaleEndDetails {
  ScaleEndDetails({ this.velocity = Velocity.zero, this.scaleVelocity = 0, this.pointerCount = 0 });

  final Velocity velocity;

  final double scaleVelocity;

  final int pointerCount;

  @override
  String toString() => 'ScaleEndDetails(velocity: $velocity, scaleVelocity: $scaleVelocity, pointerCount: $pointerCount)';
}

typedef GestureScaleStartCallback = void Function(ScaleStartDetails details);

typedef GestureScaleUpdateCallback = void Function(ScaleUpdateDetails details);

typedef GestureScaleEndCallback = void Function(ScaleEndDetails details);

bool _isFlingGesture(Velocity velocity) {
  final double speedSquared = velocity.pixelsPerSecond.distanceSquared;
  return speedSquared > kMinFlingVelocity * kMinFlingVelocity;
}


class _LineBetweenPointers {

  _LineBetweenPointers({
    this.pointerStartLocation = Offset.zero,
    this.pointerStartId = 0,
    this.pointerEndLocation = Offset.zero,
    this.pointerEndId = 1,
  }) : assert(pointerStartId != pointerEndId);

  // The location and the id of the pointer that marks the start of the line.
  final Offset pointerStartLocation;
  final int pointerStartId;

  // The location and the id of the pointer that marks the end of the line.
  final Offset pointerEndLocation;
  final int pointerEndId;

}


class ScaleGestureRecognizer extends OneSequenceGestureRecognizer {
  ScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    this.dragStartBehavior = DragStartBehavior.down,
    this.trackpadScrollCausesScale = false,
    this.trackpadScrollToScaleFactor = kDefaultTrackpadScrollToScaleFactor,
  });

  DragStartBehavior dragStartBehavior;

  GestureScaleStartCallback? onStart;

  GestureScaleUpdateCallback? onUpdate;

  GestureScaleEndCallback? onEnd;

  _ScaleState _state = _ScaleState.ready;

  Matrix4? _lastTransform;

  bool trackpadScrollCausesScale;

  Offset trackpadScrollToScaleFactor;

  int get pointerCount {
    return _pointerPanZooms.length + _pointerQueue.length;
  }

  late Offset _initialFocalPoint;
  Offset? _currentFocalPoint;
  late double _initialSpan;
  late double _currentSpan;
  late double _initialHorizontalSpan;
  late double _currentHorizontalSpan;
  late double _initialVerticalSpan;
  late double _currentVerticalSpan;
  late Offset _localFocalPoint;
  _LineBetweenPointers? _initialLine;
  _LineBetweenPointers? _currentLine;
  final Map<int, Offset> _pointerLocations = <int, Offset>{};
  final List<int> _pointerQueue = <int>[]; // A queue to sort pointers in order of entrance
  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};
  VelocityTracker? _scaleVelocityTracker;
  late Offset _delta;
  final Map<int, _PointerPanZoomData> _pointerPanZooms = <int, _PointerPanZoomData>{};
  double _initialPanZoomScaleFactor = 1;
  double _initialPanZoomRotationFactor = 0;

  double get _pointerScaleFactor => _initialSpan > 0.0 ? _currentSpan / _initialSpan : 1.0;

  double get _pointerHorizontalScaleFactor => _initialHorizontalSpan > 0.0 ? _currentHorizontalSpan / _initialHorizontalSpan : 1.0;

  double get _pointerVerticalScaleFactor => _initialVerticalSpan > 0.0 ? _currentVerticalSpan / _initialVerticalSpan : 1.0;

  double get _scaleFactor {
    double scale = _pointerScaleFactor;
    for (final _PointerPanZoomData p in _pointerPanZooms.values) {
      scale *= p.scale / _initialPanZoomScaleFactor;
    }
    return scale;
  }

  double get _horizontalScaleFactor {
    double scale = _pointerHorizontalScaleFactor;
    for (final _PointerPanZoomData p in _pointerPanZooms.values) {
      scale *= p.scale / _initialPanZoomScaleFactor;
    }
    return scale;
  }

  double get _verticalScaleFactor {
    double scale = _pointerVerticalScaleFactor;
    for (final _PointerPanZoomData p in _pointerPanZooms.values) {
      scale *= p.scale / _initialPanZoomScaleFactor;
    }
    return scale;
  }

  double _computeRotationFactor() {
    double factor = 0.0;
    if (_initialLine != null && _currentLine != null) {
      final double fx = _initialLine!.pointerStartLocation.dx;
      final double fy = _initialLine!.pointerStartLocation.dy;
      final double sx = _initialLine!.pointerEndLocation.dx;
      final double sy = _initialLine!.pointerEndLocation.dy;

      final double nfx = _currentLine!.pointerStartLocation.dx;
      final double nfy = _currentLine!.pointerStartLocation.dy;
      final double nsx = _currentLine!.pointerEndLocation.dx;
      final double nsy = _currentLine!.pointerEndLocation.dy;

      final double angle1 = math.atan2(fy - sy, fx - sx);
      final double angle2 = math.atan2(nfy - nsy, nfx - nsx);

      factor = angle2 - angle1;
    }
    for (final _PointerPanZoomData p in _pointerPanZooms.values) {
      factor += p.rotation;
    }
    factor -= _initialPanZoomRotationFactor;
    return factor;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _velocityTrackers[event.pointer] = VelocityTracker.withKind(event.kind);
    if (_state == _ScaleState.ready) {
      _state = _ScaleState.possible;
      _initialSpan = 0.0;
      _currentSpan = 0.0;
      _initialHorizontalSpan = 0.0;
      _currentHorizontalSpan = 0.0;
      _initialVerticalSpan = 0.0;
      _currentVerticalSpan = 0.0;
    }
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) => true;

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    startTrackingPointer(event.pointer, event.transform);
    _velocityTrackers[event.pointer] = VelocityTracker.withKind(event.kind);
    if (_state == _ScaleState.ready) {
      _state = _ScaleState.possible;
      _initialPanZoomScaleFactor = 1.0;
      _initialPanZoomRotationFactor = 0.0;
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _ScaleState.ready);
    bool didChangeConfiguration = false;
    bool shouldStartIfAccepted = false;
    if (event is PointerMoveEvent) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer]!;
      if (!event.synthesized) {
        tracker.addPosition(event.timeStamp, event.position);
      }
      _pointerLocations[event.pointer] = event.position;
      shouldStartIfAccepted = true;
      _lastTransform = event.transform;
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
      _pointerQueue.add(event.pointer);
      didChangeConfiguration = true;
      shouldStartIfAccepted = true;
      _lastTransform = event.transform;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
      _pointerQueue.remove(event.pointer);
      didChangeConfiguration = true;
      _lastTransform = event.transform;
    } else if (event is PointerPanZoomStartEvent) {
      assert(_pointerPanZooms[event.pointer] == null);
      _pointerPanZooms[event.pointer] = _PointerPanZoomData.fromStartEvent(this, event);
      didChangeConfiguration = true;
      shouldStartIfAccepted = true;
      _lastTransform = event.transform;
    } else if (event is PointerPanZoomUpdateEvent) {
      assert(_pointerPanZooms[event.pointer] != null);
      if (!event.synthesized && !trackpadScrollCausesScale) {
        _velocityTrackers[event.pointer]!.addPosition(event.timeStamp, event.pan);
      }
      _pointerPanZooms[event.pointer] = _PointerPanZoomData.fromUpdateEvent(this, event);
      _lastTransform = event.transform;
      shouldStartIfAccepted = true;
    } else if (event is PointerPanZoomEndEvent) {
      assert(_pointerPanZooms[event.pointer] != null);
      _pointerPanZooms.remove(event.pointer);
      didChangeConfiguration = true;
    }

    _updateLines();
    _update();

    if (!didChangeConfiguration || _reconfigure(event.pointer)) {
      _advanceStateMachine(shouldStartIfAccepted, event);
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _update() {
    final Offset? previousFocalPoint = _currentFocalPoint;

    // Compute the focal point
    Offset focalPoint = Offset.zero;
    for (final int pointer in _pointerLocations.keys) {
      focalPoint += _pointerLocations[pointer]!;
    }
    for (final _PointerPanZoomData p in _pointerPanZooms.values) {
      focalPoint += p.focalPoint;
    }
    _currentFocalPoint = pointerCount > 0 ? focalPoint / pointerCount.toDouble() : Offset.zero;

    if (previousFocalPoint == null) {
      _localFocalPoint = PointerEvent.transformPosition(
        _lastTransform,
        _currentFocalPoint!,
      );
      _delta = Offset.zero;
    } else {
      final Offset localPreviousFocalPoint = _localFocalPoint;
      _localFocalPoint = PointerEvent.transformPosition(
        _lastTransform,
        _currentFocalPoint!,
      );
      _delta = _localFocalPoint - localPreviousFocalPoint;
    }

    final int count = _pointerLocations.keys.length;

    Offset pointerFocalPoint = Offset.zero;
    for (final int pointer in _pointerLocations.keys) {
      pointerFocalPoint += _pointerLocations[pointer]!;
    }
    if (count > 0) {
      pointerFocalPoint = pointerFocalPoint / count.toDouble();
    }

    // Span is the average deviation from focal point. Horizontal and vertical
    // spans are the average deviations from the focal point's horizontal and
    // vertical coordinates, respectively.
    double totalDeviation = 0.0;
    double totalHorizontalDeviation = 0.0;
    double totalVerticalDeviation = 0.0;
    for (final int pointer in _pointerLocations.keys) {
      totalDeviation += (pointerFocalPoint - _pointerLocations[pointer]!).distance;
      totalHorizontalDeviation += (pointerFocalPoint.dx - _pointerLocations[pointer]!.dx).abs();
      totalVerticalDeviation += (pointerFocalPoint.dy - _pointerLocations[pointer]!.dy).abs();
    }
    _currentSpan = count > 0 ? totalDeviation / count : 0.0;
    _currentHorizontalSpan = count > 0 ? totalHorizontalDeviation / count : 0.0;
    _currentVerticalSpan = count > 0 ? totalVerticalDeviation / count : 0.0;
  }

  void _updateLines() {
    final int count = _pointerLocations.keys.length;
    assert(_pointerQueue.length >= count);
    if (count < 2) {
      _initialLine = _currentLine;
    } else if (_initialLine != null &&
      _initialLine!.pointerStartId == _pointerQueue[0] &&
      _initialLine!.pointerEndId == _pointerQueue[1]) {
      _currentLine = _LineBetweenPointers(
        pointerStartId: _pointerQueue[0],
        pointerStartLocation: _pointerLocations[_pointerQueue[0]]!,
        pointerEndId: _pointerQueue[1],
        pointerEndLocation: _pointerLocations[_pointerQueue[1]]!,
      );
    } else {
      _initialLine = _LineBetweenPointers(
        pointerStartId: _pointerQueue[0],
        pointerStartLocation: _pointerLocations[_pointerQueue[0]]!,
        pointerEndId: _pointerQueue[1],
        pointerEndLocation: _pointerLocations[_pointerQueue[1]]!,
      );
      _currentLine = _initialLine;
    }
  }

  bool _reconfigure(int pointer) {
    _initialFocalPoint = _currentFocalPoint!;
    _initialSpan = _currentSpan;
    _initialLine = _currentLine;
    _initialHorizontalSpan = _currentHorizontalSpan;
    _initialVerticalSpan = _currentVerticalSpan;
    if (_pointerPanZooms.isEmpty) {
      _initialPanZoomScaleFactor = 1.0;
      _initialPanZoomRotationFactor = 0.0;
    } else {
      _initialPanZoomScaleFactor = _scaleFactor / _pointerScaleFactor;
      _initialPanZoomRotationFactor = _pointerPanZooms.values.map((_PointerPanZoomData x) => x.rotation).reduce((double a, double b) => a + b);
    }
    if (_state == _ScaleState.started) {
      if (onEnd != null) {
        final VelocityTracker tracker = _velocityTrackers[pointer]!;

        Velocity velocity = tracker.getVelocity();
        if (_isFlingGesture(velocity)) {
          final Offset pixelsPerSecond = velocity.pixelsPerSecond;
          if (pixelsPerSecond.distanceSquared > kMaxFlingVelocity * kMaxFlingVelocity) {
            velocity = Velocity(pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) * kMaxFlingVelocity);
          }
          invokeCallback<void>('onEnd', () => onEnd!(ScaleEndDetails(velocity: velocity, scaleVelocity: _scaleVelocityTracker?.getVelocity().pixelsPerSecond.dx ?? -1, pointerCount: pointerCount)));
        } else {
          invokeCallback<void>('onEnd', () => onEnd!(ScaleEndDetails(scaleVelocity: _scaleVelocityTracker?.getVelocity().pixelsPerSecond.dx ?? -1, pointerCount: pointerCount)));
        }
      }
      _state = _ScaleState.accepted;
      _scaleVelocityTracker = VelocityTracker.withKind(PointerDeviceKind.touch); // arbitrary PointerDeviceKind
      return false;
    }
    _scaleVelocityTracker = VelocityTracker.withKind(PointerDeviceKind.touch); // arbitrary PointerDeviceKind
    return true;
  }

  void _advanceStateMachine(bool shouldStartIfAccepted, PointerEvent event) {
    if (_state == _ScaleState.ready) {
      _state = _ScaleState.possible;
    }

    if (_state == _ScaleState.possible) {
      final double spanDelta = (_currentSpan - _initialSpan).abs();
      final double focalPointDelta = (_currentFocalPoint! - _initialFocalPoint).distance;
      if (spanDelta > computeScaleSlop(event.kind) || focalPointDelta > computePanSlop(event.kind, gestureSettings) || math.max(_scaleFactor / _pointerScaleFactor, _pointerScaleFactor / _scaleFactor) > 1.05) {
        resolve(GestureDisposition.accepted);
      }
    } else if (_state.index >= _ScaleState.accepted.index) {
      resolve(GestureDisposition.accepted);
    }

    if (_state == _ScaleState.accepted && shouldStartIfAccepted) {
      _state = _ScaleState.started;
      _dispatchOnStartCallbackIfNeeded();
    }

    if (_state == _ScaleState.started) {
      _scaleVelocityTracker?.addPosition(event.timeStamp, Offset(_scaleFactor, 0));
      if (onUpdate != null) {
        invokeCallback<void>('onUpdate', () {
          onUpdate!(ScaleUpdateDetails(
            scale: _scaleFactor,
            horizontalScale: _horizontalScaleFactor,
            verticalScale: _verticalScaleFactor,
            focalPoint: _currentFocalPoint!,
            localFocalPoint: _localFocalPoint,
            rotation: _computeRotationFactor(),
            pointerCount: pointerCount,
            focalPointDelta: _delta,
          ));
        });
      }
    }
  }

  void _dispatchOnStartCallbackIfNeeded() {
    assert(_state == _ScaleState.started);
    if (onStart != null) {
      invokeCallback<void>('onStart', () {
        onStart!(ScaleStartDetails(
          focalPoint: _currentFocalPoint!,
          localFocalPoint: _localFocalPoint,
          pointerCount: pointerCount,
        ));
      });
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (_state == _ScaleState.possible) {
      _state = _ScaleState.started;
      _dispatchOnStartCallbackIfNeeded();
      if (dragStartBehavior == DragStartBehavior.start) {
        _initialFocalPoint = _currentFocalPoint!;
        _initialSpan = _currentSpan;
        _initialLine = _currentLine;
        _initialHorizontalSpan = _currentHorizontalSpan;
        _initialVerticalSpan = _currentVerticalSpan;
        if (_pointerPanZooms.isEmpty) {
          _initialPanZoomScaleFactor = 1.0;
          _initialPanZoomRotationFactor = 0.0;
        } else {
          _initialPanZoomScaleFactor = _scaleFactor / _pointerScaleFactor;
          _initialPanZoomRotationFactor = _pointerPanZooms.values.map((_PointerPanZoomData x) => x.rotation).reduce((double a, double b) => a + b);
        }
      }
    }
  }

  @override
  void rejectGesture(int pointer) {
    _pointerPanZooms.remove(pointer);
    _pointerLocations.remove(pointer);
    _pointerQueue.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    switch (_state) {
      case _ScaleState.possible:
        resolve(GestureDisposition.rejected);
      case _ScaleState.ready:
        assert(false); // We should have not seen a pointer yet
      case _ScaleState.accepted:
        break;
      case _ScaleState.started:
        assert(false); // We should be in the accepted state when user is done
    }
    _state = _ScaleState.ready;
  }

  @override
  void dispose() {
    _velocityTrackers.clear();
    super.dispose();
  }

  @override
  String get debugDescription => 'scale';
}