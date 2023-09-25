
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'input_decorator.dart';
import 'material_state.dart';
import 'text_button.dart';
import 'text_theme.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class DatePickerThemeData with Diagnosticable {
  const DatePickerThemeData({
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.headerBackgroundColor,
    this.headerForegroundColor,
    this.headerHeadlineStyle,
    this.headerHelpStyle,
    this.weekdayStyle,
    this.dayStyle,
    this.dayForegroundColor,
    this.dayBackgroundColor,
    this.dayOverlayColor,
    this.todayForegroundColor,
    this.todayBackgroundColor,
    this.todayBorder,
    this.yearStyle,
    this.yearForegroundColor,
    this.yearBackgroundColor,
    this.yearOverlayColor,
    this.rangePickerBackgroundColor,
    this.rangePickerElevation,
    this.rangePickerShadowColor,
    this.rangePickerSurfaceTintColor,
    this.rangePickerShape,
    this.rangePickerHeaderBackgroundColor,
    this.rangePickerHeaderForegroundColor,
    this.rangePickerHeaderHeadlineStyle,
    this.rangePickerHeaderHelpStyle,
    this.rangeSelectionBackgroundColor,
    this.rangeSelectionOverlayColor,
    this.dividerColor,
    this.inputDecorationTheme,
    this.cancelButtonStyle,
    this.confirmButtonStyle,
  });

  final Color? backgroundColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final ShapeBorder? shape;

  final Color? headerBackgroundColor;

  final Color? headerForegroundColor;

  final TextStyle? headerHeadlineStyle;

  final TextStyle? headerHelpStyle;

  final TextStyle? weekdayStyle;

  final TextStyle? dayStyle;

  final MaterialStateProperty<Color?>? dayForegroundColor;

  final MaterialStateProperty<Color?>? dayBackgroundColor;

  final MaterialStateProperty<Color?>? dayOverlayColor;

  final MaterialStateProperty<Color?>? todayForegroundColor;

  final MaterialStateProperty<Color?>? todayBackgroundColor;

  final BorderSide? todayBorder;

  final TextStyle? yearStyle;

  final MaterialStateProperty<Color?>? yearForegroundColor;

  final MaterialStateProperty<Color?>? yearBackgroundColor;

  final MaterialStateProperty<Color?>? yearOverlayColor;

  final Color? rangePickerBackgroundColor;

  final double? rangePickerElevation;

  final Color? rangePickerShadowColor;

  final Color? rangePickerSurfaceTintColor;

  final ShapeBorder? rangePickerShape;

  final Color? rangePickerHeaderBackgroundColor;

  final Color? rangePickerHeaderForegroundColor;

  final TextStyle? rangePickerHeaderHeadlineStyle;

  final TextStyle? rangePickerHeaderHelpStyle;

  final Color? rangeSelectionBackgroundColor;

  final MaterialStateProperty<Color?>? rangeSelectionOverlayColor;

  final Color? dividerColor;

  final InputDecorationTheme? inputDecorationTheme;

  final ButtonStyle? cancelButtonStyle;

  final ButtonStyle? confirmButtonStyle;

  DatePickerThemeData copyWith({
    Color? backgroundColor,
    double? elevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    ShapeBorder? shape,
    Color? headerBackgroundColor,
    Color? headerForegroundColor,
    TextStyle? headerHeadlineStyle,
    TextStyle? headerHelpStyle,
    TextStyle? weekdayStyle,
    TextStyle? dayStyle,
    MaterialStateProperty<Color?>? dayForegroundColor,
    MaterialStateProperty<Color?>? dayBackgroundColor,
    MaterialStateProperty<Color?>? dayOverlayColor,
    MaterialStateProperty<Color?>? todayForegroundColor,
    MaterialStateProperty<Color?>? todayBackgroundColor,
    BorderSide? todayBorder,
    TextStyle? yearStyle,
    MaterialStateProperty<Color?>? yearForegroundColor,
    MaterialStateProperty<Color?>? yearBackgroundColor,
    MaterialStateProperty<Color?>? yearOverlayColor,
    Color? rangePickerBackgroundColor,
    double? rangePickerElevation,
    Color? rangePickerShadowColor,
    Color? rangePickerSurfaceTintColor,
    ShapeBorder? rangePickerShape,
    Color? rangePickerHeaderBackgroundColor,
    Color? rangePickerHeaderForegroundColor,
    TextStyle? rangePickerHeaderHeadlineStyle,
    TextStyle? rangePickerHeaderHelpStyle,
    Color? rangeSelectionBackgroundColor,
    MaterialStateProperty<Color?>? rangeSelectionOverlayColor,
    Color? dividerColor,
    InputDecorationTheme? inputDecorationTheme,
    ButtonStyle? cancelButtonStyle,
    ButtonStyle? confirmButtonStyle,
  }) {
    return DatePickerThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      shape: shape ?? this.shape,
      headerBackgroundColor: headerBackgroundColor ?? this.headerBackgroundColor,
      headerForegroundColor: headerForegroundColor ?? this.headerForegroundColor,
      headerHeadlineStyle: headerHeadlineStyle ?? this.headerHeadlineStyle,
      headerHelpStyle: headerHelpStyle ?? this.headerHelpStyle,
      weekdayStyle: weekdayStyle ?? this.weekdayStyle,
      dayStyle: dayStyle ?? this.dayStyle,
      dayForegroundColor: dayForegroundColor ?? this.dayForegroundColor,
      dayBackgroundColor: dayBackgroundColor ?? this.dayBackgroundColor,
      dayOverlayColor: dayOverlayColor ?? this.dayOverlayColor,
      todayForegroundColor: todayForegroundColor ?? this.todayForegroundColor,
      todayBackgroundColor: todayBackgroundColor ?? this.todayBackgroundColor,
      todayBorder: todayBorder ?? this.todayBorder,
      yearStyle: yearStyle ?? this.yearStyle,
      yearForegroundColor: yearForegroundColor ?? this.yearForegroundColor,
      yearBackgroundColor: yearBackgroundColor ?? this.yearBackgroundColor,
      yearOverlayColor: yearOverlayColor ?? this.yearOverlayColor,
      rangePickerBackgroundColor: rangePickerBackgroundColor ?? this.rangePickerBackgroundColor,
      rangePickerElevation: rangePickerElevation ?? this.rangePickerElevation,
      rangePickerShadowColor: rangePickerShadowColor ?? this.rangePickerShadowColor,
      rangePickerSurfaceTintColor: rangePickerSurfaceTintColor ?? this.rangePickerSurfaceTintColor,
      rangePickerShape: rangePickerShape ?? this.rangePickerShape,
      rangePickerHeaderBackgroundColor: rangePickerHeaderBackgroundColor ?? this.rangePickerHeaderBackgroundColor,
      rangePickerHeaderForegroundColor: rangePickerHeaderForegroundColor ?? this.rangePickerHeaderForegroundColor,
      rangePickerHeaderHeadlineStyle: rangePickerHeaderHeadlineStyle ?? this.rangePickerHeaderHeadlineStyle,
      rangePickerHeaderHelpStyle: rangePickerHeaderHelpStyle ?? this.rangePickerHeaderHelpStyle,
      rangeSelectionBackgroundColor: rangeSelectionBackgroundColor ?? this.rangeSelectionBackgroundColor,
      rangeSelectionOverlayColor: rangeSelectionOverlayColor ?? this.rangeSelectionOverlayColor,
      dividerColor: dividerColor ?? this.dividerColor,
      inputDecorationTheme: inputDecorationTheme ?? this.inputDecorationTheme,
      cancelButtonStyle: cancelButtonStyle ?? this.cancelButtonStyle,
      confirmButtonStyle: confirmButtonStyle ?? this.confirmButtonStyle,
    );
  }

  static DatePickerThemeData lerp(DatePickerThemeData? a, DatePickerThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return DatePickerThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      headerBackgroundColor: Color.lerp(a?.headerBackgroundColor, b?.headerBackgroundColor, t),
      headerForegroundColor: Color.lerp(a?.headerForegroundColor, b?.headerForegroundColor, t),
      headerHeadlineStyle: TextStyle.lerp(a?.headerHeadlineStyle, b?.headerHeadlineStyle, t),
      headerHelpStyle: TextStyle.lerp(a?.headerHelpStyle, b?.headerHelpStyle, t),
      weekdayStyle: TextStyle.lerp(a?.weekdayStyle, b?.weekdayStyle, t),
      dayStyle: TextStyle.lerp(a?.dayStyle, b?.dayStyle, t),
      dayForegroundColor: MaterialStateProperty.lerp<Color?>(a?.dayForegroundColor, b?.dayForegroundColor, t, Color.lerp),
      dayBackgroundColor: MaterialStateProperty.lerp<Color?>(a?.dayBackgroundColor, b?.dayBackgroundColor, t, Color.lerp),
      dayOverlayColor: MaterialStateProperty.lerp<Color?>(a?.dayOverlayColor, b?.dayOverlayColor, t, Color.lerp),
      todayForegroundColor: MaterialStateProperty.lerp<Color?>(a?.todayForegroundColor, b?.todayForegroundColor, t, Color.lerp),
      todayBackgroundColor: MaterialStateProperty.lerp<Color?>(a?.todayBackgroundColor, b?.todayBackgroundColor, t, Color.lerp),
      todayBorder: _lerpBorderSide(a?.todayBorder, b?.todayBorder, t),
      yearStyle: TextStyle.lerp(a?.yearStyle, b?.yearStyle, t),
      yearForegroundColor: MaterialStateProperty.lerp<Color?>(a?.yearForegroundColor, b?.yearForegroundColor, t, Color.lerp),
      yearBackgroundColor: MaterialStateProperty.lerp<Color?>(a?.yearBackgroundColor, b?.yearBackgroundColor, t, Color.lerp),
      yearOverlayColor: MaterialStateProperty.lerp<Color?>(a?.yearOverlayColor, b?.yearOverlayColor, t, Color.lerp),
      rangePickerBackgroundColor: Color.lerp(a?.rangePickerBackgroundColor, b?.rangePickerBackgroundColor, t),
      rangePickerElevation: lerpDouble(a?.rangePickerElevation, b?.rangePickerElevation, t),
      rangePickerShadowColor: Color.lerp(a?.rangePickerShadowColor, b?.rangePickerShadowColor, t),
      rangePickerSurfaceTintColor: Color.lerp(a?.rangePickerSurfaceTintColor, b?.rangePickerSurfaceTintColor, t),
      rangePickerShape: ShapeBorder.lerp(a?.rangePickerShape, b?.rangePickerShape, t),
      rangePickerHeaderBackgroundColor: Color.lerp(a?.rangePickerHeaderBackgroundColor, b?.rangePickerHeaderBackgroundColor, t),
      rangePickerHeaderForegroundColor: Color.lerp(a?.rangePickerHeaderForegroundColor, b?.rangePickerHeaderForegroundColor, t),
      rangePickerHeaderHeadlineStyle: TextStyle.lerp(a?.rangePickerHeaderHeadlineStyle, b?.rangePickerHeaderHeadlineStyle, t),
      rangePickerHeaderHelpStyle: TextStyle.lerp(a?.rangePickerHeaderHelpStyle, b?.rangePickerHeaderHelpStyle, t),
      rangeSelectionBackgroundColor: Color.lerp(a?.rangeSelectionBackgroundColor, b?.rangeSelectionBackgroundColor, t),
      rangeSelectionOverlayColor: MaterialStateProperty.lerp<Color?>(a?.rangeSelectionOverlayColor, b?.rangeSelectionOverlayColor, t, Color.lerp),
      dividerColor: Color.lerp(a?.dividerColor, b?.dividerColor, t),
      inputDecorationTheme: t < 0.5 ? a?.inputDecorationTheme : b?.inputDecorationTheme,
      cancelButtonStyle: ButtonStyle.lerp(a?.cancelButtonStyle, b?.cancelButtonStyle, t),
      confirmButtonStyle: ButtonStyle.lerp(a?.confirmButtonStyle, b?.confirmButtonStyle, t),
    );
  }

  static BorderSide? _lerpBorderSide(BorderSide? a, BorderSide? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return BorderSide.lerp(BorderSide(width: 0, color: b!.color.withAlpha(0)), b, t);
    }
    return BorderSide.lerp(a, BorderSide(width: 0, color: a.color.withAlpha(0)), t);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    backgroundColor,
    elevation,
    shadowColor,
    surfaceTintColor,
    shape,
    headerBackgroundColor,
    headerForegroundColor,
    headerHeadlineStyle,
    headerHelpStyle,
    weekdayStyle,
    dayStyle,
    dayForegroundColor,
    dayBackgroundColor,
    dayOverlayColor,
    todayForegroundColor,
    todayBackgroundColor,
    todayBorder,
    yearStyle,
    yearForegroundColor,
    yearBackgroundColor,
    yearOverlayColor,
    rangePickerBackgroundColor,
    rangePickerElevation,
    rangePickerShadowColor,
    rangePickerSurfaceTintColor,
    rangePickerShape,
    rangePickerHeaderBackgroundColor,
    rangePickerHeaderForegroundColor,
    rangePickerHeaderHeadlineStyle,
    rangePickerHeaderHelpStyle,
    rangeSelectionBackgroundColor,
    rangeSelectionOverlayColor,
    dividerColor,
    inputDecorationTheme,
    cancelButtonStyle,
    confirmButtonStyle,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DatePickerThemeData
      && other.backgroundColor == backgroundColor
      && other.elevation == elevation
      && other.shadowColor == shadowColor
      && other.surfaceTintColor == surfaceTintColor
      && other.shape == shape
      && other.headerBackgroundColor == headerBackgroundColor
      && other.headerForegroundColor == headerForegroundColor
      && other.headerHeadlineStyle == headerHeadlineStyle
      && other.headerHelpStyle == headerHelpStyle
      && other.weekdayStyle == weekdayStyle
      && other.dayStyle == dayStyle
      && other.dayForegroundColor == dayForegroundColor
      && other.dayBackgroundColor == dayBackgroundColor
      && other.dayOverlayColor == dayOverlayColor
      && other.todayForegroundColor == todayForegroundColor
      && other.todayBackgroundColor == todayBackgroundColor
      && other.todayBorder == todayBorder
      && other.yearStyle == yearStyle
      && other.yearForegroundColor == yearForegroundColor
      && other.yearBackgroundColor == yearBackgroundColor
      && other.yearOverlayColor == yearOverlayColor
      && other.rangePickerBackgroundColor == rangePickerBackgroundColor
      && other.rangePickerElevation == rangePickerElevation
      && other.rangePickerShadowColor == rangePickerShadowColor
      && other.rangePickerSurfaceTintColor == rangePickerSurfaceTintColor
      && other.rangePickerShape == rangePickerShape
      && other.rangePickerHeaderBackgroundColor == rangePickerHeaderBackgroundColor
      && other.rangePickerHeaderForegroundColor == rangePickerHeaderForegroundColor
      && other.rangePickerHeaderHeadlineStyle == rangePickerHeaderHeadlineStyle
      && other.rangePickerHeaderHelpStyle == rangePickerHeaderHelpStyle
      && other.rangeSelectionBackgroundColor == rangeSelectionBackgroundColor
      && other.rangeSelectionOverlayColor == rangeSelectionOverlayColor
      && other.dividerColor == dividerColor
      && other.inputDecorationTheme == inputDecorationTheme
      && other.cancelButtonStyle == cancelButtonStyle
      && other.confirmButtonStyle == confirmButtonStyle;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(ColorProperty('headerBackgroundColor', headerBackgroundColor, defaultValue: null));
    properties.add(ColorProperty('headerForegroundColor', headerForegroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('headerHeadlineStyle', headerHeadlineStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('headerHelpStyle', headerHelpStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('weekDayStyle', weekdayStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('dayStyle', dayStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('dayForegroundColor', dayForegroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('dayBackgroundColor', dayBackgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('dayOverlayColor', dayOverlayColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('todayForegroundColor', todayForegroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('todayBackgroundColor', todayBackgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide?>('todayBorder', todayBorder, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('yearStyle', yearStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('yearForegroundColor', yearForegroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('yearBackgroundColor', yearBackgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('yearOverlayColor', yearOverlayColor, defaultValue: null));
    properties.add(ColorProperty('rangePickerBackgroundColor', rangePickerBackgroundColor, defaultValue: null));
    properties.add(DoubleProperty('rangePickerElevation', rangePickerElevation, defaultValue: null));
    properties.add(ColorProperty('rangePickerShadowColor', rangePickerShadowColor, defaultValue: null));
    properties.add(ColorProperty('rangePickerSurfaceTintColor', rangePickerSurfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('rangePickerShape', rangePickerShape, defaultValue: null));
    properties.add(ColorProperty('rangePickerHeaderBackgroundColor', rangePickerHeaderBackgroundColor, defaultValue: null));
    properties.add(ColorProperty('rangePickerHeaderForegroundColor', rangePickerHeaderForegroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('rangePickerHeaderHeadlineStyle', rangePickerHeaderHeadlineStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('rangePickerHeaderHelpStyle', rangePickerHeaderHelpStyle, defaultValue: null));
    properties.add(ColorProperty('rangeSelectionBackgroundColor', rangeSelectionBackgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('rangeSelectionOverlayColor', rangeSelectionOverlayColor, defaultValue: null));
    properties.add(ColorProperty('dividerColor', dividerColor, defaultValue: null));
    properties.add(DiagnosticsProperty<InputDecorationTheme>('inputDecorationTheme', inputDecorationTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<ButtonStyle>('cancelButtonStyle', cancelButtonStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<ButtonStyle>('confirmButtonStyle', confirmButtonStyle, defaultValue: null));
  }
}

class DatePickerTheme extends InheritedTheme {
  const DatePickerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final DatePickerThemeData data;

  static DatePickerThemeData of(BuildContext context) {
    return maybeOf(context) ?? Theme.of(context).datePickerTheme;
  }

  static DatePickerThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DatePickerTheme>()?.data;
  }

  static DatePickerThemeData defaults(BuildContext context) {
    return Theme.of(context).useMaterial3
      ? _DatePickerDefaultsM3(context)
      : _DatePickerDefaultsM2(context);
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DatePickerTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(DatePickerTheme oldWidget) => data != oldWidget.data;
}

// Hand coded defaults based on Material Design 2.
class _DatePickerDefaultsM2 extends DatePickerThemeData {
  _DatePickerDefaultsM2(this.context)
    : super(
        elevation: 24.0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4.0))),
        rangePickerElevation: 0.0,
        rangePickerShape: const RoundedRectangleBorder(),
      );

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;
  late final TextTheme _textTheme = _theme.textTheme;
  late final bool _isDark = _colors.brightness == Brightness.dark;

  @override
  Color? get headerBackgroundColor => _isDark ? _colors.surface : _colors.primary;

  @override
  ButtonStyle get cancelButtonStyle {
    return TextButton.styleFrom();
  }

  @override
  ButtonStyle get confirmButtonStyle {
    return TextButton.styleFrom();
  }

  @override
  Color? get headerForegroundColor => _isDark ? _colors.onSurface : _colors.onPrimary;

  @override
  TextStyle? get headerHeadlineStyle => _textTheme.headlineSmall;

  @override
  TextStyle? get headerHelpStyle => _textTheme.labelSmall;

  @override
  TextStyle? get weekdayStyle => _textTheme.bodySmall?.apply(
    color: _colors.onSurface.withOpacity(0.60),
  );

  @override
  TextStyle? get dayStyle => _textTheme.bodySmall;

  @override
  MaterialStateProperty<Color?>? get dayForegroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.onPrimary;
      } else if (states.contains(MaterialState.disabled)) {
        return _colors.onSurface.withOpacity(0.38);
      }
      return _colors.onSurface;
    });

  @override
  MaterialStateProperty<Color?>? get dayBackgroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.primary;
      }
      return null;
    });

  @override
  MaterialStateProperty<Color?>? get dayOverlayColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onPrimary.withOpacity(0.38);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onPrimary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onPrimary.withOpacity(0.12);
        }
      } else {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onSurfaceVariant.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
      }
      return null;
    });

  @override
  MaterialStateProperty<Color?>? get todayForegroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.onPrimary;
      } else if (states.contains(MaterialState.disabled)) {
        return _colors.onSurface.withOpacity(0.38);
      }
      return _colors.primary;
    });

  @override
  MaterialStateProperty<Color?>? get todayBackgroundColor => dayBackgroundColor;

  @override
  BorderSide? get todayBorder => BorderSide(color: _colors.primary);

  @override
  TextStyle? get yearStyle => _textTheme.bodyLarge;

  @override
  Color? get rangePickerBackgroundColor => _colors.surface;

  @override
  Color? get rangePickerShadowColor => Colors.transparent;

  @override
  Color? get rangePickerSurfaceTintColor => Colors.transparent;

  @override
  Color? get rangePickerHeaderBackgroundColor => _isDark ? _colors.surface : _colors.primary;

  @override
  Color? get rangePickerHeaderForegroundColor => _isDark ? _colors.onSurface : _colors.onPrimary;

  @override
  TextStyle? get rangePickerHeaderHeadlineStyle => _textTheme.headlineSmall;

  @override
  TextStyle? get rangePickerHeaderHelpStyle => _textTheme.labelSmall;

  @override
  Color? get rangeSelectionBackgroundColor => _colors.primary.withOpacity(0.12);

  @override
  MaterialStateProperty<Color?>? get rangeSelectionOverlayColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onPrimary.withOpacity(0.38);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onPrimary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onPrimary.withOpacity(0.12);
        }
      } else {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onSurfaceVariant.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
      }
      return null;
    });
}

// BEGIN GENERATED TOKEN PROPERTIES - DatePicker

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _DatePickerDefaultsM3 extends DatePickerThemeData {
  _DatePickerDefaultsM3(this.context)
    : super(
        elevation: 6.0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28.0))),
        rangePickerElevation: 0.0,
        rangePickerShape: const RoundedRectangleBorder(),
      );

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;
  late final TextTheme _textTheme = _theme.textTheme;

  @override
  Color? get backgroundColor => _colors.surface;

  @override
  ButtonStyle get cancelButtonStyle {
    return TextButton.styleFrom();
  }

  @override
  ButtonStyle get confirmButtonStyle {
    return TextButton.styleFrom();
  }

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  Color? get headerBackgroundColor => Colors.transparent;

  @override
  Color? get headerForegroundColor => _colors.onSurfaceVariant;

  @override
  TextStyle? get headerHeadlineStyle => _textTheme.headlineLarge;

  @override
  TextStyle? get headerHelpStyle => _textTheme.labelLarge;

  @override
  TextStyle? get weekdayStyle => _textTheme.bodyLarge?.apply(
    color: _colors.onSurface,
  );

  @override
  TextStyle? get dayStyle => _textTheme.bodyLarge;

  @override
  MaterialStateProperty<Color?>? get dayForegroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.onPrimary;
      } else if (states.contains(MaterialState.disabled)) {
        return _colors.onSurface.withOpacity(0.38);
      }
      return _colors.onSurface;
    });

  @override
  MaterialStateProperty<Color?>? get dayBackgroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.primary;
      }
      return null;
    });

  @override
  MaterialStateProperty<Color?>? get dayOverlayColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onPrimary.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onPrimary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onPrimary.withOpacity(0.12);
        }
      } else {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onSurfaceVariant.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
      }
      return null;
    });

  @override
  MaterialStateProperty<Color?>? get todayForegroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.onPrimary;
      } else if (states.contains(MaterialState.disabled)) {
        return _colors.primary.withOpacity(0.38);
      }
      return _colors.primary;
    });

  @override
  MaterialStateProperty<Color?>? get todayBackgroundColor => dayBackgroundColor;

  @override
  BorderSide? get todayBorder => BorderSide(color: _colors.primary);

  @override
  TextStyle? get yearStyle => _textTheme.bodyLarge;

  @override
  MaterialStateProperty<Color?>? get yearForegroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.onPrimary;
      } else if (states.contains(MaterialState.disabled)) {
        return _colors.onSurfaceVariant.withOpacity(0.38);
      }
      return _colors.onSurfaceVariant;
    });

  @override
  MaterialStateProperty<Color?>? get yearBackgroundColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return _colors.primary;
      }
      return null;
    });

  @override
  MaterialStateProperty<Color?>? get yearOverlayColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onPrimary.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onPrimary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onPrimary.withOpacity(0.12);
        }
      } else {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.onSurfaceVariant.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.onSurfaceVariant.withOpacity(0.12);
        }
      }
      return null;
    });

    @override
    Color? get rangePickerShadowColor => Colors.transparent;

    @override
    Color? get rangePickerSurfaceTintColor => Colors.transparent;

    @override
    Color? get rangeSelectionBackgroundColor => _colors.secondaryContainer;

  @override
  MaterialStateProperty<Color?>? get rangeSelectionOverlayColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) {
        return _colors.onPrimaryContainer.withOpacity(0.12);
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onPrimaryContainer.withOpacity(0.08);
      }
      if (states.contains(MaterialState.focused)) {
        return _colors.onPrimaryContainer.withOpacity(0.12);
      }
      return null;
    });

  @override
  Color? get rangePickerHeaderBackgroundColor => Colors.transparent;

  @override
  Color? get rangePickerHeaderForegroundColor => _colors.onSurfaceVariant;

  @override
  TextStyle? get rangePickerHeaderHeadlineStyle => _textTheme.titleLarge;

  @override
  TextStyle? get rangePickerHeaderHelpStyle => _textTheme.titleSmall;
}

// END GENERATED TOKEN PROPERTIES - DatePicker