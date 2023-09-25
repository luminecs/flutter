// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'navigation_rail.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class NavigationRailThemeData with Diagnosticable {
  const NavigationRailThemeData({
    this.backgroundColor,
    this.elevation,
    this.unselectedLabelTextStyle,
    this.selectedLabelTextStyle,
    this.unselectedIconTheme,
    this.selectedIconTheme,
    this.groupAlignment,
    this.labelType,
    this.useIndicator,
    this.indicatorColor,
    this.indicatorShape,
    this.minWidth,
    this.minExtendedWidth,
  });

  final Color? backgroundColor;

  final double? elevation;

  final TextStyle? unselectedLabelTextStyle;

  final TextStyle? selectedLabelTextStyle;

  final IconThemeData? unselectedIconTheme;

  final IconThemeData? selectedIconTheme;

  final double? groupAlignment;

  final NavigationRailLabelType? labelType;

  final bool? useIndicator;

  final Color? indicatorColor;

  final ShapeBorder? indicatorShape;

  final double? minWidth;

  final double? minExtendedWidth;

  NavigationRailThemeData copyWith({
    Color? backgroundColor,
    double? elevation,
    TextStyle? unselectedLabelTextStyle,
    TextStyle? selectedLabelTextStyle,
    IconThemeData? unselectedIconTheme,
    IconThemeData? selectedIconTheme,
    double? groupAlignment,
    NavigationRailLabelType? labelType,
    bool? useIndicator,
    Color? indicatorColor,
    ShapeBorder? indicatorShape,
    double? minWidth,
    double? minExtendedWidth,
  }) {
    return NavigationRailThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      unselectedLabelTextStyle: unselectedLabelTextStyle ?? this.unselectedLabelTextStyle,
      selectedLabelTextStyle: selectedLabelTextStyle ?? this.selectedLabelTextStyle,
      unselectedIconTheme: unselectedIconTheme ?? this.unselectedIconTheme,
      selectedIconTheme: selectedIconTheme ?? this.selectedIconTheme,
      groupAlignment: groupAlignment ?? this.groupAlignment,
      labelType: labelType ?? this.labelType,
      useIndicator: useIndicator ?? this.useIndicator,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorShape: indicatorShape ?? this.indicatorShape,
      minWidth: minWidth ?? this.minWidth,
      minExtendedWidth: minExtendedWidth ?? this.minExtendedWidth,
    );
  }

  static NavigationRailThemeData? lerp(NavigationRailThemeData? a, NavigationRailThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return NavigationRailThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      unselectedLabelTextStyle: TextStyle.lerp(a?.unselectedLabelTextStyle, b?.unselectedLabelTextStyle, t),
      selectedLabelTextStyle: TextStyle.lerp(a?.selectedLabelTextStyle, b?.selectedLabelTextStyle, t),
      unselectedIconTheme: a?.unselectedIconTheme == null && b?.unselectedIconTheme == null
        ? null : IconThemeData.lerp(a?.unselectedIconTheme, b?.unselectedIconTheme, t),
      selectedIconTheme: a?.selectedIconTheme == null && b?.selectedIconTheme == null
        ? null : IconThemeData.lerp(a?.selectedIconTheme, b?.selectedIconTheme, t),
      groupAlignment: lerpDouble(a?.groupAlignment, b?.groupAlignment, t),
      labelType: t < 0.5 ? a?.labelType : b?.labelType,
      useIndicator: t < 0.5 ? a?.useIndicator : b?.useIndicator,
      indicatorColor: Color.lerp(a?.indicatorColor, b?.indicatorColor, t),
      indicatorShape: ShapeBorder.lerp(a?.indicatorShape, b?.indicatorShape, t),
      minWidth: lerpDouble(a?.minWidth, b?.minWidth, t),
      minExtendedWidth: lerpDouble(a?.minExtendedWidth, b?.minExtendedWidth, t),

    );
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    elevation,
    unselectedLabelTextStyle,
    selectedLabelTextStyle,
    unselectedIconTheme,
    selectedIconTheme,
    groupAlignment,
    labelType,
    useIndicator,
    indicatorColor,
    indicatorShape,
    minWidth,
    minExtendedWidth,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is NavigationRailThemeData
        && other.backgroundColor == backgroundColor
        && other.elevation == elevation
        && other.unselectedLabelTextStyle == unselectedLabelTextStyle
        && other.selectedLabelTextStyle == selectedLabelTextStyle
        && other.unselectedIconTheme == unselectedIconTheme
        && other.selectedIconTheme == selectedIconTheme
        && other.groupAlignment == groupAlignment
        && other.labelType == labelType
        && other.useIndicator == useIndicator
        && other.indicatorColor == indicatorColor
        && other.indicatorShape == indicatorShape
        && other.minWidth == minWidth
        && other.minExtendedWidth == minExtendedWidth;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const NavigationRailThemeData defaultData = NavigationRailThemeData();

    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: defaultData.backgroundColor));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: defaultData.elevation));
    properties.add(DiagnosticsProperty<TextStyle>('unselectedLabelTextStyle', unselectedLabelTextStyle, defaultValue: defaultData.unselectedLabelTextStyle));
    properties.add(DiagnosticsProperty<TextStyle>('selectedLabelTextStyle', selectedLabelTextStyle, defaultValue: defaultData.selectedLabelTextStyle));
    properties.add(DiagnosticsProperty<IconThemeData>('unselectedIconTheme', unselectedIconTheme, defaultValue: defaultData.unselectedIconTheme));
    properties.add(DiagnosticsProperty<IconThemeData>('selectedIconTheme', selectedIconTheme, defaultValue: defaultData.selectedIconTheme));
    properties.add(DoubleProperty('groupAlignment', groupAlignment, defaultValue: defaultData.groupAlignment));
    properties.add(DiagnosticsProperty<NavigationRailLabelType>('labelType', labelType, defaultValue: defaultData.labelType));
    properties.add(DiagnosticsProperty<bool>('useIndicator', useIndicator, defaultValue: defaultData.useIndicator));
    properties.add(ColorProperty('indicatorColor', indicatorColor, defaultValue: defaultData.indicatorColor));
    properties.add(DiagnosticsProperty<ShapeBorder>('indicatorShape', indicatorShape, defaultValue: null));
    properties.add(DoubleProperty('minWidth', minWidth, defaultValue: defaultData.minWidth));
    properties.add(DoubleProperty('minExtendedWidth', minExtendedWidth, defaultValue: defaultData.minExtendedWidth));
  }
}

class NavigationRailTheme extends InheritedTheme {
  const NavigationRailTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final NavigationRailThemeData data;

  static NavigationRailThemeData of(BuildContext context) {
    final NavigationRailTheme? navigationRailTheme = context.dependOnInheritedWidgetOfExactType<NavigationRailTheme>();
    return navigationRailTheme?.data ?? Theme.of(context).navigationRailTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return NavigationRailTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(NavigationRailTheme oldWidget) => data != oldWidget.data;
}