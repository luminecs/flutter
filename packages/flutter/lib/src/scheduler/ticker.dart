import 'dart:async';

import 'package:flutter/foundation.dart';

import 'binding.dart';

export 'dart:ui' show VoidCallback;

export 'package:flutter/foundation.dart' show DiagnosticsNode;

typedef TickerCallback = void Function(Duration elapsed);

abstract class TickerProvider {
  const TickerProvider();

  @factory
  Ticker createTicker(TickerCallback onTick);
}

// TODO(jacobr): make Ticker use Diagnosticable to simplify reporting errors
// related to a ticker.
class Ticker {
  Ticker(this._onTick, {this.debugLabel}) {
    assert(() {
      _debugCreationStack = StackTrace.current;
      return true;
    }());
  }

  TickerFuture? _future;

  bool get muted => _muted;
  bool _muted = false;
  set muted(bool value) {
    if (value == muted) {
      return;
    }
    _muted = value;
    if (value) {
      unscheduleTick();
    } else if (shouldScheduleTick) {
      scheduleTick();
    }
  }

  bool get isTicking {
    if (_future == null) {
      return false;
    }
    if (muted) {
      return false;
    }
    if (SchedulerBinding.instance.framesEnabled) {
      return true;
    }
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      return true;
    } // for example, we might be in a warm-up frame or forced frame
    return false;
  }

  bool get isActive => _future != null;

  Duration? _startTime;

  TickerFuture start() {
    assert(() {
      if (isActive) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A ticker was started twice.'),
          ErrorDescription(
              'A ticker that is already active cannot be started again without first stopping it.'),
          describeForError('The affected ticker was'),
        ]);
      }
      return true;
    }());
    assert(_startTime == null);
    _future = TickerFuture._();
    if (shouldScheduleTick) {
      scheduleTick();
    }
    if (SchedulerBinding.instance.schedulerPhase.index >
            SchedulerPhase.idle.index &&
        SchedulerBinding.instance.schedulerPhase.index <
            SchedulerPhase.postFrameCallbacks.index) {
      _startTime = SchedulerBinding.instance.currentFrameTimeStamp;
    }
    return _future!;
  }

  DiagnosticsNode describeForError(String name) {
    // TODO(jacobr): make this more structured.
    return DiagnosticsProperty<Ticker>(name, this,
        description: toString(debugIncludeStack: true));
  }

  void stop({bool canceled = false}) {
    if (!isActive) {
      return;
    }

    // We take the _future into a local variable so that isTicking is false
    // when we actually complete the future (isTicking uses _future to
    // determine its state).
    final TickerFuture localFuture = _future!;
    _future = null;
    _startTime = null;
    assert(!isActive);

    unscheduleTick();
    if (canceled) {
      localFuture._cancel(this);
    } else {
      localFuture._complete();
    }
  }

  final TickerCallback _onTick;

  int? _animationId;

  @protected
  bool get scheduled => _animationId != null;

  @protected
  bool get shouldScheduleTick => !muted && isActive && !scheduled;

  void _tick(Duration timeStamp) {
    assert(isTicking);
    assert(scheduled);
    _animationId = null;

    _startTime ??= timeStamp;
    _onTick(timeStamp - _startTime!);

    // The onTick callback may have scheduled another tick already, for
    // example by calling stop then start again.
    if (shouldScheduleTick) {
      scheduleTick(rescheduling: true);
    }
  }

  @protected
  void scheduleTick({bool rescheduling = false}) {
    assert(!scheduled);
    assert(shouldScheduleTick);
    _animationId = SchedulerBinding.instance
        .scheduleFrameCallback(_tick, rescheduling: rescheduling);
  }

  @protected
  void unscheduleTick() {
    if (scheduled) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_animationId!);
      _animationId = null;
    }
    assert(!shouldScheduleTick);
  }

  void absorbTicker(Ticker originalTicker) {
    assert(!isActive);
    assert(_future == null);
    assert(_startTime == null);
    assert(_animationId == null);
    assert(
        (originalTicker._future == null) == (originalTicker._startTime == null),
        'Cannot absorb Ticker after it has been disposed.');
    if (originalTicker._future != null) {
      _future = originalTicker._future;
      _startTime = originalTicker._startTime;
      if (shouldScheduleTick) {
        scheduleTick();
      }
      originalTicker._future =
          null; // so that it doesn't get disposed when we dispose of originalTicker
      originalTicker.unscheduleTick();
    }
    originalTicker.dispose();
  }

  @mustCallSuper
  void dispose() {
    if (_future != null) {
      final TickerFuture localFuture = _future!;
      _future = null;
      assert(!isActive);
      unscheduleTick();
      localFuture._cancel(this);
    }
    assert(() {
      // We intentionally don't null out _startTime. This means that if start()
      // was ever called, the object is now in a bogus state. This weakly helps
      // catch cases of use-after-dispose.
      _startTime = Duration.zero;
      return true;
    }());
  }

  final String? debugLabel;
  late StackTrace _debugCreationStack;

  @override
  String toString({bool debugIncludeStack = false}) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('${objectRuntimeType(this, 'Ticker')}(');
    assert(() {
      buffer.write(debugLabel ?? '');
      return true;
    }());
    buffer.write(')');
    assert(() {
      if (debugIncludeStack) {
        buffer.writeln();
        buffer.writeln(
            'The stack trace when the $runtimeType was actually created was:');
        FlutterError.defaultStackFilter(
                _debugCreationStack.toString().trimRight().split('\n'))
            .forEach(buffer.writeln);
      }
      return true;
    }());
    return buffer.toString();
  }
}

class TickerFuture implements Future<void> {
  TickerFuture._();

  TickerFuture.complete() {
    _complete();
  }

  final Completer<void> _primaryCompleter = Completer<void>();
  Completer<void>? _secondaryCompleter;
  bool?
      _completed; // null means unresolved, true means complete, false means canceled

  void _complete() {
    assert(_completed == null);
    _completed = true;
    _primaryCompleter.complete();
    _secondaryCompleter?.complete();
  }

  void _cancel(Ticker ticker) {
    assert(_completed == null);
    _completed = false;
    _secondaryCompleter?.completeError(TickerCanceled(ticker));
  }

  void whenCompleteOrCancel(VoidCallback callback) {
    void thunk(dynamic value) {
      callback();
    }

    orCancel.then<void>(thunk, onError: thunk);
  }

  Future<void> get orCancel {
    if (_secondaryCompleter == null) {
      _secondaryCompleter = Completer<void>();
      if (_completed != null) {
        if (_completed!) {
          _secondaryCompleter!.complete();
        } else {
          _secondaryCompleter!.completeError(const TickerCanceled());
        }
      }
    }
    return _secondaryCompleter!.future;
  }

  @override
  Stream<void> asStream() {
    return _primaryCompleter.future.asStream();
  }

  @override
  Future<void> catchError(Function onError, {bool Function(Object)? test}) {
    return _primaryCompleter.future.catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(void value) onValue,
      {Function? onError}) {
    return _primaryCompleter.future.then<R>(onValue, onError: onError);
  }

  @override
  Future<void> timeout(Duration timeLimit,
      {FutureOr<void> Function()? onTimeout}) {
    return _primaryCompleter.future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<void> whenComplete(dynamic Function() action) {
    return _primaryCompleter.future.whenComplete(action);
  }

  @override
  String toString() =>
      '${describeIdentity(this)}(${_completed == null ? "active" : _completed! ? "complete" : "canceled"})';
}

class TickerCanceled implements Exception {
  const TickerCanceled([this.ticker]);

  final Ticker? ticker;

  @override
  String toString() {
    if (ticker != null) {
      return 'This ticker was canceled: $ticker';
    }
    return 'The ticker was canceled before the "orCancel" property was first used.';
  }
}
