import 'dart:async';

import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'binding.dart';
import 'constants.dart';
import 'drag.dart';
import 'drag_details.dart';
import 'events.dart';
import 'recognizer.dart';
import 'velocity_tracker.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'arena.dart' show GestureDisposition;
export 'drag.dart' show Drag;
export 'events.dart' show PointerDownEvent;
export 'gesture_settings.dart' show DeviceGestureSettings;

typedef GestureMultiDragStartCallback = Drag? Function(Offset position);

abstract class MultiDragPointerState {
  MultiDragPointerState(this.initialPosition, this.kind, this.gestureSettings)
      : _velocityTracker = VelocityTracker.withKind(kind);

  final DeviceGestureSettings? gestureSettings;

  final Offset initialPosition;

  final VelocityTracker _velocityTracker;

  final PointerDeviceKind kind;

  Drag? _client;

  Offset? get pendingDelta => _pendingDelta;
  Offset? _pendingDelta = Offset.zero;

  Duration? _lastPendingEventTimestamp;

  GestureArenaEntry? _arenaEntry;
  void _setArenaEntry(GestureArenaEntry entry) {
    assert(_arenaEntry == null);
    assert(pendingDelta != null);
    assert(_client == null);
    _arenaEntry = entry;
  }

  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    _arenaEntry!.resolve(disposition);
  }

  void _move(PointerMoveEvent event) {
    assert(_arenaEntry != null);
    if (!event.synthesized) {
      _velocityTracker.addPosition(event.timeStamp, event.position);
    }
    if (_client != null) {
      assert(pendingDelta == null);
      // Call client last to avoid reentrancy.
      _client!.update(DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.delta,
        globalPosition: event.position,
      ));
    } else {
      assert(pendingDelta != null);
      _pendingDelta = _pendingDelta! + event.delta;
      _lastPendingEventTimestamp = event.timeStamp;
      checkForResolutionAfterMove();
    }
  }

  @protected
  void checkForResolutionAfterMove() {}

  @protected
  void accepted(GestureMultiDragStartCallback starter);

  @protected
  @mustCallSuper
  void rejected() {
    assert(_arenaEntry != null);
    assert(_client == null);
    assert(pendingDelta != null);
    _pendingDelta = null;
    _lastPendingEventTimestamp = null;
    _arenaEntry = null;
  }

  void _startDrag(Drag client) {
    assert(_arenaEntry != null);
    assert(_client == null);
    assert(pendingDelta != null);
    _client = client;
    final DragUpdateDetails details = DragUpdateDetails(
      sourceTimeStamp: _lastPendingEventTimestamp,
      delta: pendingDelta!,
      globalPosition: initialPosition,
    );
    _pendingDelta = null;
    _lastPendingEventTimestamp = null;
    // Call client last to avoid reentrancy.
    _client!.update(details);
  }

  void _up() {
    assert(_arenaEntry != null);
    if (_client != null) {
      assert(pendingDelta == null);
      final DragEndDetails details =
          DragEndDetails(velocity: _velocityTracker.getVelocity());
      final Drag client = _client!;
      _client = null;
      // Call client last to avoid reentrancy.
      client.end(details);
    } else {
      assert(pendingDelta != null);
      _pendingDelta = null;
      _lastPendingEventTimestamp = null;
    }
  }

  void _cancel() {
    assert(_arenaEntry != null);
    if (_client != null) {
      assert(pendingDelta == null);
      final Drag client = _client!;
      _client = null;
      // Call client last to avoid reentrancy.
      client.cancel();
    } else {
      assert(pendingDelta != null);
      _pendingDelta = null;
      _lastPendingEventTimestamp = null;
    }
  }

  @protected
  @mustCallSuper
  void dispose() {
    _arenaEntry?.resolve(GestureDisposition.rejected);
    _arenaEntry = null;
    assert(() {
      _pendingDelta = null;
      return true;
    }());
  }
}

abstract class MultiDragGestureRecognizer extends GestureRecognizer {
  MultiDragGestureRecognizer({
    required super.debugOwner,
    super.supportedDevices,
    AllowedButtonsFilter? allowedButtonsFilter,
  }) : super(
            allowedButtonsFilter:
                allowedButtonsFilter ?? _defaultButtonAcceptBehavior);

  // Accept the input if, and only if, [kPrimaryButton] is pressed.
  static bool _defaultButtonAcceptBehavior(int buttons) =>
      buttons == kPrimaryButton;

  GestureMultiDragStartCallback? onStart;

  Map<int, MultiDragPointerState>? _pointers = <int, MultiDragPointerState>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(_pointers != null);
    assert(!_pointers!.containsKey(event.pointer));
    final MultiDragPointerState state = createNewPointerState(event);
    _pointers![event.pointer] = state;
    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
    state._setArenaEntry(
        GestureBinding.instance.gestureArena.add(event.pointer, this));
  }

  @protected
  @factory
  MultiDragPointerState createNewPointerState(PointerDownEvent event);

  void _handleEvent(PointerEvent event) {
    assert(_pointers != null);
    assert(_pointers!.containsKey(event.pointer));
    final MultiDragPointerState state = _pointers![event.pointer]!;
    if (event is PointerMoveEvent) {
      state._move(event);
      // We might be disposed here.
    } else if (event is PointerUpEvent) {
      assert(event.delta == Offset.zero);
      state._up();
      // We might be disposed here.
      _removeState(event.pointer);
    } else if (event is PointerCancelEvent) {
      assert(event.delta == Offset.zero);
      state._cancel();
      // We might be disposed here.
      _removeState(event.pointer);
    } else if (event is! PointerDownEvent) {
      // we get the PointerDownEvent that resulted in our addPointer getting called since we
      // add ourselves to the pointer router then (before the pointer router has heard of
      // the event).
      assert(false);
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_pointers != null);
    final MultiDragPointerState? state = _pointers![pointer];
    if (state == null) {
      return; // We might already have canceled this drag if the up comes before the accept.
    }
    state.accepted(
        (Offset initialPosition) => _startDrag(initialPosition, pointer));
  }

  Drag? _startDrag(Offset initialPosition, int pointer) {
    assert(_pointers != null);
    final MultiDragPointerState state = _pointers![pointer]!;
    assert(state._pendingDelta != null);
    Drag? drag;
    if (onStart != null) {
      drag = invokeCallback<Drag?>('onStart', () => onStart!(initialPosition));
    }
    if (drag != null) {
      state._startDrag(drag);
    } else {
      _removeState(pointer);
    }
    return drag;
  }

  @override
  void rejectGesture(int pointer) {
    assert(_pointers != null);
    if (_pointers!.containsKey(pointer)) {
      final MultiDragPointerState state = _pointers![pointer]!;
      state.rejected();
      _removeState(pointer);
    } // else we already preemptively forgot about it (e.g. we got an up event)
  }

  void _removeState(int pointer) {
    if (_pointers == null) {
      // We've already been disposed. It's harmless to skip removing the state
      // for the given pointer because dispose() has already removed it.
      return;
    }
    assert(_pointers!.containsKey(pointer));
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
    _pointers!.remove(pointer)!.dispose();
  }

  @override
  void dispose() {
    _pointers!.keys.toList().forEach(_removeState);
    assert(_pointers!.isEmpty);
    _pointers = null;
    super.dispose();
  }
}

class _ImmediatePointerState extends MultiDragPointerState {
  _ImmediatePointerState(
      super.initialPosition, super.kind, super.gestureSettings);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class ImmediateMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  ImmediateMultiDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _ImmediatePointerState(event.position, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'multidrag';
}

class _HorizontalPointerState extends MultiDragPointerState {
  _HorizontalPointerState(
      super.initialPosition, super.kind, super.gestureSettings);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.dx.abs() > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class HorizontalMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  HorizontalMultiDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _HorizontalPointerState(event.position, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'horizontal multidrag';
}

class _VerticalPointerState extends MultiDragPointerState {
  _VerticalPointerState(
      super.initialPosition, super.kind, super.gestureSettings);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta!.dy.abs() > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class VerticalMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  VerticalMultiDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _VerticalPointerState(event.position, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'vertical multidrag';
}

class _DelayedPointerState extends MultiDragPointerState {
  _DelayedPointerState(super.initialPosition, Duration delay, super.kind,
      super.gestureSettings) {
    _timer = Timer(delay, _delayPassed);
  }

  Timer? _timer;
  GestureMultiDragStartCallback? _starter;

  void _delayPassed() {
    assert(_timer != null);
    assert(pendingDelta != null);
    assert(pendingDelta!.distance <= computeHitSlop(kind, gestureSettings));
    _timer = null;
    if (_starter != null) {
      _starter!(initialPosition);
      _starter = null;
    } else {
      resolve(GestureDisposition.accepted);
    }
    assert(_starter == null);
  }

  void _ensureTimerStopped() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    assert(_starter == null);
    if (_timer == null) {
      starter(initialPosition);
    } else {
      _starter = starter;
    }
  }

  @override
  void checkForResolutionAfterMove() {
    if (_timer == null) {
      // If we've been accepted by the gesture arena but the pointer moves too
      // much before the timer fires, we end up a state where the timer is
      // stopped but we keep getting calls to this function because we never
      // actually started the drag. In this case, _starter will be non-null
      // because we're essentially waiting forever to start the drag.
      assert(_starter != null);
      return;
    }
    assert(pendingDelta != null);
    if (pendingDelta!.distance > computeHitSlop(kind, gestureSettings)) {
      resolve(GestureDisposition.rejected);
      _ensureTimerStopped();
    }
  }

  @override
  void dispose() {
    _ensureTimerStopped();
    super.dispose();
  }
}

class DelayedMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  DelayedMultiDragGestureRecognizer({
    this.delay = kLongPressTimeout,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  final Duration delay;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    return _DelayedPointerState(
        event.position, delay, event.kind, gestureSettings);
  }

  @override
  String get debugDescription => 'long multidrag';
}
