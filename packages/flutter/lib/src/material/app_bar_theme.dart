// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

@immutable
class AppBarTheme with Diagnosticable {
  const AppBarTheme({
    Color? color,
    Color? backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.iconTheme,
    this.actionsIconTheme,
    this.centerTitle,
    this.titleSpacing,
    this.toolbarHeight,
    this.toolbarTextStyle,
    this.titleTextStyle,
    this.systemOverlayStyle,
  }) : assert(
         color == null || backgroundColor == null,
         'The color and backgroundColor parameters mean the same thing. Only specify one.',
       ),
       backgroundColor = backgroundColor ?? color;

  final Color? backgroundColor;

  final Color? foregroundColor;

  final double? elevation;

  final double? scrolledUnderElevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final ShapeBorder? shape;

  final IconThemeData? iconTheme;

  final IconThemeData? actionsIconTheme;

  final bool? centerTitle;

  final double? titleSpacing;

  final double? toolbarHeight;

  final TextStyle? toolbarTextStyle;

  final TextStyle? titleTextStyle;

  final SystemUiOverlayStyle? systemOverlayStyle;

  AppBarTheme copyWith({
    IconThemeData? actionsIconTheme,
    Color? color,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    double? scrolledUnderElevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    ShapeBorder? shape,
    IconThemeData? iconTheme,
    bool? centerTitle,
    double? titleSpacing,
    double? toolbarHeight,
    TextStyle? toolbarTextStyle,
    TextStyle? titleTextStyle,
    SystemUiOverlayStyle? systemOverlayStyle,
  }) {
    assert(
      color == null || backgroundColor == null,
      'The color and backgroundColor parameters mean the same thing. Only specify one.',
    );
    return AppBarTheme(
      backgroundColor: backgroundColor ?? color ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      elevation: elevation ?? this.elevation,
      scrolledUnderElevation: scrolledUnderElevation ?? this.scrolledUnderElevation,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      shape: shape ?? this.shape,
      iconTheme: iconTheme ?? this.iconTheme,
      actionsIconTheme: actionsIconTheme ?? this.actionsIconTheme,
      centerTitle: centerTitle ?? this.centerTitle,
      titleSpacing: titleSpacing ?? this.titleSpacing,
      toolbarHeight: toolbarHeight ?? this.toolbarHeight,
      toolbarTextStyle: toolbarTextStyle ?? this.toolbarTextStyle,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      systemOverlayStyle: systemOverlayStyle ?? this.systemOverlayStyle,
    );
  }

  static AppBarTheme of(BuildContext context) {
    return Theme.of(context).appBarTheme;
  }

  static AppBarTheme lerp(AppBarTheme? a, AppBarTheme? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return AppBarTheme(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      foregroundColor: Color.lerp(a?.foregroundColor, b?.foregroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      scrolledUnderElevation: lerpDouble(a?.scrolledUnderElevation, b?.scrolledUnderElevation, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      iconTheme: IconThemeData.lerp(a?.iconTheme, b?.iconTheme, t),
      actionsIconTheme: IconThemeData.lerp(a?.actionsIconTheme, b?.actionsIconTheme, t),
      centerTitle: t < 0.5 ? a?.centerTitle : b?.centerTitle,
      titleSpacing: lerpDouble(a?.titleSpacing, b?.titleSpacing, t),
      toolbarHeight: lerpDouble(a?.toolbarHeight, b?.toolbarHeight, t),
      toolbarTextStyle: TextStyle.lerp(a?.toolbarTextStyle, b?.toolbarTextStyle, t),
      titleTextStyle: TextStyle.lerp(a?.titleTextStyle, b?.titleTextStyle, t),
      systemOverlayStyle: t < 0.5 ? a?.systemOverlayStyle : b?.systemOverlayStyle,
    );
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    foregroundColor,
    elevation,
    scrolledUnderElevation,
    shadowColor,
    surfaceTintColor,
    shape,
    iconTheme,
    actionsIconTheme,
    centerTitle,
    titleSpacing,
    toolbarHeight,
    toolbarTextStyle,
    titleTextStyle,
    systemOverlayStyle,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AppBarTheme
        && other.backgroundColor == backgroundColor
        && other.foregroundColor == foregroundColor
        && other.elevation == elevation
        && other.scrolledUnderElevation == scrolledUnderElevation
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.shape == shape
        && other.iconTheme == iconTheme
        && other.actionsIconTheme == actionsIconTheme
        && other.centerTitle == centerTitle
        && other.titleSpacing == titleSpacing
        && other.toolbarHeight == toolbarHeight
        && other.toolbarTextStyle == toolbarTextStyle
        && other.titleTextStyle == titleTextStyle
        && other.systemOverlayStyle == systemOverlayStyle;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('foregroundColor', foregroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('scrolledUnderElevation', scrolledUnderElevation, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<IconThemeData>('iconTheme', iconTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<IconThemeData>('actionsIconTheme', actionsIconTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('centerTitle', centerTitle, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('titleSpacing', titleSpacing, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('toolbarHeight', toolbarHeight, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('toolbarTextStyle', toolbarTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('titleTextStyle', titleTextStyle, defaultValue: null));
  }
}