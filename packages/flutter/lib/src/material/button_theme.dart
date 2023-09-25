import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'color_scheme.dart';
import 'colors.dart';
import 'constants.dart';
import 'material_button.dart';
import 'material_state.dart';
import 'theme.dart';
import 'theme_data.dart' show MaterialTapTargetSize;

// Examples can assume:
// late BuildContext context;

enum ButtonTextTheme {
  normal,

  accent,

  primary,
}

enum ButtonBarLayoutBehavior {
  constrained,

  padded,
}

class ButtonTheme extends InheritedTheme {
  ButtonTheme({
    super.key,
    ButtonTextTheme textTheme = ButtonTextTheme.normal,
    ButtonBarLayoutBehavior layoutBehavior = ButtonBarLayoutBehavior.padded,
    double minWidth = 88.0,
    double height = 36.0,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
    bool alignedDropdown = false,
    Color? buttonColor,
    Color? disabledColor,
    Color? focusColor,
    Color? hoverColor,
    Color? highlightColor,
    Color? splashColor,
    ColorScheme? colorScheme,
    MaterialTapTargetSize? materialTapTargetSize,
    required super.child,
  }) : assert(minWidth >= 0.0),
       assert(height >= 0.0),
       data = ButtonThemeData(
         textTheme: textTheme,
         minWidth: minWidth,
         height: height,
         padding: padding,
         shape: shape,
         alignedDropdown: alignedDropdown,
         layoutBehavior: layoutBehavior,
         buttonColor: buttonColor,
         disabledColor: disabledColor,
         focusColor: focusColor,
         hoverColor: hoverColor,
         highlightColor: highlightColor,
         splashColor: splashColor,
         colorScheme: colorScheme,
         materialTapTargetSize: materialTapTargetSize,
       );

  const ButtonTheme.fromButtonThemeData({
    super.key,
    required this.data,
    required super.child,
  });

  final ButtonThemeData data;

  static ButtonThemeData of(BuildContext context) {
    final ButtonTheme? inheritedButtonTheme = context.dependOnInheritedWidgetOfExactType<ButtonTheme>();
    ButtonThemeData? buttonTheme = inheritedButtonTheme?.data;
    if (buttonTheme?.colorScheme == null) { // if buttonTheme or buttonTheme.colorScheme is null
      final ThemeData theme = Theme.of(context);
      buttonTheme ??= theme.buttonTheme;
      if (buttonTheme.colorScheme == null) {
        buttonTheme = buttonTheme.copyWith(
          colorScheme: theme.buttonTheme.colorScheme ?? theme.colorScheme,
        );
        assert(buttonTheme.colorScheme != null);
      }
    }
    return buttonTheme!;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ButtonTheme.fromButtonThemeData(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ButtonTheme oldWidget) => data != oldWidget.data;
}

@immutable
class ButtonThemeData with Diagnosticable {
  const ButtonThemeData({
    this.textTheme = ButtonTextTheme.normal,
    this.minWidth = 88.0,
    this.height = 36.0,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
    this.layoutBehavior = ButtonBarLayoutBehavior.padded,
    this.alignedDropdown = false,
    Color? buttonColor,
    Color? disabledColor,
    Color? focusColor,
    Color? hoverColor,
    Color? highlightColor,
    Color? splashColor,
    this.colorScheme,
    MaterialTapTargetSize? materialTapTargetSize,
  }) : assert(minWidth >= 0.0),
       assert(height >= 0.0),
       _buttonColor = buttonColor,
       _disabledColor = disabledColor,
       _focusColor = focusColor,
       _hoverColor = hoverColor,
       _highlightColor = highlightColor,
       _splashColor = splashColor,
       _padding = padding,
       _shape = shape,
       _materialTapTargetSize = materialTapTargetSize;

  final double minWidth;

  final double height;

  final ButtonTextTheme textTheme;

  final ButtonBarLayoutBehavior layoutBehavior;

  BoxConstraints get constraints {
    return BoxConstraints(
      minWidth: minWidth,
      minHeight: height,
    );
  }

  EdgeInsetsGeometry get padding {
    if (_padding != null) {
      return _padding;
    }
    switch (textTheme) {
      case ButtonTextTheme.normal:
      case ButtonTextTheme.accent:
        return const EdgeInsets.symmetric(horizontal: 16.0);
      case ButtonTextTheme.primary:
        return const EdgeInsets.symmetric(horizontal: 24.0);
    }
  }
  final EdgeInsetsGeometry? _padding;

  ShapeBorder get shape {
    if (_shape != null) {
      return _shape;
    }
    switch (textTheme) {
      case ButtonTextTheme.normal:
      case ButtonTextTheme.accent:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2.0)),
        );
      case ButtonTextTheme.primary:
        return const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)),
        );
    }
  }
  final ShapeBorder? _shape;

  final bool alignedDropdown;

  final Color? _buttonColor;

  final Color? _disabledColor;

  final Color? _focusColor;

  final Color? _hoverColor;

  final Color? _highlightColor;

  final Color? _splashColor;

  final ColorScheme? colorScheme;

  // The minimum size of a button's tap target.
  //
  // This property is null by default.
  final MaterialTapTargetSize? _materialTapTargetSize;

  Brightness getBrightness(MaterialButton button) {
    return button.colorBrightness ?? colorScheme!.brightness;
  }

  ButtonTextTheme getTextTheme(MaterialButton button) => button.textTheme ?? textTheme;

  Color getDisabledTextColor(MaterialButton button) {
    return button.textColor ?? button.disabledTextColor ?? colorScheme!.onSurface.withOpacity(0.38);
  }

  Color getDisabledFillColor(MaterialButton button) {
    return button.disabledColor ?? _disabledColor ?? colorScheme!.onSurface.withOpacity(0.38);
  }

  Color? getFillColor(MaterialButton button) {
    final Color? fillColor = button.enabled ? button.color : button.disabledColor;
    if (fillColor != null) {
      return fillColor;
    }

    if (button.runtimeType == MaterialButton) {
      return null;
    }

    if (button.enabled && _buttonColor != null) {
      return _buttonColor;
    }

    switch (getTextTheme(button)) {
      case ButtonTextTheme.normal:
      case ButtonTextTheme.accent:
        return button.enabled ? colorScheme!.primary : getDisabledFillColor(button);
      case ButtonTextTheme.primary:
        return button.enabled
          ? _buttonColor ?? colorScheme!.primary
          : colorScheme!.onSurface.withOpacity(0.12);
    }
  }

  Color getTextColor(MaterialButton button) {
    if (!button.enabled) {
      return getDisabledTextColor(button);
    }

    if (button.textColor != null) {
      return button.textColor!;
    }

    switch (getTextTheme(button)) {
      case ButtonTextTheme.normal:
        return getBrightness(button) == Brightness.dark ? Colors.white : Colors.black87;

      case ButtonTextTheme.accent:
        return colorScheme!.secondary;

      case ButtonTextTheme.primary:
        final Color? fillColor = getFillColor(button);
        final bool fillIsDark = fillColor != null
          ? ThemeData.estimateBrightnessForColor(fillColor) == Brightness.dark
          : getBrightness(button) == Brightness.dark;
        return fillIsDark ? Colors.white : Colors.black;
    }
  }

  Color getSplashColor(MaterialButton button) {
    if (button.splashColor != null) {
      return button.splashColor!;
    }

    if (_splashColor != null) {
      switch (getTextTheme(button)) {
        case ButtonTextTheme.normal:
        case ButtonTextTheme.accent:
          return _splashColor;
        case ButtonTextTheme.primary:
          break;
      }
    }

    return getTextColor(button).withOpacity(0.12);
  }

  Color getFocusColor(MaterialButton button) {
    return button.focusColor ?? _focusColor ?? getTextColor(button).withOpacity(0.12);
  }

  Color getHoverColor(MaterialButton button) {
    return button.hoverColor ?? _hoverColor ?? getTextColor(button).withOpacity(0.04);
  }

  Color getHighlightColor(MaterialButton button) {
    if (button.highlightColor != null) {
      return button.highlightColor!;
    }

    switch (getTextTheme(button)) {
      case ButtonTextTheme.normal:
      case ButtonTextTheme.accent:
        return _highlightColor ?? getTextColor(button).withOpacity(0.16);
      case ButtonTextTheme.primary:
        return Colors.transparent;
    }
  }

  double getElevation(MaterialButton button) => button.elevation ?? 2.0;

  double getFocusElevation(MaterialButton button) => button.focusElevation ?? 4.0;

  double getHoverElevation(MaterialButton button) => button.hoverElevation ?? 4.0;

  double getHighlightElevation(MaterialButton button) => button.highlightElevation ?? 8.0;

  double getDisabledElevation(MaterialButton button) => button.disabledElevation ?? 0.0;

  EdgeInsetsGeometry getPadding(MaterialButton button) {
    if (button.padding != null) {
      return button.padding!;
    }

    if (_padding != null) {
      return _padding;
    }

    switch (getTextTheme(button)) {
      case ButtonTextTheme.normal:
      case ButtonTextTheme.accent:
        return const EdgeInsets.symmetric(horizontal: 16.0);
      case ButtonTextTheme.primary:
        return const EdgeInsets.symmetric(horizontal: 24.0);
    }
  }

  ShapeBorder getShape(MaterialButton button) => button.shape ?? shape;

  Duration getAnimationDuration(MaterialButton button) {
    return button.animationDuration ?? kThemeChangeDuration;
  }

  BoxConstraints getConstraints(MaterialButton button) => constraints;

  MaterialTapTargetSize getMaterialTapTargetSize(MaterialButton button) {
    return button.materialTapTargetSize ?? _materialTapTargetSize ?? MaterialTapTargetSize.padded;
  }

  ButtonThemeData copyWith({
    ButtonTextTheme? textTheme,
    ButtonBarLayoutBehavior? layoutBehavior,
    double? minWidth,
    double? height,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
    bool? alignedDropdown,
    Color? buttonColor,
    Color? disabledColor,
    Color? focusColor,
    Color? hoverColor,
    Color? highlightColor,
    Color? splashColor,
    ColorScheme? colorScheme,
    MaterialTapTargetSize? materialTapTargetSize,
  }) {
    return ButtonThemeData(
      textTheme: textTheme ?? this.textTheme,
      layoutBehavior: layoutBehavior ?? this.layoutBehavior,
      minWidth: minWidth ?? this.minWidth,
      height: height ?? this.height,
      padding: padding ?? this.padding,
      shape: shape ?? this.shape,
      alignedDropdown: alignedDropdown ?? this.alignedDropdown,
      buttonColor: buttonColor ?? _buttonColor,
      disabledColor: disabledColor ?? _disabledColor,
      focusColor: focusColor ?? _focusColor,
      hoverColor: hoverColor ?? _hoverColor,
      highlightColor: highlightColor ?? _highlightColor,
      splashColor: splashColor ?? _splashColor,
      colorScheme: colorScheme ?? this.colorScheme,
      materialTapTargetSize: materialTapTargetSize ?? _materialTapTargetSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ButtonThemeData
        && other.textTheme == textTheme
        && other.minWidth == minWidth
        && other.height == height
        && other.padding == padding
        && other.shape == shape
        && other.alignedDropdown == alignedDropdown
        && other._buttonColor == _buttonColor
        && other._disabledColor == _disabledColor
        && other._focusColor == _focusColor
        && other._hoverColor == _hoverColor
        && other._highlightColor == _highlightColor
        && other._splashColor == _splashColor
        && other.colorScheme == colorScheme
        && other._materialTapTargetSize == _materialTapTargetSize;
  }

  @override
  int get hashCode => Object.hash(
    textTheme,
    minWidth,
    height,
    padding,
    shape,
    alignedDropdown,
    _buttonColor,
    _disabledColor,
    _focusColor,
    _hoverColor,
    _highlightColor,
    _splashColor,
    colorScheme,
    _materialTapTargetSize,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const ButtonThemeData defaultTheme = ButtonThemeData();
    properties.add(EnumProperty<ButtonTextTheme>('textTheme', textTheme, defaultValue: defaultTheme.textTheme));
    properties.add(DoubleProperty('minWidth', minWidth, defaultValue: defaultTheme.minWidth));
    properties.add(DoubleProperty('height', height, defaultValue: defaultTheme.height));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: defaultTheme.padding));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: defaultTheme.shape));
    properties.add(FlagProperty('alignedDropdown',
      value: alignedDropdown,
      defaultValue: defaultTheme.alignedDropdown,
      ifTrue: 'dropdown width matches button',
    ));
    properties.add(ColorProperty('buttonColor', _buttonColor, defaultValue: null));
    properties.add(ColorProperty('disabledColor', _disabledColor, defaultValue: null));
    properties.add(ColorProperty('focusColor', _focusColor, defaultValue: null));
    properties.add(ColorProperty('hoverColor', _hoverColor, defaultValue: null));
    properties.add(ColorProperty('highlightColor', _highlightColor, defaultValue: null));
    properties.add(ColorProperty('splashColor', _splashColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ColorScheme>('colorScheme', colorScheme, defaultValue: defaultTheme.colorScheme));
    properties.add(DiagnosticsProperty<MaterialTapTargetSize>('materialTapTargetSize', _materialTapTargetSize, defaultValue: null));
  }
}