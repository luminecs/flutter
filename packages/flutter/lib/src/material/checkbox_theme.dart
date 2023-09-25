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
class CheckboxThemeData with Diagnosticable {
  const CheckboxThemeData({
    this.mouseCursor,
    this.fillColor,
    this.checkColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.shape,
    this.side,
  });

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final MaterialStateProperty<Color?>? fillColor;

  final MaterialStateProperty<Color?>? checkColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final MaterialTapTargetSize? materialTapTargetSize;

  final VisualDensity? visualDensity;

  final OutlinedBorder? shape;

  final BorderSide? side;

  CheckboxThemeData copyWith({
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    MaterialStateProperty<Color?>? fillColor,
    MaterialStateProperty<Color?>? checkColor,
    MaterialStateProperty<Color?>? overlayColor,
    double? splashRadius,
    MaterialTapTargetSize? materialTapTargetSize,
    VisualDensity? visualDensity,
    OutlinedBorder? shape,
    BorderSide? side,
  }) {
    return CheckboxThemeData(
      mouseCursor: mouseCursor ?? this.mouseCursor,
      fillColor: fillColor ?? this.fillColor,
      checkColor: checkColor ?? this.checkColor,
      overlayColor: overlayColor ?? this.overlayColor,
      splashRadius: splashRadius ?? this.splashRadius,
      materialTapTargetSize: materialTapTargetSize ?? this.materialTapTargetSize,
      visualDensity: visualDensity ?? this.visualDensity,
      shape: shape ?? this.shape,
      side: side ?? this.side,
    );
  }

  static CheckboxThemeData lerp(CheckboxThemeData? a, CheckboxThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return CheckboxThemeData(
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      fillColor: MaterialStateProperty.lerp<Color?>(a?.fillColor, b?.fillColor, t, Color.lerp),
      checkColor: MaterialStateProperty.lerp<Color?>(a?.checkColor, b?.checkColor, t, Color.lerp),
      overlayColor: MaterialStateProperty.lerp<Color?>(a?.overlayColor, b?.overlayColor, t, Color.lerp),
      splashRadius: lerpDouble(a?.splashRadius, b?.splashRadius, t),
      materialTapTargetSize: t < 0.5 ? a?.materialTapTargetSize : b?.materialTapTargetSize,
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t) as OutlinedBorder?,
      side: _lerpSides(a?.side, b?.side, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    mouseCursor,
    fillColor,
    checkColor,
    overlayColor,
    splashRadius,
    materialTapTargetSize,
    visualDensity,
    shape,
    side,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CheckboxThemeData
      && other.mouseCursor == mouseCursor
      && other.fillColor == fillColor
      && other.checkColor == checkColor
      && other.overlayColor == overlayColor
      && other.splashRadius == splashRadius
      && other.materialTapTargetSize == materialTapTargetSize
      && other.visualDensity == visualDensity
      && other.shape == shape
      && other.side == side;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>('mouseCursor', mouseCursor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('fillColor', fillColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('checkColor', checkColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('overlayColor', overlayColor, defaultValue: null));
    properties.add(DoubleProperty('splashRadius', splashRadius, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialTapTargetSize>('materialTapTargetSize', materialTapTargetSize, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
    properties.add(DiagnosticsProperty<OutlinedBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide>('side', side, defaultValue: null));
  }

  // Special case because BorderSide.lerp() doesn't support null arguments
  static BorderSide? _lerpSides(BorderSide? a, BorderSide? b, double t) {
    if (a == null || b == null) {
      return null;
    }
    if (identical(a, b)) {
      return a;
    }
    return BorderSide.lerp(a, b, t);
  }
}

class CheckboxTheme extends InheritedWidget {
  const CheckboxTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final CheckboxThemeData data;

  static CheckboxThemeData of(BuildContext context) {
    final CheckboxTheme? checkboxTheme = context.dependOnInheritedWidgetOfExactType<CheckboxTheme>();
    return checkboxTheme?.data ?? Theme.of(context).checkboxTheme;
  }

  @override
  bool updateShouldNotify(CheckboxTheme oldWidget) => data != oldWidget.data;
}