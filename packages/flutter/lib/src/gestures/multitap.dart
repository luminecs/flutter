import 'dart:async';

import 'arena.dart';
import 'binding.dart';
import 'constants.dart';
import 'events.dart';
import 'pointer_router.dart';
import 'recognizer.dart';
import 'tap.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'events.dart' show PointerDownEvent;
export 'tap.dart' show GestureTapCancelCallback, GestureTapDownCallback, TapDownDetails, TapUpDetails;

typedef GestureDoubleTapCallback = void Function();

typedef GestureMultiTapDownCallback = void Function(int pointer, TapDownDetails details);

typedef GestureMultiTapUpCallback = void Function(int pointer, TapUpDetails details);

typedef GestureMultiTapCallback = void Function(int pointer);

typedef GestureMultiTapCancelCallback = void Function(int pointer);

class _CountdownZoned {
  _CountdownZoned({ required Duration duration }) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}

class _TapTracker {
  _TapTracker({
    required PointerDownEvent event,
    required this.entry,
    required Duration doubleTapMinTime,
    required this.gestureSettings,
  }) : pointer = event.pointer,
       _initialGlobalPosition = event.position,
       initialButtons = event.buttons,
       _doubleTapMinTimeCountdown = _CountdownZoned(duration: doubleTapMinTime);

  final DeviceGestureSettings? gestureSettings;
  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4? transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      GestureBinding.instance.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      GestureBinding.instance.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

class DoubleTapGestureRecognizer extends GestureRecognizer {
  DoubleTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    AllowedButtonsFilter? allowedButtonsFilter,
  }) : super(allowedButtonsFilter: allowedButtonsFilter ?? _defaultButtonAcceptBehavior);

  // The default value for [allowedButtonsFilter].
  // Accept the input if, and only if, [kPrimaryButton] is pressed.
  static bool _defaultButtonAcceptBehavior(int buttons) => buttons == kPrimaryButton;

  // Implementation notes:
  //
  // The double tap recognizer can be in one of four states. There's no
  // explicit enum for the states, because they are already captured by
  // the state of existing fields. Specifically:
  //
  // 1. Waiting on first tap: In this state, the _trackers list is empty, and
  //    _firstTap is null.
  // 2. First tap in progress: In this state, the _trackers list contains all
  //    the states for taps that have begun but not completed. This list can
  //    have more than one entry if two pointers begin to tap.
  // 3. Waiting on second tap: In this state, one of the in-progress taps has
  //    completed successfully. The _trackers list is again empty, and
  //    _firstTap records the successful tap.
  // 4. Second tap in progress: Much like the "first tap in progress" state, but
  //    _firstTap is non-null. If a tap completes successfully while in this
  //    state, the callback is called and the state is reset.
  //
  // There are various other scenarios that cause the state to reset:
  //
  // - All in-progress taps are rejected (by time, distance, pointercancel, etc)
  // - The long timer between taps expires
  // - The gesture arena decides we have been rejected wholesale

  GestureTapDownCallback? onDoubleTapDown;

  GestureDoubleTapCallback? onDoubleTap;

  GestureTapCancelCallback? onDoubleTapCancel;

  Timer? _doubleTapTimer;
  _TapTracker? _firstTap;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_firstTap == null) {
      if (onDoubleTapDown == null &&
          onDoubleTap == null &&
          onDoubleTapCancel == null) {
        return false;
      }
    }

    // If second tap is not allowed, reset the state.
    final bool isPointerAllowed = super.isPointerAllowed(event);
    if (!isPointerAllowed) {
      _reset();
    }
    return isPointerAllowed;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_firstTap != null) {
      if (!_firstTap!.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        // Ignore out-of-bounds second taps.
        return;
      } else if (!_firstTap!.hasElapsedMinTime() || !_firstTap!.hasSameButton(event)) {
        // Restart when the second tap is too close to the first (touch screens
        // often detect touches intermittently), or when buttons mismatch.
        _reset();
        return _trackTap(event);
      } else if (onDoubleTapDown != null) {
        final TapDownDetails details = TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: getKindForPointer(event.pointer),
        );
        invokeCallback<void>('onDoubleTapDown', () => onDoubleTapDown!(details));
      }
    }
    _trackTap(event);
  }

  void _trackTap(PointerDownEvent event) {
    _stopDoubleTapTimer();
    final _TapTracker tracker = _TapTracker(
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
      gestureSettings: gestureSettings,
    );
    _trackers[event.pointer] = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer]!;
    if (event is PointerUpEvent) {
      if (_firstTap == null) {
        _registerFirstTap(tracker);
      } else {
        _registerSecondTap(tracker);
      }
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        _reject(tracker);
      }
    } else if (event is PointerCancelEvent) {
      _reject(tracker);
    }
  }

  @override
  void acceptGesture(int pointer) { }

  @override
  void rejectGesture(int pointer) {
    _TapTracker? tracker = _trackers[pointer];
    // If tracker isn't in the list, check if this is the first tap tracker
    if (tracker == null &&
        _firstTap != null &&
        _firstTap!.pointer == pointer) {
      tracker = _firstTap;
    }
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) {
      _reject(tracker);
    }
  }

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null) {
      if (tracker == _firstTap) {
        _reset();
      } else {
        _checkCancel();
        if (_trackers.isEmpty) {
          _reset();
        }
      }
    }
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    _stopDoubleTapTimer();
    if (_firstTap != null) {
      if (_trackers.isNotEmpty) {
        _checkCancel();
      }
      // Note, order is important below in order for the resolve -> reject logic
      // to work properly.
      final _TapTracker tracker = _firstTap!;
      _firstTap = null;
      _reject(tracker);
      GestureBinding.instance.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startDoubleTapTimer();
    GestureBinding.instance.gestureArena.hold(tracker.pointer);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _registerSecondTap(_TapTracker tracker) {
    _firstTap!.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkUp(tracker.initialButtons);
    _reset();
  }

  void _clearTrackers() {
    _trackers.values.toList().forEach(_reject);
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startDoubleTapTimer() {
    _doubleTapTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopDoubleTapTimer() {
    if (_doubleTapTimer != null) {
      _doubleTapTimer!.cancel();
      _doubleTapTimer = null;
    }
  }

  void _checkUp(int buttons) {
    if (onDoubleTap != null) {
      invokeCallback<void>('onDoubleTap', onDoubleTap!);
    }
  }

  void _checkCancel() {
    if (onDoubleTapCancel != null) {
      invokeCallback<void>('onDoubleTapCancel', onDoubleTapCancel!);
    }
  }

  @override
  String get debugDescription => 'double tap';
}

class _TapGesture extends _TapTracker {

  _TapGesture({
    required this.gestureRecognizer,
    required PointerEvent event,
    required Duration longTapDelay,
    required super.gestureSettings,
  }) : _lastPosition = OffsetPair.fromEventPosition(event),
       super(
    event: event as PointerDownEvent,
    entry: GestureBinding.instance.gestureArena.add(event.pointer, gestureRecognizer),
    doubleTapMinTime: kDoubleTapMinTime,
  ) {
    startTrackingPointer(handleEvent, event.transform);
    if (longTapDelay > Duration.zero) {
      _timer = Timer(longTapDelay, () {
        _timer = null;
        gestureRecognizer._dispatchLongTap(event.pointer, _lastPosition);
      });
    }
  }

  final MultiTapGestureRecognizer gestureRecognizer;

  bool _wonArena = false;
  Timer? _timer;

  OffsetPair _lastPosition;
  OffsetPair? _finalPosition;

  void handleEvent(PointerEvent event) {
    assert(event.pointer == pointer);
    if (event is PointerMoveEvent) {
      if (!isWithinGlobalTolerance(event, computeHitSlop(event.kind, gestureSettings))) {
        cancel();
      } else {
        _lastPosition = OffsetPair.fromEventPosition(event);
      }
    } else if (event is PointerCancelEvent) {
      cancel();
    } else if (event is PointerUpEvent) {
      stopTrackingPointer(handleEvent);
      _finalPosition = OffsetPair.fromEventPosition(event);
      _check();
    }
  }

  @override
  void stopTrackingPointer(PointerRoute route) {
    _timer?.cancel();
    _timer = null;
    super.stopTrackingPointer(route);
  }

  void accept() {
    _wonArena = true;
    _check();
  }

  void reject() {
    stopTrackingPointer(handleEvent);
    gestureRecognizer._dispatchCancel(pointer);
  }

  void cancel() {
    // If we won the arena already, then entry is resolved, so resolving
    // again is a no-op. But we still need to clean up our own state.
    if (_wonArena) {
      reject();
    } else {
      entry.resolve(GestureDisposition.rejected); // eventually calls reject()
    }
  }

  void _check() {
    if (_wonArena && _finalPosition != null) {
      gestureRecognizer._dispatchTap(pointer, _finalPosition!);
    }
  }
}

class MultiTapGestureRecognizer extends GestureRecognizer {
  MultiTapGestureRecognizer({
    this.longTapDelay = Duration.zero,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  GestureMultiTapDownCallback? onTapDown;

  GestureMultiTapUpCallback? onTapUp;

  GestureMultiTapCallback? onTap;

  GestureMultiTapCancelCallback? onTapCancel;

  Duration longTapDelay;

  GestureMultiTapDownCallback? onLongTapDown;

  final Map<int, _TapGesture> _gestureMap = <int, _TapGesture>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(!_gestureMap.containsKey(event.pointer));
    _gestureMap[event.pointer] = _TapGesture(
      gestureRecognizer: this,
      event: event,
      longTapDelay: longTapDelay,
      gestureSettings: gestureSettings,
    );
    if (onTapDown != null) {
      invokeCallback<void>('onTapDown', () {
        onTapDown!(event.pointer, TapDownDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          kind: event.kind,
        ));
      });
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap[pointer]!.accept();
  }

  @override
  void rejectGesture(int pointer) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap[pointer]!.reject();
    assert(!_gestureMap.containsKey(pointer));
  }

  void _dispatchCancel(int pointer) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap.remove(pointer);
    if (onTapCancel != null) {
      invokeCallback<void>('onTapCancel', () => onTapCancel!(pointer));
    }
  }

  void _dispatchTap(int pointer, OffsetPair position) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap.remove(pointer);
    if (onTapUp != null) {
      invokeCallback<void>('onTapUp', () {
        onTapUp!(pointer, TapUpDetails(
          kind: getKindForPointer(pointer),
          localPosition: position.local,
          globalPosition: position.global,
        ));
      });
    }
    if (onTap != null) {
      invokeCallback<void>('onTap', () => onTap!(pointer));
    }
  }

  void _dispatchLongTap(int pointer, OffsetPair lastPosition) {
    assert(_gestureMap.containsKey(pointer));
    if (onLongTapDown != null) {
      invokeCallback<void>('onLongTapDown', () {
        onLongTapDown!(
          pointer,
          TapDownDetails(
            globalPosition: lastPosition.global,
            localPosition: lastPosition.local,
            kind: getKindForPointer(pointer),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    final List<_TapGesture> localGestures = List<_TapGesture>.of(_gestureMap.values);
    for (final _TapGesture gesture in localGestures) {
      gesture.cancel();
    }
    // Rejection of each gesture should cause it to be removed from our map
    assert(_gestureMap.isEmpty);
    super.dispose();
  }

  @override
  String get debugDescription => 'multitap';
}

typedef GestureSerialTapDownCallback = void Function(SerialTapDownDetails details);

class SerialTapDownDetails {
  SerialTapDownDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    required this.kind,
    this.buttons = 0,
    this.count = 1,
  }) : assert(count > 0),
       localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind kind;

  final int buttons;

  final int count;
}

typedef GestureSerialTapCancelCallback = void Function(SerialTapCancelDetails details);

class SerialTapCancelDetails {
  SerialTapCancelDetails({
    this.count = 1,
  }) : assert(count > 0);

  final int count;
}

typedef GestureSerialTapUpCallback = void Function(SerialTapUpDetails details);

class SerialTapUpDetails {
  SerialTapUpDetails({
    this.globalPosition = Offset.zero,
    Offset? localPosition,
    this.kind,
    this.count = 1,
  }) : assert(count > 0),
       localPosition = localPosition ?? globalPosition;

  final Offset globalPosition;

  final Offset localPosition;

  final PointerDeviceKind? kind;

  final int count;
}

class SerialTapGestureRecognizer extends GestureRecognizer {
  SerialTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  GestureSerialTapDownCallback? onSerialTapDown;

  GestureSerialTapCancelCallback? onSerialTapCancel;

  GestureSerialTapUpCallback? onSerialTapUp;

  Timer? _serialTapTimer;
  final List<_TapTracker> _completedTaps = <_TapTracker>[];
  final Map<int, GestureDisposition> _gestureResolutions = <int, GestureDisposition>{};
  _TapTracker? _pendingTap;

  bool get isTrackingPointer => _pendingTap != null;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (onSerialTapDown == null &&
        onSerialTapCancel == null &&
        onSerialTapUp == null) {
      return false;
    }
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if ((_completedTaps.isNotEmpty && !_representsSameSeries(_completedTaps.last, event))
        || _pendingTap != null) {
      _reset();
    }
    _trackTap(event);
  }

  bool _representsSameSeries(_TapTracker tap, PointerDownEvent event) {
    return tap.hasElapsedMinTime() // touch screens often detect touches intermittently
        && tap.hasSameButton(event)
        && tap.isWithinGlobalTolerance(event, kDoubleTapSlop);
  }

  void _trackTap(PointerDownEvent event) {
    _stopSerialTapTimer();
    if (onSerialTapDown != null) {
      final SerialTapDownDetails details = SerialTapDownDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: getKindForPointer(event.pointer),
        buttons: event.buttons,
        count: _completedTaps.length + 1,
      );
      invokeCallback<void>('onSerialTapDown', () => onSerialTapDown!(details));
    }
    final _TapTracker tracker = _TapTracker(
      gestureSettings: gestureSettings,
      event: event,
      entry: GestureBinding.instance.gestureArena.add(event.pointer, this),
      doubleTapMinTime: kDoubleTapMinTime,
    );
    assert(_pendingTap == null);
    _pendingTap = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    assert(_pendingTap != null);
    assert(_pendingTap!.pointer == event.pointer);
    final _TapTracker tracker = _pendingTap!;
    if (event is PointerUpEvent) {
      _registerTap(event, tracker);
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop)) {
        _reset();
      }
    } else if (event is PointerCancelEvent) {
      _reset();
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_pendingTap != null);
    assert(_pendingTap!.pointer == pointer);
    _gestureResolutions[pointer] = GestureDisposition.accepted;
  }

  @override
  void rejectGesture(int pointer) {
    _gestureResolutions[pointer] = GestureDisposition.rejected;
    _reset();
  }

  void _rejectPendingTap() {
    assert(_pendingTap != null);
    final _TapTracker tracker = _pendingTap!;
    _pendingTap = null;
    // Order is important here; the `resolve` call can yield a re-entrant
    // `reset()`, so we need to check cancel here while we can trust the
    // length of our _completedTaps list.
    _checkCancel(_completedTaps.length + 1);
    if (!_gestureResolutions.containsKey(tracker.pointer)) {
      tracker.entry.resolve(GestureDisposition.rejected);
    }
    _stopTrackingPointer(tracker);
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    if (_pendingTap != null) {
      _rejectPendingTap();
    }
    _pendingTap = null;
    _completedTaps.clear();
    _gestureResolutions.clear();
    _stopSerialTapTimer();
  }

  void _registerTap(PointerUpEvent event, _TapTracker tracker) {
    assert(tracker == _pendingTap);
    assert(tracker.pointer == event.pointer);
    _startSerialTapTimer();
    assert(_gestureResolutions[event.pointer] != GestureDisposition.rejected);
    if (!_gestureResolutions.containsKey(event.pointer)) {
      tracker.entry.resolve(GestureDisposition.accepted);
    }
    assert(_gestureResolutions[event.pointer] == GestureDisposition.accepted);
    _stopTrackingPointer(tracker);
    // Note, order is important below in order for the clear -> reject logic to
    // work properly.
    _pendingTap = null;
    _checkUp(event, tracker);
    _completedTaps.add(tracker);
  }

  void _stopTrackingPointer(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startSerialTapTimer() {
    _serialTapTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopSerialTapTimer() {
    if (_serialTapTimer != null) {
      _serialTapTimer!.cancel();
      _serialTapTimer = null;
    }
  }

  void _checkUp(PointerUpEvent event, _TapTracker tracker) {
    if (onSerialTapUp != null) {
      final SerialTapUpDetails details = SerialTapUpDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        kind: getKindForPointer(tracker.pointer),
        count: _completedTaps.length + 1,
      );
      invokeCallback<void>('onSerialTapUp', () => onSerialTapUp!(details));
    }
  }

  void _checkCancel(int count) {
    if (onSerialTapCancel != null) {
      final SerialTapCancelDetails details = SerialTapCancelDetails(
        count: count,
      );
      invokeCallback<void>('onSerialTapCancel', () => onSerialTapCancel!(details));
    }
  }

  @override
  String get debugDescription => 'serial tap';
}