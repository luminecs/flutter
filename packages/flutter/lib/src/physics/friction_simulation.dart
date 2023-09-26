import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'simulation.dart';

export 'tolerance.dart' show Tolerance;

double _newtonsMethod(
    {required double initialGuess,
    required double target,
    required double Function(double) f,
    required double Function(double) df,
    required int iterations}) {
  double guess = initialGuess;
  for (int i = 0; i < iterations; i++) {
    guess = guess - (f(guess) - target) / df(guess);
  }
  return guess;
}

class FrictionSimulation extends Simulation {
  FrictionSimulation(double drag, double position, double velocity,
      {super.tolerance, double constantDeceleration = 0})
      : _drag = drag,
        _dragLog = math.log(drag),
        _x = position,
        _v = velocity,
        _constantDeceleration = constantDeceleration * velocity.sign {
    _finalTime = _newtonsMethod(
        initialGuess: 0,
        target: 0,
        f: dx,
        df: (double time) =>
            (_v * math.pow(_drag, time) * _dragLog) - _constantDeceleration,
        iterations: 10);
  }

  factory FrictionSimulation.through(double startPosition, double endPosition,
      double startVelocity, double endVelocity) {
    assert(startVelocity == 0.0 ||
        endVelocity == 0.0 ||
        startVelocity.sign == endVelocity.sign);
    assert(startVelocity.abs() >= endVelocity.abs());
    assert((endPosition - startPosition).sign == startVelocity.sign);
    return FrictionSimulation(
      _dragFor(startPosition, endPosition, startVelocity, endVelocity),
      startPosition,
      startVelocity,
      tolerance: Tolerance(velocity: endVelocity.abs()),
    );
  }

  final double _drag;
  final double _dragLog;
  final double _x;
  final double _v;
  final double _constantDeceleration;
  // The time at which the simulation should be stopped.
  // This is needed when constantDeceleration is not zero (on Desktop), when
  // using the pure friction simulation, acceleration naturally reduces to zero
  // and creates a stopping point.
  double _finalTime = double
      .infinity; // needs to be infinity for newtonsMethod call in constructor.

  // Return the drag value for a FrictionSimulation whose x() and dx() values pass
  // through the specified start and end position/velocity values.
  //
  // Total time to reach endVelocity is just: (log(endVelocity) / log(startVelocity)) / log(_drag)
  // or (log(v1) - log(v0)) / log(D), given v = v0 * D^t per the dx() function below.
  // Solving for D given x(time) is trickier. Algebra courtesy of Wolfram Alpha:
  // x1 = x0 + (v0 * D^((log(v1) - log(v0)) / log(D))) / log(D) - v0 / log(D), find D
  static double _dragFor(double startPosition, double endPosition,
      double startVelocity, double endVelocity) {
    return math.pow(math.e,
            (startVelocity - endVelocity) / (startPosition - endPosition))
        as double;
  }

  @override
  double x(double time) {
    if (time > _finalTime) {
      return finalX;
    }
    return _x +
        _v * math.pow(_drag, time) / _dragLog -
        _v / _dragLog -
        ((_constantDeceleration / 2) * time * time);
  }

  @override
  double dx(double time) {
    if (time > _finalTime) {
      return 0;
    }
    return _v * math.pow(_drag, time) - _constantDeceleration * time;
  }

  double get finalX {
    if (_constantDeceleration == 0) {
      return _x - _v / _dragLog;
    }
    return x(_finalTime);
  }

  double timeAtX(double x) {
    if (x == _x) {
      return 0.0;
    }
    if (_v == 0.0 ||
        (_v > 0 ? (x < _x || x > finalX) : (x > _x || x < finalX))) {
      return double.infinity;
    }
    return _newtonsMethod(
        target: x, initialGuess: 0, f: this.x, df: dx, iterations: 10);
  }

  @override
  bool isDone(double time) {
    return dx(time).abs() < tolerance.velocity;
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'FrictionSimulation')}(cₓ: ${_drag.toStringAsFixed(1)}, x₀: ${_x.toStringAsFixed(1)}, dx₀: ${_v.toStringAsFixed(1)})';
}

class BoundedFrictionSimulation extends FrictionSimulation {
  BoundedFrictionSimulation(
    super.drag,
    super.position,
    super.velocity,
    this._minX,
    this._maxX,
  ) : assert(clampDouble(position, _minX, _maxX) == position);

  final double _minX;
  final double _maxX;

  @override
  double x(double time) {
    return clampDouble(super.x(time), _minX, _maxX);
  }

  @override
  bool isDone(double time) {
    return super.isDone(time) ||
        (x(time) - _minX).abs() < tolerance.distance ||
        (x(time) - _maxX).abs() < tolerance.distance;
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'BoundedFrictionSimulation')}(cₓ: ${_drag.toStringAsFixed(1)}, x₀: ${_x.toStringAsFixed(1)}, dx₀: ${_v.toStringAsFixed(1)}, x: ${_minX.toStringAsFixed(1)}..${_maxX.toStringAsFixed(1)})';
}
