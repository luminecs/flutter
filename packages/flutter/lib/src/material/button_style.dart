// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'ink_well.dart';
import 'material_state.dart';
import 'theme_data.dart';

// Examples can assume:
// late BuildContext context;
// typedef MyAppHome = Placeholder;

@immutable
class ButtonStyle with Diagnosticable {
  const ButtonStyle({
    this.textStyle,
    this.backgroundColor,
    this.foregroundColor,
    this.overlayColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.maximumSize,
    this.iconColor,
    this.iconSize,
    this.side,
    this.shape,
    this.mouseCursor,
    this.visualDensity,
    this.tapTargetSize,
    this.animationDuration,
    this.enableFeedback,
    this.alignment,
    this.splashFactory,
  });

  final MaterialStateProperty<TextStyle?>? textStyle;

  final MaterialStateProperty<Color?>? backgroundColor;

  final MaterialStateProperty<Color?>? foregroundColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final MaterialStateProperty<Color?>? shadowColor;

  final MaterialStateProperty<Color?>? surfaceTintColor;

  final MaterialStateProperty<double?>? elevation;

  final MaterialStateProperty<EdgeInsetsGeometry?>? padding;

  final MaterialStateProperty<Size?>? minimumSize;

  final MaterialStateProperty<Size?>? fixedSize;

  final MaterialStateProperty<Size?>? maximumSize;

  final MaterialStateProperty<Color?>? iconColor;

  final MaterialStateProperty<double?>? iconSize;

  final MaterialStateProperty<BorderSide?>? side;

  final MaterialStateProperty<OutlinedBorder?>? shape;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final VisualDensity? visualDensity;

  final MaterialTapTargetSize? tapTargetSize;

  final Duration? animationDuration;

  final bool? enableFeedback;

  final AlignmentGeometry? alignment;

  final InteractiveInkFeatureFactory? splashFactory;

  ButtonStyle copyWith({
    MaterialStateProperty<TextStyle?>? textStyle,
    MaterialStateProperty<Color?>? backgroundColor,
    MaterialStateProperty<Color?>? foregroundColor,
    MaterialStateProperty<Color?>? overlayColor,
    MaterialStateProperty<Color?>? shadowColor,
    MaterialStateProperty<Color?>? surfaceTintColor,
    MaterialStateProperty<double?>? elevation,
    MaterialStateProperty<EdgeInsetsGeometry?>? padding,
    MaterialStateProperty<Size?>? minimumSize,
    MaterialStateProperty<Size?>? fixedSize,
    MaterialStateProperty<Size?>? maximumSize,
    MaterialStateProperty<Color?>? iconColor,
    MaterialStateProperty<double?>? iconSize,
    MaterialStateProperty<BorderSide?>? side,
    MaterialStateProperty<OutlinedBorder?>? shape,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
    AlignmentGeometry? alignment,
    InteractiveInkFeatureFactory? splashFactory,
  }) {
    return ButtonStyle(
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      overlayColor: overlayColor ?? this.overlayColor,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      elevation: elevation ?? this.elevation,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      fixedSize: fixedSize ?? this.fixedSize,
      maximumSize: maximumSize ?? this.maximumSize,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
      side: side ?? this.side,
      shape: shape ?? this.shape,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      visualDensity: visualDensity ?? this.visualDensity,
      tapTargetSize: tapTargetSize ?? this.tapTargetSize,
      animationDuration: animationDuration ?? this.animationDuration,
      enableFeedback: enableFeedback ?? this.enableFeedback,
      alignment: alignment ?? this.alignment,
      splashFactory: splashFactory ?? this.splashFactory,
    );
  }

  ButtonStyle merge(ButtonStyle? style) {
    if (style == null) {
      return this;
    }
    return copyWith(
      textStyle: textStyle ?? style.textStyle,
      backgroundColor: backgroundColor ?? style.backgroundColor,
      foregroundColor: foregroundColor ?? style.foregroundColor,
      overlayColor: overlayColor ?? style.overlayColor,
      shadowColor: shadowColor ?? style.shadowColor,
      surfaceTintColor: surfaceTintColor ?? style.surfaceTintColor,
      elevation: elevation ?? style.elevation,
      padding: padding ?? style.padding,
      minimumSize: minimumSize ?? style.minimumSize,
      fixedSize: fixedSize ?? style.fixedSize,
      maximumSize: maximumSize ?? style.maximumSize,
      iconColor: iconColor ?? style.iconColor,
      iconSize: iconSize ?? style.iconSize,
      side: side ?? style.side,
      shape: shape ?? style.shape,
      mouseCursor: mouseCursor ?? style.mouseCursor,
      visualDensity: visualDensity ?? style.visualDensity,
      tapTargetSize: tapTargetSize ?? style.tapTargetSize,
      animationDuration: animationDuration ?? style.animationDuration,
      enableFeedback: enableFeedback ?? style.enableFeedback,
      alignment: alignment ?? style.alignment,
      splashFactory: splashFactory ?? style.splashFactory,
    );
  }

  @override
  int get hashCode {
    final List<Object?> values = <Object?>[
      textStyle,
      backgroundColor,
      foregroundColor,
      overlayColor,
      shadowColor,
      surfaceTintColor,
      elevation,
      padding,
      minimumSize,
      fixedSize,
      maximumSize,
      iconColor,
      iconSize,
      side,
      shape,
      mouseCursor,
      visualDensity,
      tapTargetSize,
      animationDuration,
      enableFeedback,
      alignment,
      splashFactory,
    ];
    return Object.hashAll(values);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ButtonStyle
        && other.textStyle == textStyle
        && other.backgroundColor == backgroundColor
        && other.foregroundColor == foregroundColor
        && other.overlayColor == overlayColor
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.elevation == elevation
        && other.padding == padding
        && other.minimumSize == minimumSize
        && other.fixedSize == fixedSize
        && other.maximumSize == maximumSize
        && other.iconColor == iconColor
        && other.iconSize == iconSize
        && other.side == side
        && other.shape == shape
        && other.mouseCursor == mouseCursor
        && other.visualDensity == visualDensity
        && other.tapTargetSize == tapTargetSize
        && other.animationDuration == animationDuration
        && other.enableFeedback == enableFeedback
        && other.alignment == alignment
        && other.splashFactory == splashFactory;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<TextStyle?>>('textStyle', textStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('foregroundColor', foregroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('overlayColor', overlayColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('shadowColor', shadowColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<double?>>('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<EdgeInsetsGeometry?>>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Size?>>('minimumSize', minimumSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Size?>>('fixedSize', fixedSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Size?>>('maximumSize', maximumSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('iconColor', iconColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<double?>>('iconSize', iconSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<BorderSide?>>('side', side, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<OutlinedBorder?>>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>('mouseCursor', mouseCursor, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
    properties.add(EnumProperty<MaterialTapTargetSize>('tapTargetSize', tapTargetSize, defaultValue: null));
    properties.add(DiagnosticsProperty<Duration>('animationDuration', animationDuration, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback, defaultValue: null));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment, defaultValue: null));
  }

  static ButtonStyle? lerp(ButtonStyle? a, ButtonStyle? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ButtonStyle(
      textStyle: MaterialStateProperty.lerp<TextStyle?>(a?.textStyle, b?.textStyle, t, TextStyle.lerp),
      backgroundColor: MaterialStateProperty.lerp<Color?>(a?.backgroundColor, b?.backgroundColor, t, Color.lerp),
      foregroundColor: MaterialStateProperty.lerp<Color?>(a?.foregroundColor, b?.foregroundColor, t, Color.lerp),
      overlayColor: MaterialStateProperty.lerp<Color?>(a?.overlayColor, b?.overlayColor, t, Color.lerp),
      shadowColor: MaterialStateProperty.lerp<Color?>(a?.shadowColor, b?.shadowColor, t, Color.lerp),
      surfaceTintColor: MaterialStateProperty.lerp<Color?>(a?.surfaceTintColor, b?.surfaceTintColor, t, Color.lerp),
      elevation: MaterialStateProperty.lerp<double?>(a?.elevation, b?.elevation, t, lerpDouble),
      padding: MaterialStateProperty.lerp<EdgeInsetsGeometry?>(a?.padding, b?.padding, t, EdgeInsetsGeometry.lerp),
      minimumSize: MaterialStateProperty.lerp<Size?>(a?.minimumSize, b?.minimumSize, t, Size.lerp),
      fixedSize: MaterialStateProperty.lerp<Size?>(a?.fixedSize, b?.fixedSize, t, Size.lerp),
      maximumSize: MaterialStateProperty.lerp<Size?>(a?.maximumSize, b?.maximumSize, t, Size.lerp),
      iconColor: MaterialStateProperty.lerp<Color?>(a?.iconColor, b?.iconColor, t, Color.lerp),
      iconSize: MaterialStateProperty.lerp<double?>(a?.iconSize, b?.iconSize, t, lerpDouble),
      side: _lerpSides(a?.side, b?.side, t),
      shape: MaterialStateProperty.lerp<OutlinedBorder?>(a?.shape, b?.shape, t, OutlinedBorder.lerp),
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
      tapTargetSize: t < 0.5 ? a?.tapTargetSize : b?.tapTargetSize,
      animationDuration: t < 0.5 ? a?.animationDuration : b?.animationDuration,
      enableFeedback: t < 0.5 ? a?.enableFeedback : b?.enableFeedback,
      alignment: AlignmentGeometry.lerp(a?.alignment, b?.alignment, t),
      splashFactory: t < 0.5 ? a?.splashFactory : b?.splashFactory,
    );
  }

  // Special case because BorderSide.lerp() doesn't support null arguments
  static MaterialStateProperty<BorderSide?>? _lerpSides(MaterialStateProperty<BorderSide?>? a, MaterialStateProperty<BorderSide?>? b, double t) {
    if (a == null && b == null) {
      return null;
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
    if (resolvedA == null && resolvedB == null) {
      return null;
    }
    if (resolvedA == null) {
      return BorderSide.lerp(BorderSide(width: 0, color: resolvedB!.color.withAlpha(0)), resolvedB, t);
    }
    if (resolvedB == null) {
      return BorderSide.lerp(resolvedA, BorderSide(width: 0, color: resolvedA.color.withAlpha(0)), t);
    }
    return BorderSide.lerp(resolvedA, resolvedB, t);
  }
}