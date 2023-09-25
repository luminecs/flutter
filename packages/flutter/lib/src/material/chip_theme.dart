// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'material_state.dart';
import 'theme.dart';

class ChipTheme extends InheritedTheme {
  const ChipTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ChipThemeData data;

  static ChipThemeData of(BuildContext context) {
    final ChipTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<ChipTheme>();
    return inheritedTheme?.data ?? Theme.of(context).chipTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ChipTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ChipTheme oldWidget) => data != oldWidget.data;
}

@immutable
class ChipThemeData with Diagnosticable {
  const ChipThemeData({
    this.color,
    this.backgroundColor,
    this.deleteIconColor,
    this.disabledColor,
    this.selectedColor,
    this.secondarySelectedColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.selectedShadowColor,
    this.showCheckmark,
    this.checkmarkColor,
    this.labelPadding,
    this.padding,
    this.side,
    this.shape,
    this.labelStyle,
    this.secondaryLabelStyle,
    this.brightness,
    this.elevation,
    this.pressElevation,
    this.iconTheme,
  });

  factory ChipThemeData.fromDefaults({
    Brightness? brightness,
    Color? primaryColor,
    required Color secondaryColor,
    required TextStyle labelStyle,
  }) {
    assert(primaryColor != null || brightness != null, 'One of primaryColor or brightness must be specified');
    assert(primaryColor == null || brightness == null, 'Only one of primaryColor or brightness may be specified');

    if (primaryColor != null) {
      brightness = ThemeData.estimateBrightnessForColor(primaryColor);
    }

    // These are Material Design defaults, and are used to derive
    // component Colors (with opacity) from base colors.
    const int backgroundAlpha = 0x1f; // 12%
    const int deleteIconAlpha = 0xde; // 87%
    const int disabledAlpha = 0x0c; // 38% * 12% = 5%
    const int selectAlpha = 0x3d; // 12% + 12% = 24%
    const int textLabelAlpha = 0xde; // 87%
    const EdgeInsetsGeometry padding = EdgeInsets.all(4.0);

    primaryColor = primaryColor ?? (brightness == Brightness.light ? Colors.black : Colors.white);
    final Color backgroundColor = primaryColor.withAlpha(backgroundAlpha);
    final Color deleteIconColor = primaryColor.withAlpha(deleteIconAlpha);
    final Color disabledColor = primaryColor.withAlpha(disabledAlpha);
    final Color selectedColor = primaryColor.withAlpha(selectAlpha);
    final Color secondarySelectedColor = secondaryColor.withAlpha(selectAlpha);
    final TextStyle secondaryLabelStyle = labelStyle.copyWith(
      color: secondaryColor.withAlpha(textLabelAlpha),
    );
    labelStyle = labelStyle.copyWith(color: primaryColor.withAlpha(textLabelAlpha));

    return ChipThemeData(
      backgroundColor: backgroundColor,
      deleteIconColor: deleteIconColor,
      disabledColor: disabledColor,
      selectedColor: selectedColor,
      secondarySelectedColor: secondarySelectedColor,
      shadowColor: Colors.black,
      selectedShadowColor: Colors.black,
      showCheckmark: true,
      padding: padding,
      labelStyle: labelStyle,
      secondaryLabelStyle: secondaryLabelStyle,
      brightness: brightness,
      elevation: 0.0,
      pressElevation: 8.0,
    );
  }

  final MaterialStateProperty<Color?>? color;

  final Color? backgroundColor;

  final Color? deleteIconColor;

  final Color? disabledColor;

  final Color? selectedColor;

  final Color? secondarySelectedColor;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final Color? selectedShadowColor;

  final bool? showCheckmark;

  final Color? checkmarkColor;

  final EdgeInsetsGeometry? labelPadding;

  final EdgeInsetsGeometry? padding;

  final BorderSide? side;

  final OutlinedBorder? shape;

  final TextStyle? labelStyle;

  final TextStyle? secondaryLabelStyle;

  final Brightness? brightness;

  final double? elevation;

  final double? pressElevation;

  final IconThemeData? iconTheme;

  ChipThemeData copyWith({
    MaterialStateProperty<Color?>? color,
    Color? backgroundColor,
    Color? deleteIconColor,
    Color? disabledColor,
    Color? selectedColor,
    Color? secondarySelectedColor,
    Color? shadowColor,
    Color? surfaceTintColor,
    Color? selectedShadowColor,
    bool? showCheckmark,
    Color? checkmarkColor,
    EdgeInsetsGeometry? labelPadding,
    EdgeInsetsGeometry? padding,
    BorderSide? side,
    OutlinedBorder? shape,
    TextStyle? labelStyle,
    TextStyle? secondaryLabelStyle,
    Brightness? brightness,
    double? elevation,
    double? pressElevation,
    IconThemeData? iconTheme,
  }) {
    return ChipThemeData(
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      deleteIconColor: deleteIconColor ?? this.deleteIconColor,
      disabledColor: disabledColor ?? this.disabledColor,
      selectedColor: selectedColor ?? this.selectedColor,
      secondarySelectedColor: secondarySelectedColor ?? this.secondarySelectedColor,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      selectedShadowColor: selectedShadowColor ?? this.selectedShadowColor,
      showCheckmark: showCheckmark ?? this.showCheckmark,
      checkmarkColor: checkmarkColor ?? this.checkmarkColor,
      labelPadding: labelPadding ?? this.labelPadding,
      padding: padding ?? this.padding,
      side: side ?? this.side,
      shape: shape ?? this.shape,
      labelStyle: labelStyle ?? this.labelStyle,
      secondaryLabelStyle: secondaryLabelStyle ?? this.secondaryLabelStyle,
      brightness: brightness ?? this.brightness,
      elevation: elevation ?? this.elevation,
      pressElevation: pressElevation ?? this.pressElevation,
      iconTheme: iconTheme ?? this.iconTheme,
    );
  }

  static ChipThemeData? lerp(ChipThemeData? a, ChipThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ChipThemeData(
      color: MaterialStateProperty.lerp<Color?>(a?.color, b?.color, t, Color.lerp),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      deleteIconColor: Color.lerp(a?.deleteIconColor, b?.deleteIconColor, t),
      disabledColor: Color.lerp(a?.disabledColor, b?.disabledColor, t),
      selectedColor: Color.lerp(a?.selectedColor, b?.selectedColor, t),
      secondarySelectedColor: Color.lerp(a?.secondarySelectedColor, b?.secondarySelectedColor, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      selectedShadowColor: Color.lerp(a?.selectedShadowColor, b?.selectedShadowColor, t),
      showCheckmark: t < 0.5 ? a?.showCheckmark ?? true : b?.showCheckmark ?? true,
      checkmarkColor: Color.lerp(a?.checkmarkColor, b?.checkmarkColor, t),
      labelPadding: EdgeInsetsGeometry.lerp(a?.labelPadding, b?.labelPadding, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      side: _lerpSides(a?.side, b?.side, t),
      shape: _lerpShapes(a?.shape, b?.shape, t),
      labelStyle: TextStyle.lerp(a?.labelStyle, b?.labelStyle, t),
      secondaryLabelStyle: TextStyle.lerp(a?.secondaryLabelStyle, b?.secondaryLabelStyle, t),
      brightness: t < 0.5 ? a?.brightness ?? Brightness.light : b?.brightness ?? Brightness.light,
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      pressElevation: lerpDouble(a?.pressElevation, b?.pressElevation, t),
      iconTheme: a?.iconTheme != null || b?.iconTheme != null
        ? IconThemeData.lerp(a?.iconTheme, b?.iconTheme, t)
        : null,
    );
  }

  // Special case because BorderSide.lerp() doesn't support null arguments.
  static BorderSide? _lerpSides(BorderSide? a, BorderSide? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return BorderSide.lerp(BorderSide(width: 0, color: b!.color.withAlpha(0)), b, t);
    }
    if (b == null) {
      return BorderSide.lerp(BorderSide(width: 0, color: a.color.withAlpha(0)), a, t);
    }
    return BorderSide.lerp(a, b, t);
  }

  // TODO(perclasson): OutlinedBorder needs a lerp method - https://github.com/flutter/flutter/issues/60555.
  static OutlinedBorder? _lerpShapes(OutlinedBorder? a, OutlinedBorder? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    return ShapeBorder.lerp(a, b, t) as OutlinedBorder?;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    color,
    backgroundColor,
    deleteIconColor,
    disabledColor,
    selectedColor,
    secondarySelectedColor,
    shadowColor,
    surfaceTintColor,
    selectedShadowColor,
    showCheckmark,
    checkmarkColor,
    labelPadding,
    padding,
    side,
    shape,
    labelStyle,
    secondaryLabelStyle,
    brightness,
    elevation,
    pressElevation,
    iconTheme,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ChipThemeData
        && other.color == color
        && other.backgroundColor == backgroundColor
        && other.deleteIconColor == deleteIconColor
        && other.disabledColor == disabledColor
        && other.selectedColor == selectedColor
        && other.secondarySelectedColor == secondarySelectedColor
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.selectedShadowColor == selectedShadowColor
        && other.showCheckmark == showCheckmark
        && other.checkmarkColor == checkmarkColor
        && other.labelPadding == labelPadding
        && other.padding == padding
        && other.side == side
        && other.shape == shape
        && other.labelStyle == labelStyle
        && other.secondaryLabelStyle == secondaryLabelStyle
        && other.brightness == brightness
        && other.elevation == elevation
        && other.pressElevation == pressElevation
        && other.iconTheme == iconTheme;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('color', color, defaultValue: null));
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('deleteIconColor', deleteIconColor, defaultValue: null));
    properties.add(ColorProperty('disabledColor', disabledColor, defaultValue: null));
    properties.add(ColorProperty('selectedColor', selectedColor, defaultValue: null));
    properties.add(ColorProperty('secondarySelectedColor', secondarySelectedColor, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(ColorProperty('selectedShadowColor', selectedShadowColor, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('showCheckmark', showCheckmark, defaultValue: null));
    properties.add(ColorProperty('checkMarkColor', checkmarkColor, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('labelPadding', labelPadding, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide>('side', side, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('labelStyle', labelStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('secondaryLabelStyle', secondaryLabelStyle, defaultValue: null));
    properties.add(EnumProperty<Brightness>('brightness', brightness, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(DoubleProperty('pressElevation', pressElevation, defaultValue: null));
    properties.add(DiagnosticsProperty<IconThemeData>('iconTheme', iconTheme, defaultValue: null));
  }
}