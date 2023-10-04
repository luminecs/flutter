
import 'package:flutter/foundation.dart';

import 'simulation.dart';

// Examples can assume:
// late AnimationController _controller;

class GravitySimulation extends Simulation {
  GravitySimulation(
    double acceleration,
    double distance,
    double endDistance,
    double velocity,
  ) : assert(endDistance >= 0),
      _a = acceleration,
      _x = distance,
      _v = velocity,
      _end = endDistance;

  final double _x;
  final double _v;
  final double _a;
  final double _end;

  @override
  double x(double time) => _x + _v * time + 0.5 * _a * time * time;

  @override
  double dx(double time) => _v + time * _a;

  @override
  bool isDone(double time) => x(time).abs() >= _end;

  @override
  String toString() => '${objectRuntimeType(this, 'GravitySimulation')}(g: ${_a.toStringAsFixed(1)}, x₀: ${_x.toStringAsFixed(1)}, dx₀: ${_v.toStringAsFixed(1)}, xₘₐₓ: ±${_end.toStringAsFixed(1)})';
}