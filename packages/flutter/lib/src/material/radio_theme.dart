// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class RadioThemeData with Diagnosticable {
  const RadioThemeData({
    this.mouseCursor,
    this.fillColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
  });

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final MaterialStateProperty<Color?>? fillColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final MaterialTapTargetSize? materialTapTargetSize;

  final VisualDensity? visualDensity;

  RadioThemeData copyWith({
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    MaterialStateProperty<Color?>? fillColor,
    MaterialStateProperty<Color?>? overlayColor,
    double? splashRadius,
    MaterialTapTargetSize? materialTapTargetSize,
    VisualDensity? visualDensity,
  }) {
    return RadioThemeData(
      mouseCursor: mouseCursor ?? this.mouseCursor,
      fillColor: fillColor ?? this.fillColor,
      overlayColor: overlayColor ?? this.overlayColor,
      splashRadius: splashRadius ?? this.splashRadius,
      materialTapTargetSize: materialTapTargetSize ?? this.materialTapTargetSize,
      visualDensity: visualDensity ?? this.visualDensity,
    );
  }

  static RadioThemeData lerp(RadioThemeData? a, RadioThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return RadioThemeData(
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      fillColor: MaterialStateProperty.lerp<Color?>(a?.fillColor, b?.fillColor, t, Color.lerp),
      materialTapTargetSize: t < 0.5 ? a?.materialTapTargetSize : b?.materialTapTargetSize,
      overlayColor: MaterialStateProperty.lerp<Color?>(a?.overlayColor, b?.overlayColor, t, Color.lerp),
      splashRadius: lerpDouble(a?.splashRadius, b?.splashRadius, t),
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
    );
  }

  @override
  int get hashCode => Object.hash(
    mouseCursor,
    fillColor,
    overlayColor,
    splashRadius,
    materialTapTargetSize,
    visualDensity,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is RadioThemeData
      && other.mouseCursor == mouseCursor
      && other.fillColor == fillColor
      && other.overlayColor == overlayColor
      && other.splashRadius == splashRadius
      && other.materialTapTargetSize == materialTapTargetSize
      && other.visualDensity == visualDensity;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>('mouseCursor', mouseCursor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('fillColor', fillColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('overlayColor', overlayColor, defaultValue: null));
    properties.add(DoubleProperty('splashRadius', splashRadius, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialTapTargetSize>('materialTapTargetSize', materialTapTargetSize, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
  }
}

class RadioTheme extends InheritedWidget {
  const RadioTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final RadioThemeData data;

  static RadioThemeData of(BuildContext context) {
    final RadioTheme? radioTheme = context.dependOnInheritedWidgetOfExactType<RadioTheme>();
    return radioTheme?.data ?? Theme.of(context).radioTheme;
  }

  @override
  bool updateShouldNotify(RadioTheme oldWidget) => data != oldWidget.data;
}