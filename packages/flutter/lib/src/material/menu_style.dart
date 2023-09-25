
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'material_state.dart';
import 'menu_anchor.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// late Widget child;
// late BuildContext context;
// late MenuStyle style;
// @immutable
// class MyAppHome extends StatelessWidget {
//   const MyAppHome({super.key});
//   @override
//   Widget build(BuildContext context) => const SizedBox();
// }

@immutable
class MenuStyle with Diagnosticable {
  const MenuStyle({
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.maximumSize,
    this.side,
    this.shape,
    this.mouseCursor,
    this.visualDensity,
    this.alignment,
  });

  final MaterialStateProperty<Color?>? backgroundColor;

  final MaterialStateProperty<Color?>? shadowColor;

  final MaterialStateProperty<Color?>? surfaceTintColor;

  final MaterialStateProperty<double?>? elevation;

  final MaterialStateProperty<EdgeInsetsGeometry?>? padding;

  final MaterialStateProperty<Size?>? minimumSize;

  final MaterialStateProperty<Size?>? fixedSize;

  final MaterialStateProperty<Size?>? maximumSize;

  final MaterialStateProperty<BorderSide?>? side;

  final MaterialStateProperty<OutlinedBorder?>? shape;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final VisualDensity? visualDensity;

  final AlignmentGeometry? alignment;

  @override
  int get hashCode {
    final List<Object?> values = <Object?>[
      backgroundColor,
      shadowColor,
      surfaceTintColor,
      elevation,
      padding,
      minimumSize,
      fixedSize,
      maximumSize,
      side,
      shape,
      mouseCursor,
      visualDensity,
      alignment,
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
    return other is MenuStyle
        && other.backgroundColor == backgroundColor
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.elevation == elevation
        && other.padding == padding
        && other.minimumSize == minimumSize
        && other.fixedSize == fixedSize
        && other.maximumSize == maximumSize
        && other.side == side
        && other.shape == shape
        && other.mouseCursor == mouseCursor
        && other.visualDensity == visualDensity
        && other.alignment == alignment;
  }

  MenuStyle copyWith({
    MaterialStateProperty<Color?>? backgroundColor,
    MaterialStateProperty<Color?>? shadowColor,
    MaterialStateProperty<Color?>? surfaceTintColor,
    MaterialStateProperty<double?>? elevation,
    MaterialStateProperty<EdgeInsetsGeometry?>? padding,
    MaterialStateProperty<Size?>? minimumSize,
    MaterialStateProperty<Size?>? fixedSize,
    MaterialStateProperty<Size?>? maximumSize,
    MaterialStateProperty<BorderSide?>? side,
    MaterialStateProperty<OutlinedBorder?>? shape,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    VisualDensity? visualDensity,
    AlignmentGeometry? alignment,
  }) {
    return MenuStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      elevation: elevation ?? this.elevation,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      fixedSize: fixedSize ?? this.fixedSize,
      maximumSize: maximumSize ?? this.maximumSize,
      side: side ?? this.side,
      shape: shape ?? this.shape,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      visualDensity: visualDensity ?? this.visualDensity,
      alignment: alignment ?? this.alignment,
    );
  }

  MenuStyle merge(MenuStyle? style) {
    if (style == null) {
      return this;
    }
    return copyWith(
      backgroundColor: backgroundColor ?? style.backgroundColor,
      shadowColor: shadowColor ?? style.shadowColor,
      surfaceTintColor: surfaceTintColor ?? style.surfaceTintColor,
      elevation: elevation ?? style.elevation,
      padding: padding ?? style.padding,
      minimumSize: minimumSize ?? style.minimumSize,
      fixedSize: fixedSize ?? style.fixedSize,
      maximumSize: maximumSize ?? style.maximumSize,
      side: side ?? style.side,
      shape: shape ?? style.shape,
      mouseCursor: mouseCursor ?? style.mouseCursor,
      visualDensity: visualDensity ?? style.visualDensity,
      alignment: alignment ?? style.alignment,
    );
  }

  static MenuStyle? lerp(MenuStyle? a, MenuStyle? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return MenuStyle(
      backgroundColor: MaterialStateProperty.lerp<Color?>(a?.backgroundColor, b?.backgroundColor, t, Color.lerp),
      shadowColor: MaterialStateProperty.lerp<Color?>(a?.shadowColor, b?.shadowColor, t, Color.lerp),
      surfaceTintColor: MaterialStateProperty.lerp<Color?>(a?.surfaceTintColor, b?.surfaceTintColor, t, Color.lerp),
      elevation: MaterialStateProperty.lerp<double?>(a?.elevation, b?.elevation, t, lerpDouble),
      padding:  MaterialStateProperty.lerp<EdgeInsetsGeometry?>(a?.padding, b?.padding, t, EdgeInsetsGeometry.lerp),
      minimumSize: MaterialStateProperty.lerp<Size?>(a?.minimumSize, b?.minimumSize, t, Size.lerp),
      fixedSize: MaterialStateProperty.lerp<Size?>(a?.fixedSize, b?.fixedSize, t, Size.lerp),
      maximumSize: MaterialStateProperty.lerp<Size?>(a?.maximumSize, b?.maximumSize, t, Size.lerp),
      side: _LerpSides(a?.side, b?.side, t),
      shape: MaterialStateProperty.lerp<OutlinedBorder?>(a?.shape, b?.shape, t, OutlinedBorder.lerp),
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
      alignment: AlignmentGeometry.lerp(a?.alignment, b?.alignment, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('shadowColor', shadowColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('surfaceTintColor', surfaceTintColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<double?>>('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<EdgeInsetsGeometry?>>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Size?>>('minimumSize', minimumSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Size?>>('fixedSize', fixedSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Size?>>('maximumSize', maximumSize, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<BorderSide?>>('side', side, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<OutlinedBorder?>>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>('mouseCursor', mouseCursor, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment, defaultValue: null));
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