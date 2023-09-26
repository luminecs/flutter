import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'material_state.dart';
import 'menu_anchor.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class MenuButtonThemeData with Diagnosticable {
  const MenuButtonThemeData({this.style});

  final ButtonStyle? style;

  static MenuButtonThemeData? lerp(
      MenuButtonThemeData? a, MenuButtonThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return MenuButtonThemeData(style: ButtonStyle.lerp(a?.style, b?.style, t));
  }

  @override
  int get hashCode => style.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MenuButtonThemeData && other.style == style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
  }
}

class MenuButtonTheme extends InheritedTheme {
  const MenuButtonTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final MenuButtonThemeData data;

  static MenuButtonThemeData of(BuildContext context) {
    final MenuButtonTheme? buttonTheme =
        context.dependOnInheritedWidgetOfExactType<MenuButtonTheme>();
    return buttonTheme?.data ?? Theme.of(context).menuButtonTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return MenuButtonTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(MenuButtonTheme oldWidget) => data != oldWidget.data;
}
