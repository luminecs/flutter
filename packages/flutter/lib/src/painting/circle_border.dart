import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'borders.dart';

class CircleBorder extends OutlinedBorder {
  const CircleBorder({super.side, this.eccentricity = 0.0})
      : assert(eccentricity >= 0.0,
            'The eccentricity argument $eccentricity is not greater than or equal to zero.'),
        assert(eccentricity <= 1.0,
            'The eccentricity argument $eccentricity is not less than or equal to one.');

  final double eccentricity;

  @override
  ShapeBorder scale(double t) =>
      CircleBorder(side: side.scale(t), eccentricity: eccentricity);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is CircleBorder) {
      return CircleBorder(
        side: BorderSide.lerp(a.side, side, t),
        eccentricity: clampDouble(
            ui.lerpDouble(a.eccentricity, eccentricity, t)!, 0.0, 1.0),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is CircleBorder) {
      return CircleBorder(
        side: BorderSide.lerp(side, b.side, t),
        eccentricity: clampDouble(
            ui.lerpDouble(eccentricity, b.eccentricity, t)!, 0.0, 1.0),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addOval(_adjustRect(rect).deflate(side.strokeInset));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addOval(_adjustRect(rect));
  }

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint,
      {TextDirection? textDirection}) {
    if (eccentricity == 0.0) {
      canvas.drawCircle(rect.center, rect.shortestSide / 2.0, paint);
    } else {
      canvas.drawOval(_adjustRect(rect), paint);
    }
  }

  @override
  bool get preferPaintInterior => true;

  @override
  CircleBorder copyWith({BorderSide? side, double? eccentricity}) {
    return CircleBorder(
        side: side ?? this.side,
        eccentricity: eccentricity ?? this.eccentricity);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        if (eccentricity == 0.0) {
          canvas.drawCircle(rect.center,
              (rect.shortestSide + side.strokeOffset) / 2, side.toPaint());
        } else {
          final Rect borderRect = _adjustRect(rect);
          canvas.drawOval(
              borderRect.inflate(side.strokeOffset / 2), side.toPaint());
        }
    }
  }

  Rect _adjustRect(Rect rect) {
    if (eccentricity == 0.0 || rect.width == rect.height) {
      return Rect.fromCircle(
          center: rect.center, radius: rect.shortestSide / 2.0);
    }
    if (rect.width < rect.height) {
      final double delta =
          (1.0 - eccentricity) * (rect.height - rect.width) / 2.0;
      return Rect.fromLTRB(
        rect.left,
        rect.top + delta,
        rect.right,
        rect.bottom - delta,
      );
    } else {
      final double delta =
          (1.0 - eccentricity) * (rect.width - rect.height) / 2.0;
      return Rect.fromLTRB(
        rect.left + delta,
        rect.top,
        rect.right - delta,
        rect.bottom,
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CircleBorder &&
        other.side == side &&
        other.eccentricity == eccentricity;
  }

  @override
  int get hashCode => Object.hash(side, eccentricity);

  @override
  String toString() {
    if (eccentricity != 0.0) {
      return '${objectRuntimeType(this, 'CircleBorder')}($side, eccentricity: $eccentricity)';
    }
    return '${objectRuntimeType(this, 'CircleBorder')}($side)';
  }
}
