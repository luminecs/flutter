import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui show Gradient, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'alignment.dart';
import 'basic_types.dart';

class _ColorsAndStops {
  _ColorsAndStops(this.colors, this.stops);
  final List<Color> colors;
  final List<double> stops;
}

Color _sample(List<Color> colors, List<double> stops, double t) {
  assert(colors.isNotEmpty);
  assert(stops.isNotEmpty);
  if (t <= stops.first) {
    return colors.first;
  }
  if (t >= stops.last) {
    return colors.last;
  }
  final int index = stops.lastIndexWhere((double s) => s <= t);
  assert(index != -1);
  return Color.lerp(
    colors[index],
    colors[index + 1],
    (t - stops[index]) / (stops[index + 1] - stops[index]),
  )!;
}

_ColorsAndStops _interpolateColorsAndStops(
  List<Color> aColors,
  List<double> aStops,
  List<Color> bColors,
  List<double> bStops,
  double t,
) {
  assert(aColors.length >= 2);
  assert(bColors.length >= 2);
  assert(aStops.length == aColors.length);
  assert(bStops.length == bColors.length);
  final SplayTreeSet<double> stops = SplayTreeSet<double>()
    ..addAll(aStops)
    ..addAll(bStops);
  final List<double> interpolatedStops = stops.toList(growable: false);
  final List<Color> interpolatedColors = interpolatedStops
      .map<Color>(
        (double stop) => Color.lerp(
            _sample(aColors, aStops, stop), _sample(bColors, bStops, stop), t)!,
      )
      .toList(growable: false);
  return _ColorsAndStops(interpolatedColors, interpolatedStops);
}

@immutable
abstract class GradientTransform {
  const GradientTransform();

  Matrix4? transform(Rect bounds, {TextDirection? textDirection});
}

@immutable
class GradientRotation extends GradientTransform {
  const GradientRotation(this.radians);

  final double radians;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double sinRadians = math.sin(radians);
    final double oneMinusCosRadians = 1 - math.cos(radians);
    final Offset center = bounds.center;
    final double originX =
        sinRadians * center.dy + oneMinusCosRadians * center.dx;
    final double originY =
        -sinRadians * center.dx + oneMinusCosRadians * center.dy;

    return Matrix4.identity()
      ..translate(originX, originY)
      ..rotateZ(radians);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is GradientRotation && other.radians == radians;
  }

  @override
  int get hashCode => radians.hashCode;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'GradientRotation')}(radians: ${debugFormatDouble(radians)})';
  }
}

@immutable
abstract class Gradient {
  const Gradient({
    required this.colors,
    this.stops,
    this.transform,
  });

  final List<Color> colors;

  final List<double>? stops;

  final GradientTransform? transform;

  List<double> _impliedStops() {
    if (stops != null) {
      return stops!;
    }
    assert(colors.length >= 2, 'colors list must have at least two colors');
    final double separation = 1.0 / (colors.length - 1);
    return List<double>.generate(
      colors.length,
      (int index) => index * separation,
      growable: false,
    );
  }

  @factory
  Shader createShader(Rect rect, {TextDirection? textDirection});

  Gradient scale(double factor);

  @protected
  Gradient? lerpFrom(Gradient? a, double t) {
    if (a == null) {
      return scale(t);
    }
    return null;
  }

  @protected
  Gradient? lerpTo(Gradient? b, double t) {
    if (b == null) {
      return scale(1.0 - t);
    }
    return null;
  }

  static Gradient? lerp(Gradient? a, Gradient? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    Gradient? result;
    if (b != null) {
      result = b.lerpFrom(a, t); // if a is null, this must return non-null
    }
    if (result == null && a != null) {
      result = a.lerpTo(b, t); // if b is null, this must return non-null
    }
    if (result != null) {
      return result;
    }
    assert(a != null && b != null);
    return t < 0.5 ? a!.scale(1.0 - (t * 2.0)) : b!.scale((t - 0.5) * 2.0);
  }

  Float64List? _resolveTransform(Rect bounds, TextDirection? textDirection) {
    return transform?.transform(bounds, textDirection: textDirection)?.storage;
  }
}

class LinearGradient extends Gradient {
  const LinearGradient({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    required super.colors,
    super.stops,
    this.tileMode = TileMode.clamp,
    super.transform,
  });

  final AlignmentGeometry begin;

  final AlignmentGeometry end;

  final TileMode tileMode;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    return ui.Gradient.linear(
      begin.resolve(textDirection).withinRect(rect),
      end.resolve(textDirection).withinRect(rect),
      colors,
      _impliedStops(),
      tileMode,
      _resolveTransform(rect, textDirection),
    );
  }

  @override
  LinearGradient scale(double factor) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors
          .map<Color>((Color color) => Color.lerp(null, color, factor)!)
          .toList(),
      stops: stops,
      tileMode: tileMode,
    );
  }

  @override
  Gradient? lerpFrom(Gradient? a, double t) {
    if (a == null || (a is LinearGradient)) {
      return LinearGradient.lerp(a as LinearGradient?, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  Gradient? lerpTo(Gradient? b, double t) {
    if (b == null || (b is LinearGradient)) {
      return LinearGradient.lerp(this, b as LinearGradient?, t);
    }
    return super.lerpTo(b, t);
  }

  static LinearGradient? lerp(LinearGradient? a, LinearGradient? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    final _ColorsAndStops interpolated = _interpolateColorsAndStops(
      a.colors,
      a._impliedStops(),
      b.colors,
      b._impliedStops(),
      t,
    );
    return LinearGradient(
      begin: AlignmentGeometry.lerp(a.begin, b.begin, t)!,
      end: AlignmentGeometry.lerp(a.end, b.end, t)!,
      colors: interpolated.colors,
      stops: interpolated.stops,
      tileMode: t < 0.5
          ? a.tileMode
          : b.tileMode, // TODO(ianh): interpolate tile mode
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
    return other is LinearGradient &&
        other.begin == begin &&
        other.end == end &&
        other.tileMode == tileMode &&
        other.transform == transform &&
        listEquals<Color>(other.colors, colors) &&
        listEquals<double>(other.stops, stops);
  }

  @override
  int get hashCode => Object.hash(
        begin,
        end,
        tileMode,
        transform,
        Object.hashAll(colors),
        stops == null ? null : Object.hashAll(stops!),
      );

  @override
  String toString() {
    final List<String> description = <String>[
      'begin: $begin',
      'end: $end',
      'colors: $colors',
      if (stops != null) 'stops: $stops',
      'tileMode: $tileMode',
      if (transform != null) 'transform: $transform',
    ];

    return '${objectRuntimeType(this, 'LinearGradient')}(${description.join(', ')})';
  }
}

class RadialGradient extends Gradient {
  const RadialGradient({
    this.center = Alignment.center,
    this.radius = 0.5,
    required super.colors,
    super.stops,
    this.tileMode = TileMode.clamp,
    this.focal,
    this.focalRadius = 0.0,
    super.transform,
  });

  final AlignmentGeometry center;

  final double radius;

  final TileMode tileMode;

  final AlignmentGeometry? focal;

  final double focalRadius;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    return ui.Gradient.radial(
      center.resolve(textDirection).withinRect(rect),
      radius * rect.shortestSide,
      colors,
      _impliedStops(),
      tileMode,
      _resolveTransform(rect, textDirection),
      focal?.resolve(textDirection).withinRect(rect),
      focalRadius * rect.shortestSide,
    );
  }

  @override
  RadialGradient scale(double factor) {
    return RadialGradient(
      center: center,
      radius: radius,
      colors: colors
          .map<Color>((Color color) => Color.lerp(null, color, factor)!)
          .toList(),
      stops: stops,
      tileMode: tileMode,
      focal: focal,
      focalRadius: focalRadius,
    );
  }

  @override
  Gradient? lerpFrom(Gradient? a, double t) {
    if (a == null || (a is RadialGradient)) {
      return RadialGradient.lerp(a as RadialGradient?, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  Gradient? lerpTo(Gradient? b, double t) {
    if (b == null || (b is RadialGradient)) {
      return RadialGradient.lerp(this, b as RadialGradient?, t);
    }
    return super.lerpTo(b, t);
  }

  static RadialGradient? lerp(RadialGradient? a, RadialGradient? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    final _ColorsAndStops interpolated = _interpolateColorsAndStops(
      a.colors,
      a._impliedStops(),
      b.colors,
      b._impliedStops(),
      t,
    );
    return RadialGradient(
      center: AlignmentGeometry.lerp(a.center, b.center, t)!,
      radius: math.max(0.0, ui.lerpDouble(a.radius, b.radius, t)!),
      colors: interpolated.colors,
      stops: interpolated.stops,
      tileMode: t < 0.5
          ? a.tileMode
          : b.tileMode, // TODO(ianh): interpolate tile mode
      focal: AlignmentGeometry.lerp(a.focal, b.focal, t),
      focalRadius:
          math.max(0.0, ui.lerpDouble(a.focalRadius, b.focalRadius, t)!),
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
    return other is RadialGradient &&
        other.center == center &&
        other.radius == radius &&
        other.tileMode == tileMode &&
        other.transform == transform &&
        listEquals<Color>(other.colors, colors) &&
        listEquals<double>(other.stops, stops) &&
        other.focal == focal &&
        other.focalRadius == focalRadius;
  }

  @override
  int get hashCode => Object.hash(
        center,
        radius,
        tileMode,
        transform,
        Object.hashAll(colors),
        stops == null ? null : Object.hashAll(stops!),
        focal,
        focalRadius,
      );

  @override
  String toString() {
    final List<String> description = <String>[
      'center: $center',
      'radius: ${debugFormatDouble(radius)}',
      'colors: $colors',
      if (stops != null) 'stops: $stops',
      'tileMode: $tileMode',
      if (focal != null) 'focal: $focal',
      'focalRadius: ${debugFormatDouble(focalRadius)}',
      if (transform != null) 'transform: $transform',
    ];

    return '${objectRuntimeType(this, 'RadialGradient')}(${description.join(', ')})';
  }
}

class SweepGradient extends Gradient {
  const SweepGradient({
    this.center = Alignment.center,
    this.startAngle = 0.0,
    this.endAngle = math.pi * 2,
    required super.colors,
    super.stops,
    this.tileMode = TileMode.clamp,
    super.transform,
  });

  final AlignmentGeometry center;

  final double startAngle;

  final double endAngle;

  final TileMode tileMode;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    return ui.Gradient.sweep(
      center.resolve(textDirection).withinRect(rect),
      colors,
      _impliedStops(),
      tileMode,
      startAngle,
      endAngle,
      _resolveTransform(rect, textDirection),
    );
  }

  @override
  SweepGradient scale(double factor) {
    return SweepGradient(
      center: center,
      startAngle: startAngle,
      endAngle: endAngle,
      colors: colors
          .map<Color>((Color color) => Color.lerp(null, color, factor)!)
          .toList(),
      stops: stops,
      tileMode: tileMode,
    );
  }

  @override
  Gradient? lerpFrom(Gradient? a, double t) {
    if (a == null || (a is SweepGradient)) {
      return SweepGradient.lerp(a as SweepGradient?, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  Gradient? lerpTo(Gradient? b, double t) {
    if (b == null || (b is SweepGradient)) {
      return SweepGradient.lerp(this, b as SweepGradient?, t);
    }
    return super.lerpTo(b, t);
  }

  static SweepGradient? lerp(SweepGradient? a, SweepGradient? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    final _ColorsAndStops interpolated = _interpolateColorsAndStops(
      a.colors,
      a._impliedStops(),
      b.colors,
      b._impliedStops(),
      t,
    );
    return SweepGradient(
      center: AlignmentGeometry.lerp(a.center, b.center, t)!,
      startAngle: math.max(0.0, ui.lerpDouble(a.startAngle, b.startAngle, t)!),
      endAngle: math.max(0.0, ui.lerpDouble(a.endAngle, b.endAngle, t)!),
      colors: interpolated.colors,
      stops: interpolated.stops,
      tileMode: t < 0.5
          ? a.tileMode
          : b.tileMode, // TODO(ianh): interpolate tile mode
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
    return other is SweepGradient &&
        other.center == center &&
        other.startAngle == startAngle &&
        other.endAngle == endAngle &&
        other.tileMode == tileMode &&
        other.transform == transform &&
        listEquals<Color>(other.colors, colors) &&
        listEquals<double>(other.stops, stops);
  }

  @override
  int get hashCode => Object.hash(
        center,
        startAngle,
        endAngle,
        tileMode,
        transform,
        Object.hashAll(colors),
        stops == null ? null : Object.hashAll(stops!),
      );

  @override
  String toString() {
    final List<String> description = <String>[
      'center: $center',
      'startAngle: ${debugFormatDouble(startAngle)}',
      'endAngle: ${debugFormatDouble(endAngle)}',
      'colors: $colors',
      if (stops != null) 'stops: $stops',
      'tileMode: $tileMode',
      if (transform != null) 'transform: $transform',
    ];

    return '${objectRuntimeType(this, 'SweepGradient')}(${description.join(', ')})';
  }
}
