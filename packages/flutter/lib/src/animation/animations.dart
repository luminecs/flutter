import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'animation.dart';
import 'curves.dart';
import 'listener_helpers.dart';

export 'dart:ui' show VoidCallback;

export 'animation.dart'
    show Animation, AnimationStatus, AnimationStatusListener;
export 'curves.dart' show Curve;

// Examples can assume:
// late AnimationController controller;

class _AlwaysCompleteAnimation extends Animation<double> {
  const _AlwaysCompleteAnimation();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.completed;

  @override
  double get value => 1.0;

  @override
  String toString() => 'kAlwaysCompleteAnimation';
}

const Animation<double> kAlwaysCompleteAnimation = _AlwaysCompleteAnimation();

class _AlwaysDismissedAnimation extends Animation<double> {
  const _AlwaysDismissedAnimation();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.dismissed;

  @override
  double get value => 0.0;

  @override
  String toString() => 'kAlwaysDismissedAnimation';
}

const Animation<double> kAlwaysDismissedAnimation = _AlwaysDismissedAnimation();

class AlwaysStoppedAnimation<T> extends Animation<T> {
  const AlwaysStoppedAnimation(this.value);

  @override
  final T value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  String toStringDetails() {
    return '${super.toStringDetails()} $value; paused';
  }
}

mixin AnimationWithParentMixin<T> {
  Animation<T> get parent;

  // keep these next five dartdocs in sync with the dartdocs in Animation<T>

  void addListener(VoidCallback listener) => parent.addListener(listener);

  void removeListener(VoidCallback listener) => parent.removeListener(listener);

  void addStatusListener(AnimationStatusListener listener) =>
      parent.addStatusListener(listener);

  void removeStatusListener(AnimationStatusListener listener) =>
      parent.removeStatusListener(listener);

  AnimationStatus get status => parent.status;
}

class ProxyAnimation extends Animation<double>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  ProxyAnimation([Animation<double>? animation]) {
    _parent = animation;
    if (_parent == null) {
      _status = AnimationStatus.dismissed;
      _value = 0.0;
    }
  }

  AnimationStatus? _status;
  double? _value;

  Animation<double>? get parent => _parent;
  Animation<double>? _parent;
  set parent(Animation<double>? value) {
    if (value == _parent) {
      return;
    }
    if (_parent != null) {
      _status = _parent!.status;
      _value = _parent!.value;
      if (isListening) {
        didStopListening();
      }
    }
    _parent = value;
    if (_parent != null) {
      if (isListening) {
        didStartListening();
      }
      if (_value != _parent!.value) {
        notifyListeners();
      }
      if (_status != _parent!.status) {
        notifyStatusListeners(_parent!.status);
      }
      _status = null;
      _value = null;
    }
  }

  @override
  void didStartListening() {
    if (_parent != null) {
      _parent!.addListener(notifyListeners);
      _parent!.addStatusListener(notifyStatusListeners);
    }
  }

  @override
  void didStopListening() {
    if (_parent != null) {
      _parent!.removeListener(notifyListeners);
      _parent!.removeStatusListener(notifyStatusListeners);
    }
  }

  @override
  AnimationStatus get status => _parent != null ? _parent!.status : _status!;

  @override
  double get value => _parent != null ? _parent!.value : _value!;

  @override
  String toString() {
    if (parent == null) {
      return '${objectRuntimeType(this, 'ProxyAnimation')}(null; ${super.toStringDetails()} ${value.toStringAsFixed(3)})';
    }
    return '$parent\u27A9${objectRuntimeType(this, 'ProxyAnimation')}';
  }
}

class ReverseAnimation extends Animation<double>
    with AnimationLazyListenerMixin, AnimationLocalStatusListenersMixin {
  ReverseAnimation(this.parent);

  final Animation<double> parent;

  @override
  void addListener(VoidCallback listener) {
    didRegisterListener();
    parent.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    parent.removeListener(listener);
    didUnregisterListener();
  }

  @override
  void didStartListening() {
    parent.addStatusListener(_statusChangeHandler);
  }

  @override
  void didStopListening() {
    parent.removeStatusListener(_statusChangeHandler);
  }

  void _statusChangeHandler(AnimationStatus status) {
    notifyStatusListeners(_reverseStatus(status));
  }

  @override
  AnimationStatus get status => _reverseStatus(parent.status);

  @override
  double get value => 1.0 - parent.value;

  AnimationStatus _reverseStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        return AnimationStatus.reverse;
      case AnimationStatus.reverse:
        return AnimationStatus.forward;
      case AnimationStatus.completed:
        return AnimationStatus.dismissed;
      case AnimationStatus.dismissed:
        return AnimationStatus.completed;
    }
  }

  @override
  String toString() {
    return '$parent\u27AA${objectRuntimeType(this, 'ReverseAnimation')}';
  }
}

class CurvedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  CurvedAnimation({
    required this.parent,
    required this.curve,
    this.reverseCurve,
  }) {
    _updateCurveDirection(parent.status);
    parent.addStatusListener(_updateCurveDirection);
  }

  @override
  final Animation<double> parent;

  Curve curve;

  Curve? reverseCurve;

  AnimationStatus? _curveDirection;

  bool isDisposed = false;

  void _updateCurveDirection(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        _curveDirection = null;
      case AnimationStatus.forward:
        _curveDirection ??= AnimationStatus.forward;
      case AnimationStatus.reverse:
        _curveDirection ??= AnimationStatus.reverse;
    }
  }

  bool get _useForwardCurve {
    return reverseCurve == null ||
        (_curveDirection ?? parent.status) != AnimationStatus.reverse;
  }

  void dispose() {
    isDisposed = true;
    parent.removeStatusListener(_updateCurveDirection);
  }

  @override
  double get value {
    final Curve? activeCurve = _useForwardCurve ? curve : reverseCurve;

    final double t = parent.value;
    if (activeCurve == null) {
      return t;
    }
    if (t == 0.0 || t == 1.0) {
      assert(() {
        final double transformedValue = activeCurve.transform(t);
        final double roundedTransformedValue =
            transformedValue.round().toDouble();
        if (roundedTransformedValue != t) {
          throw FlutterError(
            'Invalid curve endpoint at $t.\n'
            'Curves must map 0.0 to near zero and 1.0 to near one but '
            '${activeCurve.runtimeType} mapped $t to $transformedValue, which '
            'is near $roundedTransformedValue.',
          );
        }
        return true;
      }());
      return t;
    }
    return activeCurve.transform(t);
  }

  @override
  String toString() {
    if (reverseCurve == null) {
      return '$parent\u27A9$curve';
    }
    if (_useForwardCurve) {
      return '$parent\u27A9$curve\u2092\u2099/$reverseCurve';
    }
    return '$parent\u27A9$curve/$reverseCurve\u2092\u2099';
  }
}

enum _TrainHoppingMode { minimize, maximize }

class TrainHoppingAnimation extends Animation<double>
    with
        AnimationEagerListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  TrainHoppingAnimation(
    Animation<double> this._currentTrain,
    this._nextTrain, {
    this.onSwitchedTrain,
  }) {
    if (_nextTrain != null) {
      if (_currentTrain!.value == _nextTrain!.value) {
        _currentTrain = _nextTrain;
        _nextTrain = null;
      } else if (_currentTrain!.value > _nextTrain!.value) {
        _mode = _TrainHoppingMode.maximize;
      } else {
        assert(_currentTrain!.value < _nextTrain!.value);
        _mode = _TrainHoppingMode.minimize;
      }
    }
    _currentTrain!.addStatusListener(_statusChangeHandler);
    _currentTrain!.addListener(_valueChangeHandler);
    _nextTrain?.addListener(_valueChangeHandler);
    assert(_mode != null || _nextTrain == null);
  }

  Animation<double>? get currentTrain => _currentTrain;
  Animation<double>? _currentTrain;
  Animation<double>? _nextTrain;
  _TrainHoppingMode? _mode;

  VoidCallback? onSwitchedTrain;

  AnimationStatus? _lastStatus;
  void _statusChangeHandler(AnimationStatus status) {
    assert(_currentTrain != null);
    if (status != _lastStatus) {
      notifyListeners();
      _lastStatus = status;
    }
    assert(_lastStatus != null);
  }

  @override
  AnimationStatus get status => _currentTrain!.status;

  double? _lastValue;
  void _valueChangeHandler() {
    assert(_currentTrain != null);
    bool hop = false;
    if (_nextTrain != null) {
      assert(_mode != null);
      switch (_mode!) {
        case _TrainHoppingMode.minimize:
          hop = _nextTrain!.value <= _currentTrain!.value;
        case _TrainHoppingMode.maximize:
          hop = _nextTrain!.value >= _currentTrain!.value;
      }
      if (hop) {
        _currentTrain!
          ..removeStatusListener(_statusChangeHandler)
          ..removeListener(_valueChangeHandler);
        _currentTrain = _nextTrain;
        _nextTrain = null;
        _currentTrain!.addStatusListener(_statusChangeHandler);
        _statusChangeHandler(_currentTrain!.status);
      }
    }
    final double newValue = value;
    if (newValue != _lastValue) {
      notifyListeners();
      _lastValue = newValue;
    }
    assert(_lastValue != null);
    if (hop && onSwitchedTrain != null) {
      onSwitchedTrain!();
    }
  }

  @override
  double get value => _currentTrain!.value;

  @override
  void dispose() {
    assert(_currentTrain != null);
    _currentTrain!.removeStatusListener(_statusChangeHandler);
    _currentTrain!.removeListener(_valueChangeHandler);
    _currentTrain = null;
    _nextTrain?.removeListener(_valueChangeHandler);
    _nextTrain = null;
    clearListeners();
    clearStatusListeners();
    super.dispose();
  }

  @override
  String toString() {
    if (_nextTrain != null) {
      return '$currentTrain\u27A9${objectRuntimeType(this, 'TrainHoppingAnimation')}(next: $_nextTrain)';
    }
    return '$currentTrain\u27A9${objectRuntimeType(this, 'TrainHoppingAnimation')}(no next)';
  }
}

abstract class CompoundAnimation<T> extends Animation<T>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  CompoundAnimation({
    required this.first,
    required this.next,
  });

  final Animation<T> first;

  final Animation<T> next;

  @override
  void didStartListening() {
    first.addListener(_maybeNotifyListeners);
    first.addStatusListener(_maybeNotifyStatusListeners);
    next.addListener(_maybeNotifyListeners);
    next.addStatusListener(_maybeNotifyStatusListeners);
  }

  @override
  void didStopListening() {
    first.removeListener(_maybeNotifyListeners);
    first.removeStatusListener(_maybeNotifyStatusListeners);
    next.removeListener(_maybeNotifyListeners);
    next.removeStatusListener(_maybeNotifyStatusListeners);
  }

  @override
  AnimationStatus get status {
    if (next.status == AnimationStatus.forward ||
        next.status == AnimationStatus.reverse) {
      return next.status;
    }
    return first.status;
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'CompoundAnimation')}($first, $next)';
  }

  AnimationStatus? _lastStatus;
  void _maybeNotifyStatusListeners(AnimationStatus _) {
    if (status != _lastStatus) {
      _lastStatus = status;
      notifyStatusListeners(status);
    }
  }

  T? _lastValue;
  void _maybeNotifyListeners() {
    if (value != _lastValue) {
      _lastValue = value;
      notifyListeners();
    }
  }
}

class AnimationMean extends CompoundAnimation<double> {
  AnimationMean({
    required Animation<double> left,
    required Animation<double> right,
  }) : super(first: left, next: right);

  @override
  double get value => (first.value + next.value) / 2.0;
}

class AnimationMax<T extends num> extends CompoundAnimation<T> {
  AnimationMax(Animation<T> first, Animation<T> next)
      : super(first: first, next: next);

  @override
  T get value => math.max(first.value, next.value);
}

class AnimationMin<T extends num> extends CompoundAnimation<T> {
  AnimationMin(Animation<T> first, Animation<T> next)
      : super(first: first, next: next);

  @override
  T get value => math.min(first.value, next.value);
}
