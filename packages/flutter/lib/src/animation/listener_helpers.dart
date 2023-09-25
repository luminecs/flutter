
import 'package:flutter/foundation.dart';

import 'animation.dart';

export 'dart:ui' show VoidCallback;

export 'animation.dart' show AnimationStatus, AnimationStatusListener;

mixin AnimationLazyListenerMixin {
  int _listenerCounter = 0;

  @protected
  void didRegisterListener() {
    assert(_listenerCounter >= 0);
    if (_listenerCounter == 0) {
      didStartListening();
    }
    _listenerCounter += 1;
  }

  @protected
  void didUnregisterListener() {
    assert(_listenerCounter >= 1);
    _listenerCounter -= 1;
    if (_listenerCounter == 0) {
      didStopListening();
    }
  }

  @protected
  void didStartListening();

  @protected
  void didStopListening();

  bool get isListening => _listenerCounter > 0;
}

mixin AnimationEagerListenerMixin {
  @protected
  void didRegisterListener() { }

  @protected
  void didUnregisterListener() { }

  @mustCallSuper
  void dispose() { }
}

mixin AnimationLocalListenersMixin {
  final ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();

  @protected
  void didRegisterListener();

  @protected
  void didUnregisterListener();

  void addListener(VoidCallback listener) {
    didRegisterListener();
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    final bool removed = _listeners.remove(listener);
    if (removed) {
      didUnregisterListener();
    }
  }

  @protected
  void clearListeners() {
    _listeners.clear();
  }

  @protected
  @pragma('vm:notify-debugger-on-exception')
  void notifyListeners() {
    final List<VoidCallback> localListeners = _listeners.toList(growable: false);
    for (final VoidCallback listener in localListeners) {
      InformationCollector? collector;
      assert(() {
        collector = () => <DiagnosticsNode>[
          DiagnosticsProperty<AnimationLocalListenersMixin>(
            'The $runtimeType notifying listeners was',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ];
        return true;
      }());
      try {
        if (_listeners.contains(listener)) {
          listener();
        }
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'animation library',
          context: ErrorDescription('while notifying listeners for $runtimeType'),
          informationCollector: collector,
        ));
      }
    }
  }
}

mixin AnimationLocalStatusListenersMixin {
  final ObserverList<AnimationStatusListener> _statusListeners = ObserverList<AnimationStatusListener>();

  @protected
  void didRegisterListener();

  @protected
  void didUnregisterListener();

  void addStatusListener(AnimationStatusListener listener) {
    didRegisterListener();
    _statusListeners.add(listener);
  }

  void removeStatusListener(AnimationStatusListener listener) {
    final bool removed = _statusListeners.remove(listener);
    if (removed) {
      didUnregisterListener();
    }
  }

  @protected
  void clearStatusListeners() {
    _statusListeners.clear();
  }

  @protected
  @pragma('vm:notify-debugger-on-exception')
  void notifyStatusListeners(AnimationStatus status) {
    final List<AnimationStatusListener> localListeners = _statusListeners.toList(growable: false);
    for (final AnimationStatusListener listener in localListeners) {
      try {
        if (_statusListeners.contains(listener)) {
          listener(status);
        }
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<AnimationLocalStatusListenersMixin>(
              'The $runtimeType notifying status listeners was',
              this,
              style: DiagnosticsTreeStyle.errorProperty,
            ),
          ];
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'animation library',
          context: ErrorDescription('while notifying status listeners for $runtimeType'),
          informationCollector: collector,
        ));
      }
    }
  }
}