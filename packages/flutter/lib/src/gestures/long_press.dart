
import 'constants.dart';
import 'events.dart';
import 'recognizer.dart';
import 'velocity_tracker.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'arena.dart' show GestureDisposition;
export 'events.dart' show PointerDownEvent, PointerEvent;
export 'velocity_tracker.dart' show Velocity;

typedef GestureLongPressDownCallback = void Function(LongPressDownDetails details);

typedef GestureLongPressCancelCallback = void Function();

typedef GestureLongPressCallback = void Function();

typedef GestureLongPressUpCallback = void Function();

typedef GestureLongPressStartCallback = void Function(LongPressStartDetails details);

typedef GestureLongPressMoveUpdateCallback = void Function(LongPressMoveUpdateDetails details);

typedef GestureLongPressEndCallback = void Function(LongPressEndDetails details);

class LongPressDownDetails {
  const LongPressDownDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.kind,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final PointerDeviceKind? kind;

  final Offset localPosition;
}

class LongPressStartDetails {
  const LongPressStartDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;
}

class LongPressMoveUpdateDetails {
  const LongPressMoveUpdateDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.offsetFromOrigin = Offset.zero,
    Offset? localOffsetFromOrigin,
  }) : localPosition = localPosition ?? globalPosition,
       localOffsetFromOrigin = localOffsetFromOrigin ?? offsetFromOrigin;

  final Offset globalPosition;

  final Offset localPosition;

  final Offset offsetFromOrigin;

  final Offset localOffsetFromOrigin;
}

class LongPressEndDetails {
  const LongPressEndDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.velocity = Velocity.zero,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;

  final Velocity velocity;
}

class LongPressGestureRecognizer extends PrimaryPointerGestureRecognizer {
  LongPressGestureRecognizer({
    Duration? duration,
    super.postAcceptSlopTolerance = null,
    super.supportedDevices,
    super.debugOwner,
    AllowedButtonsFilter? allowedButtonsFilter,
  }) : super(
         deadline: duration ?? kLongPressTimeout,
         allowedButtonsFilter: allowedButtonsFilter ?? _defaultButtonAcceptBehavior,
       );

  bool _longPressAccepted = false;
  OffsetPair? _longPressOrigin;
  // The buttons sent by `PointerDownEvent`. If a `PointerMoveEvent` comes with a
  // different set of buttons, the gesture is canceled.
  int? _initialButtons;

  // Accept the input if, and only if, a single button is pressed.
  static bool _defaultButtonAcceptBehavior(int buttons) =>
      buttons == kPrimaryButton ||
      buttons == kSecondaryButton ||
      buttons == kTertiaryButton;

  GestureLongPressDownCallback? onLongPressDown;

  GestureLongPressCancelCallback? onLongPressCancel;

  GestureLongPressCallback? onLongPress;

  GestureLongPressStartCallback? onLongPressStart;

  GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;

  GestureLongPressUpCallback? onLongPressUp;

  GestureLongPressEndCallback? onLongPressEnd;

  GestureLongPressDownCallback? onSecondaryLongPressDown;

  GestureLongPressCancelCallback? onSecondaryLongPressCancel;

  GestureLongPressCallback? onSecondaryLongPress;

  GestureLongPressStartCallback? onSecondaryLongPressStart;

  GestureLongPressMoveUpdateCallback? onSecondaryLongPressMoveUpdate;

  GestureLongPressUpCallback? onSecondaryLongPressUp;

  GestureLongPressEndCallback? onSecondaryLongPressEnd;

  GestureLongPressDownCallback? onTertiaryLongPressDown;

  GestureLongPressCancelCallback? onTertiaryLongPressCancel;

  GestureLongPressCallback? onTertiaryLongPress;

  GestureLongPressStartCallback? onTertiaryLongPressStart;

  GestureLongPressMoveUpdateCallback? onTertiaryLongPressMoveUpdate;

  GestureLongPressUpCallback? onTertiaryLongPressUp;

  GestureLongPressEndCallback? onTertiaryLongPressEnd;

  VelocityTracker? _velocityTracker;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    switch (event.buttons) {
      case kPrimaryButton:
        if (onLongPressDown == null &&
            onLongPressCancel == null &&
            onLongPressStart == null &&
            onLongPress == null &&
            onLongPressMoveUpdate == null &&
            onLongPressEnd == null &&
            onLongPressUp == null) {
          return false;
        }
      case kSecondaryButton:
        if (onSecondaryLongPressDown == null &&
            onSecondaryLongPressCancel == null &&
            onSecondaryLongPressStart == null &&
            onSecondaryLongPress == null &&
            onSecondaryLongPressMoveUpdate == null &&
            onSecondaryLongPressEnd == null &&
            onSecondaryLongPressUp == null) {
          return false;
        }
      case kTertiaryButton:
        if (onTertiaryLongPressDown == null &&
            onTertiaryLongPressCancel == null &&
            onTertiaryLongPressStart == null &&
            onTertiaryLongPress == null &&
            onTertiaryLongPressMoveUpdate == null &&
            onTertiaryLongPressEnd == null &&
            onTertiaryLongPressUp == null) {
          return false;
        }
      default:
        return false;
    }
    return super.isPointerAllowed(event);
  }

  @override
  void didExceedDeadline() {
    // Exceeding the deadline puts the gesture in the accepted state.
    resolve(GestureDisposition.accepted);
    _longPressAccepted = true;
    super.acceptGesture(primaryPointer!);
    _checkLongPressStart();
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (!event.synthesized) {
      if (event is PointerDownEvent) {
        _velocityTracker = VelocityTracker.withKind(event.kind);
        _velocityTracker!.addPosition(event.timeStamp, event.localPosition);
      }
      if (event is PointerMoveEvent) {
        assert(_velocityTracker != null);
        _velocityTracker!.addPosition(event.timeStamp, event.localPosition);
      }
    }

    if (event is PointerUpEvent) {
      if (_longPressAccepted) {
        _checkLongPressEnd(event);
      } else {
        // Pointer is lifted before timeout.
        resolve(GestureDisposition.rejected);
      }
      _reset();
    } else if (event is PointerCancelEvent) {
      _checkLongPressCancel();
      _reset();
    } else if (event is PointerDownEvent) {
      // The first touch.
      _longPressOrigin = OffsetPair.fromEventPosition(event);
      _initialButtons = event.buttons;
      _checkLongPressDown(event);
    } else if (event is PointerMoveEvent) {
      if (event.buttons != _initialButtons && !_longPressAccepted) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(primaryPointer!);
      } else if (_longPressAccepted) {
        _checkLongPressMoveUpdate(event);
      }
    }
  }

  void _checkLongPressDown(PointerDownEvent event) {
    assert(_longPressOrigin != null);
    final LongPressDownDetails details = LongPressDownDetails(
      globalPosition: _longPressOrigin!.global,
      localPosition: _longPressOrigin!.local,
      kind: getKindForPointer(event.pointer),
    );
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressDown != null) {
          invokeCallback<void>('onLongPressDown', () => onLongPressDown!(details));
        }
      case kSecondaryButton:
        if (onSecondaryLongPressDown != null) {
          invokeCallback<void>('onSecondaryLongPressDown', () => onSecondaryLongPressDown!(details));
        }
      case kTertiaryButton:
        if (onTertiaryLongPressDown != null) {
          invokeCallback<void>('onTertiaryLongPressDown', () => onTertiaryLongPressDown!(details));
        }
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _checkLongPressCancel() {
    if (state == GestureRecognizerState.possible) {
      switch (_initialButtons) {
        case kPrimaryButton:
          if (onLongPressCancel != null) {
            invokeCallback<void>('onLongPressCancel', onLongPressCancel!);
          }
        case kSecondaryButton:
          if (onSecondaryLongPressCancel != null) {
            invokeCallback<void>('onSecondaryLongPressCancel', onSecondaryLongPressCancel!);
          }
        case kTertiaryButton:
          if (onTertiaryLongPressCancel != null) {
            invokeCallback<void>('onTertiaryLongPressCancel', onTertiaryLongPressCancel!);
          }
        default:
          assert(false, 'Unhandled button $_initialButtons');
      }
    }
  }

  void _checkLongPressStart() {
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressStart != null) {
          final LongPressStartDetails details = LongPressStartDetails(
            globalPosition: _longPressOrigin!.global,
            localPosition: _longPressOrigin!.local,
          );
          invokeCallback<void>('onLongPressStart', () => onLongPressStart!(details));
        }
        if (onLongPress != null) {
          invokeCallback<void>('onLongPress', onLongPress!);
        }
      case kSecondaryButton:
        if (onSecondaryLongPressStart != null) {
          final LongPressStartDetails details = LongPressStartDetails(
            globalPosition: _longPressOrigin!.global,
            localPosition: _longPressOrigin!.local,
          );
          invokeCallback<void>('onSecondaryLongPressStart', () => onSecondaryLongPressStart!(details));
        }
        if (onSecondaryLongPress != null) {
          invokeCallback<void>('onSecondaryLongPress', onSecondaryLongPress!);
        }
      case kTertiaryButton:
        if (onTertiaryLongPressStart != null) {
          final LongPressStartDetails details = LongPressStartDetails(
            globalPosition: _longPressOrigin!.global,
            localPosition: _longPressOrigin!.local,
          );
          invokeCallback<void>('onTertiaryLongPressStart', () => onTertiaryLongPressStart!(details));
        }
        if (onTertiaryLongPress != null) {
          invokeCallback<void>('onTertiaryLongPress', onTertiaryLongPress!);
        }
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _checkLongPressMoveUpdate(PointerEvent event) {
    final LongPressMoveUpdateDetails details = LongPressMoveUpdateDetails(
      globalPosition: event.position,
      localPosition: event.localPosition,
      offsetFromOrigin: event.position - _longPressOrigin!.global,
      localOffsetFromOrigin: event.localPosition - _longPressOrigin!.local,
    );
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressMoveUpdate != null) {
          invokeCallback<void>('onLongPressMoveUpdate', () => onLongPressMoveUpdate!(details));
        }
      case kSecondaryButton:
        if (onSecondaryLongPressMoveUpdate != null) {
          invokeCallback<void>('onSecondaryLongPressMoveUpdate', () => onSecondaryLongPressMoveUpdate!(details));
        }
      case kTertiaryButton:
        if (onTertiaryLongPressMoveUpdate != null) {
          invokeCallback<void>('onTertiaryLongPressMoveUpdate', () => onTertiaryLongPressMoveUpdate!(details));
        }
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _checkLongPressEnd(PointerEvent event) {
    final VelocityEstimate? estimate = _velocityTracker!.getVelocityEstimate();
    final Velocity velocity = estimate == null
        ? Velocity.zero
        : Velocity(pixelsPerSecond: estimate.pixelsPerSecond);
    final LongPressEndDetails details = LongPressEndDetails(
      globalPosition: event.position,
      localPosition: event.localPosition,
      velocity: velocity,
    );

    _velocityTracker = null;
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressEnd != null) {
          invokeCallback<void>('onLongPressEnd', () => onLongPressEnd!(details));
        }
        if (onLongPressUp != null) {
          invokeCallback<void>('onLongPressUp', onLongPressUp!);
        }
      case kSecondaryButton:
        if (onSecondaryLongPressEnd != null) {
          invokeCallback<void>('onSecondaryLongPressEnd', () => onSecondaryLongPressEnd!(details));
        }
        if (onSecondaryLongPressUp != null) {
          invokeCallback<void>('onSecondaryLongPressUp', onSecondaryLongPressUp!);
        }
      case kTertiaryButton:
        if (onTertiaryLongPressEnd != null) {
          invokeCallback<void>('onTertiaryLongPressEnd', () => onTertiaryLongPressEnd!(details));
        }
        if (onTertiaryLongPressUp != null) {
          invokeCallback<void>('onTertiaryLongPressUp', onTertiaryLongPressUp!);
        }
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _reset() {
    _longPressAccepted = false;
    _longPressOrigin = null;
    _initialButtons = null;
    _velocityTracker = null;
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.rejected) {
      if (_longPressAccepted) {
        // This can happen if the gesture has been canceled. For example when
        // the buttons have changed.
        _reset();
      } else {
        _checkLongPressCancel();
      }
    }
    super.resolve(disposition);
  }

  @override
  void acceptGesture(int pointer) {
    // Winning the arena isn't important here since it may happen from a sweep.
    // Explicitly exceeding the deadline puts the gesture in accepted state.
  }

  @override
  String get debugDescription => 'long press';
}