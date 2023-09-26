import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'material_state.dart';

@immutable
class FloatingActionButtonThemeData with Diagnosticable {
  const FloatingActionButtonThemeData({
    this.foregroundColor,
    this.backgroundColor,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.disabledElevation,
    this.highlightElevation,
    this.shape,
    this.enableFeedback,
    this.iconSize,
    this.sizeConstraints,
    this.smallSizeConstraints,
    this.largeSizeConstraints,
    this.extendedSizeConstraints,
    this.extendedIconLabelSpacing,
    this.extendedPadding,
    this.extendedTextStyle,
    this.mouseCursor,
  });

  final Color? foregroundColor;

  final Color? backgroundColor;

  final Color? focusColor;

  final Color? hoverColor;

  final Color? splashColor;

  final double? elevation;

  final double? focusElevation;

  final double? hoverElevation;

  final double? disabledElevation;

  final double? highlightElevation;

  final ShapeBorder? shape;

  final bool? enableFeedback;

  final double? iconSize;

  final BoxConstraints? sizeConstraints;

  final BoxConstraints? smallSizeConstraints;

  final BoxConstraints? largeSizeConstraints;

  final BoxConstraints? extendedSizeConstraints;

  final double? extendedIconLabelSpacing;

  final EdgeInsetsGeometry? extendedPadding;

  final TextStyle? extendedTextStyle;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  FloatingActionButtonThemeData copyWith({
    Color? foregroundColor,
    Color? backgroundColor,
    Color? focusColor,
    Color? hoverColor,
    Color? splashColor,
    double? elevation,
    double? focusElevation,
    double? hoverElevation,
    double? disabledElevation,
    double? highlightElevation,
    ShapeBorder? shape,
    bool? enableFeedback,
    double? iconSize,
    BoxConstraints? sizeConstraints,
    BoxConstraints? smallSizeConstraints,
    BoxConstraints? largeSizeConstraints,
    BoxConstraints? extendedSizeConstraints,
    double? extendedIconLabelSpacing,
    EdgeInsetsGeometry? extendedPadding,
    TextStyle? extendedTextStyle,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
  }) {
    return FloatingActionButtonThemeData(
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      focusColor: focusColor ?? this.focusColor,
      hoverColor: hoverColor ?? this.hoverColor,
      splashColor: splashColor ?? this.splashColor,
      elevation: elevation ?? this.elevation,
      focusElevation: focusElevation ?? this.focusElevation,
      hoverElevation: hoverElevation ?? this.hoverElevation,
      disabledElevation: disabledElevation ?? this.disabledElevation,
      highlightElevation: highlightElevation ?? this.highlightElevation,
      shape: shape ?? this.shape,
      enableFeedback: enableFeedback ?? this.enableFeedback,
      iconSize: iconSize ?? this.iconSize,
      sizeConstraints: sizeConstraints ?? this.sizeConstraints,
      smallSizeConstraints: smallSizeConstraints ?? this.smallSizeConstraints,
      largeSizeConstraints: largeSizeConstraints ?? this.largeSizeConstraints,
      extendedSizeConstraints:
          extendedSizeConstraints ?? this.extendedSizeConstraints,
      extendedIconLabelSpacing:
          extendedIconLabelSpacing ?? this.extendedIconLabelSpacing,
      extendedPadding: extendedPadding ?? this.extendedPadding,
      extendedTextStyle: extendedTextStyle ?? this.extendedTextStyle,
      mouseCursor: mouseCursor ?? this.mouseCursor,
    );
  }

  static FloatingActionButtonThemeData? lerp(FloatingActionButtonThemeData? a,
      FloatingActionButtonThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return FloatingActionButtonThemeData(
      foregroundColor: Color.lerp(a?.foregroundColor, b?.foregroundColor, t),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      focusColor: Color.lerp(a?.focusColor, b?.focusColor, t),
      hoverColor: Color.lerp(a?.hoverColor, b?.hoverColor, t),
      splashColor: Color.lerp(a?.splashColor, b?.splashColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      focusElevation: lerpDouble(a?.focusElevation, b?.focusElevation, t),
      hoverElevation: lerpDouble(a?.hoverElevation, b?.hoverElevation, t),
      disabledElevation:
          lerpDouble(a?.disabledElevation, b?.disabledElevation, t),
      highlightElevation:
          lerpDouble(a?.highlightElevation, b?.highlightElevation, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      enableFeedback: t < 0.5 ? a?.enableFeedback : b?.enableFeedback,
      iconSize: lerpDouble(a?.iconSize, b?.iconSize, t),
      sizeConstraints:
          BoxConstraints.lerp(a?.sizeConstraints, b?.sizeConstraints, t),
      smallSizeConstraints: BoxConstraints.lerp(
          a?.smallSizeConstraints, b?.smallSizeConstraints, t),
      largeSizeConstraints: BoxConstraints.lerp(
          a?.largeSizeConstraints, b?.largeSizeConstraints, t),
      extendedSizeConstraints: BoxConstraints.lerp(
          a?.extendedSizeConstraints, b?.extendedSizeConstraints, t),
      extendedIconLabelSpacing: lerpDouble(
          a?.extendedIconLabelSpacing, b?.extendedIconLabelSpacing, t),
      extendedPadding:
          EdgeInsetsGeometry.lerp(a?.extendedPadding, b?.extendedPadding, t),
      extendedTextStyle:
          TextStyle.lerp(a?.extendedTextStyle, b?.extendedTextStyle, t),
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
    );
  }

  @override
  int get hashCode => Object.hash(
        foregroundColor,
        backgroundColor,
        focusColor,
        hoverColor,
        splashColor,
        elevation,
        focusElevation,
        hoverElevation,
        disabledElevation,
        highlightElevation,
        shape,
        enableFeedback,
        iconSize,
        sizeConstraints,
        smallSizeConstraints,
        largeSizeConstraints,
        extendedSizeConstraints,
        extendedIconLabelSpacing,
        extendedPadding,
        Object.hash(
          extendedTextStyle,
          mouseCursor,
        ),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FloatingActionButtonThemeData &&
        other.foregroundColor == foregroundColor &&
        other.backgroundColor == backgroundColor &&
        other.focusColor == focusColor &&
        other.hoverColor == hoverColor &&
        other.splashColor == splashColor &&
        other.elevation == elevation &&
        other.focusElevation == focusElevation &&
        other.hoverElevation == hoverElevation &&
        other.disabledElevation == disabledElevation &&
        other.highlightElevation == highlightElevation &&
        other.shape == shape &&
        other.enableFeedback == enableFeedback &&
        other.iconSize == iconSize &&
        other.sizeConstraints == sizeConstraints &&
        other.smallSizeConstraints == smallSizeConstraints &&
        other.largeSizeConstraints == largeSizeConstraints &&
        other.extendedSizeConstraints == extendedSizeConstraints &&
        other.extendedIconLabelSpacing == extendedIconLabelSpacing &&
        other.extendedPadding == extendedPadding &&
        other.extendedTextStyle == extendedTextStyle &&
        other.mouseCursor == mouseCursor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties.add(
        ColorProperty('foregroundColor', foregroundColor, defaultValue: null));
    properties.add(
        ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('focusColor', focusColor, defaultValue: null));
    properties.add(ColorProperty('hoverColor', hoverColor, defaultValue: null));
    properties
        .add(ColorProperty('splashColor', splashColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(
        DoubleProperty('focusElevation', focusElevation, defaultValue: null));
    properties.add(
        DoubleProperty('hoverElevation', hoverElevation, defaultValue: null));
    properties.add(DoubleProperty('disabledElevation', disabledElevation,
        defaultValue: null));
    properties.add(DoubleProperty('highlightElevation', highlightElevation,
        defaultValue: null));
    properties.add(
        DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback,
        defaultValue: null));
    properties.add(DoubleProperty('iconSize', iconSize, defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'sizeConstraints', sizeConstraints,
        defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'smallSizeConstraints', smallSizeConstraints,
        defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'largeSizeConstraints', largeSizeConstraints,
        defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'extendedSizeConstraints', extendedSizeConstraints,
        defaultValue: null));
    properties.add(DoubleProperty(
        'extendedIconLabelSpacing', extendedIconLabelSpacing,
        defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'extendedPadding', extendedPadding,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>(
        'extendedTextStyle', extendedTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>(
        'mouseCursor', mouseCursor,
        defaultValue: null));
  }
}
