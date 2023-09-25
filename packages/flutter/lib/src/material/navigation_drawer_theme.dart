import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';
import 'navigation_drawer.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class NavigationDrawerThemeData with Diagnosticable {
  const NavigationDrawerThemeData({
    this.tileHeight,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.indicatorColor,
    this.indicatorShape,
    this.indicatorSize,
    this.labelTextStyle,
    this.iconTheme,
  });

  final double? tileHeight;

  final Color? backgroundColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final Color? indicatorColor;

  final ShapeBorder? indicatorShape;

  final Size? indicatorSize;

  final MaterialStateProperty<TextStyle?>? labelTextStyle;

  final MaterialStateProperty<IconThemeData?>? iconTheme;

  NavigationDrawerThemeData copyWith({
    double? tileHeight,
    Color? backgroundColor,
    double? elevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    Color? indicatorColor,
    ShapeBorder? indicatorShape,
    Size? indicatorSize,
    MaterialStateProperty<TextStyle?>? labelTextStyle,
    MaterialStateProperty<IconThemeData?>? iconTheme,
  }) {
    return NavigationDrawerThemeData(
      tileHeight: tileHeight ?? this.tileHeight,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorShape: indicatorShape ?? this.indicatorShape,
      indicatorSize: indicatorSize ?? this.indicatorSize,
      labelTextStyle: labelTextStyle ?? this.labelTextStyle,
      iconTheme: iconTheme ?? this.iconTheme,
    );
  }

  static NavigationDrawerThemeData? lerp(NavigationDrawerThemeData? a, NavigationDrawerThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return NavigationDrawerThemeData(
      tileHeight: lerpDouble(a?.tileHeight, b?.tileHeight, t),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      indicatorColor: Color.lerp(a?.indicatorColor, b?.indicatorColor, t),
      indicatorShape: ShapeBorder.lerp(a?.indicatorShape, b?.indicatorShape, t),
      indicatorSize: Size.lerp(a?.indicatorSize, a?.indicatorSize, t),
      labelTextStyle: MaterialStateProperty.lerp<TextStyle?>(
          a?.labelTextStyle, b?.labelTextStyle, t, TextStyle.lerp),
      iconTheme: MaterialStateProperty.lerp<IconThemeData?>(
          a?.iconTheme, b?.iconTheme, t, IconThemeData.lerp),
    );
  }

  @override
  int get hashCode => Object.hash(
        tileHeight,
        backgroundColor,
        elevation,
        shadowColor,
        surfaceTintColor,
        indicatorColor,
        indicatorShape,
        indicatorSize,
        labelTextStyle,
        iconTheme,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is NavigationDrawerThemeData &&
        other.tileHeight == tileHeight &&
        other.backgroundColor == backgroundColor &&
        other.elevation == elevation &&
        other.shadowColor == shadowColor &&
        other.surfaceTintColor == surfaceTintColor &&
        other.indicatorColor == indicatorColor &&
        other.indicatorShape == indicatorShape &&
        other.indicatorSize == indicatorSize &&
        other.labelTextStyle == labelTextStyle &&
        other.iconTheme == iconTheme;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DoubleProperty('tileHeight', tileHeight, defaultValue: null));
    properties.add(
        ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(ColorProperty('shadowColor', shadowColor, defaultValue: null));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor,
        defaultValue: null));
    properties.add(
        ColorProperty('indicatorColor', indicatorColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>(
        'indicatorShape', indicatorShape,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Size>('indicatorSize', indicatorSize,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<TextStyle?>>(
        'labelTextStyle', labelTextStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<IconThemeData?>>(
        'iconTheme', iconTheme,
        defaultValue: null));
  }
}

class NavigationDrawerTheme extends InheritedTheme {
  const NavigationDrawerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final NavigationDrawerThemeData data;

  static NavigationDrawerThemeData of(BuildContext context) {
    final NavigationDrawerTheme? navigationDrawerTheme =
        context.dependOnInheritedWidgetOfExactType<NavigationDrawerTheme>();
    return navigationDrawerTheme?.data ??
        Theme.of(context).navigationDrawerTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return NavigationDrawerTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(NavigationDrawerTheme oldWidget) =>
      data != oldWidget.data;
}