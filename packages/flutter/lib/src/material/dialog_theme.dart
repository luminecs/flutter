import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

@immutable
class DialogTheme with Diagnosticable {
  const DialogTheme({
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.alignment,
    this.iconColor,
    this.titleTextStyle,
    this.contentTextStyle,
    this.actionsPadding,
  });

  final Color? backgroundColor;

  final double? elevation;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final ShapeBorder? shape;

  final AlignmentGeometry? alignment;

  final TextStyle? titleTextStyle;

  final TextStyle? contentTextStyle;

  final EdgeInsetsGeometry? actionsPadding;

  final Color? iconColor;

  DialogTheme copyWith({
    Color? backgroundColor,
    double? elevation,
    Color? shadowColor,
    Color? surfaceTintColor,
    ShapeBorder? shape,
    AlignmentGeometry? alignment,
    Color? iconColor,
    TextStyle? titleTextStyle,
    TextStyle? contentTextStyle,
    EdgeInsetsGeometry? actionsPadding,
  }) {
    return DialogTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      elevation: elevation ?? this.elevation,
      shadowColor: shadowColor ?? this.shadowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      shape: shape ?? this.shape,
      alignment: alignment ?? this.alignment,
      iconColor: iconColor ?? this.iconColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      contentTextStyle: contentTextStyle ?? this.contentTextStyle,
      actionsPadding: actionsPadding ?? this.actionsPadding,
    );
  }

  static DialogTheme of(BuildContext context) {
    return Theme.of(context).dialogTheme;
  }

  static DialogTheme lerp(DialogTheme? a, DialogTheme? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return DialogTheme(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      shadowColor: Color.lerp(a?.shadowColor, b?.shadowColor, t),
      surfaceTintColor: Color.lerp(a?.surfaceTintColor, b?.surfaceTintColor, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      alignment: AlignmentGeometry.lerp(a?.alignment, b?.alignment, t),
      iconColor: Color.lerp(a?.iconColor, b?.iconColor, t),
      titleTextStyle: TextStyle.lerp(a?.titleTextStyle, b?.titleTextStyle, t),
      contentTextStyle: TextStyle.lerp(a?.contentTextStyle, b?.contentTextStyle, t),
      actionsPadding: EdgeInsetsGeometry.lerp(a?.actionsPadding, b?.actionsPadding, t),
    );
  }

  @override
  int get hashCode => shape.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DialogTheme
        && other.backgroundColor == backgroundColor
        && other.elevation == elevation
        && other.shadowColor == shadowColor
        && other.surfaceTintColor == surfaceTintColor
        && other.shape == shape
        && other.alignment == alignment
        && other.iconColor == iconColor
        && other.titleTextStyle == titleTextStyle
        && other.contentTextStyle == contentTextStyle
        && other.actionsPadding == actionsPadding;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor));
    properties.add(DoubleProperty('elevation', elevation));
    properties.add(ColorProperty('shadowColor', shadowColor));
    properties.add(ColorProperty('surfaceTintColor', surfaceTintColor));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment, defaultValue: null));
    properties.add(ColorProperty('iconColor', iconColor));
    properties.add(DiagnosticsProperty<TextStyle>('titleTextStyle', titleTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('contentTextStyle', contentTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('actionsPadding', actionsPadding, defaultValue: null));
  }
}