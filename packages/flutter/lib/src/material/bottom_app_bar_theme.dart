
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

@immutable
class BottomAppBarTheme with Diagnosticable {
  const BottomAppBarTheme({
    this.color,
    this.elevation,
    this.shape,
    this.height,
    this.surfaceTintColor,
    this.shadowColor,
    this.padding,
  });

  final Color? color;

  final double? elevation;

  final NotchedShape? shape;

  final double? height;

  final Color? surfaceTintColor;

  final Color? shadowColor;

  final EdgeInsetsGeometry? padding;

  BottomAppBarTheme copyWith({
    Color? color,
    double? elevation,
    NotchedShape? shape,
    double? height,
    Color? surfaceTintColor,
    Color? shadowColor,
    EdgeInsetsGeometry? padding,
  }) {
    return BottomAppBarTheme(
      color: color ?? this.color,
      elevation: elevation ?? this.elevation,
      shape: shape ?? this.shape,
      height: height ?? this.height,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      shadowColor: shadowColor ?? this.shadowColor,
      padding: padding ?? this.padding,
    );
  }

  static BottomAppBarTheme of(BuildContext context) {
    return Theme.of(context).bottomAppBarTheme;
  }

  static BottomAppBarTheme lerp(BottomAppBarTheme? a, BottomAppBarTheme? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return BottomAppBarTheme(
      color: Color.lerp(a?.color, b?.color, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shape: t < 0.5 ? a?.shape : b?.shape,
      height: lerpDouble(a?.height, b?.height, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    color,
    elevation,
    shape,
    height,
    surfaceTintColor,
    shadowColor,
    padding,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BottomAppBarTheme
        && other.color == color
        && other.elevation == elevation
        && other.shape == shape
        && other.height == height
        && other.surfaceTintColor == surfaceTintColor
        && other.shadowColor == shadowColor
        && other.padding == padding;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<NotchedShape>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('height', height, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
  }
}