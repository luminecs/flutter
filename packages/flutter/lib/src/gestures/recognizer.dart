import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'binding.dart';
import 'constants.dart';
import 'debug.dart';
import 'events.dart';
import 'pointer_router.dart';
import 'team.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;
export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'arena.dart' show GestureDisposition;
export 'events.dart'
    show PointerDownEvent, PointerEvent, PointerPanZoomStartEvent;
export 'gesture_settings.dart' show DeviceGestureSettings;
export 'team.dart' show GestureArenaTeam;

typedef RecognizerCallback<T> = T Function();

enum DragStartBehavior {
  down,

  start,
}

typedef AllowedButtonsFilter = bool Function(int buttons);

abstract class GestureRecognizer extends GestureArenaMember
    with DiagnosticableTreeMixin {
  GestureRecognizer({
    this.debugOwner,
    this.supportedDevices,
    AllowedButtonsFilter? allowedButtonsFilter,
  }) : _allowedButtonsFilter =
            allowedButtonsFilter ?? _defaultButtonAcceptBehavior;

  final Object? debugOwner;

  DeviceGestureSettings? gestureSettings;

  Set<PointerDeviceKind>? supportedDevices;

  final AllowedButtonsFilter _allowedButtonsFilter;

  // The default value for [allowedButtonsFilter].
  // Accept any input.
  static bool _defaultButtonAcceptBehavior(int buttons) => true;

  final Map<int, PointerDeviceKind> _pointerToKind = <int, PointerDeviceKind>{};

  void addPointerPanZoom(PointerPanZoomStartEvent event) {
    _pointerToKind[event.pointer] = event.kind;
    if (isPointerPanZoomAllowed(event)) {
      addAllowedPointerPanZoom(event);
    } else {
      handleNonAllowedPointerPanZoom(event);
    }
  }

  @protected
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {}

  void addPointer(PointerDownEvent event) {
    _pointerToKind[event.pointer] = event.kind;
    if (isPointerAllowed(event)) {
      addAllowedPointer(event);
    } else {
      handleNonAllowedPointer(event);
    }
  }

  @protected
  void addAllowedPointer(PointerDownEvent event) {}

  @protected
  void handleNonAllowedPointer(PointerDownEvent event) {}

  @protected
  bool isPointerAllowed(PointerDownEvent event) {
    return (supportedDevices == null ||
            supportedDevices!.contains(event.kind)) &&
        _allowedButtonsFilter(event.buttons);
  }

  @protected
  void handleNonAllowedPointerPanZoom(PointerPanZoomStartEvent event) {}

  @protected
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    return supportedDevices == null || supportedDevices!.contains(event.kind);
  }

  @protected
  PointerDeviceKind getKindForPointer(int pointer) {
    assert(_pointerToKind.containsKey(pointer));
    return _pointerToKind[pointer]!;
  }

  @mustCallSuper
  void dispose() {}

  String get debugDescription;

  @protected
  @pragma('vm:notify-debugger-on-exception')
  T? invokeCallback<T>(String name, RecognizerCallback<T> callback,
      {String Function()? debugReport}) {
    T? result;
    try {
      assert(() {
        if (debugPrintRecognizerCallbacksTrace) {
          final String? report = debugReport != null ? debugReport() : null;
          // The 19 in the line below is the width of the prefix used by
          // _debugLogDiagnostic in arena.dart.
          final String prefix =
              debugPrintGestureArenaDiagnostics ? '${' ' * 19}❙ ' : '';
          debugPrint(
              '$prefix$this calling $name callback.${(report?.isNotEmpty ?? false) ? " $report" : ""}');
        }
        return true;
      }());
      result = callback();
    } catch (exception, stack) {
      InformationCollector? collector;
      assert(() {
        collector = () => <DiagnosticsNode>[
              StringProperty('Handler', name),
              DiagnosticsProperty<GestureRecognizer>('Recognizer', this,
                  style: DiagnosticsTreeStyle.errorProperty),
            ];
        return true;
      }());
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'gesture',
        context: ErrorDescription('while handling a gesture'),
        informationCollector: collector,
      ));
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('debugOwner', debugOwner,
        defaultValue: null));
  }
}

abstract class OneSequenceGestureRecognizer extends GestureRecognizer {
  OneSequenceGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  final Map<int, GestureArenaEntry> _entries = <int, GestureArenaEntry>{};
  final Set<int> _trackedPointers = HashSet<int>();

  @override
  @protected
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  @protected
  void handleNonAllowedPointer(PointerDownEvent event) {
    resolve(GestureDisposition.rejected);
  }

  @protected
  void handleEvent(PointerEvent event);

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}

  @protected
  void didStopTrackingLastPointer(int pointer);

  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    final List<GestureArenaEntry> localEntries =
        List<GestureArenaEntry>.of(_entries.values);
    _entries.clear();
    for (final GestureArenaEntry entry in localEntries) {
      entry.resolve(disposition);
    }
  }

  @protected
  @mustCallSuper
  void resolvePointer(int pointer, GestureDisposition disposition) {
    final GestureArenaEntry? entry = _entries[pointer];
    if (entry != null) {
      _entries.remove(pointer);
      entry.resolve(disposition);
    }
  }

  @override
  void dispose() {
    resolve(GestureDisposition.rejected);
    for (final int pointer in _trackedPointers) {
      GestureBinding.instance.pointerRouter.removeRoute(pointer, handleEvent);
    }
    _trackedPointers.clear();
    assert(_entries.isEmpty);
    super.dispose();
  }

  GestureArenaTeam? get team => _team;
  GestureArenaTeam? _team;
  set team(GestureArenaTeam? value) {
    assert(value != null);
    assert(_entries.isEmpty);
    assert(_trackedPointers.isEmpty);
    assert(_team == null);
    _team = value;
  }

  GestureArenaEntry _addPointerToArena(int pointer) {
    if (_team != null) {
      return _team!.add(pointer, this);
    }
    return GestureBinding.instance.gestureArena.add(pointer, this);
  }

  @protected
  void startTrackingPointer(int pointer, [Matrix4? transform]) {
    GestureBinding.instance.pointerRouter
        .addRoute(pointer, handleEvent, transform);
    _trackedPointers.add(pointer);
    // TODO(goderbauer): Enable assert after recognizers properly clean up their defunct `_entries`, see https://github.com/flutter/flutter/issues/117356.
    // assert(!_entries.containsKey(pointer));
    _entries[pointer] = _addPointerToArena(pointer);
  }

  @protected
  void stopTrackingPointer(int pointer) {
    if (_trackedPointers.contains(pointer)) {
      GestureBinding.instance.pointerRouter.removeRoute(pointer, handleEvent);
      _trackedPointers.remove(pointer);
      if (_trackedPointers.isEmpty) {
        didStopTrackingLastPointer(pointer);
      }
    }
  }

  @protected
  void stopTrackingIfPointerNoLongerDown(PointerEvent event) {
    if (event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerPanZoomEndEvent) {
      stopTrackingPointer(event.pointer);
    }
  }
}

enum GestureRecognizerState {
  ready,

  possible,

  defunct,
}

abstract class PrimaryPointerGestureRecognizer
    extends OneSequenceGestureRecognizer {
  PrimaryPointerGestureRecognizer({
    this.deadline,
    this.preAcceptSlopTolerance = kTouchSlop,
    this.postAcceptSlopTolerance = kTouchSlop,
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  })  : assert(
          preAcceptSlopTolerance == null || preAcceptSlopTolerance >= 0,
          'The preAcceptSlopTolerance must be positive or null',
        ),
        assert(
          postAcceptSlopTolerance == null || postAcceptSlopTolerance >= 0,
          'The postAcceptSlopTolerance must be positive or null',
        );

  final Duration? deadline;

  final double? preAcceptSlopTolerance;

  final double? postAcceptSlopTolerance;

  GestureRecognizerState get state => _state;
  GestureRecognizerState _state = GestureRecognizerState.ready;

  int? get primaryPointer => _primaryPointer;
  int? _primaryPointer;

  OffsetPair? get initialPosition => _initialPosition;
  OffsetPair? _initialPosition;

  // Whether this pointer is accepted by winning the arena or as defined by
  // a subclass calling acceptGesture.
  bool _gestureAccepted = false;
  Timer? _timer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (state == GestureRecognizerState.ready) {
      _state = GestureRecognizerState.possible;
      _primaryPointer = event.pointer;
      _initialPosition =
          OffsetPair(local: event.localPosition, global: event.position);
      if (deadline != null) {
        _timer = Timer(deadline!, () => didExceedDeadlineWithEvent(event));
      }
    }
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {
    if (!_gestureAccepted) {
      super.handleNonAllowedPointer(event);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(state != GestureRecognizerState.ready);
    if (state == GestureRecognizerState.possible &&
        event.pointer == primaryPointer) {
      final bool isPreAcceptSlopPastTolerance = !_gestureAccepted &&
          preAcceptSlopTolerance != null &&
          _getGlobalDistance(event) > preAcceptSlopTolerance!;
      final bool isPostAcceptSlopPastTolerance = _gestureAccepted &&
          postAcceptSlopTolerance != null &&
          _getGlobalDistance(event) > postAcceptSlopTolerance!;

      if (event is PointerMoveEvent &&
          (isPreAcceptSlopPastTolerance || isPostAcceptSlopPastTolerance)) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(primaryPointer!);
      } else {
        handlePrimaryPointer(event);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @protected
  void handlePrimaryPointer(PointerEvent event);

  @protected
  void didExceedDeadline() {
    assert(deadline == null);
  }

  @protected
  void didExceedDeadlineWithEvent(PointerDownEvent event) {
    didExceedDeadline();
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer == primaryPointer) {
      _stopTimer();
      _gestureAccepted = true;
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == primaryPointer && state == GestureRecognizerState.possible) {
      _stopTimer();
      _state = GestureRecognizerState.defunct;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    assert(state != GestureRecognizerState.ready);
    _stopTimer();
    _state = GestureRecognizerState.ready;
    _initialPosition = null;
    _gestureAccepted = false;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  double _getGlobalDistance(PointerEvent event) {
    final Offset offset = event.position - initialPosition!.global;
    return offset.distance;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<GestureRecognizerState>('state', state));
  }
}

@immutable
class OffsetPair {
  const OffsetPair({
    required this.local,
    required this.global,
  });

  factory OffsetPair.fromEventPosition(PointerEvent event) {
    return OffsetPair(local: event.localPosition, global: event.position);
  }

  factory OffsetPair.fromEventDelta(PointerEvent event) {
    return OffsetPair(local: event.localDelta, global: event.delta);
  }

  static const OffsetPair zero =
      OffsetPair(local: Offset.zero, global: Offset.zero);

  final Offset local;

  final Offset global;

  OffsetPair operator +(OffsetPair other) {
    return OffsetPair(
      local: local + other.local,
      global: global + other.global,
    );
  }

  OffsetPair operator -(OffsetPair other) {
    return OffsetPair(
      local: local - other.local,
      global: global - other.global,
    );
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'OffsetPair')}(local: $local, global: $global)';
}
