import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class DividerThemeData with Diagnosticable {

  const DividerThemeData({
    this.color,
    this.space,
    this.thickness,
    this.indent,
    this.endIndent,
  });

  final Color? color;

  final double? space;

  final double? thickness;

  final double? indent;

  final double? endIndent;

  DividerThemeData copyWith({
    Color? color,
    double? space,
    double? thickness,
    double? indent,
    double? endIndent,
  }) {
    return DividerThemeData(
      color: color ?? this.color,
      space: space ?? this.space,
      thickness: thickness ?? this.thickness,
      indent: indent ?? this.indent,
      endIndent: endIndent ?? this.endIndent,
    );
  }

  static DividerThemeData lerp(DividerThemeData? a, DividerThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return DividerThemeData(
      color: Color.lerp(a?.color, b?.color, t),
      space: lerpDouble(a?.space, b?.space, t),
      thickness: lerpDouble(a?.thickness, b?.thickness, t),
      indent: lerpDouble(a?.indent, b?.indent, t),
      endIndent: lerpDouble(a?.endIndent, b?.endIndent, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    color,
    space,
    thickness,
    indent,
    endIndent,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DividerThemeData
        && other.color == color
        && other.space == space
        && other.thickness == thickness
        && other.indent == indent
        && other.endIndent == endIndent;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DoubleProperty('space', space, defaultValue: null));
    properties.add(DoubleProperty('thickness', thickness, defaultValue: null));
    properties.add(DoubleProperty('indent', indent, defaultValue: null));
    properties.add(DoubleProperty('endIndent', endIndent, defaultValue: null));
  }
}

class DividerTheme extends InheritedTheme {
  const DividerTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final DividerThemeData data;

  static DividerThemeData of(BuildContext context) {
    final DividerTheme? dividerTheme = context.dependOnInheritedWidgetOfExactType<DividerTheme>();
    return dividerTheme?.data ?? Theme.of(context).dividerTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DividerTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(DividerTheme oldWidget) => data != oldWidget.data;
}