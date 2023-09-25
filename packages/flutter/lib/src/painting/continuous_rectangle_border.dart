import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'border_radius.dart';
import 'borders.dart';
import 'edge_insets.dart';

class ContinuousRectangleBorder extends OutlinedBorder {
  const ContinuousRectangleBorder({
    super.side,
    this.borderRadius = BorderRadius.zero,
  });

  final BorderRadiusGeometry borderRadius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) {
    return ContinuousRectangleBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ContinuousRectangleBorder) {
      return ContinuousRectangleBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ContinuousRectangleBorder) {
      return ContinuousRectangleBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  double _clampToShortest(RRect rrect, double value) {
    return value > rrect.shortestSide ? rrect.shortestSide : value;
  }

  Path _getPath(RRect rrect) {
    final double left = rrect.left;
    final double right = rrect.right;
    final double top = rrect.top;
    final double bottom = rrect.bottom;
    //  Radii will be clamped to the value of the shortest side
    // of rrect to avoid strange tie-fighter shapes.
    final double tlRadiusX =
      math.max(0.0, _clampToShortest(rrect, rrect.tlRadiusX));
    final double tlRadiusY =
      math.max(0.0, _clampToShortest(rrect, rrect.tlRadiusY));
    final double trRadiusX =
      math.max(0.0, _clampToShortest(rrect, rrect.trRadiusX));
    final double trRadiusY =
      math.max(0.0, _clampToShortest(rrect, rrect.trRadiusY));
    final double blRadiusX =
      math.max(0.0, _clampToShortest(rrect, rrect.blRadiusX));
    final double blRadiusY =
      math.max(0.0, _clampToShortest(rrect, rrect.blRadiusY));
    final double brRadiusX =
      math.max(0.0, _clampToShortest(rrect, rrect.brRadiusX));
    final double brRadiusY =
      math.max(0.0, _clampToShortest(rrect, rrect.brRadiusY));

    return Path()
      ..moveTo(left, top + tlRadiusX)
      ..cubicTo(left, top, left, top, left + tlRadiusY, top)
      ..lineTo(right - trRadiusX, top)
      ..cubicTo(right, top, right, top, right, top + trRadiusY)
      ..lineTo(right, bottom - brRadiusX)
      ..cubicTo(right, bottom, right, bottom, right - brRadiusY, bottom)
      ..lineTo(left + blRadiusX, bottom)
      ..cubicTo(left, bottom, left, bottom, left, bottom - blRadiusY)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, { TextDirection? textDirection }) {
    return _getPath(borderRadius.resolve(textDirection).toRRect(rect).deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, { TextDirection? textDirection }) {
    return _getPath(borderRadius.resolve(textDirection).toRRect(rect));
  }

  @override
  ContinuousRectangleBorder copyWith({ BorderSide? side, BorderRadiusGeometry? borderRadius }) {
    return ContinuousRectangleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, { TextDirection? textDirection }) {
    if (rect.isEmpty) {
      return;
    }
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        canvas.drawPath(
          getOuterPath(rect, textDirection: textDirection),
          side.toPaint(),
        );
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ContinuousRectangleBorder
        && other.side == side
        && other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(side, borderRadius);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ContinuousRectangleBorder')}($side, $borderRadius)';
  }
}