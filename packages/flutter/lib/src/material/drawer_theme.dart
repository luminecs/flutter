import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class DrawerThemeData with Diagnosticable {
  const DrawerThemeData({
    this.backgroundColor,
    this.scrimColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.endShape,
    this.width,
  });

  final Color? backgroundColor;

  final Color? scrimColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final ShapeBorder? shape;

  final ShapeBorder? endShape;

  final double? width;

  DrawerThemeData copyWith({
    Color? backgroundColor,
    Color? scrimColor,
    double? elevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    ShapeBorder? shape,
    ShapeBorder? endShape,
    double? width,
  }) {
    return DrawerThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      scrimColor: scrimColor ?? this.scrimColor,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      shape: shape ?? this.shape,
      endShape: endShape ?? this.endShape,
      width: width ?? this.width,
    );
  }

  static DrawerThemeData? lerp(DrawerThemeData? a, DrawerThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return DrawerThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      scrimColor: Color.lerp(a?.scrimColor, b?.scrimColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      endShape: ShapeBorder.lerp(a?.endShape, b?.endShape, t),
      width: lerpDouble(a?.width, b?.width, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    scrimColor,
    elevation,
    shadowColor,
    surfaceTintColor,
    shape,
    endShape,
    width,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DrawerThemeData
        && other.backgroundColor == backgroundColor
        && other.scrimColor == scrimColor
        && other.elevation == elevation
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.shape == shape
        && other.endShape == endShape
        && other.width == width;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('scrimColor', scrimColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('endShape', endShape, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
  }
}

class DrawerTheme extends InheritedTheme {
  const DrawerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final DrawerThemeData data;

  static DrawerThemeData of(BuildContext context) {
    final DrawerTheme? drawerTheme = context.dependOnInheritedWidgetOfExactType<DrawerTheme>();
    return drawerTheme?.data ?? Theme.of(context).drawerTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DrawerTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(DrawerTheme oldWidget) => data != oldWidget.data;
}