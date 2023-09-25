// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';
import 'navigation_bar.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class NavigationBarThemeData with Diagnosticable {
  const NavigationBarThemeData({
    this.height,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.indicatorColor,
    this.indicatorShape,
    this.labelTextStyle,
    this.iconTheme,
    this.labelBehavior,
  });

  final double? height;

  final Color? backgroundColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final Color? indicatorColor;

  final ShapeBorder? indicatorShape;

  final MaterialStateProperty<TextStyle?>? labelTextStyle;

  final MaterialStateProperty<IconThemeData?>? iconTheme;

  final NavigationDestinationLabelBehavior? labelBehavior;

  NavigationBarThemeData copyWith({
    double? height,
    Color? backgroundColor,
    double? elevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    Color? indicatorColor,
    ShapeBorder? indicatorShape,
    MaterialStateProperty<TextStyle?>? labelTextStyle,
    MaterialStateProperty<IconThemeData?>? iconTheme,
    NavigationDestinationLabelBehavior? labelBehavior,
  }) {
    return NavigationBarThemeData(
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorShape: indicatorShape ?? this.indicatorShape,
      labelTextStyle: labelTextStyle ?? this.labelTextStyle,
      iconTheme: iconTheme ?? this.iconTheme,
      labelBehavior: labelBehavior ?? this.labelBehavior,
    );
  }

  static NavigationBarThemeData? lerp(NavigationBarThemeData? a, NavigationBarThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return NavigationBarThemeData(
      height: lerpDouble(a?.height, b?.height, t),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      indicatorColor: Color.lerp(a?.indicatorColor, b?.indicatorColor, t),
      indicatorShape: ShapeBorder.lerp(a?.indicatorShape, b?.indicatorShape, t),
      labelTextStyle: MaterialStateProperty.lerp<TextStyle?>(a?.labelTextStyle, b?.labelTextStyle, t, TextStyle.lerp),
      iconTheme: MaterialStateProperty.lerp<IconThemeData?>(a?.iconTheme, b?.iconTheme, t, IconThemeData.lerp),
      labelBehavior: t < 0.5 ? a?.labelBehavior : b?.labelBehavior,
    );
  }

  @override
  int get hashCode => Object.hash(
    height,
    backgroundColor,
    elevation,
    shadowColor,
    surfaceTintColor,
    indicatorColor,
    indicatorShape,
    labelTextStyle,
    iconTheme,
    labelBehavior,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is NavigationBarThemeData
        && other.height == height
        && other.backgroundColor == backgroundColor
        && other.elevation == elevation
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.indicatorColor == indicatorColor
        && other.indicatorShape == indicatorShape
        && other.labelTextStyle == labelTextStyle
        && other.iconTheme == iconTheme
        && other.labelBehavior == labelBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('height', height, defaultValue: null));
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(ColorProperty('indicatorColor', indicatorColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('indicatorShape', indicatorShape, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<TextStyle?>>('labelTextStyle', labelTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<IconThemeData?>>('iconTheme', iconTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<NavigationDestinationLabelBehavior>('labelBehavior', labelBehavior, defaultValue: null));
  }
}

class NavigationBarTheme extends InheritedTheme {
  const NavigationBarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final NavigationBarThemeData data;

  static NavigationBarThemeData of(BuildContext context) {
    final NavigationBarTheme? navigationBarTheme = context.dependOnInheritedWidgetOfExactType<NavigationBarTheme>();
    return navigationBarTheme?.data ?? Theme.of(context).navigationBarTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return NavigationBarTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(NavigationBarTheme oldWidget) => data != oldWidget.data;
}