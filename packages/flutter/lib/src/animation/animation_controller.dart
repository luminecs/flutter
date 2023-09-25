

import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import 'animation.dart';
import 'curves.dart';
import 'listener_helpers.dart';

export 'package:flutter/physics.dart' show Simulation, SpringDescription;
export 'package:flutter/scheduler.dart' show TickerFuture, TickerProvider;

export 'animation.dart' show Animation, AnimationStatus;
export 'curves.dart' show Curve;

// Examples can assume:
// late AnimationController _controller, fadeAnimationController, sizeAnimationController;
// late bool dismissed;
// void setState(VoidCallback fn) { }

enum _AnimationDirection {
  forward,

  reverse,
}

final SpringDescription _kFlingSpringDescription = SpringDescription.withDampingRatio(
  mass: 1.0,
  stiffness: 500.0,
);

const Tolerance _kFlingTolerance = Tolerance(
  velocity: double.infinity,
  distance: 0.01,
);

enum AnimationBehavior {
  normal,

  preserve,
}

class AnimationController extends Animation<double>
  with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  AnimationController({
    double? value,
    this.duration,
    this.reverseDuration,
    this.debugLabel,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
    this.animationBehavior = AnimationBehavior.normal,
    required TickerProvider vsync,
  }) : assert(upperBound >= lowerBound),
       _direction = _AnimationDirection.forward {
    _ticker = vsync.createTicker(_tick);
    _internalSetValue(value ?? lowerBound);
  }

  AnimationController.unbounded({
    double value = 0.0,
    this.duration,
    this.reverseDuration,
    this.debugLabel,
    required TickerProvider vsync,
    this.animationBehavior = AnimationBehavior.preserve,
  }) : lowerBound = double.negativeInfinity,
       upperBound = double.infinity,
       _direction = _AnimationDirection.forward {
    _ticker = vsync.createTicker(_tick);
    _internalSetValue(value);
  }

  final double lowerBound;

  final double upperBound;

  final String? debugLabel;

  final AnimationBehavior animationBehavior;

  Animation<double> get view => this;

  Duration? duration;

  Duration? reverseDuration;

  Ticker? _ticker;

  void resync(TickerProvider vsync) {
    final Ticker oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

  Simulation? _simulation;

  @override
  double get value => _value;
  late double _value;
  set value(double newValue) {
    stop();
    _internalSetValue(newValue);
    notifyListeners();
    _checkStatusChanged();
  }

  void reset() {
    value = lowerBound;
  }

  double get velocity {
    if (!isAnimating) {
      return 0.0;
    }
    return _simulation!.dx(lastElapsedDuration!.inMicroseconds.toDouble() / Duration.microsecondsPerSecond);
  }

  void _internalSetValue(double newValue) {
    _value = clampDouble(newValue, lowerBound, upperBound);
    if (_value == lowerBound) {
      _status = AnimationStatus.dismissed;
    } else if (_value == upperBound) {
      _status = AnimationStatus.completed;
    } else {
      _status = (_direction == _AnimationDirection.forward) ?
        AnimationStatus.forward :
        AnimationStatus.reverse;
    }
  }

  Duration? get lastElapsedDuration => _lastElapsedDuration;
  Duration? _lastElapsedDuration;

  bool get isAnimating => _ticker != null && _ticker!.isActive;

  _AnimationDirection _direction;

  @override
  AnimationStatus get status => _status;
  late AnimationStatus _status;

  TickerFuture forward({ double? from }) {
    assert(() {
      if (duration == null) {
        throw FlutterError(
          'AnimationController.forward() called with no default duration.\n'
          'The "duration" property should be set, either in the constructor or later, before '
          'calling the forward() function.',
        );
      }
      return true;
    }());
    assert(
      _ticker != null,
      'AnimationController.forward() called after AnimationController.dispose()\n'
      'AnimationController methods should not be used after calling dispose.',
    );
    _direction = _AnimationDirection.forward;
    if (from != null) {
      value = from;
    }
    return _animateToInternal(upperBound);
  }

  TickerFuture reverse({ double? from }) {
    assert(() {
      if (duration == null && reverseDuration == null) {
        throw FlutterError(
          'AnimationController.reverse() called with no default duration or reverseDuration.\n'
          'The "duration" or "reverseDuration" property should be set, either in the constructor or later, before '
          'calling the reverse() function.',
        );
      }
      return true;
    }());
    assert(
      _ticker != null,
      'AnimationController.reverse() called after AnimationController.dispose()\n'
      'AnimationController methods should not be used after calling dispose.',
    );
    _direction = _AnimationDirection.reverse;
    if (from != null) {
      value = from;
    }
    return _animateToInternal(lowerBound);
  }

  TickerFuture animateTo(double target, { Duration? duration, Curve curve = Curves.linear }) {
    assert(() {
      if (this.duration == null && duration == null) {
        throw FlutterError(
          'AnimationController.animateTo() called with no explicit duration and no default duration.\n'
          'Either the "duration" argument to the animateTo() method should be provided, or the '
          '"duration" property should be set, either in the constructor or later, before '
          'calling the animateTo() function.',
        );
      }
      return true;
    }());
    assert(
      _ticker != null,
      'AnimationController.animateTo() called after AnimationController.dispose()\n'
      'AnimationController methods should not be used after calling dispose.',
    );
    _direction = _AnimationDirection.forward;
    return _animateToInternal(target, duration: duration, curve: curve);
  }

  TickerFuture animateBack(double target, { Duration? duration, Curve curve = Curves.linear }) {
    assert(() {
      if (this.duration == null && reverseDuration == null && duration == null) {
        throw FlutterError(
          'AnimationController.animateBack() called with no explicit duration and no default duration or reverseDuration.\n'
          'Either the "duration" argument to the animateBack() method should be provided, or the '
          '"duration" or "reverseDuration" property should be set, either in the constructor or later, before '
          'calling the animateBack() function.',
        );
      }
      return true;
    }());
    assert(
      _ticker != null,
      'AnimationController.animateBack() called after AnimationController.dispose()\n'
      'AnimationController methods should not be used after calling dispose.',
    );
    _direction = _AnimationDirection.reverse;
    return _animateToInternal(target, duration: duration, curve: curve);
  }

  TickerFuture _animateToInternal(double target, { Duration? duration, Curve curve = Curves.linear }) {
    double scale = 1.0;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (animationBehavior) {
        case AnimationBehavior.normal:
          // Since the framework cannot handle zero duration animations, we run it at 5% of the normal
          // duration to limit most animations to a single frame.
          // Ideally, the framework would be able to handle zero duration animations, however, the common
          // pattern of an eternally repeating animation might cause an endless loop if it weren't delayed
          // for at least one frame.
          scale = 0.05;
        case AnimationBehavior.preserve:
          break;
      }
    }
    Duration? simulationDuration = duration;
    if (simulationDuration == null) {
      assert(!(this.duration == null && _direction == _AnimationDirection.forward));
      assert(!(this.duration == null && _direction == _AnimationDirection.reverse && reverseDuration == null));
      final double range = upperBound - lowerBound;
      final double remainingFraction = range.isFinite ? (target - _value).abs() / range : 1.0;
      final Duration directionDuration =
        (_direction == _AnimationDirection.reverse && reverseDuration != null)
        ? reverseDuration!
        : this.duration!;
      simulationDuration = directionDuration * remainingFraction;
    } else if (target == value) {
      // Already at target, don't animate.
      simulationDuration = Duration.zero;
    }
    stop();
    if (simulationDuration == Duration.zero) {
      if (value != target) {
        _value = clampDouble(target, lowerBound, upperBound);
        notifyListeners();
      }
      _status = (_direction == _AnimationDirection.forward) ?
        AnimationStatus.completed :
        AnimationStatus.dismissed;
      _checkStatusChanged();
      return TickerFuture.complete();
    }
    assert(simulationDuration > Duration.zero);
    assert(!isAnimating);
    return _startSimulation(_InterpolationSimulation(_value, target, simulationDuration, curve, scale));
  }

  TickerFuture repeat({ double? min, double? max, bool reverse = false, Duration? period }) {
    min ??= lowerBound;
    max ??= upperBound;
    period ??= duration;
    assert(() {
      if (period == null) {
        throw FlutterError(
          'AnimationController.repeat() called without an explicit period and with no default Duration.\n'
          'Either the "period" argument to the repeat() method should be provided, or the '
          '"duration" property should be set, either in the constructor or later, before '
          'calling the repeat() function.',
        );
      }
      return true;
    }());
    assert(max >= min);
    assert(max <= upperBound && min >= lowerBound);
    stop();
    return _startSimulation(_RepeatingSimulation(_value, min, max, reverse, period!, _directionSetter));
  }

  void _directionSetter(_AnimationDirection direction) {
    _direction = direction;
    _status = (_direction == _AnimationDirection.forward) ?
      AnimationStatus.forward :
      AnimationStatus.reverse;
    _checkStatusChanged();
  }

  TickerFuture fling({ double velocity = 1.0, SpringDescription? springDescription, AnimationBehavior? animationBehavior }) {
    springDescription ??= _kFlingSpringDescription;
    _direction = velocity < 0.0 ? _AnimationDirection.reverse : _AnimationDirection.forward;
    final double target = velocity < 0.0 ? lowerBound - _kFlingTolerance.distance
                                         : upperBound + _kFlingTolerance.distance;
    double scale = 1.0;
    final AnimationBehavior behavior = animationBehavior ?? this.animationBehavior;
    if (SemanticsBinding.instance.disableAnimations) {
      switch (behavior) {
        case AnimationBehavior.normal:
          scale = 200.0; // This is arbitrary (it was chosen because it worked for the drawer widget).
        case AnimationBehavior.preserve:
          break;
      }
    }
    final SpringSimulation simulation = SpringSimulation(springDescription, value, target, velocity * scale)
      ..tolerance = _kFlingTolerance;
    assert(
      simulation.type != SpringType.underDamped,
      'The specified spring simulation is of type SpringType.underDamped.\n'
      'An underdamped spring results in oscillation rather than a fling. '
      'Consider specifying a different springDescription, or use animateWith() '
      'with an explicit SpringSimulation if an underdamped spring is intentional.',
    );
    stop();
    return _startSimulation(simulation);
  }

  TickerFuture animateWith(Simulation simulation) {
    assert(
      _ticker != null,
      'AnimationController.animateWith() called after AnimationController.dispose()\n'
      'AnimationController methods should not be used after calling dispose.',
    );
    stop();
    _direction = _AnimationDirection.forward;
    return _startSimulation(simulation);
  }

  TickerFuture _startSimulation(Simulation simulation) {
    assert(!isAnimating);
    _simulation = simulation;
    _lastElapsedDuration = Duration.zero;
    _value = clampDouble(simulation.x(0.0), lowerBound, upperBound);
    final TickerFuture result = _ticker!.start();
    _status = (_direction == _AnimationDirection.forward) ?
      AnimationStatus.forward :
      AnimationStatus.reverse;
    _checkStatusChanged();
    return result;
  }

  void stop({ bool canceled = true }) {
    assert(
      _ticker != null,
      'AnimationController.stop() called after AnimationController.dispose()\n'
      'AnimationController methods should not be used after calling dispose.',
    );
    _simulation = null;
    _lastElapsedDuration = null;
    _ticker!.stop(canceled: canceled);
  }

  @override
  void dispose() {
    assert(() {
      if (_ticker == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('AnimationController.dispose() called more than once.'),
          ErrorDescription('A given $runtimeType cannot be disposed more than once.\n'),
          DiagnosticsProperty<AnimationController>(
            'The following $runtimeType object was disposed multiple times',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }
      return true;
    }());
    _ticker!.dispose();
    _ticker = null;
    clearStatusListeners();
    clearListeners();
    super.dispose();
  }

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    final AnimationStatus newStatus = status;
    if (_lastReportedStatus != newStatus) {
      _lastReportedStatus = newStatus;
      notifyStatusListeners(newStatus);
    }
  }

  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;
    final double elapsedInSeconds = elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
    assert(elapsedInSeconds >= 0.0);
    _value = clampDouble(_simulation!.x(elapsedInSeconds), lowerBound, upperBound);
    if (_simulation!.isDone(elapsedInSeconds)) {
      _status = (_direction == _AnimationDirection.forward) ?
        AnimationStatus.completed :
        AnimationStatus.dismissed;
      stop(canceled: false);
    }
    notifyListeners();
    _checkStatusChanged();
  }

  @override
  String toStringDetails() {
    final String paused = isAnimating ? '' : '; paused';
    final String ticker = _ticker == null ? '; DISPOSED' : (_ticker!.muted ? '; silenced' : '');
    String label = '';
    assert(() {
      if (debugLabel != null) {
        label = '; for $debugLabel';
      }
      return true;
    }());
    final String more = '${super.toStringDetails()} ${value.toStringAsFixed(3)}';
    return '$more$paused$ticker$label';
  }
}

class _InterpolationSimulation extends Simulation {
  _InterpolationSimulation(this._begin, this._end, Duration duration, this._curve, double scale)
    : assert(duration.inMicroseconds > 0),
      _durationInSeconds = (duration.inMicroseconds * scale) / Duration.microsecondsPerSecond;

  final double _durationInSeconds;
  final double _begin;
  final double _end;
  final Curve _curve;

  @override
  double x(double timeInSeconds) {
    final double t = clampDouble(timeInSeconds / _durationInSeconds, 0.0, 1.0);
    if (t == 0.0) {
      return _begin;
    } else if (t == 1.0) {
      return _end;
    } else {
      return _begin + (_end - _begin) * _curve.transform(t);
    }
  }

  @override
  double dx(double timeInSeconds) {
    final double epsilon = tolerance.time;
    return (x(timeInSeconds + epsilon) - x(timeInSeconds - epsilon)) / (2 * epsilon);
  }

  @override
  bool isDone(double timeInSeconds) => timeInSeconds > _durationInSeconds;
}

typedef _DirectionSetter = void Function(_AnimationDirection direction);

class _RepeatingSimulation extends Simulation {
  _RepeatingSimulation(double initialValue, this.min, this.max, this.reverse, Duration period, this.directionSetter)
      : _periodInSeconds = period.inMicroseconds / Duration.microsecondsPerSecond,
        _initialT = (max == min) ? 0.0 : (initialValue / (max - min)) * (period.inMicroseconds / Duration.microsecondsPerSecond) {
    assert(_periodInSeconds > 0.0);
    assert(_initialT >= 0.0);
  }

  final double min;
  final double max;
  final bool reverse;
  final _DirectionSetter directionSetter;

  final double _periodInSeconds;
  final double _initialT;

  @override
  double x(double timeInSeconds) {
    assert(timeInSeconds >= 0.0);

    final double totalTimeInSeconds = timeInSeconds + _initialT;
    final double t = (totalTimeInSeconds / _periodInSeconds) % 1.0;
    final bool isPlayingReverse = (totalTimeInSeconds ~/ _periodInSeconds).isOdd;

    if (reverse && isPlayingReverse) {
      directionSetter(_AnimationDirection.reverse);
      return ui.lerpDouble(max, min, t)!;
    } else {
      directionSetter(_AnimationDirection.forward);
      return ui.lerpDouble(min, max, t)!;
    }
  }

  @override
  double dx(double timeInSeconds) => (max - min) / _periodInSeconds;

  @override
  bool isDone(double timeInSeconds) => false;
}