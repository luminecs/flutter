
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_theme.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ButtonBarThemeData with Diagnosticable {
  const ButtonBarThemeData({
    this.alignment,
    this.mainAxisSize,
    this.buttonTextTheme,
    this.buttonMinWidth,
    this.buttonHeight,
    this.buttonPadding,
    this.buttonAlignedDropdown,
    this.layoutBehavior,
    this.overflowDirection,
  }) : assert(buttonMinWidth == null || buttonMinWidth >= 0.0),
       assert(buttonHeight == null || buttonHeight >= 0.0);

  final MainAxisAlignment? alignment;

  final MainAxisSize? mainAxisSize;

  final ButtonTextTheme? buttonTextTheme;

  final double? buttonMinWidth;

  final double? buttonHeight;

  final EdgeInsetsGeometry? buttonPadding;

  final bool? buttonAlignedDropdown;

  final ButtonBarLayoutBehavior? layoutBehavior;

  final VerticalDirection? overflowDirection;

  ButtonBarThemeData copyWith({
    MainAxisAlignment? alignment,
    MainAxisSize? mainAxisSize,
    ButtonTextTheme? buttonTextTheme,
    double? buttonMinWidth,
    double? buttonHeight,
    EdgeInsetsGeometry? buttonPadding,
    bool? buttonAlignedDropdown,
    ButtonBarLayoutBehavior? layoutBehavior,
    VerticalDirection? overflowDirection,
  }) {
    return ButtonBarThemeData(
      alignment: alignment ?? this.alignment,
      mainAxisSize: mainAxisSize ?? this.mainAxisSize,
      buttonTextTheme: buttonTextTheme ?? this.buttonTextTheme,
      buttonMinWidth: buttonMinWidth ?? this.buttonMinWidth,
      buttonHeight: buttonHeight ?? this.buttonHeight,
      buttonPadding: buttonPadding ?? this.buttonPadding,
      buttonAlignedDropdown: buttonAlignedDropdown ?? this.buttonAlignedDropdown,
      layoutBehavior: layoutBehavior ?? this.layoutBehavior,
      overflowDirection: overflowDirection ?? this.overflowDirection,
    );
  }

  static ButtonBarThemeData? lerp(ButtonBarThemeData? a, ButtonBarThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ButtonBarThemeData(
      alignment: t < 0.5 ? a?.alignment : b?.alignment,
      mainAxisSize: t < 0.5 ? a?.mainAxisSize : b?.mainAxisSize,
      buttonTextTheme: t < 0.5 ? a?.buttonTextTheme : b?.buttonTextTheme,
      buttonMinWidth: lerpDouble(a?.buttonMinWidth, b?.buttonMinWidth, t),
      buttonHeight: lerpDouble(a?.buttonHeight, b?.buttonHeight, t),
      buttonPadding: EdgeInsetsGeometry.lerp(a?.buttonPadding, b?.buttonPadding, t),
      buttonAlignedDropdown: t < 0.5 ? a?.buttonAlignedDropdown : b?.buttonAlignedDropdown,
      layoutBehavior: t < 0.5 ? a?.layoutBehavior : b?.layoutBehavior,
      overflowDirection: t < 0.5 ? a?.overflowDirection : b?.overflowDirection,
    );
  }

  @override
  int get hashCode => Object.hash(
    alignment,
    mainAxisSize,
    buttonTextTheme,
    buttonMinWidth,
    buttonHeight,
    buttonPadding,
    buttonAlignedDropdown,
    layoutBehavior,
    overflowDirection,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ButtonBarThemeData
        && other.alignment == alignment
        && other.mainAxisSize == mainAxisSize
        && other.buttonTextTheme == buttonTextTheme
        && other.buttonMinWidth == buttonMinWidth
        && other.buttonHeight == buttonHeight
        && other.buttonPadding == buttonPadding
        && other.buttonAlignedDropdown == buttonAlignedDropdown
        && other.layoutBehavior == layoutBehavior
        && other.overflowDirection == overflowDirection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MainAxisAlignment>('alignment', alignment, defaultValue: null));
    properties.add(DiagnosticsProperty<MainAxisSize>('mainAxisSize', mainAxisSize, defaultValue: null));
    properties.add(DiagnosticsProperty<ButtonTextTheme>('textTheme', buttonTextTheme, defaultValue: null));
    properties.add(DoubleProperty('minWidth', buttonMinWidth, defaultValue: null));
    properties.add(DoubleProperty('height', buttonHeight, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', buttonPadding, defaultValue: null));
    properties.add(FlagProperty(
      'buttonAlignedDropdown',
      value: buttonAlignedDropdown,
      ifTrue: 'dropdown width matches button',
    ));
    properties.add(DiagnosticsProperty<ButtonBarLayoutBehavior>('layoutBehavior', layoutBehavior, defaultValue: null));
    properties.add(DiagnosticsProperty<VerticalDirection>('overflowDirection', overflowDirection, defaultValue: null));
  }
}

class ButtonBarTheme extends InheritedWidget {
  const ButtonBarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ButtonBarThemeData data;

  static ButtonBarThemeData of(BuildContext context) {
    final ButtonBarTheme? buttonBarTheme = context.dependOnInheritedWidgetOfExactType<ButtonBarTheme>();
    return buttonBarTheme?.data ?? Theme.of(context).buttonBarTheme;
  }

  @override
  bool updateShouldNotify(ButtonBarTheme oldWidget) => data != oldWidget.data;
}