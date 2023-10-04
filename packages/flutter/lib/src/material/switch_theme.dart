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
class SwitchThemeData with Diagnosticable {
  const SwitchThemeData({
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.trackOutlineWidth,
    this.materialTapTargetSize,
    this.mouseCursor,
    this.overlayColor,
    this.splashRadius,
    this.thumbIcon,
  });

  final MaterialStateProperty<Color?>? thumbColor;

  final MaterialStateProperty<Color?>? trackColor;

  final MaterialStateProperty<Color?>? trackOutlineColor;

  final MaterialStateProperty<double?>? trackOutlineWidth;

  final MaterialTapTargetSize? materialTapTargetSize;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final MaterialStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final MaterialStateProperty<Icon?>? thumbIcon;

  SwitchThemeData copyWith({
    MaterialStateProperty<Color?>? thumbColor,
    MaterialStateProperty<Color?>? trackColor,
    MaterialStateProperty<Color?>? trackOutlineColor,
    MaterialStateProperty<double?>? trackOutlineWidth,
    MaterialTapTargetSize? materialTapTargetSize,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    MaterialStateProperty<Color?>? overlayColor,
    double? splashRadius,
    MaterialStateProperty<Icon?>? thumbIcon,
  }) {
    return SwitchThemeData(
      thumbColor: thumbColor ?? this.thumbColor,
      trackColor: trackColor ?? this.trackColor,
      trackOutlineColor: trackOutlineColor ?? this.trackOutlineColor,
      trackOutlineWidth: trackOutlineWidth ?? this.trackOutlineWidth,
      materialTapTargetSize:
          materialTapTargetSize ?? this.materialTapTargetSize,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      overlayColor: overlayColor ?? this.overlayColor,
      splashRadius: splashRadius ?? this.splashRadius,
      thumbIcon: thumbIcon ?? this.thumbIcon,
    );
  }

  static SwitchThemeData lerp(
      SwitchThemeData? a, SwitchThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return SwitchThemeData(
      thumbColor: MaterialStateProperty.lerp<Color?>(
          a?.thumbColor, b?.thumbColor, t, Color.lerp),
      trackColor: MaterialStateProperty.lerp<Color?>(
          a?.trackColor, b?.trackColor, t, Color.lerp),
      trackOutlineColor: MaterialStateProperty.lerp<Color?>(
          a?.trackOutlineColor, b?.trackOutlineColor, t, Color.lerp),
      trackOutlineWidth: MaterialStateProperty.lerp<double?>(
          a?.trackOutlineWidth, b?.trackOutlineWidth, t, lerpDouble),
      materialTapTargetSize:
          t < 0.5 ? a?.materialTapTargetSize : b?.materialTapTargetSize,
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      overlayColor: MaterialStateProperty.lerp<Color?>(
          a?.overlayColor, b?.overlayColor, t, Color.lerp),
      splashRadius: lerpDouble(a?.splashRadius, b?.splashRadius, t),
      thumbIcon: t < 0.5 ? a?.thumbIcon : b?.thumbIcon,
    );
  }

  @override
  int get hashCode => Object.hash(
        thumbColor,
        trackColor,
        trackOutlineColor,
        trackOutlineWidth,
        materialTapTargetSize,
        mouseCursor,
        overlayColor,
        splashRadius,
        thumbIcon,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SwitchThemeData &&
        other.thumbColor == thumbColor &&
        other.trackColor == trackColor &&
        other.trackOutlineColor == trackOutlineColor &&
        other.trackOutlineWidth == trackOutlineWidth &&
        other.materialTapTargetSize == materialTapTargetSize &&
        other.mouseCursor == mouseCursor &&
        other.overlayColor == overlayColor &&
        other.splashRadius == splashRadius &&
        other.thumbIcon == thumbIcon;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'thumbColor', thumbColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'trackColor', trackColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'trackOutlineColor', trackOutlineColor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<double?>>(
        'trackOutlineWidth', trackOutlineWidth,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialTapTargetSize>(
        'materialTapTargetSize', materialTapTargetSize,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>(
        'mouseCursor', mouseCursor,
        defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>(
        'overlayColor', overlayColor,
        defaultValue: null));
    properties
        .add(DoubleProperty('splashRadius', splashRadius, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Icon?>>(
        'thumbIcon', thumbIcon,
        defaultValue: null));
  }
}

class SwitchTheme extends InheritedWidget {
  const SwitchTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final SwitchThemeData data;

  static SwitchThemeData of(BuildContext context) {
    final SwitchTheme? switchTheme =
        context.dependOnInheritedWidgetOfExactType<SwitchTheme>();
    return switchTheme?.data ?? Theme.of(context).switchTheme;
  }

  @override
  bool updateShouldNotify(SwitchTheme oldWidget) => data != oldWidget.data;
}
