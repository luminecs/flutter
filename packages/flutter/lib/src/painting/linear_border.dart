
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'borders.dart';
import 'edge_insets.dart';

@immutable
class LinearBorderEdge {
  const LinearBorderEdge({
    this.size = 1.0,
    this.alignment = 0.0,
  }) : assert(size >= 0.0 && size <= 1.0);

  final double size;

  final double alignment;

  static LinearBorderEdge? lerp(LinearBorderEdge? a, LinearBorderEdge? b, double t) {
    if (identical(a, b)) {
      return a;
    }

    a ??= LinearBorderEdge(alignment: b!.alignment, size: 0);
    b ??= LinearBorderEdge(alignment: a.alignment, size: 0);

    return LinearBorderEdge(
      size: lerpDouble(a.size, b.size, t)!,
      alignment: lerpDouble(a.alignment, b.alignment, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is LinearBorderEdge
        && other.size == size
        && other.alignment == alignment;
  }

  @override
  int get hashCode => Object.hash(size, alignment);

  @override
  String toString() {
    final StringBuffer s = StringBuffer('${objectRuntimeType(this, 'LinearBorderEdge')}(');
    if (size != 1.0 ) {
      s.write('size: $size');
    }
    if (alignment != 0) {
      final String comma = size != 1.0 ? ', ' : '';
      s.write('${comma}alignment: $alignment');
    }
    s.write(')');
    return s.toString();
  }
}

class LinearBorder extends OutlinedBorder {
  const LinearBorder({
    super.side,
    this.start,
    this.end,
    this.top,
    this.bottom,
  });

  LinearBorder.start({
    super.side,
    double alignment = 0.0,
    double size = 1.0
  }) : start = LinearBorderEdge(alignment: alignment, size: size),
       end = null,
       top = null,
       bottom = null;

  LinearBorder.end({
    super.side,
    double alignment = 0.0,
    double size = 1.0
  }) : start = null,
       end = LinearBorderEdge(alignment: alignment, size: size),
       top = null,
       bottom = null;

  LinearBorder.top({
    super.side,
    double alignment = 0.0,
    double size = 1.0
  }) : start = null,
       end = null,
       top = LinearBorderEdge(alignment: alignment, size: size),
       bottom = null;

  LinearBorder.bottom({
    super.side,
    double alignment = 0.0,
    double size = 1.0
  }) : start = null,
       end = null,
       top = null,
       bottom = LinearBorderEdge(alignment: alignment, size: size);

  static const LinearBorder none = LinearBorder();

  final LinearBorderEdge? start;

  final LinearBorderEdge? end;

  final LinearBorderEdge? top;

  final LinearBorderEdge? bottom;

  @override
  LinearBorder scale(double t) {
    return LinearBorder(
      side: side.scale(t),
    );
  }

  @override
  EdgeInsetsGeometry get dimensions {
    final double width = side.width;
    return EdgeInsetsDirectional.fromSTEB(
      start == null ? 0.0 : width,
      top == null ? 0.0 : width,
      end == null ? 0.0 : width,
      bottom == null ? 0.0 : width,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is LinearBorder) {
      return LinearBorder(
        side: BorderSide.lerp(a.side, side, t),
        start: LinearBorderEdge.lerp(a.start, start, t),
        end: LinearBorderEdge.lerp(a.end, end, t),
        top: LinearBorderEdge.lerp(a.top, top, t),
        bottom: LinearBorderEdge.lerp(a.bottom, bottom, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is LinearBorder) {
      return LinearBorder(
        side: BorderSide.lerp(side, b.side, t),
        start: LinearBorderEdge.lerp(start, b.start, t),
        end: LinearBorderEdge.lerp(end, b.end, t),
        top: LinearBorderEdge.lerp(top, b.top, t),
        bottom: LinearBorderEdge.lerp(bottom, b.bottom, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  LinearBorder copyWith({
    BorderSide? side,
    LinearBorderEdge? start,
    LinearBorderEdge? end,
    LinearBorderEdge? top,
    LinearBorderEdge? bottom,
  }) {
    return LinearBorder(
      side: side ?? this.side,
      start: start ?? this.start,
      end: end ?? this.end,
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  Path getInnerPath(Rect rect, { TextDirection? textDirection }) {
    final Rect adjustedRect = dimensions.resolve(textDirection).deflateRect(rect);
    return Path()
      ..addRect(adjustedRect);
  }

  @override
  Path getOuterPath(Rect rect, { TextDirection? textDirection }) {
    return Path()
      ..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, { TextDirection? textDirection }) {
    final EdgeInsets insets = dimensions.resolve(textDirection);
    final bool rtl = textDirection == TextDirection.rtl;

    final Path path = Path();
    final Paint paint = Paint()
      ..strokeWidth = 0.0;

    void drawEdge(Rect rect, Color color) {
      paint.color = color;
      path.reset();
      path.moveTo(rect.left, rect.top);
      if (rect.width == 0.0) {
        paint.style = PaintingStyle.stroke;
        path.lineTo(rect.left, rect.bottom);
      } else if (rect.height == 0.0) {
        paint.style = PaintingStyle.stroke;
        path.lineTo(rect.right, rect.top);
      } else {
        paint.style = PaintingStyle.fill;
        path.lineTo(rect.right, rect.top);
        path.lineTo(rect.right, rect.bottom);
        path.lineTo(rect.left, rect.bottom);
      }
      canvas.drawPath(path, paint);
    }

    if (start != null && start!.size != 0.0 && side.style != BorderStyle.none) {
      final Rect insetRect = Rect.fromLTWH(rect.left, rect.top + insets.top, rect.width, rect.height - insets.vertical);
      final double x = rtl ? rect.right - insets.right : rect.left;
      final double width = rtl ? insets.right : insets.left;
      final double height = insetRect.height * start!.size;
      final double y = (insetRect.height - height) * ((start!.alignment + 1.0) / 2.0);
      final Rect r = Rect.fromLTWH(x, y, width, height);
      drawEdge(r, side.color);
    }

    if (end != null && end!.size != 0.0 && side.style != BorderStyle.none) {
      final Rect insetRect = Rect.fromLTWH(rect.left, rect.top + insets.top, rect.width, rect.height - insets.vertical);
      final double x = rtl ? rect.left : rect.right - insets.right;
      final double width = rtl ? insets.left : insets.right;
      final double height = insetRect.height * end!.size;
      final double y = (insetRect.height - height) * ((end!.alignment + 1.0) / 2.0);
      final Rect r = Rect.fromLTWH(x, y, width, height);
      drawEdge(r, side.color);
    }

    if (top != null && top!.size != 0.0 && side.style != BorderStyle.none) {
      final double width = rect.width * top!.size;
      final double startX = (rect.width - width) * ((top!.alignment + 1.0) / 2.0);
      final double x = rtl ? rect.width - startX - width : startX;
      final Rect r = Rect.fromLTWH(x, rect.top, width, insets.top);
      drawEdge(r, side.color);
    }

    if (bottom != null && bottom!.size != 0.0 && side.style != BorderStyle.none) {
      final double width = rect.width * bottom!.size;
      final double startX = (rect.width - width) * ((bottom!.alignment + 1.0) / 2.0);
      final double x = rtl ? rect.width - startX - width: startX;
      final Rect r = Rect.fromLTWH(x, rect.bottom - insets.bottom, width, side.width);
      drawEdge(r, side.color);
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
    return other is LinearBorder
      && other.side == side
      && other.start == start
      && other.end == end
      && other.top == top
      && other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(side, start, end, top, bottom);

  @override
  String toString() {
    if (this == LinearBorder.none) {
      return 'LinearBorder.none';
    }

    final StringBuffer s = StringBuffer('${objectRuntimeType(this, 'LinearBorder')}(side: $side');

    if (start != null ) {
      s.write(', start: $start');
    }
    if (end != null ) {
      s.write(', end: $end');
    }
    if (top != null ) {
      s.write(', top: $top');
    }
    if (bottom != null ) {
      s.write(', bottom: $bottom');
    }
    s.write(')');
    return s.toString();
  }
}