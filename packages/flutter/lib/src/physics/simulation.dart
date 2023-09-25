
import 'package:flutter/foundation.dart';

import 'tolerance.dart';

export 'tolerance.dart' show Tolerance;

abstract class Simulation {
  Simulation({ this.tolerance = Tolerance.defaultTolerance });

  double x(double time);

  double dx(double time);

  bool isDone(double time);

  Tolerance tolerance;

  @override
  String toString() => objectRuntimeType(this, 'Simulation');
}