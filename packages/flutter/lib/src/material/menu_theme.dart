
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'menu_anchor.dart';
import 'menu_style.dart';
import 'theme.dart';

// Examples can assume:
// late Widget child;

@immutable
class MenuThemeData with Diagnosticable {
  const MenuThemeData({this.style});

  final MenuStyle? style;

  static MenuThemeData? lerp(MenuThemeData? a, MenuThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return MenuThemeData(style: MenuStyle.lerp(a?.style, b?.style, t));
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
    return other is MenuThemeData && other.style == style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MenuStyle>('style', style, defaultValue: null));
  }
}

class MenuTheme extends InheritedTheme {
  const MenuTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final MenuThemeData data;

  static MenuThemeData of(BuildContext context) {
    final MenuTheme? menuTheme = context.dependOnInheritedWidgetOfExactType<MenuTheme>();
    return menuTheme?.data ?? Theme.of(context).menuTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return MenuTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(MenuTheme oldWidget) => data != oldWidget.data;
}