// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'input_decorator.dart';
import 'material_state.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class TimePickerThemeData with Diagnosticable {

  const TimePickerThemeData({
    this.backgroundColor,
    this.cancelButtonStyle,
    this.confirmButtonStyle,
    this.dayPeriodBorderSide,
    this.dayPeriodColor,
    this.dayPeriodShape,
    this.dayPeriodTextColor,
    this.dayPeriodTextStyle,
    this.dialBackgroundColor,
    this.dialHandColor,
    this.dialTextColor,
    this.dialTextStyle,
    this.elevation,
    this.entryModeIconColor,
    this.helpTextStyle,
    this.hourMinuteColor,
    this.hourMinuteShape,
    this.hourMinuteTextColor,
    this.hourMinuteTextStyle,
    this.inputDecorationTheme,
    this.padding,
    this.shape,
  });

  final Color? backgroundColor;

  final ButtonStyle? cancelButtonStyle;

  final ButtonStyle? confirmButtonStyle;

  final BorderSide? dayPeriodBorderSide;

  final Color? dayPeriodColor;

  final OutlinedBorder? dayPeriodShape;

  final Color? dayPeriodTextColor;

  final TextStyle? dayPeriodTextStyle;

  final Color? dialBackgroundColor;

  final Color? dialHandColor;

  final Color? dialTextColor;

  final TextStyle? dialTextStyle;

  final double? elevation;

  final Color? entryModeIconColor;

  final TextStyle? helpTextStyle;

  final Color? hourMinuteColor;

  final ShapeBorder? hourMinuteShape;

  final Color? hourMinuteTextColor;

  final TextStyle? hourMinuteTextStyle;

  final InputDecorationTheme? inputDecorationTheme;

  final EdgeInsetsGeometry? padding;

  final ShapeBorder? shape;

  TimePickerThemeData copyWith({
    Color? backgroundColor,
    ButtonStyle? cancelButtonStyle,
    ButtonStyle? confirmButtonStyle,
    ButtonStyle? dayPeriodButtonStyle,
    BorderSide? dayPeriodBorderSide,
    Color? dayPeriodColor,
    OutlinedBorder? dayPeriodShape,
    Color? dayPeriodTextColor,
    TextStyle? dayPeriodTextStyle,
    Color? dialBackgroundColor,
    Color? dialHandColor,
    Color? dialTextColor,
    TextStyle? dialTextStyle,
    double? elevation,
    Color? entryModeIconColor,
    TextStyle? helpTextStyle,
    Color? hourMinuteColor,
    ShapeBorder? hourMinuteShape,
    Color? hourMinuteTextColor,
    TextStyle? hourMinuteTextStyle,
    InputDecorationTheme? inputDecorationTheme,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
  }) {
    return TimePickerThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      cancelButtonStyle: cancelButtonStyle ?? this.cancelButtonStyle,
      confirmButtonStyle: confirmButtonStyle ?? this.confirmButtonStyle,
      dayPeriodBorderSide: dayPeriodBorderSide ?? this.dayPeriodBorderSide,
      dayPeriodColor: dayPeriodColor ?? this.dayPeriodColor,
      dayPeriodShape: dayPeriodShape ?? this.dayPeriodShape,
      dayPeriodTextColor: dayPeriodTextColor ?? this.dayPeriodTextColor,
      dayPeriodTextStyle: dayPeriodTextStyle ?? this.dayPeriodTextStyle,
      dialBackgroundColor: dialBackgroundColor ?? this.dialBackgroundColor,
      dialHandColor: dialHandColor ?? this.dialHandColor,
      dialTextColor: dialTextColor ?? this.dialTextColor,
      dialTextStyle: dialTextStyle ?? this.dialTextStyle,
      elevation: elevation ?? this.elevation,
      entryModeIconColor: entryModeIconColor ?? this.entryModeIconColor,
      helpTextStyle: helpTextStyle ?? this.helpTextStyle,
      hourMinuteColor: hourMinuteColor ?? this.hourMinuteColor,
      hourMinuteShape: hourMinuteShape ?? this.hourMinuteShape,
      hourMinuteTextColor: hourMinuteTextColor ?? this.hourMinuteTextColor,
      hourMinuteTextStyle: hourMinuteTextStyle ?? this.hourMinuteTextStyle,
      inputDecorationTheme: inputDecorationTheme ?? this.inputDecorationTheme,
      padding: padding ?? this.padding,
      shape: shape ?? this.shape,
    );
  }

  static TimePickerThemeData lerp(TimePickerThemeData? a, TimePickerThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    // Workaround since BorderSide's lerp does not allow for null arguments.
    BorderSide? lerpedBorderSide;
    if (a?.dayPeriodBorderSide == null && b?.dayPeriodBorderSide == null) {
      lerpedBorderSide = null;
    } else if (a?.dayPeriodBorderSide == null) {
      lerpedBorderSide = b?.dayPeriodBorderSide;
    } else if (b?.dayPeriodBorderSide == null) {
      lerpedBorderSide = a?.dayPeriodBorderSide;
    } else {
      lerpedBorderSide = BorderSide.lerp(a!.dayPeriodBorderSide!, b!.dayPeriodBorderSide!, t);
    }
    return TimePickerThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      cancelButtonStyle: ButtonStyle.lerp(a?.cancelButtonStyle, b?.cancelButtonStyle, t),
      confirmButtonStyle: ButtonStyle.lerp(a?.confirmButtonStyle, b?.confirmButtonStyle, t),
      dayPeriodBorderSide: lerpedBorderSide,
      dayPeriodColor: Color.lerp(a?.dayPeriodColor, b?.dayPeriodColor, t),
      dayPeriodShape: ShapeBorder.lerp(a?.dayPeriodShape, b?.dayPeriodShape, t) as OutlinedBorder?,
      dayPeriodTextColor: Color.lerp(a?.dayPeriodTextColor, b?.dayPeriodTextColor, t),
      dayPeriodTextStyle: TextStyle.lerp(a?.dayPeriodTextStyle, b?.dayPeriodTextStyle, t),
      dialBackgroundColor: Color.lerp(a?.dialBackgroundColor, b?.dialBackgroundColor, t),
      dialHandColor: Color.lerp(a?.dialHandColor, b?.dialHandColor, t),
      dialTextColor: Color.lerp(a?.dialTextColor, b?.dialTextColor, t),
      dialTextStyle: TextStyle.lerp(a?.dialTextStyle, b?.dialTextStyle, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      entryModeIconColor: Color.lerp(a?.entryModeIconColor, b?.entryModeIconColor, t),
      helpTextStyle: TextStyle.lerp(a?.helpTextStyle, b?.helpTextStyle, t),
      hourMinuteColor: Color.lerp(a?.hourMinuteColor, b?.hourMinuteColor, t),
      hourMinuteShape: ShapeBorder.lerp(a?.hourMinuteShape, b?.hourMinuteShape, t),
      hourMinuteTextColor: Color.lerp(a?.hourMinuteTextColor, b?.hourMinuteTextColor, t),
      hourMinuteTextStyle: TextStyle.lerp(a?.hourMinuteTextStyle, b?.hourMinuteTextStyle, t),
      inputDecorationTheme: t < 0.5 ? a?.inputDecorationTheme : b?.inputDecorationTheme,
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
    );
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    backgroundColor,
    cancelButtonStyle,
    confirmButtonStyle,
    dayPeriodBorderSide,
    dayPeriodColor,
    dayPeriodShape,
    dayPeriodTextColor,
    dayPeriodTextStyle,
    dialBackgroundColor,
    dialHandColor,
    dialTextColor,
    dialTextStyle,
    elevation,
    entryModeIconColor,
    helpTextStyle,
    hourMinuteColor,
    hourMinuteShape,
    hourMinuteTextColor,
    hourMinuteTextStyle,
    inputDecorationTheme,
    padding,
    shape,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TimePickerThemeData
        && other.backgroundColor == backgroundColor
        && other.cancelButtonStyle == cancelButtonStyle
        && other.confirmButtonStyle == confirmButtonStyle
        && other.dayPeriodBorderSide == dayPeriodBorderSide
        && other.dayPeriodColor == dayPeriodColor
        && other.dayPeriodShape == dayPeriodShape
        && other.dayPeriodTextColor == dayPeriodTextColor
        && other.dayPeriodTextStyle == dayPeriodTextStyle
        && other.dialBackgroundColor == dialBackgroundColor
        && other.dialHandColor == dialHandColor
        && other.dialTextColor == dialTextColor
        && other.dialTextStyle == dialTextStyle
        && other.elevation == elevation
        && other.entryModeIconColor == entryModeIconColor
        && other.helpTextStyle == helpTextStyle
        && other.hourMinuteColor == hourMinuteColor
        && other.hourMinuteShape == hourMinuteShape
        && other.hourMinuteTextColor == hourMinuteTextColor
        && other.hourMinuteTextStyle == hourMinuteTextStyle
        && other.inputDecorationTheme == inputDecorationTheme
        && other.padding == padding
        && other.shape == shape;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ButtonStyle>('cancelButtonStyle', cancelButtonStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<ButtonStyle>('confirmButtonStyle', confirmButtonStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide>('dayPeriodBorderSide', dayPeriodBorderSide, defaultValue: null));
    properties.add(ColorProperty('dayPeriodColor', dayPeriodColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('dayPeriodShape', dayPeriodShape, defaultValue: null));
    properties.add(ColorProperty('dayPeriodTextColor', dayPeriodTextColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('dayPeriodTextStyle', dayPeriodTextStyle, defaultValue: null));
    properties.add(ColorProperty('dialBackgroundColor', dialBackgroundColor, defaultValue: null));
    properties.add(ColorProperty('dialHandColor', dialHandColor, defaultValue: null));
    properties.add(ColorProperty('dialTextColor', dialTextColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle?>('dialTextStyle', dialTextStyle, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(ColorProperty('entryModeIconColor', entryModeIconColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('helpTextStyle', helpTextStyle, defaultValue: null));
    properties.add(ColorProperty('hourMinuteColor', hourMinuteColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('hourMinuteShape', hourMinuteShape, defaultValue: null));
    properties.add(ColorProperty('hourMinuteTextColor', hourMinuteTextColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('hourMinuteTextStyle', hourMinuteTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<InputDecorationTheme>('inputDecorationTheme', inputDecorationTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
  }
}

class TimePickerTheme extends InheritedTheme {
  const TimePickerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final TimePickerThemeData data;

  static TimePickerThemeData of(BuildContext context) {
    final TimePickerTheme? timePickerTheme = context.dependOnInheritedWidgetOfExactType<TimePickerTheme>();
    return timePickerTheme?.data ?? Theme.of(context).timePickerTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return TimePickerTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(TimePickerTheme oldWidget) => data != oldWidget.data;
}