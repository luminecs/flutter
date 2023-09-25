import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ScrollbarThemeData with Diagnosticable {
  const ScrollbarThemeData({
    this.thumbVisibility,
    this.thickness,
    this.trackVisibility,
    this.radius,
    this.thumbColor,
    this.trackColor,
    this.trackBorderColor,
    this.crossAxisMargin,
    this.mainAxisMargin,
    this.minThumbLength,
    this.interactive,
    @Deprecated(
      'Use ScrollbarThemeData.trackVisibility to resolve based on the current state instead. '
      'This feature was deprecated after v3.4.0-19.0.pre.',
    )
    this.showTrackOnHover,
  });

  final MaterialStateProperty<bool?>? thumbVisibility;

  final MaterialStateProperty<double?>? thickness;

  final MaterialStateProperty<bool?>? trackVisibility;

  @Deprecated(
    'Use ScrollbarThemeData.trackVisibility to resolve based on the current state instead. '
    'This feature was deprecated after v3.4.0-19.0.pre.',
  )
  final bool? showTrackOnHover;

  final bool? interactive;

  final Radius? radius;

  final MaterialStateProperty<Color?>? thumbColor;

  final MaterialStateProperty<Color?>? trackColor;

  final MaterialStateProperty<Color?>? trackBorderColor;

  final double? crossAxisMargin;

  final double? mainAxisMargin;

  final double? minThumbLength;

  ScrollbarThemeData copyWith({
    MaterialStateProperty<bool?>? thumbVisibility,
    MaterialStateProperty<double?>? thickness,
    MaterialStateProperty<bool?>? trackVisibility,
    bool? interactive,
    Radius? radius,
    MaterialStateProperty<Color?>? thumbColor,
    MaterialStateProperty<Color?>? trackColor,
    MaterialStateProperty<Color?>? trackBorderColor,
    double? crossAxisMargin,
    double? mainAxisMargin,
    double? minThumbLength,
    @Deprecated(
      'Use ScrollbarThemeData.trackVisibility to resolve based on the current state instead. '
      'This feature was deprecated after v3.4.0-19.0.pre.',
    )
    bool? showTrackOnHover,
  }) {
    return ScrollbarThemeData(
      thumbVisibility: thumbVisibility ?? this.thumbVisibility,
      thickness: thickness ?? this.thickness,
      trackVisibility: trackVisibility ?? this.trackVisibility,
      showTrackOnHover: showTrackOnHover ?? this.showTrackOnHover,
      interactive: interactive ?? this.interactive,
      radius: radius ?? this.radius,
      thumbColor: thumbColor ?? this.thumbColor,
      trackColor: trackColor ?? this.trackColor,
      trackBorderColor: trackBorderColor ?? this.trackBorderColor,
      crossAxisMargin: crossAxisMargin ?? this.crossAxisMargin,
      mainAxisMargin: mainAxisMargin ?? this.mainAxisMargin,
      minThumbLength: minThumbLength ?? this.minThumbLength,
    );
  }

  static ScrollbarThemeData lerp(ScrollbarThemeData? a, ScrollbarThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return ScrollbarThemeData(
      thumbVisibility: MaterialStateProperty.lerp<bool?>(a?.thumbVisibility, b?.thumbVisibility, t, _lerpBool),
      thickness: MaterialStateProperty.lerp<double?>(a?.thickness, b?.thickness, t, lerpDouble),
      trackVisibility: MaterialStateProperty.lerp<bool?>(a?.trackVisibility, b?.trackVisibility, t, _lerpBool),
      showTrackOnHover: _lerpBool(a?.showTrackOnHover, b?.showTrackOnHover, t),
      interactive: _lerpBool(a?.interactive, b?.interactive, t),
      radius: Radius.lerp(a?.radius, b?.radius, t),
      thumbColor: MaterialStateProperty.lerp<Color?>(a?.thumbColor, b?.thumbColor, t, Color.lerp),
      trackColor: MaterialStateProperty.lerp<Color?>(a?.trackColor, b?.trackColor, t, Color.lerp),
      trackBorderColor: MaterialStateProperty.lerp<Color?>(a?.trackBorderColor, b?.trackBorderColor, t, Color.lerp),
      crossAxisMargin: lerpDouble(a?.crossAxisMargin, b?.crossAxisMargin, t),
      mainAxisMargin: lerpDouble(a?.mainAxisMargin, b?.mainAxisMargin, t),
      minThumbLength: lerpDouble(a?.minThumbLength, b?.minThumbLength, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    thumbVisibility,
    thickness,
    trackVisibility,
    showTrackOnHover,
    interactive,
    radius,
    thumbColor,
    trackColor,
    trackBorderColor,
    crossAxisMargin,
    mainAxisMargin,
    minThumbLength,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ScrollbarThemeData
      && other.thumbVisibility == thumbVisibility
      && other.thickness == thickness
      && other.trackVisibility == trackVisibility
      && other.showTrackOnHover == showTrackOnHover
      && other.interactive == interactive
      && other.radius == radius
      && other.thumbColor == thumbColor
      && other.trackColor == trackColor
      && other.trackBorderColor == trackBorderColor
      && other.crossAxisMargin == crossAxisMargin
      && other.mainAxisMargin == mainAxisMargin
      && other.minThumbLength == minThumbLength;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MaterialStateProperty<bool?>>('thumbVisibility', thumbVisibility, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<double?>>('thickness', thickness, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<bool?>>('trackVisibility', trackVisibility, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('showTrackOnHover', showTrackOnHover, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('interactive', interactive, defaultValue: null));
    properties.add(DiagnosticsProperty<Radius>('radius', radius, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('thumbColor', thumbColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('trackColor', trackColor, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<Color?>>('trackBorderColor', trackBorderColor, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('crossAxisMargin', crossAxisMargin, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('mainAxisMargin', mainAxisMargin, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('minThumbLength', minThumbLength, defaultValue: null));
  }
}

bool? _lerpBool(bool? a, bool? b, double t) => t < 0.5 ? a : b;

class ScrollbarTheme extends InheritedTheme {
  const ScrollbarTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ScrollbarThemeData data;

  static ScrollbarThemeData of(BuildContext context) {
    final ScrollbarTheme? scrollbarTheme = context.dependOnInheritedWidgetOfExactType<ScrollbarTheme>();
    return scrollbarTheme?.data ?? Theme.of(context).scrollbarTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ScrollbarTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ScrollbarTheme oldWidget) => data != oldWidget.data;
}