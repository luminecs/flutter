
import 'package:flutter/widgets.dart';

import 'menu_anchor.dart';
import 'menu_style.dart';
import 'menu_theme.dart';
import 'theme.dart';

// Examples can assume:
// late Widget child;

@immutable
class MenuBarThemeData extends MenuThemeData {
  const MenuBarThemeData({super.style});

  static MenuBarThemeData? lerp(MenuBarThemeData? a, MenuBarThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return MenuBarThemeData(style: MenuStyle.lerp(a?.style, b?.style, t));
  }
}

class MenuBarTheme extends InheritedTheme {
  const MenuBarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final MenuBarThemeData data;

  static MenuBarThemeData of(BuildContext context) {
    final MenuBarTheme? menuBarTheme = context.dependOnInheritedWidgetOfExactType<MenuBarTheme>();
    return menuBarTheme?.data ?? Theme.of(context).menuBarTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return MenuBarTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(MenuBarTheme oldWidget) => data != oldWidget.data;
}