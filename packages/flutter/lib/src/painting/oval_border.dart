
import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';

import 'borders.dart';
import 'circle_border.dart';

class OvalBorder extends CircleBorder {
  const OvalBorder({ super.side, super.eccentricity = 1.0 });

  @override
  ShapeBorder scale(double t) => OvalBorder(side: side.scale(t), eccentricity: eccentricity);

  @override
  OvalBorder copyWith({ BorderSide? side, double? eccentricity }) {
    return OvalBorder(side: side ?? this.side, eccentricity: eccentricity ?? this.eccentricity);
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is OvalBorder) {
      return OvalBorder(
        side: BorderSide.lerp(a.side, side, t),
        eccentricity: clampDouble(ui.lerpDouble(a.eccentricity, eccentricity, t)!, 0.0, 1.0),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is OvalBorder) {
      return OvalBorder(
        side: BorderSide.lerp(side, b.side, t),
        eccentricity: clampDouble(ui.lerpDouble(eccentricity, b.eccentricity, t)!, 0.0, 1.0),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  String toString() {
    if (eccentricity != 1.0) {
      return '${objectRuntimeType(this, 'OvalBorder')}($side, eccentricity: $eccentricity)';
    }
    return '${objectRuntimeType(this, 'OvalBorder')}($side)';
  }
}