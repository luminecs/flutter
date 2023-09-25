
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'binding.dart';

typedef AppExitRequestCallback = Future<AppExitResponse> Function();

class AppLifecycleListener with WidgetsBindingObserver, Diagnosticable {
  AppLifecycleListener({
    WidgetsBinding? binding,
    this.onResume,
    this.onInactive,
    this.onHide,
    this.onShow,
    this.onPause,
    this.onRestart,
    this.onDetach,
    this.onExitRequested,
    this.onStateChange,
  })  : binding = binding ?? WidgetsBinding.instance,
        _lifecycleState = (binding ?? WidgetsBinding.instance).lifecycleState {
    this.binding.addObserver(this);
  }

  AppLifecycleState? _lifecycleState;

  final WidgetsBinding binding;

  final ValueChanged<AppLifecycleState>? onStateChange;

  final VoidCallback? onInactive;

  final VoidCallback? onResume;

  final VoidCallback? onHide;

  final VoidCallback? onShow;

  final VoidCallback? onPause;

  final VoidCallback? onRestart;

  final AppExitRequestCallback? onExitRequested;

  final VoidCallback? onDetach;

  bool _debugDisposed = false;

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    binding.removeObserver(this);
    assert(() {
      _debugDisposed = true;
      return true;
    }());
  }

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_debugDisposed) {
        throw FlutterError(
          'A $runtimeType was used after being disposed.\n'
          'Once you have called dispose() on a $runtimeType, it '
          'can no longer be used.',
        );
      }
      return true;
    }());
    return true;
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    assert(_debugAssertNotDisposed());
    if (onExitRequested == null) {
      return AppExitResponse.exit;
    }
    return onExitRequested!();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    assert(_debugAssertNotDisposed());
    final AppLifecycleState? previousState = _lifecycleState;
    if (state == previousState) {
      // Transitioning to the same state twice doesn't produce any
      // notifications (but also won't actually occur).
      return;
    }
    _lifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        assert(previousState == null || previousState == AppLifecycleState.inactive || previousState == AppLifecycleState.detached, 'Invalid state transition from $previousState to $state');
        onResume?.call();
      case AppLifecycleState.inactive:
        assert(previousState == null || previousState == AppLifecycleState.hidden || previousState == AppLifecycleState.resumed, 'Invalid state transition from $previousState to $state');
        if (previousState == AppLifecycleState.hidden) {
          onShow?.call();
        } else if (previousState == null || previousState == AppLifecycleState.resumed) {
          onInactive?.call();
        }
      case AppLifecycleState.hidden:
        assert(previousState == null || previousState == AppLifecycleState.paused || previousState == AppLifecycleState.inactive, 'Invalid state transition from $previousState to $state');
        if (previousState == AppLifecycleState.paused) {
          onRestart?.call();
        } else if (previousState == null || previousState == AppLifecycleState.inactive) {
          onHide?.call();
        }
      case AppLifecycleState.paused:
        assert(previousState == null || previousState == AppLifecycleState.hidden, 'Invalid state transition from $previousState to $state');
        if (previousState == null || previousState == AppLifecycleState.hidden) {
          onPause?.call();
        }
      case AppLifecycleState.detached:
        assert(previousState == null || previousState == AppLifecycleState.paused, 'Invalid state transition from $previousState to $state');
        onDetach?.call();
    }
    // At this point, it can't be null anymore.
    onStateChange?.call(_lifecycleState!);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<WidgetsBinding>('binding', binding));
    properties.add(FlagProperty('onStateChange', value: onStateChange != null, ifTrue: 'onStateChange'));
    properties.add(FlagProperty('onInactive', value: onInactive != null, ifTrue: 'onInactive'));
    properties.add(FlagProperty('onResume', value: onResume != null, ifTrue: 'onResume'));
    properties.add(FlagProperty('onHide', value: onHide != null, ifTrue: 'onHide'));
    properties.add(FlagProperty('onShow', value: onShow != null, ifTrue: 'onShow'));
    properties.add(FlagProperty('onPause', value: onPause != null, ifTrue: 'onPause'));
    properties.add(FlagProperty('onRestart', value: onRestart != null, ifTrue: 'onRestart'));
    properties.add(FlagProperty('onExitRequested', value: onExitRequested != null, ifTrue: 'onExitRequested'));
    properties.add(FlagProperty('onDetach', value: onDetach != null, ifTrue: 'onDetach'));
  }
}