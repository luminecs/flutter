import 'dart:ui' as ui show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'framework.dart' show BuildContext;

@immutable
class IconThemeData with Diagnosticable {
  const IconThemeData({
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.color,
    double? opacity,
    this.shadows,
  }) : _opacity = opacity,
       assert(fill == null || (0.0 <= fill && fill <= 1.0)),
       assert(weight == null || (0.0 < weight)),
       assert(opticalSize == null || (0.0 < opticalSize));

  const IconThemeData.fallback()
      : size = 24.0,
        fill = 0.0,
        weight = 400.0,
        grade = 0.0,
        opticalSize = 48.0,
        color = const Color(0xFF000000),
        _opacity = 1.0,
        shadows = null;

  IconThemeData copyWith({
    double? size,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
    Color? color,
    double? opacity,
    List<Shadow>? shadows,
  }) {
    return IconThemeData(
      size: size ?? this.size,
      fill: fill ?? this.fill,
      weight: weight ?? this.weight,
      grade: grade ?? this.grade,
      opticalSize: opticalSize ?? this.opticalSize,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      shadows: shadows ?? this.shadows,
    );
  }

  IconThemeData merge(IconThemeData? other) {
    if (other == null) {
      return this;
    }
    return copyWith(
      size: other.size,
      fill: other.fill,
      weight: other.weight,
      grade: other.grade,
      opticalSize: other.opticalSize,
      color: other.color,
      opacity: other.opacity,
      shadows: other.shadows,
    );
  }

  IconThemeData resolve(BuildContext context) => this;

  bool get isConcrete => size != null
    && fill != null
    && weight != null
    && grade != null
    && opticalSize != null
    && color != null
    && opacity != null;

  final double? size;

  final double? fill;

  final double? weight;

  final double? grade;

  final double? opticalSize;

  final Color? color;

  double? get opacity => _opacity == null ? null : clampDouble(_opacity, 0.0, 1.0);
  final double? _opacity;

  final List<Shadow>? shadows;

  static IconThemeData lerp(IconThemeData? a, IconThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return IconThemeData(
      size: ui.lerpDouble(a?.size, b?.size, t),
      fill: ui.lerpDouble(a?.fill, b?.fill, t),
      weight: ui.lerpDouble(a?.weight, b?.weight, t),
      grade: ui.lerpDouble(a?.grade, b?.grade, t),
      opticalSize: ui.lerpDouble(a?.opticalSize, b?.opticalSize, t),
      color: Color.lerp(a?.color, b?.color, t),
      opacity: ui.lerpDouble(a?.opacity, b?.opacity, t),
      shadows: Shadow.lerpList(a?.shadows, b?.shadows, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IconThemeData
        && other.size == size
        && other.fill == fill
        && other.weight == weight
        && other.grade == grade
        && other.opticalSize == opticalSize
        && other.color == color
        && other.opacity == opacity
        && listEquals(other.shadows, shadows);
  }

  @override
  int get hashCode => Object.hash(
    size,
    fill,
    weight,
    grade,
    opticalSize,
    color,
    opacity,
    shadows == null ? null : Object.hashAll(shadows!),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('size', size, defaultValue: null));
    properties.add(DoubleProperty('fill', fill, defaultValue: null));
    properties.add(DoubleProperty('weight', weight, defaultValue: null));
    properties.add(DoubleProperty('grade', grade, defaultValue: null));
    properties.add(DoubleProperty('opticalSize', opticalSize, defaultValue: null));
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DoubleProperty('opacity', opacity, defaultValue: null));
    properties.add(IterableProperty<Shadow>('shadows', shadows, defaultValue: null));
  }
}