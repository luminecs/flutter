// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ProgressIndicatorThemeData with Diagnosticable {
  const ProgressIndicatorThemeData({
    this.color,
    this.linearTrackColor,
    this.linearMinHeight,
    this.circularTrackColor,
    this.refreshBackgroundColor,
  });

  final Color? color;

  final Color? linearTrackColor;

  final double? linearMinHeight;

  final Color? circularTrackColor;

  final Color? refreshBackgroundColor;

  ProgressIndicatorThemeData copyWith({
    Color? color,
    Color? linearTrackColor,
    double? linearMinHeight,
    Color? circularTrackColor,
    Color? refreshBackgroundColor,
  }) {
    return ProgressIndicatorThemeData(
      color: color ?? this.color,
      linearTrackColor : linearTrackColor ?? this.linearTrackColor,
      linearMinHeight : linearMinHeight ?? this.linearMinHeight,
      circularTrackColor : circularTrackColor ?? this.circularTrackColor,
      refreshBackgroundColor : refreshBackgroundColor ?? this.refreshBackgroundColor,
    );
  }

  static ProgressIndicatorThemeData? lerp(ProgressIndicatorThemeData? a, ProgressIndicatorThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ProgressIndicatorThemeData(
      color: Color.lerp(a?.color, b?.color, t),
      linearTrackColor : Color.lerp(a?.linearTrackColor, b?.linearTrackColor, t),
      linearMinHeight : lerpDouble(a?.linearMinHeight, b?.linearMinHeight, t),
      circularTrackColor : Color.lerp(a?.circularTrackColor, b?.circularTrackColor, t),
      refreshBackgroundColor : Color.lerp(a?.refreshBackgroundColor, b?.refreshBackgroundColor, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    color,
    linearTrackColor,
    linearMinHeight,
    circularTrackColor,
    refreshBackgroundColor,
  );

  @override
  bool operator==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ProgressIndicatorThemeData
      && other.color == color
      && other.linearTrackColor == linearTrackColor
      && other.linearMinHeight == linearMinHeight
      && other.circularTrackColor == circularTrackColor
      && other.refreshBackgroundColor == refreshBackgroundColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(ColorProperty('linearTrackColor', linearTrackColor, defaultValue: null));
    properties.add(DoubleProperty('linearMinHeight', linearMinHeight, defaultValue: null));
    properties.add(ColorProperty('circularTrackColor', circularTrackColor, defaultValue: null));
    properties.add(ColorProperty('refreshBackgroundColor', refreshBackgroundColor, defaultValue: null));
  }
}

class ProgressIndicatorTheme extends InheritedTheme {
  const ProgressIndicatorTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ProgressIndicatorThemeData data;

  static ProgressIndicatorThemeData of(BuildContext context) {
    final ProgressIndicatorTheme? progressIndicatorTheme = context.dependOnInheritedWidgetOfExactType<ProgressIndicatorTheme>();
    return progressIndicatorTheme?.data ?? Theme.of(context).progressIndicatorTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ProgressIndicatorTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ProgressIndicatorTheme oldWidget) => data != oldWidget.data;
}