import 'dart:math' as math;
import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'edge_insets.dart';

enum BorderStyle {
  none,

  solid,

  // if you add more, think about how they will lerp
}

@immutable
class BorderSide with Diagnosticable {
  const BorderSide({
    this.color = const Color(0xFF000000),
    this.width = 1.0,
    this.style = BorderStyle.solid,
    this.strokeAlign = strokeAlignInside,
  }) : assert(width >= 0.0);

  static BorderSide merge(BorderSide a, BorderSide b) {
    assert(canMerge(a, b));
    final bool aIsNone = a.style == BorderStyle.none && a.width == 0.0;
    final bool bIsNone = b.style == BorderStyle.none && b.width == 0.0;
    if (aIsNone && bIsNone) {
      return BorderSide.none;
    }
    if (aIsNone) {
      return b;
    }
    if (bIsNone) {
      return a;
    }
    assert(a.color == b.color);
    assert(a.style == b.style);
    return BorderSide(
      color: a.color, // == b.color
      width: a.width + b.width,
      strokeAlign: math.max(a.strokeAlign, b.strokeAlign),
      style: a.style, // == b.style
    );
  }

  final Color color;

  final double width;

  final BorderStyle style;

  static const BorderSide none = BorderSide(width: 0.0, style: BorderStyle.none);

  final double strokeAlign;

  static const double strokeAlignInside = -1.0;

  static const double strokeAlignCenter = 0.0;

  static const double strokeAlignOutside = 1.0;

  BorderSide copyWith({
    Color? color,
    double? width,
    BorderStyle? style,
    double? strokeAlign,
  }) {
    return BorderSide(
      color: color ?? this.color,
      width: width ?? this.width,
      style: style ?? this.style,
      strokeAlign: strokeAlign ?? this.strokeAlign,
    );
  }

  BorderSide scale(double t) {
    return BorderSide(
      color: color,
      width: math.max(0.0, width * t),
      style: t <= 0.0 ? BorderStyle.none : style,
    );
  }

  Paint toPaint() {
    switch (style) {
      case BorderStyle.solid:
        return Paint()
          ..color = color
          ..strokeWidth = width
          ..style = PaintingStyle.stroke;
      case BorderStyle.none:
        return Paint()
          ..color = const Color(0x00000000)
          ..strokeWidth = 0.0
          ..style = PaintingStyle.stroke;
    }
  }

  static bool canMerge(BorderSide a, BorderSide b) {
    if ((a.style == BorderStyle.none && a.width == 0.0) ||
        (b.style == BorderStyle.none && b.width == 0.0)) {
      return true;
    }
    return a.style == b.style
        && a.color == b.color;
  }

  static BorderSide lerp(BorderSide a, BorderSide b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (t == 0.0) {
      return a;
    }
    if (t == 1.0) {
      return b;
    }
    final double width = ui.lerpDouble(a.width, b.width, t)!;
    if (width < 0.0) {
      return BorderSide.none;
    }
    if (a.style == b.style && a.strokeAlign == b.strokeAlign) {
      return BorderSide(
        color: Color.lerp(a.color, b.color, t)!,
        width: width,
        style: a.style, // == b.style
        strokeAlign: a.strokeAlign, // == b.strokeAlign
      );
    }
    final Color colorA, colorB;
    switch (a.style) {
      case BorderStyle.solid:
        colorA = a.color;
      case BorderStyle.none:
        colorA = a.color.withAlpha(0x00);
    }
    switch (b.style) {
      case BorderStyle.solid:
        colorB = b.color;
      case BorderStyle.none:
        colorB = b.color.withAlpha(0x00);
    }
    if (a.strokeAlign != b.strokeAlign) {
      return BorderSide(
        color: Color.lerp(colorA, colorB, t)!,
        width: width,
        strokeAlign: ui.lerpDouble(a.strokeAlign, b.strokeAlign, t)!,
      );
    }
    return BorderSide(
      color: Color.lerp(colorA, colorB, t)!,
      width: width,
      strokeAlign: a.strokeAlign, // == b.strokeAlign
    );
  }

  double get strokeInset => width * (1 - (1 + strokeAlign) / 2);

  double get strokeOutset => width * (1 + strokeAlign) / 2;

  double get strokeOffset => width * strokeAlign;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BorderSide
        && other.color == color
        && other.width == width
        && other.style == style
        && other.strokeAlign == strokeAlign;
  }

  @override
  int get hashCode => Object.hash(color, width, style, strokeAlign);

  @override
  String toStringShort() => 'BorderSide';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Color>('color', color, defaultValue: const Color(0xFF000000)));
    properties.add(DoubleProperty('width', width, defaultValue: 1.0));
    properties.add(DoubleProperty('strokeAlign', strokeAlign, defaultValue: strokeAlignInside));
    properties.add(EnumProperty<BorderStyle>('style', style, defaultValue: BorderStyle.solid));
  }
}

@immutable
abstract class ShapeBorder {
  const ShapeBorder();

  EdgeInsetsGeometry get dimensions;

  @protected
  ShapeBorder? add(ShapeBorder other, { bool reversed = false }) => null;

  ShapeBorder operator +(ShapeBorder other) {
    return add(other) ?? other.add(this, reversed: true) ?? _CompoundBorder(<ShapeBorder>[other, this]);
  }

  ShapeBorder scale(double t);

  @protected
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a == null) {
      return scale(t);
    }
    return null;
  }

  @protected
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b == null) {
      return scale(1.0 - t);
    }
    return null;
  }

  static ShapeBorder? lerp(ShapeBorder? a, ShapeBorder? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    ShapeBorder? result;
    if (b != null) {
      result = b.lerpFrom(a, t);
    }
    if (result == null && a != null) {
      result = a.lerpTo(b, t);
    }
    return result ?? (t < 0.5 ? a : b);
  }

  Path getOuterPath(Rect rect, { TextDirection? textDirection });

  Path getInnerPath(Rect rect, { TextDirection? textDirection });

  void paintInterior(Canvas canvas, Rect rect, Paint paint, {TextDirection? textDirection}) {
    assert(!preferPaintInterior, '$runtimeType.preferPaintInterior returns true but $runtimeType.paintInterior is not implemented.');
    assert(false, '$runtimeType.preferPaintInterior returns false, so it is an error to call its paintInterior method.');
  }

  bool get preferPaintInterior => false;

  void paint(Canvas canvas, Rect rect, { TextDirection? textDirection });

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ShapeBorder')}()';
  }
}

@immutable
abstract class OutlinedBorder extends ShapeBorder {
  const OutlinedBorder({ this.side = BorderSide.none });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(math.max(side.strokeInset, 0));

  final BorderSide side;

  OutlinedBorder copyWith({ BorderSide? side });

  @override
  ShapeBorder scale(double t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a == null) {
      return scale(t);
    }
    return null;
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b == null) {
      return scale(1.0 - t);
    }
    return null;
  }

  static OutlinedBorder? lerp(OutlinedBorder? a, OutlinedBorder? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    ShapeBorder? result;
    if (b != null) {
      result = b.lerpFrom(a, t);
    }
    if (result == null && a != null) {
      result = a.lerpTo(b, t);
    }
    return result as OutlinedBorder? ?? (t < 0.5 ? a : b);
  }
}

class _CompoundBorder extends ShapeBorder {
  _CompoundBorder(this.borders)
    : assert(borders.length >= 2),
      assert(!borders.any((ShapeBorder border) => border is _CompoundBorder));

  final List<ShapeBorder> borders;

  @override
  EdgeInsetsGeometry get dimensions {
    return borders.fold<EdgeInsetsGeometry>(
      EdgeInsets.zero,
      (EdgeInsetsGeometry previousValue, ShapeBorder border) {
        return previousValue.add(border.dimensions);
      },
    );
  }

  @override
  ShapeBorder add(ShapeBorder other, { bool reversed = false }) {
    // This wraps the list of borders with "other", or, if "reversed" is true,
    // wraps "other" with the list of borders.
    // If "reversed" is false, "other" should end up being at the start of the
    // list, otherwise, if "reversed" is true, it should end up at the end.
    // First, see if we can merge the new adjacent borders.
    if (other is! _CompoundBorder) {
      // Here, "ours" is the border at the side where we're adding the new
      // border, and "merged" is the result of attempting to merge it with the
      // new border. If it's null, it couldn't be merged.
      final ShapeBorder ours = reversed ? borders.last : borders.first;
      final ShapeBorder? merged = ours.add(other, reversed: reversed)
                             ?? other.add(ours, reversed: !reversed);
      if (merged != null) {
        final List<ShapeBorder> result = <ShapeBorder>[...borders];
        result[reversed ? result.length - 1 : 0] = merged;
        return _CompoundBorder(result);
      }
    }
    // We can't, so fall back to just adding the new border to the list.
    final List<ShapeBorder> mergedBorders = <ShapeBorder>[
      if (reversed) ...borders,
      if (other is _CompoundBorder) ...other.borders
      else other,
      if (!reversed) ...borders,
    ];
    return _CompoundBorder(mergedBorders);
  }

  @override
  ShapeBorder scale(double t) {
    return _CompoundBorder(
      borders.map<ShapeBorder>((ShapeBorder border) => border.scale(t)).toList(),
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    return _CompoundBorder.lerp(a, this, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    return _CompoundBorder.lerp(this, b, t);
  }

  static _CompoundBorder lerp(ShapeBorder? a, ShapeBorder? b, double t) {
    assert(a is _CompoundBorder || b is _CompoundBorder); // Not really necessary, but all call sites currently intend this.
    final List<ShapeBorder?> aList = a is _CompoundBorder ? a.borders : <ShapeBorder?>[a];
    final List<ShapeBorder?> bList = b is _CompoundBorder ? b.borders : <ShapeBorder?>[b];
    final List<ShapeBorder> results = <ShapeBorder>[];
    final int length = math.max(aList.length, bList.length);
    for (int index = 0; index < length; index += 1) {
      final ShapeBorder? localA = index < aList.length ? aList[index] : null;
      final ShapeBorder? localB = index < bList.length ? bList[index] : null;
      if (localA != null && localB != null) {
        final ShapeBorder? localResult = localA.lerpTo(localB, t) ?? localB.lerpFrom(localA, t);
        if (localResult != null) {
          results.add(localResult);
          continue;
        }
      }
      // If we're changing from one shape to another, make sure the shape that is coming in
      // is inserted before the shape that is going away, so that the outer path changes to
      // the new border earlier rather than later. (This affects, among other things, where
      // the ShapeDecoration class puts its background.)
      if (localB != null) {
        results.add(localB.scale(t));
      }
      if (localA != null) {
        results.add(localA.scale(1.0 - t));
      }
    }
    return _CompoundBorder(results);
  }

  @override
  Path getInnerPath(Rect rect, { TextDirection? textDirection }) {
    for (int index = 0; index < borders.length - 1; index += 1) {
      rect = borders[index].dimensions.resolve(textDirection).deflateRect(rect);
    }
    return borders.last.getInnerPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, { TextDirection? textDirection }) {
    return borders.first.getOuterPath(rect, textDirection: textDirection);
  }

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint, { TextDirection? textDirection }) {
    borders.first.paintInterior(canvas, rect, paint, textDirection: textDirection);
  }

  @override
  bool get preferPaintInterior => borders.every((ShapeBorder border) => border.preferPaintInterior);

  @override
  void paint(Canvas canvas, Rect rect, { TextDirection? textDirection }) {
    for (final ShapeBorder border in borders) {
      border.paint(canvas, rect, textDirection: textDirection);
      rect = border.dimensions.resolve(textDirection).deflateRect(rect);
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
    return other is _CompoundBorder
        && listEquals<ShapeBorder>(other.borders, borders);
  }

  @override
  int get hashCode => Object.hashAll(borders);

  @override
  String toString() {
    // We list them in reverse order because when adding two borders they end up
    // in the list in the opposite order of what the source looks like: a + b =>
    // [b, a]. We do this to make the painting code more optimal, and most of
    // the rest of the code doesn't care, except toString() (for debugging).
    return borders.reversed.map<String>((ShapeBorder border) => border.toString()).join(' + ');
  }
}

void paintBorder(
  Canvas canvas,
  Rect rect, {
  BorderSide top = BorderSide.none,
  BorderSide right = BorderSide.none,
  BorderSide bottom = BorderSide.none,
  BorderSide left = BorderSide.none,
}) {

  // We draw the borders as filled shapes, unless the borders are hairline
  // borders, in which case we use PaintingStyle.stroke, with the stroke width
  // specified here.
  final Paint paint = Paint()
    ..strokeWidth = 0.0;

  final Path path = Path();

  switch (top.style) {
    case BorderStyle.solid:
      paint.color = top.color;
      path.reset();
      path.moveTo(rect.left, rect.top);
      path.lineTo(rect.right, rect.top);
      if (top.width == 0.0) {
        paint.style = PaintingStyle.stroke;
      } else {
        paint.style = PaintingStyle.fill;
        path.lineTo(rect.right - right.width, rect.top + top.width);
        path.lineTo(rect.left + left.width, rect.top + top.width);
      }
      canvas.drawPath(path, paint);
    case BorderStyle.none:
      break;
  }

  switch (right.style) {
    case BorderStyle.solid:
      paint.color = right.color;
      path.reset();
      path.moveTo(rect.right, rect.top);
      path.lineTo(rect.right, rect.bottom);
      if (right.width == 0.0) {
        paint.style = PaintingStyle.stroke;
      } else {
        paint.style = PaintingStyle.fill;
        path.lineTo(rect.right - right.width, rect.bottom - bottom.width);
        path.lineTo(rect.right - right.width, rect.top + top.width);
      }
      canvas.drawPath(path, paint);
    case BorderStyle.none:
      break;
  }

  switch (bottom.style) {
    case BorderStyle.solid:
      paint.color = bottom.color;
      path.reset();
      path.moveTo(rect.right, rect.bottom);
      path.lineTo(rect.left, rect.bottom);
      if (bottom.width == 0.0) {
        paint.style = PaintingStyle.stroke;
      } else {
        paint.style = PaintingStyle.fill;
        path.lineTo(rect.left + left.width, rect.bottom - bottom.width);
        path.lineTo(rect.right - right.width, rect.bottom - bottom.width);
      }
      canvas.drawPath(path, paint);
    case BorderStyle.none:
      break;
  }

  switch (left.style) {
    case BorderStyle.solid:
      paint.color = left.color;
      path.reset();
      path.moveTo(rect.left, rect.bottom);
      path.lineTo(rect.left, rect.top);
      if (left.width == 0.0) {
        paint.style = PaintingStyle.stroke;
      } else {
        paint.style = PaintingStyle.fill;
        path.lineTo(rect.left + left.width, rect.top + top.width);
        path.lineTo(rect.left + left.width, rect.bottom - bottom.width);
      }
      canvas.drawPath(path, paint);
    case BorderStyle.none:
      break;
  }
}