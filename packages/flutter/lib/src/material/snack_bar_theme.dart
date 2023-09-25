import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';
import 'theme.dart';

enum SnackBarBehavior {
  fixed,

  floating,
}

@immutable
class SnackBarThemeData with Diagnosticable {

  const SnackBarThemeData({
    this.backgroundColor,
    this.actionTextColor,
    this.disabledActionTextColor,
    this.contentTextStyle,
    this.elevation,
    this.shape,
    this.behavior,
    this.width,
    this.insetPadding,
    this.showCloseIcon,
    this.closeIconColor,
    this.actionOverflowThreshold,
    this.actionBackgroundColor,
    this.disabledActionBackgroundColor
  })  : assert(elevation == null || elevation >= 0.0),
        assert(width == null || identical(behavior, SnackBarBehavior.floating),
          'Width can only be set if behaviour is SnackBarBehavior.floating'),
        assert(actionOverflowThreshold == null || (actionOverflowThreshold >= 0 && actionOverflowThreshold <= 1),
          'Action overflow threshold must be between 0 and 1 inclusive'),
        assert(actionBackgroundColor is! MaterialStateColor || disabledActionBackgroundColor == null,
          'disabledBackgroundColor must not be provided when background color is '
          'a MaterialStateColor');

  final Color? backgroundColor;

  final Color? actionTextColor;

  final Color? disabledActionTextColor;

  final TextStyle? contentTextStyle;

  final double? elevation;

  final ShapeBorder? shape;

  final SnackBarBehavior? behavior;

  final double? width;

  final EdgeInsets? insetPadding;

  final bool? showCloseIcon;

  final Color? closeIconColor;

  final double? actionOverflowThreshold;
  final Color? actionBackgroundColor;

  final Color? disabledActionBackgroundColor;

  SnackBarThemeData copyWith({
    Color? backgroundColor,
    Color? actionTextColor,
    Color? disabledActionTextColor,
    TextStyle? contentTextStyle,
    double? elevation,
    ShapeBorder? shape,
    SnackBarBehavior? behavior,
    double? width,
    EdgeInsets? insetPadding,
    bool? showCloseIcon,
    Color? closeIconColor,
    double? actionOverflowThreshold,
    Color? actionBackgroundColor,
    Color? disabledActionBackgroundColor,
  }) {
    return SnackBarThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      actionTextColor: actionTextColor ?? this.actionTextColor,
      disabledActionTextColor: disabledActionTextColor ?? this.disabledActionTextColor,
      contentTextStyle: contentTextStyle ?? this.contentTextStyle,
      elevation: elevation ?? this.elevation,
      shape: shape ?? this.shape,
      behavior: behavior ?? this.behavior,
      width: width ?? this.width,
      insetPadding: insetPadding ?? this.insetPadding,
      showCloseIcon: showCloseIcon ?? this.showCloseIcon,
      closeIconColor: closeIconColor ?? this.closeIconColor,
      actionOverflowThreshold: actionOverflowThreshold ?? this.actionOverflowThreshold,
      actionBackgroundColor: actionBackgroundColor ?? this.actionBackgroundColor,
      disabledActionBackgroundColor: disabledActionBackgroundColor ?? this.disabledActionBackgroundColor,
    );
  }

  static SnackBarThemeData lerp(SnackBarThemeData? a, SnackBarThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return SnackBarThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      actionTextColor: Color.lerp(a?.actionTextColor, b?.actionTextColor, t),
      disabledActionTextColor: Color.lerp(a?.disabledActionTextColor, b?.disabledActionTextColor, t),
      contentTextStyle: TextStyle.lerp(a?.contentTextStyle, b?.contentTextStyle, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      behavior: t < 0.5 ? a?.behavior : b?.behavior,
      width: lerpDouble(a?.width, b?.width, t),
      insetPadding: EdgeInsets.lerp(a?.insetPadding, b?.insetPadding, t),
      closeIconColor: Color.lerp(a?.closeIconColor, b?.closeIconColor, t),
      actionOverflowThreshold: lerpDouble(a?.actionOverflowThreshold, b?.actionOverflowThreshold, t),
      actionBackgroundColor: Color.lerp(a?.actionBackgroundColor, b?.actionBackgroundColor, t),
      disabledActionBackgroundColor: Color.lerp(a?.disabledActionBackgroundColor, b?.disabledActionBackgroundColor, t),
    );
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        actionTextColor,
        disabledActionTextColor,
        contentTextStyle,
        elevation,
        shape,
        behavior,
        width,
        insetPadding,
        showCloseIcon,
        closeIconColor,
        actionOverflowThreshold,
        actionBackgroundColor,
        disabledActionBackgroundColor
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SnackBarThemeData
        && other.backgroundColor == backgroundColor
        && other.actionTextColor == actionTextColor
        && other.disabledActionTextColor == disabledActionTextColor
        && other.contentTextStyle == contentTextStyle
        && other.elevation == elevation
        && other.shape == shape
        && other.behavior == behavior
        && other.width == width
        && other.insetPadding == insetPadding
        && other.showCloseIcon == showCloseIcon
        && other.closeIconColor == closeIconColor
        && other.actionOverflowThreshold == actionOverflowThreshold
        && other.actionBackgroundColor == actionBackgroundColor
        && other.disabledActionBackgroundColor == disabledActionBackgroundColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('actionTextColor', actionTextColor, defaultValue: null));
    properties.add(ColorProperty('disabledActionTextColor', disabledActionTextColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('contentTextStyle', contentTextStyle, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<SnackBarBehavior>('behavior', behavior, defaultValue: null));
    properties.add(DoubleProperty('width', width, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsets>('insetPadding', insetPadding, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('showCloseIcon', showCloseIcon, defaultValue: null));
    properties.add(ColorProperty('closeIconColor', closeIconColor, defaultValue: null));
    properties.add(DoubleProperty('actionOverflowThreshold', actionOverflowThreshold, defaultValue: null));
    properties.add(ColorProperty('actionBackgroundColor', actionBackgroundColor, defaultValue: null));
    properties.add(ColorProperty('disabledActionBackgroundColor', disabledActionBackgroundColor, defaultValue: null));
  }
}