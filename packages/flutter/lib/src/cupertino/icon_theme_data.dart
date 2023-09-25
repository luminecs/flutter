import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'colors.dart';

class CupertinoIconThemeData extends IconThemeData with Diagnosticable {
  const CupertinoIconThemeData({
    super.size,
    super.fill,
    super.weight,
    super.grade,
    super.opticalSize,
    super.color,
    super.opacity,
    super.shadows,
  });

  @override
  IconThemeData resolve(BuildContext context) {
    final Color? resolvedColor = CupertinoDynamicColor.maybeResolve(color, context);
    return resolvedColor == color ? this : copyWith(color: resolvedColor);
  }

  @override
  CupertinoIconThemeData copyWith({
    double? size,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
    Color? color,
    double? opacity,
    List<Shadow>? shadows,
  }) {
    return CupertinoIconThemeData(
      size: size ?? this.size,
      fill: fill ?? this.fill,
      weight: weight ?? this.weight,
      grade: grade ?? this.grade,
      opticalSize: opticalSize ?? this.opticalSize,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      shadows: shadows ?? this.shadows,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(createCupertinoColorProperty('color', color, defaultValue: null));
  }
}