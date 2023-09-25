
import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'border_radius.dart';
import 'borders.dart';
import 'edge_insets.dart';

// Examples can assume:
// late BuildContext context;

enum BoxShape {
  rectangle,

  circle,

  // Don't add more, instead create a new ShapeBorder.
}

abstract class BoxBorder extends ShapeBorder {
  const BoxBorder();

  BorderSide get top;

  BorderSide get bottom;

  bool get isUniform;

  // We override this to tighten the return value, so that callers can assume
  // that we'll return a [BoxBorder].
  @override
  BoxBorder? add(ShapeBorder other, { bool reversed = false }) => null;

  static BoxBorder? lerp(BoxBorder? a, BoxBorder? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if ((a is Border?) && (b is Border?)) {
      return Border.lerp(a, b, t);
    }
    if ((a is BorderDirectional?) && (b is BorderDirectional?)) {
      return BorderDirectional.lerp(a, b, t);
    }
    if (b is Border && a is BorderDirectional) {
      final BoxBorder c = b;
      b = a;
      a = c;
      t = 1.0 - t;
      // fall through to next case
    }
    if (a is Border && b is BorderDirectional) {
      if (b.start == BorderSide.none && b.end == BorderSide.none) {
        // The fact that b is a BorderDirectional really doesn't matter, it turns out.
        return Border(
          top: BorderSide.lerp(a.top, b.top, t),
          right: BorderSide.lerp(a.right, BorderSide.none, t),
          bottom: BorderSide.lerp(a.bottom, b.bottom, t),
          left: BorderSide.lerp(a.left, BorderSide.none, t),
        );
      }
      if (a.left == BorderSide.none && a.right == BorderSide.none) {
        // The fact that a is a Border really doesn't matter, it turns out.
        return BorderDirectional(
          top: BorderSide.lerp(a.top, b.top, t),
          start: BorderSide.lerp(BorderSide.none, b.start, t),
          end: BorderSide.lerp(BorderSide.none, b.end, t),
          bottom: BorderSide.lerp(a.bottom, b.bottom, t),
        );
      }
      // Since we have to swap a visual border for a directional one,
      // we speed up the horizontal sides' transitions and switch from
      // one mode to the other at t=0.5.
      if (t < 0.5) {
        return Border(
          top: BorderSide.lerp(a.top, b.top, t),
          right: BorderSide.lerp(a.right, BorderSide.none, t * 2.0),
          bottom: BorderSide.lerp(a.bottom, b.bottom, t),
          left: BorderSide.lerp(a.left, BorderSide.none, t * 2.0),
        );
      }
      return BorderDirectional(
        top: BorderSide.lerp(a.top, b.top, t),
        start: BorderSide.lerp(BorderSide.none, b.start, (t - 0.5) * 2.0),
        end: BorderSide.lerp(BorderSide.none, b.end, (t - 0.5) * 2.0),
        bottom: BorderSide.lerp(a.bottom, b.bottom, t),
      );
    }
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('BoxBorder.lerp can only interpolate Border and BorderDirectional classes.'),
      ErrorDescription(
        'BoxBorder.lerp() was called with two objects of type ${a.runtimeType} and ${b.runtimeType}:\n'
        '  $a\n'
        '  $b\n'
        'However, only Border and BorderDirectional classes are supported by this method.',
      ),
      ErrorHint('For a more general interpolation method, consider using ShapeBorder.lerp instead.'),
    ]);
  }

  @override
  Path getInnerPath(Rect rect, { TextDirection? textDirection }) {
    assert(textDirection != null, 'The textDirection argument to $runtimeType.getInnerPath must not be null.');
    return Path()
      ..addRect(dimensions.resolve(textDirection).deflateRect(rect));
  }

  @override
  Path getOuterPath(Rect rect, { TextDirection? textDirection }) {
    assert(textDirection != null, 'The textDirection argument to $runtimeType.getOuterPath must not be null.');
    return Path()
      ..addRect(rect);
  }

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint, { TextDirection? textDirection }) {
    // For `ShapeDecoration(shape: Border.all())`, a rectangle with sharp edges
    // is always painted. There is no borderRadius parameter for
    // ShapeDecoration or Border, only for BoxDecoration, which doesn't call
    // this method.
    canvas.drawRect(rect, paint);
  }

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  });

  static void _paintUniformBorderWithRadius(Canvas canvas, Rect rect, BorderSide side, BorderRadius borderRadius) {
    assert(side.style != BorderStyle.none);
    final Paint paint = Paint()
      ..color = side.color;
    final double width = side.width;
    if (width == 0.0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.0;
      canvas.drawRRect(borderRadius.toRRect(rect), paint);
    } else {
      final RRect borderRect = borderRadius.toRRect(rect);
      final RRect inner = borderRect.deflate(side.strokeInset);
      final RRect outer = borderRect.inflate(side.strokeOutset);
      canvas.drawDRRect(outer, inner, paint);
    }
  }

  static void paintNonUniformBorder(
    Canvas canvas,
    Rect rect, {
    required BorderRadius? borderRadius,
    required TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderSide top = BorderSide.none,
    BorderSide right = BorderSide.none,
    BorderSide bottom = BorderSide.none,
    BorderSide left = BorderSide.none,
    required Color color,
  }) {
    final RRect borderRect;
    switch (shape) {
      case BoxShape.rectangle:
        borderRect = (borderRadius ?? BorderRadius.zero)
            .resolve(textDirection)
            .toRRect(rect);
      case BoxShape.circle:
        assert(borderRadius == null, 'A borderRadius cannot be given when shape is a BoxShape.circle.');
        borderRect = RRect.fromRectAndRadius(
          Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2.0),
          Radius.circular(rect.width),
        );
    }
    final Paint paint = Paint()..color = color;
    final RRect inner = _deflateRRect(borderRect, EdgeInsets.fromLTRB(left.strokeInset, top.strokeInset, right.strokeInset, bottom.strokeInset));
    final RRect outer = _inflateRRect(borderRect, EdgeInsets.fromLTRB(left.strokeOutset, top.strokeOutset, right.strokeOutset, bottom.strokeOutset));
    canvas.drawDRRect(outer, inner, paint);
  }

  static RRect _inflateRRect(RRect rect, EdgeInsets insets) {
    return RRect.fromLTRBAndCorners(
      rect.left - insets.left,
      rect.top - insets.top,
      rect.right + insets.right,
      rect.bottom + insets.bottom,
      topLeft: (rect.tlRadius + Radius.elliptical(insets.left, insets.top)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      topRight: (rect.trRadius + Radius.elliptical(insets.right, insets.top)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      bottomRight: (rect.brRadius + Radius.elliptical(insets.right, insets.bottom)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      bottomLeft: (rect.blRadius + Radius.elliptical(insets.left, insets.bottom)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
    );
  }

  static RRect _deflateRRect(RRect rect, EdgeInsets insets) {
    return RRect.fromLTRBAndCorners(
      rect.left + insets.left,
      rect.top + insets.top,
      rect.right - insets.right,
      rect.bottom - insets.bottom,
      topLeft: (rect.tlRadius - Radius.elliptical(insets.left, insets.top)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      topRight: (rect.trRadius - Radius.elliptical(insets.right, insets.top)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      bottomRight: (rect.brRadius - Radius.elliptical(insets.right, insets.bottom)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
      bottomLeft:(rect.blRadius - Radius.elliptical(insets.left, insets.bottom)).clamp(minimum: Radius.zero), // ignore_clamp_double_lint
    );
  }

  static void _paintUniformBorderWithCircle(Canvas canvas, Rect rect, BorderSide side) {
    assert(side.style != BorderStyle.none);
    final double radius = (rect.shortestSide + side.strokeOffset) / 2;
    canvas.drawCircle(rect.center, radius, side.toPaint());
  }

  static void _paintUniformBorderWithRectangle(Canvas canvas, Rect rect, BorderSide side) {
    assert(side.style != BorderStyle.none);
    canvas.drawRect(rect.inflate(side.strokeOffset / 2), side.toPaint());
  }
}

class Border extends BoxBorder {
  const Border({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
  });

  const Border.fromBorderSide(BorderSide side)
      : top = side,
        right = side,
        bottom = side,
        left = side;

  const Border.symmetric({
    BorderSide vertical = BorderSide.none,
    BorderSide horizontal = BorderSide.none,
  }) : left = vertical,
       top = horizontal,
       right = vertical,
       bottom = horizontal;

  factory Border.all({
    Color color = const Color(0xFF000000),
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
    double strokeAlign = BorderSide.strokeAlignInside,
  }) {
    final BorderSide side = BorderSide(color: color, width: width, style: style, strokeAlign: strokeAlign);
    return Border.fromBorderSide(side);
  }

  static Border merge(Border a, Border b) {
    assert(BorderSide.canMerge(a.top, b.top));
    assert(BorderSide.canMerge(a.right, b.right));
    assert(BorderSide.canMerge(a.bottom, b.bottom));
    assert(BorderSide.canMerge(a.left, b.left));
    return Border(
      top: BorderSide.merge(a.top, b.top),
      right: BorderSide.merge(a.right, b.right),
      bottom: BorderSide.merge(a.bottom, b.bottom),
      left: BorderSide.merge(a.left, b.left),
    );
  }

  @override
  final BorderSide top;

  final BorderSide right;

  @override
  final BorderSide bottom;

  final BorderSide left;

  @override
  EdgeInsetsGeometry get dimensions {
    if (_widthIsUniform) {
      return EdgeInsets.all(top.strokeInset);
    }
    return EdgeInsets.fromLTRB(left.strokeInset, top.strokeInset, right.strokeInset, bottom.strokeInset);
  }

  @override
  bool get isUniform => _colorIsUniform && _widthIsUniform && _styleIsUniform && _strokeAlignIsUniform;

  bool get _colorIsUniform {
    final Color topColor = top.color;
    return left.color == topColor && bottom.color == topColor && right.color == topColor;
  }

  bool get _widthIsUniform {
    final double topWidth = top.width;
    return left.width == topWidth && bottom.width == topWidth && right.width == topWidth;
  }

  bool get _styleIsUniform {
    final BorderStyle topStyle = top.style;
    return left.style == topStyle && bottom.style == topStyle && right.style == topStyle;
  }

  bool get _strokeAlignIsUniform {
    final double topStrokeAlign = top.strokeAlign;
    return left.strokeAlign == topStrokeAlign
        && bottom.strokeAlign == topStrokeAlign
        && right.strokeAlign == topStrokeAlign;
  }

  Set<Color> _distinctVisibleColors() {
    final Set<Color> distinctVisibleColors = <Color>{};
    if (top.style != BorderStyle.none) {
      distinctVisibleColors.add(top.color);
    }
    if (right.style != BorderStyle.none) {
      distinctVisibleColors.add(right.color);
    }
    if (bottom.style != BorderStyle.none) {
      distinctVisibleColors.add(bottom.color);
    }
    if (left.style != BorderStyle.none) {
      distinctVisibleColors.add(left.color);
    }
    return distinctVisibleColors;
  }

  // [BoxBorder.paintNonUniformBorder] is about 20% faster than [paintBorder],
  // but [paintBorder] is able to draw hairline borders when width is zero
  // and style is [BorderStyle.solid].
  bool get _hasHairlineBorder =>
      (top.style == BorderStyle.solid && top.width == 0.0) ||
      (right.style == BorderStyle.solid && right.width == 0.0) ||
      (bottom.style == BorderStyle.solid && bottom.width == 0.0) ||
      (left.style == BorderStyle.solid && left.width == 0.0);

  @override
  Border? add(ShapeBorder other, { bool reversed = false }) {
    if (other is Border &&
        BorderSide.canMerge(top, other.top) &&
        BorderSide.canMerge(right, other.right) &&
        BorderSide.canMerge(bottom, other.bottom) &&
        BorderSide.canMerge(left, other.left)) {
      return Border.merge(this, other);
    }
    return null;
  }

  @override
  Border scale(double t) {
    return Border(
      top: top.scale(t),
      right: right.scale(t),
      bottom: bottom.scale(t),
      left: left.scale(t),
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is Border) {
      return Border.lerp(a, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is Border) {
      return Border.lerp(this, b, t);
    }
    return super.lerpTo(b, t);
  }

  static Border? lerp(Border? a, Border? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    return Border(
      top: BorderSide.lerp(a.top, b.top, t),
      right: BorderSide.lerp(a.right, b.right, t),
      bottom: BorderSide.lerp(a.bottom, b.bottom, t),
      left: BorderSide.lerp(a.left, b.left, t),
    );
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (isUniform) {
      switch (top.style) {
        case BorderStyle.none:
          return;
        case BorderStyle.solid:
          switch (shape) {
            case BoxShape.circle:
              assert(borderRadius == null, 'A borderRadius cannot be given when shape is a BoxShape.circle.');
              BoxBorder._paintUniformBorderWithCircle(canvas, rect, top);
            case BoxShape.rectangle:
              if (borderRadius != null && borderRadius != BorderRadius.zero) {
                BoxBorder._paintUniformBorderWithRadius(canvas, rect, top, borderRadius);
                return;
              }
              BoxBorder._paintUniformBorderWithRectangle(canvas, rect, top);
          }
          return;
      }
    }

    if (_styleIsUniform && top.style == BorderStyle.none) {
      return;
    }

    // Allow painting non-uniform borders if the visible colors are uniform.
    final Set<Color> visibleColors = _distinctVisibleColors();
    final bool hasHairlineBorder = _hasHairlineBorder;
    // Paint a non uniform border if a single color is visible
    // and (borderRadius is present) or (border is visible and width != 0.0).
    if (visibleColors.length == 1 &&
        !hasHairlineBorder &&
        (shape == BoxShape.circle ||
            (borderRadius != null && borderRadius != BorderRadius.zero))) {
      BoxBorder.paintNonUniformBorder(canvas, rect,
          shape: shape,
          borderRadius: borderRadius,
          textDirection: textDirection,
          top: top.style == BorderStyle.none ? BorderSide.none : top,
          right: right.style == BorderStyle.none ? BorderSide.none : right,
          bottom: bottom.style == BorderStyle.none ? BorderSide.none : bottom,
          left: left.style == BorderStyle.none ? BorderSide.none : left,
          color: visibleColors.first);
      return;
    }

     assert(() {
      if (hasHairlineBorder) {
        assert(borderRadius == null || borderRadius == BorderRadius.zero,
            'A hairline border like `BorderSide(width: 0.0, style: BorderStyle.solid)` can only be drawn when BorderRadius is zero or null.');
      }
      if (borderRadius != null && borderRadius != BorderRadius.zero) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A borderRadius can only be given on borders with uniform colors.'),
          ErrorDescription('The following is not uniform:'),
          if (!_colorIsUniform) ErrorDescription('BorderSide.color'),
        ]);
      }
      return true;
    }());
    assert(() {
      if (shape != BoxShape.rectangle) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A Border can only be drawn as a circle on borders with uniform colors.'),
          ErrorDescription('The following is not uniform:'),
          if (!_colorIsUniform) ErrorDescription('BorderSide.color'),
        ]);
      }
      return true;
    }());
    assert(() {
      if (!_strokeAlignIsUniform || top.strokeAlign != BorderSide.strokeAlignInside) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A Border can only draw strokeAlign different than BorderSide.strokeAlignInside on borders with uniform colors.'),
        ]);
      }
      return true;
    }());

    paintBorder(canvas, rect, top: top, right: right, bottom: bottom, left: left);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is Border
        && other.top == top
        && other.right == right
        && other.bottom == bottom
        && other.left == left;
  }

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() {
    if (isUniform) {
      return '${objectRuntimeType(this, 'Border')}.all($top)';
    }
    final List<String> arguments = <String>[
      if (top != BorderSide.none) 'top: $top',
      if (right != BorderSide.none) 'right: $right',
      if (bottom != BorderSide.none) 'bottom: $bottom',
      if (left != BorderSide.none) 'left: $left',
    ];
    return '${objectRuntimeType(this, 'Border')}(${arguments.join(", ")})';
  }
}

class BorderDirectional extends BoxBorder {
  const BorderDirectional({
    this.top = BorderSide.none,
    this.start = BorderSide.none,
    this.end = BorderSide.none,
    this.bottom = BorderSide.none,
  });

  static BorderDirectional merge(BorderDirectional a, BorderDirectional b) {
    assert(BorderSide.canMerge(a.top, b.top));
    assert(BorderSide.canMerge(a.start, b.start));
    assert(BorderSide.canMerge(a.end, b.end));
    assert(BorderSide.canMerge(a.bottom, b.bottom));
    return BorderDirectional(
      top: BorderSide.merge(a.top, b.top),
      start: BorderSide.merge(a.start, b.start),
      end: BorderSide.merge(a.end, b.end),
      bottom: BorderSide.merge(a.bottom, b.bottom),
    );
  }

  @override
  final BorderSide top;

  final BorderSide start;

  final BorderSide end;

  @override
  final BorderSide bottom;

  @override
  EdgeInsetsGeometry get dimensions {
    if (isUniform) {
      return EdgeInsetsDirectional.all(top.strokeInset);
    }
    return EdgeInsetsDirectional.fromSTEB(start.strokeInset, top.strokeInset, end.strokeInset, bottom.strokeInset);
  }

  @override
  bool get isUniform => _colorIsUniform && _widthIsUniform && _styleIsUniform && _strokeAlignIsUniform;

  bool get _colorIsUniform {
    final Color topColor = top.color;
    return start.color == topColor && bottom.color == topColor && end.color == topColor;
  }

  bool get _widthIsUniform {
    final double topWidth = top.width;
    return start.width == topWidth && bottom.width == topWidth && end.width == topWidth;
  }

  bool get _styleIsUniform {
    final BorderStyle topStyle = top.style;
    return start.style == topStyle && bottom.style == topStyle && end.style == topStyle;
  }

  bool get _strokeAlignIsUniform {
    final double topStrokeAlign = top.strokeAlign;
    return start.strokeAlign == topStrokeAlign
        && bottom.strokeAlign == topStrokeAlign
        && end.strokeAlign == topStrokeAlign;
  }

  Set<Color> _distinctVisibleColors() {
    final Set<Color> distinctVisibleColors = <Color>{};
    if (top.style != BorderStyle.none) {
      distinctVisibleColors.add(top.color);
    }
    if (end.style != BorderStyle.none) {
      distinctVisibleColors.add(end.color);
    }
    if (bottom.style != BorderStyle.none) {
      distinctVisibleColors.add(bottom.color);
    }
    if (start.style != BorderStyle.none) {
      distinctVisibleColors.add(start.color);
    }

    return distinctVisibleColors;
  }


  bool get _hasHairlineBorder =>
      (top.style == BorderStyle.solid && top.width == 0.0) ||
      (end.style == BorderStyle.solid && end.width == 0.0) ||
      (bottom.style == BorderStyle.solid && bottom.width == 0.0) ||
      (start.style == BorderStyle.solid && start.width == 0.0);

  @override
  BoxBorder? add(ShapeBorder other, { bool reversed = false }) {
    if (other is BorderDirectional) {
      final BorderDirectional typedOther = other;
      if (BorderSide.canMerge(top, typedOther.top) &&
          BorderSide.canMerge(start, typedOther.start) &&
          BorderSide.canMerge(end, typedOther.end) &&
          BorderSide.canMerge(bottom, typedOther.bottom)) {
        return BorderDirectional.merge(this, typedOther);
      }
      return null;
    }
    if (other is Border) {
      final Border typedOther = other;
      if (!BorderSide.canMerge(typedOther.top, top) ||
          !BorderSide.canMerge(typedOther.bottom, bottom)) {
        return null;
      }
      if (start != BorderSide.none ||
          end != BorderSide.none) {
        if (typedOther.left != BorderSide.none ||
            typedOther.right != BorderSide.none) {
          return null;
        }
        assert(typedOther.left == BorderSide.none);
        assert(typedOther.right == BorderSide.none);
        return BorderDirectional(
          top: BorderSide.merge(typedOther.top, top),
          start: start,
          end: end,
          bottom: BorderSide.merge(typedOther.bottom, bottom),
        );
      }
      assert(start == BorderSide.none);
      assert(end == BorderSide.none);
      return Border(
        top: BorderSide.merge(typedOther.top, top),
        right: typedOther.right,
        bottom: BorderSide.merge(typedOther.bottom, bottom),
        left: typedOther.left,
      );
    }
    return null;
  }

  @override
  BorderDirectional scale(double t) {
    return BorderDirectional(
      top: top.scale(t),
      start: start.scale(t),
      end: end.scale(t),
      bottom: bottom.scale(t),
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BorderDirectional) {
      return BorderDirectional.lerp(a, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is BorderDirectional) {
      return BorderDirectional.lerp(this, b, t);
    }
    return super.lerpTo(b, t);
  }

  static BorderDirectional? lerp(BorderDirectional? a, BorderDirectional? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    return BorderDirectional(
      top: BorderSide.lerp(a.top, b.top, t),
      end: BorderSide.lerp(a.end, b.end, t),
      bottom: BorderSide.lerp(a.bottom, b.bottom, t),
      start: BorderSide.lerp(a.start, b.start, t),
    );
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (isUniform) {
      switch (top.style) {
        case BorderStyle.none:
          return;
        case BorderStyle.solid:
          switch (shape) {
            case BoxShape.circle:
              assert(borderRadius == null, 'A borderRadius cannot be given when shape is a BoxShape.circle.');
              BoxBorder._paintUniformBorderWithCircle(canvas, rect, top);
            case BoxShape.rectangle:
              if (borderRadius != null && borderRadius != BorderRadius.zero) {
                BoxBorder._paintUniformBorderWithRadius(canvas, rect, top, borderRadius);
                return;
              }
              BoxBorder._paintUniformBorderWithRectangle(canvas, rect, top);
          }
          return;
      }
    }

    if (_styleIsUniform && top.style == BorderStyle.none) {
      return;
    }

    final BorderSide left, right;
    assert(textDirection != null, 'Non-uniform BorderDirectional objects require a TextDirection when painting.');
    switch (textDirection!) {
      case TextDirection.rtl:
        left = end;
        right = start;
      case TextDirection.ltr:
        left = start;
        right = end;
    }

    // Allow painting non-uniform borders if the visible colors are uniform.
    final Set<Color> visibleColors = _distinctVisibleColors();
    final bool hasHairlineBorder = _hasHairlineBorder;
    if (visibleColors.length == 1 &&
        !hasHairlineBorder &&
        (shape == BoxShape.circle ||
            (borderRadius != null && borderRadius != BorderRadius.zero))) {
      BoxBorder.paintNonUniformBorder(canvas, rect,
          shape: shape,
          borderRadius: borderRadius,
          textDirection: textDirection,
          top: top.style == BorderStyle.none ? BorderSide.none : top,
          right: right.style == BorderStyle.none ? BorderSide.none : right,
          bottom: bottom.style == BorderStyle.none ? BorderSide.none : bottom,
          left: left.style == BorderStyle.none ? BorderSide.none : left,
          color: visibleColors.first);
      return;
    }

    if (hasHairlineBorder) {
      assert(borderRadius == null || borderRadius == BorderRadius.zero, 'A side like `BorderSide(width: 0.0, style: BorderStyle.solid)` can only be drawn when BorderRadius is zero or null.');
    }
    assert(borderRadius == null, 'A borderRadius can only be given for borders with uniform colors.');
    assert(shape == BoxShape.rectangle, 'A Border can only be drawn as a circle on borders with uniform colors.');
    assert(_strokeAlignIsUniform && top.strokeAlign == BorderSide.strokeAlignInside, 'A Border can only draw strokeAlign different than strokeAlignInside on borders with uniform colors.');

    paintBorder(canvas, rect, top: top, left: left, bottom: bottom, right: right);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BorderDirectional
        && other.top == top
        && other.start == start
        && other.end == end
        && other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(top, start, end, bottom);

  @override
  String toString() {
    final List<String> arguments = <String>[
      if (top != BorderSide.none) 'top: $top',
      if (start != BorderSide.none) 'start: $start',
      if (end != BorderSide.none) 'end: $end',
      if (bottom != BorderSide.none) 'bottom: $bottom',
    ];
    return '${objectRuntimeType(this, 'BorderDirectional')}(${arguments.join(", ")})';
  }
}