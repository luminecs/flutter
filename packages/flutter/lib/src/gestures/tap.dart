

import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'constants.dart';
import 'events.dart';
import 'recognizer.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;
export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'arena.dart' show GestureDisposition;
export 'events.dart' show PointerCancelEvent, PointerDownEvent, PointerEvent, PointerUpEvent;

class TapDownDetails {
  TapDownDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.kind,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final PointerDeviceKind? kind;

  final Offset localPosition;
}

typedef GestureTapDownCallback = void Function(TapDownDetails details);

class TapUpDetails {
  TapUpDetails({
    required this.kind,
    this.globalPosition = Offset.zero,
    Offset? localPosition,
  }) : localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind kind;
}

typedef GestureTapUpCallback = void Function(TapUpDetails details);

typedef GestureTapCallback = void Function();

typedef GestureTapCancelCallback = void Function();

abstract class BaseTapGestureRecognizer extends PrimaryPointerGestureRecognizer {
  BaseTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  })
    : super(deadline: kPressTimeout);

  bool _sentTapDown = false;
  bool _wonArenaForPrimaryPointer = false;

  PointerDownEvent? _down;
  PointerUpEvent? _up;

  @protected
  void handleTapDown({ required PointerDownEvent down });

  @protected
  void handleTapUp({ required PointerDownEvent down, required PointerUpEvent up });

  @protected
  void handleTapCancel({ required PointerDownEvent down, PointerCancelEvent? cancel, required String reason });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (state == GestureRecognizerState.ready) {
      // If there is no result in the previous gesture arena,
      // we ignore them and prepare to accept a new pointer.
      if (_down != null && _up != null) {
        assert(_down!.pointer == _up!.pointer);
        _reset();
      }

      assert(_down == null && _up == null);
      // `_down` must be assigned in this method instead of `handlePrimaryPointer`,
      // because `acceptGesture` might be called before `handlePrimaryPointer`,
      // which relies on `_down` to call `handleTapDown`.
      _down = event;
    }
    if (_down != null) {
      // This happens when this tap gesture has been rejected while the pointer
      // is down (i.e. due to movement), when another allowed pointer is added,
      // in which case all pointers are ignored. The `_down` being null
      // means that _reset() has been called, since it is always set at the
      // first allowed down event and will not be cleared except for reset(),
      super.addAllowedPointer(event);
    }
  }

  @override
  @protected
  void startTrackingPointer(int pointer, [Matrix4? transform]) {
    // The recognizer should never track any pointers when `_down` is null,
    // because calling `_checkDown` in this state will throw exception.
    assert(_down != null);
    super.startTrackingPointer(pointer, transform);
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      _up = event;
      _checkUp();
    } else if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
      if (_sentTapDown) {
        _checkCancel(event, '');
      }
      _reset();
    } else if (event.buttons != _down!.buttons) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(primaryPointer!);
    }
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (_wonArenaForPrimaryPointer && disposition == GestureDisposition.rejected) {
      // This can happen if the gesture has been canceled. For example, when
      // the pointer has exceeded the touch slop, the buttons have been changed,
      // or if the recognizer is disposed.
      assert(_sentTapDown);
      _checkCancel(null, 'spontaneous');
      _reset();
    }
    super.resolve(disposition);
  }

  @override
  void didExceedDeadline() {
    _checkDown();
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    if (pointer == primaryPointer) {
      _checkDown();
      _wonArenaForPrimaryPointer = true;
      _checkUp();
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    if (pointer == primaryPointer) {
      // Another gesture won the arena.
      assert(state != GestureRecognizerState.possible);
      if (_sentTapDown) {
        _checkCancel(null, 'forced');
      }
      _reset();
    }
  }

  void _checkDown() {
    if (_sentTapDown) {
      return;
    }
    handleTapDown(down: _down!);
    _sentTapDown = true;
  }

  void _checkUp() {
    if (!_wonArenaForPrimaryPointer || _up == null) {
      return;
    }
    assert(_up!.pointer == _down!.pointer);
    handleTapUp(down: _down!, up: _up!);
    _reset();
  }

  void _checkCancel(PointerCancelEvent? event, String note) {
    handleTapCancel(down: _down!, cancel: event, reason: note);
  }

  void _reset() {
    _sentTapDown = false;
    _wonArenaForPrimaryPointer = false;
    _up = null;
    _down = null;
  }

  @override
  String get debugDescription => 'base tap';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('wonArenaForPrimaryPointer', value: _wonArenaForPrimaryPointer, ifTrue: 'won arena'));
    properties.add(DiagnosticsProperty<Offset>('finalPosition', _up?.position, defaultValue: null));
    properties.add(DiagnosticsProperty<Offset>('finalLocalPosition', _up?.localPosition, defaultValue: _up?.position));
    properties.add(DiagnosticsProperty<int>('button', _down?.buttons, defaultValue: null));
    properties.add(FlagProperty('sentTapDown', value: _sentTapDown, ifTrue: 'sent tap down'));
  }
}

class TapGestureRecognizer extends BaseTapGestureRecognizer {
  TapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  GestureTapDownCallback? onTapDown;

  GestureTapUpCallback? onTapUp;

  GestureTapCallback? onTap;

  GestureTapCancelCallback? onTapCancel;

  GestureTapCallback? onSecondaryTap;

  GestureTapDownCallback? onSecondaryTapDown;

  GestureTapUpCallback? onSecondaryTapUp;

  GestureTapCancelCallback? onSecondaryTapCancel;

  GestureTapDownCallback? onTertiaryTapDown;

  GestureTapUpCallback? onTertiaryTapUp;

  GestureTapCancelCallback? onTertiaryTapCancel;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    switch (event.buttons) {
      case kPrimaryButton:
        if (onTapDown == null &&
            onTap == null &&
            onTapUp == null &&
            onTapCancel == null) {
          return false;
        }
      case kSecondaryButton:
        if (onSecondaryTap == null &&
            onSecondaryTapDown == null &&
            onSecondaryTapUp == null &&
            onSecondaryTapCancel == null) {
          return false;
        }
      case kTertiaryButton:
        if (onTertiaryTapDown == null &&
            onTertiaryTapUp == null &&
            onTertiaryTapCancel == null) {
          return false;
        }
      default:
        return false;
    }
    return super.isPointerAllowed(event);
  }

  @protected
  @override
  void handleTapDown({required PointerDownEvent down}) {
    final TapDownDetails details = TapDownDetails(
      globalPosition: down.position,
      localPosition: down.localPosition,
      kind: getKindForPointer(down.pointer),
    );
    switch (down.buttons) {
      case kPrimaryButton:
        if (onTapDown != null) {
          invokeCallback<void>('onTapDown', () => onTapDown!(details));
        }
      case kSecondaryButton:
        if (onSecondaryTapDown != null) {
          invokeCallback<void>('onSecondaryTapDown', () => onSecondaryTapDown!(details));
        }
      case kTertiaryButton:
        if (onTertiaryTapDown != null) {
          invokeCallback<void>('onTertiaryTapDown', () => onTertiaryTapDown!(details));
        }
      default:
    }
  }

  @protected
  @override
  void handleTapUp({ required PointerDownEvent down, required PointerUpEvent up}) {
    final TapUpDetails details = TapUpDetails(
      kind: up.kind,
      globalPosition: up.position,
      localPosition: up.localPosition,
    );
    switch (down.buttons) {
      case kPrimaryButton:
        if (onTapUp != null) {
          invokeCallback<void>('onTapUp', () => onTapUp!(details));
        }
        if (onTap != null) {
          invokeCallback<void>('onTap', onTap!);
        }
      case kSecondaryButton:
        if (onSecondaryTapUp != null) {
          invokeCallback<void>('onSecondaryTapUp', () => onSecondaryTapUp!(details));
        }
        if (onSecondaryTap != null) {
          invokeCallback<void>('onSecondaryTap', () => onSecondaryTap!());
        }
      case kTertiaryButton:
        if (onTertiaryTapUp != null) {
          invokeCallback<void>('onTertiaryTapUp', () => onTertiaryTapUp!(details));
        }
      default:
    }
  }

  @protected
  @override
  void handleTapCancel({ required PointerDownEvent down, PointerCancelEvent? cancel, required String reason }) {
    final String note = reason == '' ? reason : '$reason ';
    switch (down.buttons) {
      case kPrimaryButton:
        if (onTapCancel != null) {
          invokeCallback<void>('${note}onTapCancel', onTapCancel!);
        }
      case kSecondaryButton:
        if (onSecondaryTapCancel != null) {
          invokeCallback<void>('${note}onSecondaryTapCancel', onSecondaryTapCancel!);
        }
      case kTertiaryButton:
        if (onTertiaryTapCancel != null) {
          invokeCallback<void>('${note}onTertiaryTapCancel', onTertiaryTapCancel!);
        }
      default:
    }
  }

  @override
  String get debugDescription => 'tap';
}