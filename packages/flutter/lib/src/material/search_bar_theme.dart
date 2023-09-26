import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../services.dart';
import 'material_state.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class SearchBarThemeData with Diagnosticable {
  const SearchBarThemeData({
    this.elevation,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.overlayColor,
    this.side,
    this.shape,
    this.padding,
    this.textStyle,
    this.hintStyle,
    this.constraints,
    this.textCapitalization,
  });

  final MaterialStateProperty<double?>? elevation;

  final MaterialStateProperty<Color?>? backgroundColor;

  final MaterialStateProperty<Color?>? shadowColor;

  final MaterialStateProperty<Color?>? surfaceTintColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final MaterialStateProperty<BorderSide?>? side;

  final MaterialStateProperty<OutlinedBorder?>? shape;

  final MaterialStateProperty<EdgeInsetsGeometry?>? padding;

  final MaterialStateProperty<TextStyle?>? textStyle;

  final MaterialStateProperty<TextStyle?>? hintStyle;

  final BoxConstraints? constraints;

  final TextCapitalization? textCapitalization;

  SearchBarThemeData copyWith({
    MaterialStateProperty<double?>? elevation,
    MaterialStateProperty<Color?>? backgroundColor,
    MaterialStateProperty<Color?>? shadowColor,
    MaterialStateProperty<Color?>? surfaceTintColor,
    MaterialStateProperty<Color?>? overlayColor,
    MaterialStateProperty<BorderSide?>? side,
    MaterialStateProperty<OutlinedBorder?>? shape,
    MaterialStateProperty<EdgeInsetsGeometry?>? padding,
    MaterialStateProperty<TextStyle?>? textStyle,
    MaterialStateProperty<TextStyle?>? hintStyle,
    BoxConstraints? constraints,
    TextCapitalization? textCapitalization,
  }) {
    return SearchBarThemeData(
      elevation: elevation ?? this.elevation,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      overlayColor: overlayColor ?? this.overlayColor,
      side: side ?? this.side,
      shape: shape ?? this.shape,
      padding: padding ?? this.padding,
      textStyle: textStyle ?? this.textStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      constraints: constraints ?? this.constraints,
      textCapitalization: textCapitalization ?? this.textCapitalization,
    );
  }

  static SearchBarThemeData? lerp(
      SearchBarThemeData? a, SearchBarThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return SearchBarThemeData(
      elevation: MaterialStateProperty.lerp<double?>(
          a?.elevation, b?.elevation, t, lerpDouble),
      backgroundColor: MaterialStateProperty.lerp<Color?>(
          a?.backgroundColor, b?.backgroundColor, t, Color.lerp),
      shadowColor: MaterialStateProperty.lerp<Color?>(
          a?.shadowColor, b?.shadowColor, t, Color.lerp),
      surfaceTintColor: MaterialStateProperty.lerp<Color?>(
          a?.surfaceTintColor, b?.surfaceTintColor, t, Color.lerp),
      overlayColor: MaterialStateProperty.lerp<Color?>(
          a?.overlayColor, b?.overlayColor, t, Color.lerp),
      side: _lerpSides(a?.side, b?.side, t),
      shape: MaterialStateProperty.lerp<OutlinedBorder?>(
          a?.shape, b?.shape, t, OutlinedBorder.lerp),
      padding: MaterialStateProperty.lerp<EdgeInsetsGeometry?>(
          a?.padding, b?.padding, t, EdgeInsetsGeometry.lerp),
      textStyle: MaterialStateProperty.lerp<TextStyle?>(
          a?.textStyle, b?.textStyle, t, TextStyle.lerp),
      hintStyle: MaterialStateProperty.lerp<TextStyle?>(
          a?.hintStyle, b?.hintStyle, t, TextStyle.lerp),
      constraints: BoxConstraints.lerp(a?.constraints, b?.constraints, t),
      textCapitalization:
          t < 0.5 ? a?.textCapitalization : b?.textCapitalization,
    );
  }

  @override
  int get hashCode => Object.hash(
        elevation,
        backgroundColor,
        shadowColor,
        surfaceTintColor,
        overlayColor,
        side,
        shape,
        padding,
        textStyle,
        hintStyle,
        constraints,
        textCapitalization,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SearchBarThemeData &&
        other.elevation == elevation &&
        other.backgroundColor == backgroundColor &&
        other.shadowColor == shadowColor &&
        other.surfaceTintColor == surfaceTintColor &&
        other.overlayColor == overlayColor &&
        other.side == side &&
        other.shape == shape &&
        other.padding == padding &&
        other.textStyle == textStyle &&
        other.hintStyle == hintStyle &&
        other.constraints == constraints &&
        other.textCapitalization == textCapitalization;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<double?>>(
        'elevation', elevation,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'backgroundColor', backgroundColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'shadowColor', shadowColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'surfaceTintColor', surfaceTintColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'overlayColor', overlayColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<BorderSide?>>(
        'side', side,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<OutlinedBorder?>>(
        'shape', shape,
        defaultValue: null));
    properties.add(
        DiagnosticsProperty<MaterialStateProperty<EdgeInsetsGeometry?>>(
            'padding', padding,
            defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<TextStyle?>>(
        'textStyle', textStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<TextStyle?>>(
        'hintStyle', hintStyle,
        defaultValue: null));
    properties.add(DiagnosticsProperty<BoxConstraints>(
        'constraints', constraints,
        defaultValue: null));
    properties.add(DiagnosticsProperty<TextCapitalization>(
        'textCapitalization', textCapitalization,
        defaultValue: null));
  }

  // Special case because BorderSide.lerp() doesn't support null arguments
  static MaterialStateProperty<BorderSide?>? _lerpSides(
      MaterialStateProperty<BorderSide?>? a,
      MaterialStateProperty<BorderSide?>? b,
      double t) {
    if (identical(a, b)) {
      return a;
    }
    return _LerpSides(a, b, t);
  }
}

class _LerpSides implements MaterialStateProperty<BorderSide?> {
  const _LerpSides(this.a, this.b, this.t);

  final MaterialStateProperty<BorderSide?>? a;
  final MaterialStateProperty<BorderSide?>? b;
  final double t;

  @override
  BorderSide? resolve(Set<MaterialState> states) {
    final BorderSide? resolvedA = a?.resolve(states);
    final BorderSide? resolvedB = b?.resolve(states);
    if (identical(resolvedA, resolvedB)) {
      return resolvedA;
    }
    if (resolvedA == null) {
      return BorderSide.lerp(
          BorderSide(width: 0, color: resolvedB!.color.withAlpha(0)),
          resolvedB,
          t);
    }
    if (resolvedB == null) {
      return BorderSide.lerp(resolvedA,
          BorderSide(width: 0, color: resolvedA.color.withAlpha(0)), t);
    }
    return BorderSide.lerp(resolvedA, resolvedB, t);
  }
}

class SearchBarTheme extends InheritedWidget {
  const SearchBarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final SearchBarThemeData data;

  static SearchBarThemeData of(BuildContext context) {
    final SearchBarTheme? searchBarTheme =
        context.dependOnInheritedWidgetOfExactType<SearchBarTheme>();
    return searchBarTheme?.data ?? Theme.of(context).searchBarTheme;
  }

  @override
  bool updateShouldNotify(SearchBarTheme oldWidget) => data != oldWidget.data;
}
