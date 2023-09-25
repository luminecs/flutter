import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'bottom_navigation_bar.dart';
import 'material_state.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class BottomNavigationBarThemeData with Diagnosticable {
  const BottomNavigationBarThemeData({
    this.backgroundColor,
    this.elevation,
    this.selectedIconTheme,
    this.unselectedIconTheme,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
    this.showSelectedLabels,
    this.showUnselectedLabels,
    this.type,
    this.enableFeedback,
    this.landscapeLayout,
    this.mouseCursor,
  });

  final Color? backgroundColor;

  final double? elevation;

  final IconThemeData? selectedIconTheme;

  final IconThemeData? unselectedIconTheme;

  final Color? selectedItemColor;

  final Color? unselectedItemColor;

  final TextStyle? selectedLabelStyle;

  final TextStyle? unselectedLabelStyle;

  final bool? showSelectedLabels;

  final bool? showUnselectedLabels;

  final BottomNavigationBarType? type;

  final bool? enableFeedback;

  final BottomNavigationBarLandscapeLayout? landscapeLayout;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  BottomNavigationBarThemeData copyWith({
    Color? backgroundColor,
    double? elevation,
    IconThemeData? selectedIconTheme,
    IconThemeData? unselectedIconTheme,
    Color? selectedItemColor,
    Color? unselectedItemColor,
    TextStyle? selectedLabelStyle,
    TextStyle? unselectedLabelStyle,
    bool? showSelectedLabels,
    bool? showUnselectedLabels,
    BottomNavigationBarType? type,
    bool? enableFeedback,
    BottomNavigationBarLandscapeLayout? landscapeLayout,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
  }) {
    return BottomNavigationBarThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      selectedIconTheme: selectedIconTheme ?? this.selectedIconTheme,
      unselectedIconTheme: unselectedIconTheme ?? this.unselectedIconTheme,
      selectedItemColor: selectedItemColor ?? this.selectedItemColor,
      unselectedItemColor: unselectedItemColor ?? this.unselectedItemColor,
      selectedLabelStyle: selectedLabelStyle ?? this.selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle ?? this.unselectedLabelStyle,
      showSelectedLabels: showSelectedLabels ?? this.showSelectedLabels,
      showUnselectedLabels: showUnselectedLabels ?? this.showUnselectedLabels,
      type: type ?? this.type,
      enableFeedback: enableFeedback ?? this.enableFeedback,
      landscapeLayout: landscapeLayout ?? this.landscapeLayout,
      mouseCursor: mouseCursor ?? this.mouseCursor,
    );
  }

  static BottomNavigationBarThemeData lerp(BottomNavigationBarThemeData? a, BottomNavigationBarThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return BottomNavigationBarThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      selectedIconTheme: IconThemeData.lerp(a?.selectedIconTheme, b?.selectedIconTheme, t),
      unselectedIconTheme: IconThemeData.lerp(a?.unselectedIconTheme, b?.unselectedIconTheme, t),
      selectedItemColor: Color.lerp(a?.selectedItemColor, b?.selectedItemColor, t),
      unselectedItemColor: Color.lerp(a?.unselectedItemColor, b?.unselectedItemColor, t),
      selectedLabelStyle: TextStyle.lerp(a?.selectedLabelStyle, b?.selectedLabelStyle, t),
      unselectedLabelStyle: TextStyle.lerp(a?.unselectedLabelStyle, b?.unselectedLabelStyle, t),
      showSelectedLabels: t < 0.5 ? a?.showSelectedLabels : b?.showSelectedLabels,
      showUnselectedLabels: t < 0.5 ? a?.showUnselectedLabels : b?.showUnselectedLabels,
      type: t < 0.5 ? a?.type : b?.type,
      enableFeedback: t < 0.5 ? a?.enableFeedback : b?.enableFeedback,
      landscapeLayout: t < 0.5 ? a?.landscapeLayout : b?.landscapeLayout,
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
    );
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    elevation,
    selectedIconTheme,
    unselectedIconTheme,
    selectedItemColor,
    unselectedItemColor,
    selectedLabelStyle,
    unselectedLabelStyle,
    showSelectedLabels,
    showUnselectedLabels,
    type,
    enableFeedback,
    landscapeLayout,
    mouseCursor,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BottomNavigationBarThemeData
        && other.backgroundColor == backgroundColor
        && other.elevation == elevation
        && other.selectedIconTheme == selectedIconTheme
        && other.unselectedIconTheme == unselectedIconTheme
        && other.selectedItemColor == selectedItemColor
        && other.unselectedItemColor == unselectedItemColor
        && other.selectedLabelStyle == selectedLabelStyle
        && other.unselectedLabelStyle == unselectedLabelStyle
        && other.showSelectedLabels == showSelectedLabels
        && other.showUnselectedLabels == showUnselectedLabels
        && other.type == type
        && other.enableFeedback == enableFeedback
        && other.landscapeLayout == landscapeLayout
        && other.mouseCursor == mouseCursor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<IconThemeData>('selectedIconTheme', selectedIconTheme, defaultValue: null));
    properties.add(DiagnosticsProperty<IconThemeData>('unselectedIconTheme', unselectedIconTheme, defaultValue: null));
    properties.add(ColorProperty('selectedItemColor', selectedItemColor, defaultValue: null));
    properties.add(ColorProperty('unselectedItemColor', unselectedItemColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('selectedLabelStyle', selectedLabelStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('unselectedLabelStyle', unselectedLabelStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('showSelectedLabels', showSelectedLabels, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('showUnselectedLabels', showUnselectedLabels, defaultValue: null));
    properties.add(DiagnosticsProperty<BottomNavigationBarType>('type', type, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback, defaultValue: null));
    properties.add(DiagnosticsProperty<BottomNavigationBarLandscapeLayout>('landscapeLayout', landscapeLayout, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>('mouseCursor', mouseCursor, defaultValue: null));
  }
}

class BottomNavigationBarTheme extends InheritedWidget {
  const BottomNavigationBarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final BottomNavigationBarThemeData data;

  static BottomNavigationBarThemeData of(BuildContext context) {
    final BottomNavigationBarTheme? bottomNavTheme = context.dependOnInheritedWidgetOfExactType<BottomNavigationBarTheme>();
    return bottomNavTheme?.data ?? Theme.of(context).bottomNavigationBarTheme;
  }

  @override
  bool updateShouldNotify(BottomNavigationBarTheme oldWidget) => data != oldWidget.data;
}