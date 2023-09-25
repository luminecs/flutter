
import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';

import 'alignment.dart';
import 'basic_types.dart';

@immutable
class FractionalOffset extends Alignment {
  const FractionalOffset(double dx, double dy)
    : super(dx * 2.0 - 1.0, dy * 2.0 - 1.0);

  factory FractionalOffset.fromOffsetAndSize(Offset offset, Size size) {
    return FractionalOffset(
      offset.dx / size.width,
      offset.dy / size.height,
    );
  }

  factory FractionalOffset.fromOffsetAndRect(Offset offset, Rect rect) {
    return FractionalOffset.fromOffsetAndSize(
      offset - rect.topLeft,
      rect.size,
    );
  }

  double get dx => (x + 1.0) / 2.0;

  double get dy => (y + 1.0) / 2.0;

  static const FractionalOffset topLeft = FractionalOffset(0.0, 0.0);

  static const FractionalOffset topCenter = FractionalOffset(0.5, 0.0);

  static const FractionalOffset topRight = FractionalOffset(1.0, 0.0);

  static const FractionalOffset centerLeft = FractionalOffset(0.0, 0.5);

  static const FractionalOffset center = FractionalOffset(0.5, 0.5);

  static const FractionalOffset centerRight = FractionalOffset(1.0, 0.5);

  static const FractionalOffset bottomLeft = FractionalOffset(0.0, 1.0);

  static const FractionalOffset bottomCenter = FractionalOffset(0.5, 1.0);

  static const FractionalOffset bottomRight = FractionalOffset(1.0, 1.0);

  @override
  Alignment operator -(Alignment other) {
    if (other is! FractionalOffset) {
      return super - other;
    }
    return FractionalOffset(dx - other.dx, dy - other.dy);
  }

  @override
  Alignment operator +(Alignment other) {
    if (other is! FractionalOffset) {
      return super + other;
    }
    return FractionalOffset(dx + other.dx, dy + other.dy);
  }

  @override
  FractionalOffset operator -() {
    return FractionalOffset(-dx, -dy);
  }

  @override
  FractionalOffset operator *(double other) {
    return FractionalOffset(dx * other, dy * other);
  }

  @override
  FractionalOffset operator /(double other) {
    return FractionalOffset(dx / other, dy / other);
  }

  @override
  FractionalOffset operator ~/(double other) {
    return FractionalOffset((dx ~/ other).toDouble(), (dy ~/ other).toDouble());
  }

  @override
  FractionalOffset operator %(double other) {
    return FractionalOffset(dx % other, dy % other);
  }

  static FractionalOffset? lerp(FractionalOffset? a, FractionalOffset? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return FractionalOffset(ui.lerpDouble(0.5, b!.dx, t)!, ui.lerpDouble(0.5, b.dy, t)!);
    }
    if (b == null) {
      return FractionalOffset(ui.lerpDouble(a.dx, 0.5, t)!, ui.lerpDouble(a.dy, 0.5, t)!);
    }
    return FractionalOffset(ui.lerpDouble(a.dx, b.dx, t)!, ui.lerpDouble(a.dy, b.dy, t)!);
  }

  @override
  String toString() {
    return 'FractionalOffset(${dx.toStringAsFixed(1)}, '
                            '${dy.toStringAsFixed(1)})';
  }
}