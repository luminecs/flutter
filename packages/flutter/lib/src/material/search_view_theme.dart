// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class SearchViewThemeData with Diagnosticable {
  const SearchViewThemeData({
    this.backgroundColor,
    this.elevation,
    this.surfaceTintColor,
    this.constraints,
    this.side,
    this.shape,
    this.headerTextStyle,
    this.headerHintStyle,
    this.dividerColor,
  });

  final Color? backgroundColor;

  final double? elevation;

  final Color? surfaceTintColor;

  final BorderSide? side;

  final OutlinedBorder? shape;

  final TextStyle? headerTextStyle;

  final TextStyle? headerHintStyle;

  final BoxConstraints? constraints;

  final Color? dividerColor;

  SearchViewThemeData copyWith({
    Color? backgroundColor,
    double? elevation,
    Color? surfaceTintColor,
    BorderSide? side,
    OutlinedBorder? shape,
    TextStyle? headerTextStyle,
    TextStyle? headerHintStyle,
    BoxConstraints? constraints,
    Color? dividerColor,
  }) {
    return SearchViewThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      side: side ?? this.side,
      shape: shape ?? this.shape,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      headerHintStyle: headerHintStyle ?? this.headerHintStyle,
      constraints: constraints ?? this.constraints,
      dividerColor: dividerColor ?? this.dividerColor,
    );
  }

  static SearchViewThemeData? lerp(SearchViewThemeData? a, SearchViewThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return SearchViewThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      side: _lerpSides(a?.side, b?.side, t),
      shape: OutlinedBorder.lerp(a?.shape, b?.shape, t),
      headerTextStyle: TextStyle.lerp(a?.headerTextStyle, b?.headerTextStyle, t),
      headerHintStyle: TextStyle.lerp(a?.headerTextStyle, b?.headerTextStyle, t),
      constraints: BoxConstraints.lerp(a?.constraints, b?.constraints, t),
      dividerColor: Color.lerp(a?.dividerColor, b?.dividerColor, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    elevation,
    surfaceTintColor,
    side,
    shape,
    headerTextStyle,
    headerHintStyle,
    constraints,
    dividerColor,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SearchViewThemeData
      && other.backgroundColor == backgroundColor
      && other.elevation == elevation
      && other.surfaceTintColor == surfaceTintColor
      && other.side == side
      && other.shape == shape
      && other.headerTextStyle == headerTextStyle
      && other.headerHintStyle == headerHintStyle
      && other.constraints == constraints
      && other.dividerColor == dividerColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Color?>('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<double?>('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<Color?>('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<BorderSide?>('side', side, defaultValue: null));
    properties.add(DiagnosticsProperty<OutlinedBorder?>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle?>('headerTextStyle', headerTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle?>('headerHintStyle', headerHintStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>('constraints', constraints, defaultValue: null));
    properties.add(DiagnosticsProperty<Color?>('dividerColor', dividerColor, defaultValue: null));
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

class SearchViewTheme extends InheritedWidget {
  const SearchViewTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final SearchViewThemeData data;

  static SearchViewThemeData of(BuildContext context) {
    final SearchViewTheme? searchViewTheme = context.dependOnInheritedWidgetOfExactType<SearchViewTheme>();
    return searchViewTheme?.data ?? Theme.of(context).searchViewTheme;
  }

  @override
  bool updateShouldNotify(SearchViewTheme oldWidget) => data != oldWidget.data;
}