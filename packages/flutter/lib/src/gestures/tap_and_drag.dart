// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'events.dart';
import 'monodrag.dart';
import 'recognizer.dart';
import 'scale.dart';
import 'tap.dart';

// Examples can assume:
// void setState(VoidCallback fn) { }
// late String _last;

double _getGlobalDistance(PointerEvent event, OffsetPair? originPosition) {
  assert(originPosition != null);
  final Offset offset = event.position - originPosition!.global;
  return offset.distance;
}

// The possible states of a [BaseTapAndDragGestureRecognizer].
//
// The recognizer advances from [ready] to [possible] when it starts tracking
// a pointer in [BaseTapAndDragGestureRecognizer.addAllowedPointer]. Where it advances
// from there depends on the sequence of pointer events that is tracked by the
// recognizer, following the initial [PointerDownEvent]:
//
// * If a [PointerUpEvent] has not been tracked, the recognizer stays in the [possible]
//   state as long as it continues to track a pointer.
// * If a [PointerMoveEvent] is tracked that has moved a sufficient global distance
//   from the initial [PointerDownEvent] and it came before a [PointerUpEvent], then
//   this recognizer moves from the [possible] state to [accepted].
// * If a [PointerUpEvent] is tracked before the pointer has moved a sufficient global
//   distance to be considered a drag, then this recognizer moves from the [possible]
//   state to [ready].
// * If a [PointerCancelEvent] is tracked then this recognizer moves from its current
//   state to [ready].
//
// Once the recognizer has stopped tracking any remaining pointers, the recognizer
// returns to the [ready] state.
enum _DragState {
  // The recognizer is ready to start recognizing a drag.
  ready,

  // The sequence of pointer events seen thus far is consistent with a drag but
  // it has not been accepted definitively.
  possible,

  // The sequence of pointer events has been accepted definitively as a drag.
  accepted,
}

typedef GestureTapDragDownCallback  = void Function(TapDragDownDetails details);

class TapDragDownDetails with Diagnosticable {
  TapDragDownDetails({
    required this.globalPosition,
    required this.localPosition,
    this.kind,
    required this.consecutiveTapCount,
  });

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind? kind;

  final int consecutiveTapCount;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('globalPosition', globalPosition));
    properties.add(DiagnosticsProperty<Offset>('localPosition', localPosition));
    properties.add(DiagnosticsProperty<PointerDeviceKind?>('kind', kind));
    properties.add(DiagnosticsProperty<int>('consecutiveTapCount', consecutiveTapCount));
  }
}

typedef GestureTapDragUpCallback  = void Function(TapDragUpDetails details);

class TapDragUpDetails with Diagnosticable {
  TapDragUpDetails({
    required this.kind,
    required this.globalPosition,
    required this.localPosition,
    required this.consecutiveTapCount,
  });

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind kind;

  final int consecutiveTapCount;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('globalPosition', globalPosition));
    properties.add(DiagnosticsProperty<Offset>('localPosition', localPosition));
    properties.add(DiagnosticsProperty<PointerDeviceKind?>('kind', kind));
    properties.add(DiagnosticsProperty<int>('consecutiveTapCount', consecutiveTapCount));
  }
}

typedef GestureTapDragStartCallback = void Function(TapDragStartDetails details);

class TapDragStartDetails with Diagnosticable {
  TapDragStartDetails({
    this.sourceTimeStamp,
    required this.globalPosition,
    required this.localPosition,
    this.kind,
    required this.consecutiveTapCount,
  });

  final Duration? sourceTimeStamp;

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind? kind;

  final int consecutiveTapCount;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration?>('sourceTimeStamp', sourceTimeStamp));
    properties.add(DiagnosticsProperty<Offset>('globalPosition', globalPosition));
    properties.add(DiagnosticsProperty<Offset>('localPosition', localPosition));
    properties.add(DiagnosticsProperty<PointerDeviceKind?>('kind', kind));
    properties.add(DiagnosticsProperty<int>('consecutiveTapCount', consecutiveTapCount));
  }
}

typedef GestureTapDragUpdateCallback = void Function(TapDragUpdateDetails details);

class TapDragUpdateDetails with Diagnosticable {
  TapDragUpdateDetails({
    this.sourceTimeStamp,
    this.delta = Offset.zero,
    this.primaryDelta,
    required this.globalPosition,
    this.kind,
    required this.localPosition,
    required this.offsetFromOrigin,
    required this.localOffsetFromOrigin,
    required this.consecutiveTapCount,
  }) : assert(
         primaryDelta == null
           || (primaryDelta == delta.dx && delta.dy == 0.0)
           || (primaryDelta == delta.dy && delta.dx == 0.0),
       );

  final Duration? sourceTimeStamp;

  final Offset delta;

  final double? primaryDelta;

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind? kind;

  final Offset offsetFromOrigin;

  final Offset localOffsetFromOrigin;

  final int consecutiveTapCount;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration?>('sourceTimeStamp', sourceTimeStamp));
    properties.add(DiagnosticsProperty<Offset>('delta', delta));
    properties.add(DiagnosticsProperty<double?>('primaryDelta', primaryDelta));
    properties.add(DiagnosticsProperty<Offset>('globalPosition', globalPosition));
    properties.add(DiagnosticsProperty<Offset>('localPosition', localPosition));
    properties.add(DiagnosticsProperty<PointerDeviceKind?>('kind', kind));
    properties.add(DiagnosticsProperty<Offset>('offsetFromOrigin', offsetFromOrigin));
    properties.add(DiagnosticsProperty<Offset>('localOffsetFromOrigin', localOffsetFromOrigin));
    properties.add(DiagnosticsProperty<int>('consecutiveTapCount', consecutiveTapCount));
  }
}

typedef GestureTapDragEndCallback = void Function(TapDragEndDetails endDetails);

class TapDragEndDetails with Diagnosticable {
  TapDragEndDetails({
    this.velocity = Velocity.zero,
    this.primaryVelocity,
    required this.consecutiveTapCount,
  }) : assert(
         primaryVelocity == null
           || primaryVelocity == velocity.pixelsPerSecond.dx
           || primaryVelocity == velocity.pixelsPerSecond.dy,
       );

  final Velocity velocity;

  final double? primaryVelocity;

  final int consecutiveTapCount;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Velocity>('velocity', velocity));
    properties.add(DiagnosticsProperty<double?>('primaryVelocity', primaryVelocity));
    properties.add(DiagnosticsProperty<int>('consecutiveTapCount', consecutiveTapCount));
  }
}

typedef GestureCancelCallback = void Function();

// A mixin for [OneSequenceGestureRecognizer] that tracks the number of taps
// that occur in a series of [PointerEvent]s and the most recent set of
// [LogicalKeyboardKey]s pressed on the most recent tap down.
//
// A tap is tracked as part of a series of taps if:
//
// 1. The elapsed time between when a [PointerUpEvent] and the subsequent
// [PointerDownEvent] does not exceed [kDoubleTapTimeout].
// 2. The delta between the position tapped in the global coordinate system
// and the position that was tapped previously must be less than or equal
// to [kDoubleTapSlop].
//
// This mixin's state, i.e. the series of taps being tracked is reset when
// a tap is tracked that does not meet any of the specifications stated above.
mixin _TapStatusTrackerMixin on OneSequenceGestureRecognizer {
  // Public state available to [OneSequenceGestureRecognizer].

  // The [PointerDownEvent] that was most recently tracked in [addAllowedPointer].
  //
  // This value will be null if a [PointerDownEvent] has not been tracked yet in
  // [addAllowedPointer] or the timer between two taps has elapsed.
  //
  // This value is only reset when the timer between a [PointerUpEvent] and the
  // [PointerDownEvent] times out or when a new [PointerDownEvent] is tracked in
  // [addAllowedPointer].
  PointerDownEvent? get currentDown => _down;

  // The [PointerUpEvent] that was most recently tracked in [handleEvent].
  //
  // This value will be null if a [PointerUpEvent] has not been tracked yet in
  // [handleEvent] or the timer between two taps has elapsed.
  //
  // This value is only reset when the timer between a [PointerUpEvent] and the
  // [PointerDownEvent] times out or when a new [PointerDownEvent] is tracked in
  // [addAllowedPointer].
  PointerUpEvent? get currentUp => _up;

  // The number of consecutive taps that the most recently tracked [PointerDownEvent]
  // in [currentDown] represents.
  //
  // This value defaults to zero, meaning a tap series is not currently being tracked.
  //
  // When this value is greater than zero it means [addAllowedPointer] has run
  // and at least one [PointerDownEvent] belongs to the current series of taps
  // being tracked.
  //
  // [addAllowedPointer] will either increment this value by `1` or set the value to `1`
  // depending if the new [PointerDownEvent] is determined to be in the same series as the
  // tap that preceded it. If too much time has elapsed between two taps, the recognizer has lost
  // in the arena, the gesture has been cancelled, or the recognizer is being disposed then
  // this value will be set to `0`, and a new series will begin.
  int get consecutiveTapCount => _consecutiveTapCount;

  // The upper limit for the [consecutiveTapCount]. When this limit is reached
  // all tap related state is reset and a new tap series is tracked.
  //
  // If this value is null, [consecutiveTapCount] can grow infinitely large.
  int? get maxConsecutiveTap;

  // Private tap state tracked.
  PointerDownEvent? _down;
  PointerUpEvent? _up;
  int _consecutiveTapCount = 0;

  OffsetPair? _originPosition;
  int? _previousButtons;

  // For timing taps.
  Timer? _consecutiveTapTimer;
  Offset? _lastTapOffset;

  VoidCallback? onTapTrackStart;


  VoidCallback? onTapTrackReset;

  // When tracking a tap, the [consecutiveTapCount] is incremented if the given tap
  // falls under the tolerance specifications and reset to 1 if not.
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (_consecutiveTapTimer != null && !_consecutiveTapTimer!.isActive) {
      _tapTrackerReset();
    }
    if (maxConsecutiveTap == _consecutiveTapCount) {
      _tapTrackerReset();
    }
    _up = null;
    if (_down != null && !_representsSameSeries(event)) {
      // The given tap does not match the specifications of the series of taps being tracked,
      // reset the tap count and related state.
      _consecutiveTapCount = 1;
    } else {
      _consecutiveTapCount += 1;
    }
    _consecutiveTapTimerStop();
    // `_down` must be assigned in this method instead of [handleEvent],
    // because [acceptGesture] might be called before [handleEvent],
    // which may rely on `_down` to initiate a callback.
    _trackTap(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final double computedSlop = computeHitSlop(event.kind, gestureSettings);
      final bool isSlopPastTolerance = _getGlobalDistance(event, _originPosition) > computedSlop;

      if (isSlopPastTolerance) {
        _consecutiveTapTimerStop();
        _previousButtons = null;
        _lastTapOffset = null;
      }
    } else if (event is PointerUpEvent) {
      _up = event;
      if (_down != null) {
        _consecutiveTapTimerStop();
        _consecutiveTapTimerStart();
      }
    } else if (event is PointerCancelEvent) {
      _tapTrackerReset();
    }
  }

  @override
  void rejectGesture(int pointer) {
    _tapTrackerReset();
  }

  @override
  void dispose() {
    _tapTrackerReset();
    super.dispose();
  }

  void _trackTap(PointerDownEvent event) {
    _down = event;
    _previousButtons = event.buttons;
    _lastTapOffset = event.position;
    _originPosition = OffsetPair(local: event.localPosition, global: event.position);
    onTapTrackStart?.call();
  }

  bool _hasSameButton(int buttons) {
    assert(_previousButtons != null);
    if (buttons == _previousButtons!) {
      return true;
    } else {
      return false;
    }
  }

  bool _isWithinConsecutiveTapTolerance(Offset secondTapOffset) {
    if (_lastTapOffset == null) {
      return false;
    }

    final Offset difference = secondTapOffset - _lastTapOffset!;
    return difference.distance <= kDoubleTapSlop;
  }

  bool _representsSameSeries(PointerDownEvent event) {
    return _consecutiveTapTimer != null
        && _isWithinConsecutiveTapTolerance(event.position)
        && _hasSameButton(event.buttons);
  }

  void _consecutiveTapTimerStart() {
    _consecutiveTapTimer ??= Timer(kDoubleTapTimeout, _consecutiveTapTimerTimeout);
  }

  void _consecutiveTapTimerStop() {
    if (_consecutiveTapTimer != null) {
      _consecutiveTapTimer!.cancel();
      _consecutiveTapTimer = null;
    }
  }

  void _consecutiveTapTimerTimeout() {
    // The consecutive tap timer may time out before a tap down/tap up event is
    // fired. In this case we should not reset the tap tracker state immediately.
    // Instead we should reset the tap tracker on the next call to [addAllowedPointer],
    // if the timer is no longer active.
  }

  void _tapTrackerReset() {
    // The timer has timed out, i.e. the time between a [PointerUpEvent] and the subsequent
    // [PointerDownEvent] exceeded the duration of [kDoubleTapTimeout], so the tap belonging
    // to the [PointerDownEvent] cannot be considered part of the same tap series as the
    // previous [PointerUpEvent].
    _consecutiveTapTimerStop();
    _previousButtons = null;
    _originPosition = null;
    _lastTapOffset = null;
    _consecutiveTapCount = 0;
    _down = null;
    _up = null;
    onTapTrackReset?.call();
  }
}

sealed class BaseTapAndDragGestureRecognizer extends OneSequenceGestureRecognizer with _TapStatusTrackerMixin {
  BaseTapAndDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  }) : _deadline = kPressTimeout,
      dragStartBehavior = DragStartBehavior.start;

  DragStartBehavior dragStartBehavior;

  Duration? dragUpdateThrottleFrequency;

  @override
  int? maxConsecutiveTap;

  GestureTapDragDownCallback? onTapDown;

  GestureTapDragUpCallback? onTapUp;

  GestureTapDragStartCallback? onDragStart;

  GestureTapDragUpdateCallback? onDragUpdate;

  GestureTapDragEndCallback? onDragEnd;

  GestureCancelCallback? onCancel;

  // Tap related state.
  bool _pastSlopTolerance = false;
  bool _sentTapDown = false;
  bool _wonArenaForPrimaryPointer = false;

  // Primary pointer being tracked by this recognizer.
  int? _primaryPointer;
  Timer? _deadlineTimer;
  // The recognizer will call [onTapDown] after this amount of time has elapsed
  // since starting to track the primary pointer.
  //
  // [onTapDown] will not be called if the primary pointer is
  // accepted, rejected, or all pointers are up or canceled before [_deadline].
  final Duration _deadline;

  // Drag related state.
  _DragState _dragState = _DragState.ready;
  PointerEvent? _start;
  late OffsetPair _initialPosition;
  late double _globalDistanceMoved;
  late double _globalDistanceMovedAllAxes;
  OffsetPair? _correctedPosition;

  // For drag update throttle.
  TapDragUpdateDetails? _lastDragUpdateDetails;
  Timer? _dragUpdateThrottleTimer;

  final Set<int> _acceptedActivePointers = <int>{};

  Offset _getDeltaForDetails(Offset delta);
  double? _getPrimaryValueFromOffset(Offset value);
  bool _hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind);

  // Drag updates may require throttling to avoid excessive updating, such as for text layouts in text
  // fields. The frequency of invocations is controlled by the [dragUpdateThrottleFrequency].
  //
  // Once the drag gesture ends, any pending drag update will be fired
  // immediately. See [_checkDragEnd].
  void _handleDragUpdateThrottled() {
    assert(_lastDragUpdateDetails != null);
    if (onDragUpdate != null) {
      invokeCallback<void>('onDragUpdate', () => onDragUpdate!(_lastDragUpdateDetails!));
    }
    _dragUpdateThrottleTimer = null;
    _lastDragUpdateDetails = null;
  }

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (_primaryPointer == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onTapDown == null &&
              onDragStart == null &&
              onDragUpdate == null &&
              onDragEnd == null &&
              onTapUp == null &&
              onCancel == null) {
            return false;
          }
        default:
          return false;
      }
    } else {
      if (event.pointer != _primaryPointer) {
        return false;
      }
    }

    return super.isPointerAllowed(event as PointerDownEvent);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_dragState == _DragState.ready) {
      super.addAllowedPointer(event);
      _primaryPointer = event.pointer;
      _globalDistanceMoved = 0.0;
      _globalDistanceMovedAllAxes = 0.0;
      _dragState = _DragState.possible;
      _initialPosition = OffsetPair(global: event.position, local: event.localPosition);
      _deadlineTimer = Timer(_deadline, () => _didExceedDeadlineWithEvent(event));
    }
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {
    // There can be multiple drags simultaneously. Their effects are combined.
    if (event.buttons != kPrimaryButton) {
      if (!_wonArenaForPrimaryPointer) {
        super.handleNonAllowedPointer(event);
      }
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _primaryPointer) {
      return;
    }

    _stopDeadlineTimer();

    assert(!_acceptedActivePointers.contains(pointer));
    _acceptedActivePointers.add(pointer);

    // Called when this recognizer is accepted by the [GestureArena].
    if (currentDown != null) {
      _checkTapDown(currentDown!);
    }

    _wonArenaForPrimaryPointer = true;

    // resolve(GestureDisposition.accepted) will be called when the [PointerMoveEvent] has
    // moved a sufficient global distance.
    if (_start != null) {
      assert(_dragState == _DragState.accepted);
      assert(currentUp == null);
      _acceptDrag(_start!);
    }

    if (currentUp != null) {
      _checkTapUp(currentUp!);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    switch (_dragState) {
      case _DragState.ready:
        _checkCancel();
        resolve(GestureDisposition.rejected);

      case _DragState.possible:
        if (_pastSlopTolerance) {
          // This means the pointer was not accepted as a tap.
          if (_wonArenaForPrimaryPointer) {
            // If the recognizer has already won the arena for the primary pointer being tracked
            // but the pointer has exceeded the tap tolerance, then the pointer is accepted as a
            // drag gesture.
            if (currentDown != null) {
              if (!_acceptedActivePointers.remove(pointer)) {
                resolvePointer(pointer, GestureDisposition.rejected);
              }
              _dragState = _DragState.accepted;
              _acceptDrag(currentDown!);
              _checkDragEnd();
            }
          } else {
            _checkCancel();
            resolve(GestureDisposition.rejected);
          }
        } else {
          // The pointer is accepted as a tap.
          if (currentUp != null) {
            _checkTapUp(currentUp!);
          }
        }

      case _DragState.accepted:
        // For the case when the pointer has been accepted as a drag.
        // Meaning [_checkTapDown] and [_checkDragStart] have already ran.
        _checkDragEnd();
    }

    _stopDeadlineTimer();
    _dragState = _DragState.ready;
    _pastSlopTolerance = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _primaryPointer) {
      return;
    }
    super.handleEvent(event);
    if (event is PointerMoveEvent) {
      // Receiving a [PointerMoveEvent], does not automatically mean the pointer
      // being tracked is doing a drag gesture. There is some drift that can happen
      // between the initial [PointerDownEvent] and subsequent [PointerMoveEvent]s.
      // Accessing [_pastSlopTolerance] lets us know if our tap has moved past the
      // acceptable tolerance. If the pointer does not move past this tolerance than
      // it is not considered a drag.
      //
      // To be recognized as a drag, the [PointerMoveEvent] must also have moved
      // a sufficient global distance from the initial [PointerDownEvent] to be
      // accepted as a drag. This logic is handled in [_hasSufficientGlobalDistanceToAccept].
      //
      // The recognizer will also detect the gesture as a drag when the pointer
      // has been accepted and it has moved past the [slopTolerance] but has not moved
      // a sufficient global distance from the initial position to be considered a drag.
      // In this case since the gesture cannot be a tap, it defaults to a drag.
      final double computedSlop = computeHitSlop(event.kind, gestureSettings);
      _pastSlopTolerance = _pastSlopTolerance || _getGlobalDistance(event, _initialPosition) > computedSlop;

      if (_dragState == _DragState.accepted) {
        _checkDragUpdate(event);
      } else if (_dragState == _DragState.possible) {
        if (_start == null) {
          // Only check for a drag if the start of a drag was not already identified.
          _checkDrag(event);
        }

        // This can occur when the recognizer is accepted before a [PointerMoveEvent] has been
        // received that moves the pointer a sufficient global distance to be considered a drag.
        if (_start != null) {
          _acceptDrag(_start!);
        }
      }
    } else if (event is PointerUpEvent) {
      if (_dragState == _DragState.possible) {
        // The drag has not been accepted before a [PointerUpEvent], therefore the recognizer
        // attempts to recognize a tap.
        stopTrackingIfPointerNoLongerDown(event);
      } else if (_dragState == _DragState.accepted) {
        _giveUpPointer(event.pointer);
      }
    } else if (event is PointerCancelEvent) {
      _dragState = _DragState.ready;
      _giveUpPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer != _primaryPointer) {
      return;
    }
    super.rejectGesture(pointer);

    _stopDeadlineTimer();
    _giveUpPointer(pointer);
    _resetTaps();
    _resetDragUpdateThrottle();
  }

  @override
  void dispose() {
    _stopDeadlineTimer();
    _resetDragUpdateThrottle();
    super.dispose();
  }

  @override
  String get debugDescription => 'tap_and_drag';

  void _acceptDrag(PointerEvent event) {
    if (!_wonArenaForPrimaryPointer) {
      return;
    }
    if (dragStartBehavior == DragStartBehavior.start) {
      _initialPosition = _initialPosition + OffsetPair(global: event.delta, local: event.localDelta);
    }
    _checkDragStart(event);
    if (event.localDelta != Offset.zero) {
      final Matrix4? localToGlobal = event.transform != null ? Matrix4.tryInvert(event.transform!) : null;
      final Offset correctedLocalPosition = _initialPosition.local + event.localDelta;
      final Offset globalUpdateDelta = PointerEvent.transformDeltaViaPositions(
        untransformedEndPosition: correctedLocalPosition,
        untransformedDelta: event.localDelta,
        transform: localToGlobal,
      );
      final OffsetPair updateDelta = OffsetPair(local: event.localDelta, global: globalUpdateDelta);
      _correctedPosition = _initialPosition + updateDelta; // Only adds delta for down behaviour
      _checkDragUpdate(event);
      _correctedPosition = null;
    }
  }

  void _checkDrag(PointerMoveEvent event) {
    final Matrix4? localToGlobalTransform = event.transform == null ? null : Matrix4.tryInvert(event.transform!);
    final Offset movedLocally = _getDeltaForDetails(event.localDelta);
    _globalDistanceMoved += PointerEvent.transformDeltaViaPositions(
      transform: localToGlobalTransform,
      untransformedDelta: movedLocally,
      untransformedEndPosition: event.localPosition
    ).distance * (_getPrimaryValueFromOffset(movedLocally) ?? 1).sign;
    _globalDistanceMovedAllAxes += PointerEvent.transformDeltaViaPositions(
      transform: localToGlobalTransform,
      untransformedDelta: event.localDelta,
      untransformedEndPosition: event.localPosition
    ).distance * 1.sign;
    if (_hasSufficientGlobalDistanceToAccept(event.kind)
        || (_wonArenaForPrimaryPointer && _globalDistanceMovedAllAxes.abs() > computePanSlop(event.kind, gestureSettings))) {
      _start = event;
      _dragState = _DragState.accepted;
      if (!_wonArenaForPrimaryPointer) {
        resolve(GestureDisposition.accepted);
      }
    }
  }

  void _checkTapDown(PointerDownEvent event) {
    if (_sentTapDown) {
      return;
    }

    final TapDragDownDetails details = TapDragDownDetails(
      globalPosition: event.position,
      localPosition: event.localPosition,
      kind: getKindForPointer(event.pointer),
      consecutiveTapCount: consecutiveTapCount,
    );

    if (onTapDown != null) {
      invokeCallback('onTapDown', () => onTapDown!(details));
    }

    _sentTapDown = true;
  }

  void _checkTapUp(PointerUpEvent event) {
    if (!_wonArenaForPrimaryPointer) {
      return;
    }

    final TapDragUpDetails upDetails = TapDragUpDetails(
      kind: event.kind,
      globalPosition: event.position,
      localPosition: event.localPosition,
      consecutiveTapCount: consecutiveTapCount,
    );

    if (onTapUp != null) {
      invokeCallback('onTapUp', () => onTapUp!(upDetails));
    }

    _resetTaps();
    if (!_acceptedActivePointers.remove(event.pointer)) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
    }
  }

  void _checkDragStart(PointerEvent event) {
    if (onDragStart != null) {
      final TapDragStartDetails details = TapDragStartDetails(
        sourceTimeStamp: event.timeStamp,
        globalPosition: _initialPosition.global,
        localPosition: _initialPosition.local,
        kind: getKindForPointer(event.pointer),
        consecutiveTapCount: consecutiveTapCount,
      );

      invokeCallback<void>('onDragStart', () => onDragStart!(details));
    }

    _start = null;
  }

  void _checkDragUpdate(PointerEvent event) {
    final Offset globalPosition = _correctedPosition != null ? _correctedPosition!.global : event.position;
    final Offset localPosition = _correctedPosition != null ? _correctedPosition!.local : event.localPosition;

    final TapDragUpdateDetails details =  TapDragUpdateDetails(
      sourceTimeStamp: event.timeStamp,
      delta: event.localDelta,
      globalPosition: globalPosition,
      kind: getKindForPointer(event.pointer),
      localPosition: localPosition,
      offsetFromOrigin: globalPosition - _initialPosition.global,
      localOffsetFromOrigin: localPosition - _initialPosition.local,
      consecutiveTapCount: consecutiveTapCount,
    );

    if (dragUpdateThrottleFrequency != null) {
      _lastDragUpdateDetails = details;
      // Only schedule a new timer if there's not one pending.
      _dragUpdateThrottleTimer ??= Timer(dragUpdateThrottleFrequency!, _handleDragUpdateThrottled);
    } else {
      if (onDragUpdate != null) {
        invokeCallback<void>('onDragUpdate', () => onDragUpdate!(details));
      }
    }
  }

  void _checkDragEnd() {
    if (_dragUpdateThrottleTimer != null) {
      // If there's already an update scheduled, trigger it immediately and
      // cancel the timer.
      _dragUpdateThrottleTimer!.cancel();
      _handleDragUpdateThrottled();
    }

    final TapDragEndDetails endDetails =
      TapDragEndDetails(
        primaryVelocity: 0.0,
        consecutiveTapCount: consecutiveTapCount,
      );

    if (onDragEnd != null) {
      invokeCallback<void>('onDragEnd', () => onDragEnd!(endDetails));
    }

    _resetTaps();
    _resetDragUpdateThrottle();
  }

  void _checkCancel() {
    if (!_sentTapDown) {
      // Do not fire tap cancel if [onTapDown] was never called.
      return;
    }
    if (onCancel != null) {
      invokeCallback('onCancel', onCancel!);
    }
    _resetDragUpdateThrottle();
    _resetTaps();
  }

  void _didExceedDeadlineWithEvent(PointerDownEvent event) {
    _didExceedDeadline();
  }

  void _didExceedDeadline() {
    if (currentDown != null) {
      _checkTapDown(currentDown!);

      if (consecutiveTapCount > 1) {
        // If our consecutive tap count is greater than 1, i.e. is a double tap or greater,
        // then this recognizer declares victory to prevent the [LongPressGestureRecognizer]
        // from declaring itself the winner if a double tap is held for too long.
        resolve(GestureDisposition.accepted);
      }
    }
  }

  void _giveUpPointer(int pointer) {
    stopTrackingPointer(pointer);
    // If the pointer was never accepted, then it is rejected since this recognizer is no longer
    // interested in winning the gesture arena for it.
    if (!_acceptedActivePointers.remove(pointer)) {
      resolvePointer(pointer, GestureDisposition.rejected);
    }
  }

  void _resetTaps() {
    _sentTapDown = false;
    _wonArenaForPrimaryPointer = false;
    _primaryPointer = null;
  }

  void _resetDragUpdateThrottle() {
    if (dragUpdateThrottleFrequency == null) {
      return;
    }
    _lastDragUpdateDetails = null;
    if (_dragUpdateThrottleTimer != null) {
      _dragUpdateThrottleTimer!.cancel();
      _dragUpdateThrottleTimer = null;
    }
  }

  void _stopDeadlineTimer() {
    if (_deadlineTimer != null) {
      _deadlineTimer!.cancel();
      _deadlineTimer = null;
    }
  }
}

class TapAndHorizontalDragGestureRecognizer extends BaseTapAndDragGestureRecognizer {
  TapAndHorizontalDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  @override
  bool _hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind) {
    return _globalDistanceMoved.abs() > computeHitSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset _getDeltaForDetails(Offset delta) => Offset(delta.dx, 0.0);

  @override
  double _getPrimaryValueFromOffset(Offset value) => value.dx;

  @override
  String get debugDescription => 'tap and horizontal drag';
}

class TapAndPanGestureRecognizer extends BaseTapAndDragGestureRecognizer {
  TapAndPanGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  @override
  bool _hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind) {
    return _globalDistanceMoved.abs() > computePanSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset _getDeltaForDetails(Offset delta) => delta;

  @override
  double? _getPrimaryValueFromOffset(Offset value) => null;

  @override
  String get debugDescription => 'tap and pan';
}

@Deprecated(
  'Use TapAndPanGestureRecognizer instead. '
  'TapAndPanGestureRecognizer works exactly the same but has a more disambiguated name from BaseTapAndDragGestureRecognizer. '
  'This feature was deprecated after v3.9.0-19.0.pre.'
)
class TapAndDragGestureRecognizer extends BaseTapAndDragGestureRecognizer {
  @Deprecated(
    'Use TapAndPanGestureRecognizer instead. '
    'TapAndPanGestureRecognizer works exactly the same but has a more disambiguated name from BaseTapAndDragGestureRecognizer. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  TapAndDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  @override
  bool _hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind) {
    return _globalDistanceMoved.abs() > computePanSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset _getDeltaForDetails(Offset delta) => delta;

  @override
  double? _getPrimaryValueFromOffset(Offset value) => null;

  @override
  String get debugDescription => 'tap and pan';
}