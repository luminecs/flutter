import 'dart:async';

import 'package:meta/meta.dart';

import '../base/process.dart';
import '../globals.dart' as globals;
import 'async_guard.dart';
import 'io.dart';

typedef SignalHandler = FutureOr<void> Function(ProcessSignal signal);

abstract class Signals {
  @visibleForTesting
  factory Signals.test({
    List<ProcessSignal> exitSignals = defaultExitSignals,
    ShutdownHooks? shutdownHooks,
  }) =>
      LocalSignals._(exitSignals, shutdownHooks: shutdownHooks);

  // The default list of signals that should cause the process to exit.
  static const List<ProcessSignal> defaultExitSignals = <ProcessSignal>[
    ProcessSignal.sigterm,
    ProcessSignal.sigint,
  ];

  Object addHandler(ProcessSignal signal, SignalHandler handler);

  Future<bool> removeHandler(ProcessSignal signal, Object token);

  Stream<Object> get errors;
}

class LocalSignals implements Signals {
  LocalSignals._(
    this.exitSignals, {
    ShutdownHooks? shutdownHooks,
  }) : _shutdownHooks = shutdownHooks ?? globals.shutdownHooks;

  static LocalSignals instance = LocalSignals._(
    Signals.defaultExitSignals,
  );

  final List<ProcessSignal> exitSignals;
  final ShutdownHooks _shutdownHooks;

  // A table mapping (signal, token) -> signal handler.
  final Map<ProcessSignal, Map<Object, SignalHandler>> _handlersTable =
      <ProcessSignal, Map<Object, SignalHandler>>{};

  // A table mapping (signal) -> signal handler list. The list is in the order
  // that the signal handlers should be run.
  final Map<ProcessSignal, List<SignalHandler>> _handlersList =
      <ProcessSignal, List<SignalHandler>>{};

  // A table mapping (signal) -> low-level signal event stream.
  final Map<ProcessSignal, StreamSubscription<ProcessSignal>>
      _streamSubscriptions =
      <ProcessSignal, StreamSubscription<ProcessSignal>>{};

  // The stream controller for errors coming from signal handlers.
  final StreamController<Object> _errorStreamController =
      StreamController<Object>.broadcast();

  @override
  Stream<Object> get errors => _errorStreamController.stream;

  @override
  Object addHandler(ProcessSignal signal, SignalHandler handler) {
    final Object token = Object();
    _handlersTable.putIfAbsent(signal, () => <Object, SignalHandler>{});
    _handlersTable[signal]![token] = handler;

    _handlersList.putIfAbsent(signal, () => <SignalHandler>[]);
    _handlersList[signal]!.add(handler);

    // If we added the first one, then call signal.watch(), listen, and cache
    // the stream controller.
    if (_handlersList[signal]!.length == 1) {
      _streamSubscriptions[signal] = signal.watch().listen(
        _handleSignal,
        onError: (Object e) {
          _handlersTable[signal]?.remove(token);
          _handlersList[signal]?.remove(handler);
        },
      );
    }
    return token;
  }

  @override
  Future<bool> removeHandler(ProcessSignal signal, Object token) async {
    // We don't know about this signal.
    if (!_handlersTable.containsKey(signal)) {
      return false;
    }
    // We don't know about this token.
    if (!_handlersTable[signal]!.containsKey(token)) {
      return false;
    }
    final SignalHandler? handler = _handlersTable[signal]!.remove(token);
    if (handler == null) {
      return false;
    }
    final bool removed = _handlersList[signal]!.remove(handler);
    if (!removed) {
      return false;
    }

    // If _handlersList[signal] is empty, then lookup the cached stream
    // controller and unsubscribe from the stream.
    if (_handlersList.isEmpty) {
      await _streamSubscriptions[signal]?.cancel();
    }
    return true;
  }

  Future<void> _handleSignal(ProcessSignal s) async {
    final List<SignalHandler>? handlers = _handlersList[s];
    if (handlers != null) {
      final List<SignalHandler> handlersCopy = handlers.toList();
      for (final SignalHandler handler in handlersCopy) {
        try {
          await asyncGuard<void>(() async => handler(s));
        } on Exception catch (e) {
          if (_errorStreamController.hasListener) {
            _errorStreamController.add(e);
          }
        }
      }
    }
    // If this was a signal that should cause the process to go down, then
    // call exit();
    if (_shouldExitFor(s)) {
      await exitWithHooks(0, shutdownHooks: _shutdownHooks);
    }
  }

  bool _shouldExitFor(ProcessSignal signal) => exitSignals.contains(signal);
}
