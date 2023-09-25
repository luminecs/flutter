import 'package:flutter/foundation.dart';

class Tolerance {
  const Tolerance({
    this.distance = _epsilonDefault,
    this.time = _epsilonDefault,
    this.velocity = _epsilonDefault,
  });

  static const double _epsilonDefault = 1e-3;

  static const Tolerance defaultTolerance = Tolerance();

  final double distance;

  final double time;

  final double velocity;

  @override
  String toString() => '${objectRuntimeType(this, 'Tolerance')}(distance: ±$distance, time: ±$time, velocity: ±$velocity)';
}