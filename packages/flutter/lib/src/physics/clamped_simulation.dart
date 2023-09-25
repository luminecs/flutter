import 'package:flutter/foundation.dart';

import 'simulation.dart';

export 'simulation.dart' show Simulation;

class ClampedSimulation extends Simulation {
  ClampedSimulation(
    this.simulation, {
    this.xMin = double.negativeInfinity,
    this.xMax = double.infinity,
    this.dxMin = double.negativeInfinity,
    this.dxMax = double.infinity,
  }) : assert(xMax >= xMin),
       assert(dxMax >= dxMin);

  final Simulation simulation;

  final double xMin;

  final double xMax;

  final double dxMin;

  final double dxMax;

  @override
  double x(double time) => clampDouble(simulation.x(time), xMin, xMax);

  @override
  double dx(double time) => clampDouble(simulation.dx(time), dxMin, dxMax);

  @override
  bool isDone(double time) => simulation.isDone(time);

  @override
  String toString() => '${objectRuntimeType(this, 'ClampedSimulation')}(simulation: $simulation, x: ${xMin.toStringAsFixed(1)}..${xMax.toStringAsFixed(1)}, dx: ${dxMin.toStringAsFixed(1)}..${dxMax.toStringAsFixed(1)})';
}