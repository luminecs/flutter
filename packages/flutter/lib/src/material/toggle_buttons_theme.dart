import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ToggleButtonsThemeData with Diagnosticable {
  const ToggleButtonsThemeData({
    this.textStyle,
    this.constraints,
    this.color,
    this.selectedColor,
    this.disabledColor,
    this.fillColor,
    this.focusColor,
    this.highlightColor,
    this.hoverColor,
    this.splashColor,
    this.borderColor,
    this.selectedBorderColor,
    this.disabledBorderColor,
    this.borderRadius,
    this.borderWidth,
  });

  final TextStyle? textStyle;

  final BoxConstraints? constraints;

  final Color? color;

  final Color? selectedColor;

  final Color? disabledColor;

  final Color? fillColor;

  final Color? focusColor;

  final Color? highlightColor;

  final Color? splashColor;

  final Color? hoverColor;

  final Color? borderColor;

  final Color? selectedBorderColor;

  final Color? disabledBorderColor;

  final double? borderWidth;

  final BorderRadius? borderRadius;

  ToggleButtonsThemeData copyWith({
    TextStyle? textStyle,
    BoxConstraints? constraints,
    Color? color,
    Color? selectedColor,
    Color? disabledColor,
    Color? fillColor,
    Color? focusColor,
    Color? highlightColor,
    Color? hoverColor,
    Color? splashColor,
    Color? borderColor,
    Color? selectedBorderColor,
    Color? disabledBorderColor,
    BorderRadius? borderRadius,
    double? borderWidth,
  }) {
    return ToggleButtonsThemeData(
      textStyle: textStyle ?? this.textStyle,
      constraints: constraints ?? this.constraints,
      color: color ?? this.color,
      selectedColor: selectedColor ?? this.selectedColor,
      disabledColor: disabledColor ?? this.disabledColor,
      fillColor: fillColor ?? this.fillColor,
      focusColor: focusColor ?? this.focusColor,
      highlightColor: highlightColor ?? this.highlightColor,
      hoverColor: hoverColor ?? this.hoverColor,
      splashColor: splashColor ?? this.splashColor,
      borderColor: borderColor ?? this.borderColor,
      selectedBorderColor: selectedBorderColor ?? this.selectedBorderColor,
      disabledBorderColor: disabledBorderColor ?? this.disabledBorderColor,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  static ToggleButtonsThemeData? lerp(ToggleButtonsThemeData? a, ToggleButtonsThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ToggleButtonsThemeData(
      textStyle: TextStyle.lerp(a?.textStyle, b?.textStyle, t),
      constraints: BoxConstraints.lerp(a?.constraints, b?.constraints, t),
      color: Color.lerp(a?.color, b?.color, t),
      selectedColor: Color.lerp(a?.selectedColor, b?.selectedColor, t),
      disabledColor: Color.lerp(a?.disabledColor, b?.disabledColor, t),
      fillColor: Color.lerp(a?.fillColor, b?.fillColor, t),
      focusColor: Color.lerp(a?.focusColor, b?.focusColor, t),
      highlightColor: Color.lerp(a?.highlightColor, b?.highlightColor, t),
      hoverColor: Color.lerp(a?.hoverColor, b?.hoverColor, t),
      splashColor: Color.lerp(a?.splashColor, b?.splashColor, t),
      borderColor: Color.lerp(a?.borderColor, b?.borderColor, t),
      selectedBorderColor: Color.lerp(a?.selectedBorderColor, b?.selectedBorderColor, t),
      disabledBorderColor: Color.lerp(a?.disabledBorderColor, b?.disabledBorderColor, t),
      borderRadius: BorderRadius.lerp(a?.borderRadius, b?.borderRadius, t),
      borderWidth: lerpDouble(a?.borderWidth, b?.borderWidth, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    textStyle,
    constraints,
    color,
    selectedColor,
    disabledColor,
    fillColor,
    focusColor,
    highlightColor,
    hoverColor,
    splashColor,
    borderColor,
    selectedBorderColor,
    disabledBorderColor,
    borderRadius,
    borderWidth,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ToggleButtonsThemeData
        && other.textStyle == textStyle
        && other.constraints == constraints
        && other.color == color
        && other.selectedColor == selectedColor
        && other.disabledColor == disabledColor
        && other.fillColor == fillColor
        && other.focusColor == focusColor
        && other.highlightColor == highlightColor
        && other.hoverColor == hoverColor
        && other.splashColor == splashColor
        && other.borderColor == borderColor
        && other.selectedBorderColor == selectedBorderColor
        && other.disabledBorderColor == disabledBorderColor
        && other.borderRadius == borderRadius
        && other.borderWidth == borderWidth;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    textStyle?.debugFillProperties(properties, prefix: 'textStyle.');
    properties.add(DiagnosticsProperty<BoxConstraints>('constraints', constraints, defaultValue: null));
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(ColorProperty('selectedColor', selectedColor, defaultValue: null));
    properties.add(ColorProperty('disabledColor', disabledColor, defaultValue: null));
    properties.add(ColorProperty('fillColor', fillColor, defaultValue: null));
    properties.add(ColorProperty('focusColor', focusColor, defaultValue: null));
    properties.add(ColorProperty('highlightColor', highlightColor, defaultValue: null));
    properties.add(ColorProperty('hoverColor', hoverColor, defaultValue: null));
    properties.add(ColorProperty('splashColor', splashColor, defaultValue: null));
    properties.add(ColorProperty('borderColor', borderColor, defaultValue: null));
    properties.add(ColorProperty('selectedBorderColor', selectedBorderColor, defaultValue: null));
    properties.add(ColorProperty('disabledBorderColor', disabledBorderColor, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderRadius>('borderRadius', borderRadius, defaultValue: null));
    properties.add(DoubleProperty('borderWidth', borderWidth, defaultValue: null));
  }
}

class ToggleButtonsTheme extends InheritedTheme {
  const ToggleButtonsTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ToggleButtonsThemeData data;

  static ToggleButtonsThemeData of(BuildContext context) {
    final ToggleButtonsTheme? toggleButtonsTheme = context.dependOnInheritedWidgetOfExactType<ToggleButtonsTheme>();
    return toggleButtonsTheme?.data ?? Theme.of(context).toggleButtonsTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ToggleButtonsTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ToggleButtonsTheme oldWidget) => data != oldWidget.data;
}