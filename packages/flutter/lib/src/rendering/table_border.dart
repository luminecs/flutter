import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' hide Border;

@immutable
class TableBorder {
  const TableBorder({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
    this.horizontalInside = BorderSide.none,
    this.verticalInside = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
  });

  factory TableBorder.all({
    Color color = const Color(0xFF000000),
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    final BorderSide side =
        BorderSide(color: color, width: width, style: style);
    return TableBorder(
        top: side,
        right: side,
        bottom: side,
        left: side,
        horizontalInside: side,
        verticalInside: side,
        borderRadius: borderRadius);
  }

  factory TableBorder.symmetric({
    BorderSide inside = BorderSide.none,
    BorderSide outside = BorderSide.none,
  }) {
    return TableBorder(
      top: outside,
      right: outside,
      bottom: outside,
      left: outside,
      horizontalInside: inside,
      verticalInside: inside,
    );
  }

  final BorderSide top;

  final BorderSide right;

  final BorderSide bottom;

  final BorderSide left;

  final BorderSide horizontalInside;

  final BorderSide verticalInside;

  final BorderRadius borderRadius;

  EdgeInsets get dimensions {
    return EdgeInsets.fromLTRB(
        left.width, top.width, right.width, bottom.width);
  }

  bool get isUniform {
    final Color topColor = top.color;
    if (right.color != topColor ||
        bottom.color != topColor ||
        left.color != topColor ||
        horizontalInside.color != topColor ||
        verticalInside.color != topColor) {
      return false;
    }

    final double topWidth = top.width;
    if (right.width != topWidth ||
        bottom.width != topWidth ||
        left.width != topWidth ||
        horizontalInside.width != topWidth ||
        verticalInside.width != topWidth) {
      return false;
    }

    final BorderStyle topStyle = top.style;
    if (right.style != topStyle ||
        bottom.style != topStyle ||
        left.style != topStyle ||
        horizontalInside.style != topStyle ||
        verticalInside.style != topStyle) {
      return false;
    }

    return true;
  }

  TableBorder scale(double t) {
    return TableBorder(
      top: top.scale(t),
      right: right.scale(t),
      bottom: bottom.scale(t),
      left: left.scale(t),
      horizontalInside: horizontalInside.scale(t),
      verticalInside: verticalInside.scale(t),
    );
  }

  static TableBorder? lerp(TableBorder? a, TableBorder? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    return TableBorder(
      top: BorderSide.lerp(a.top, b.top, t),
      right: BorderSide.lerp(a.right, b.right, t),
      bottom: BorderSide.lerp(a.bottom, b.bottom, t),
      left: BorderSide.lerp(a.left, b.left, t),
      horizontalInside:
          BorderSide.lerp(a.horizontalInside, b.horizontalInside, t),
      verticalInside: BorderSide.lerp(a.verticalInside, b.verticalInside, t),
    );
  }

  void paint(
    Canvas canvas,
    Rect rect, {
    required Iterable<double> rows,
    required Iterable<double> columns,
  }) {
    // properties can't be null

    // arguments can't be null
    assert(rows.isEmpty || (rows.first >= 0.0 && rows.last <= rect.height));
    assert(columns.isEmpty ||
        (columns.first >= 0.0 && columns.last <= rect.width));

    if (columns.isNotEmpty || rows.isNotEmpty) {
      final Paint paint = Paint();
      final Path path = Path();

      if (columns.isNotEmpty) {
        switch (verticalInside.style) {
          case BorderStyle.solid:
            paint
              ..color = verticalInside.color
              ..strokeWidth = verticalInside.width
              ..style = PaintingStyle.stroke;
            path.reset();
            for (final double x in columns) {
              path.moveTo(rect.left + x, rect.top);
              path.lineTo(rect.left + x, rect.bottom);
            }
            canvas.drawPath(path, paint);
          case BorderStyle.none:
            break;
        }
      }

      if (rows.isNotEmpty) {
        switch (horizontalInside.style) {
          case BorderStyle.solid:
            paint
              ..color = horizontalInside.color
              ..strokeWidth = horizontalInside.width
              ..style = PaintingStyle.stroke;
            path.reset();
            for (final double y in rows) {
              path.moveTo(rect.left, rect.top + y);
              path.lineTo(rect.right, rect.top + y);
            }
            canvas.drawPath(path, paint);
          case BorderStyle.none:
            break;
        }
      }
    }
    if (!isUniform || borderRadius == BorderRadius.zero) {
      paintBorder(canvas, rect,
          top: top, right: right, bottom: bottom, left: left);
    } else {
      final RRect outer = borderRadius.toRRect(rect);
      final RRect inner = outer.deflate(top.width);
      final Paint paint = Paint()..color = top.color;
      canvas.drawDRRect(outer, inner, paint);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TableBorder &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.left == left &&
        other.horizontalInside == horizontalInside &&
        other.verticalInside == verticalInside &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(
      top, right, bottom, left, horizontalInside, verticalInside, borderRadius);

  @override
  String toString() =>
      'TableBorder($top, $right, $bottom, $left, $horizontalInside, $verticalInside, $borderRadius)';
}
