import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'input_decorator.dart';
import 'menu_style.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class DropdownMenuThemeData with Diagnosticable {
  const DropdownMenuThemeData({
    this.textStyle,
    this.inputDecorationTheme,
    this.menuStyle,
  });

  final TextStyle? textStyle;

  final InputDecorationTheme? inputDecorationTheme;

  final MenuStyle? menuStyle;

  DropdownMenuThemeData copyWith({
    TextStyle? textStyle,
    InputDecorationTheme? inputDecorationTheme,
    MenuStyle? menuStyle,
  }) {
    return DropdownMenuThemeData(
      textStyle: textStyle ?? this.textStyle,
      inputDecorationTheme: inputDecorationTheme ?? this.inputDecorationTheme,
      menuStyle: menuStyle ?? this.menuStyle,
    );
  }

  static DropdownMenuThemeData lerp(DropdownMenuThemeData? a, DropdownMenuThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return DropdownMenuThemeData(
      textStyle: TextStyle.lerp(a?.textStyle, b?.textStyle, t),
      inputDecorationTheme: t < 0.5 ? a?.inputDecorationTheme : b?.inputDecorationTheme,
      menuStyle: MenuStyle.lerp(a?.menuStyle, b?.menuStyle, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    textStyle,
    inputDecorationTheme,
    menuStyle,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DropdownMenuThemeData
        && other.textStyle == textStyle
        && other.inputDecorationTheme == inputDecorationTheme
        && other.menuStyle == menuStyle;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextStyle>('textStyle', textStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<InputDecorationTheme>('inputDecorationTheme', inputDecorationTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<MenuStyle>('menuStyle', menuStyle, defaultValue: null));
  }
}

class DropdownMenuTheme extends InheritedTheme {
  const DropdownMenuTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final DropdownMenuThemeData data;

  static DropdownMenuThemeData of(BuildContext context) {
    return maybeOf(context) ?? Theme.of(context).dropdownMenuTheme;
  }

  static DropdownMenuThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DropdownMenuTheme>()?.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DropdownMenuTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(DropdownMenuTheme oldWidget) => data != oldWidget.data;
}