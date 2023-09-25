import 'dart:math' as math;
import 'dart:ui' as ui show Shadow, lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'debug.dart';

@immutable
class BoxShadow extends ui.Shadow {
  const BoxShadow({
    super.color,
    super.offset,
    super.blurRadius,
    this.spreadRadius = 0.0,
    this.blurStyle = BlurStyle.normal,
  });

  final double spreadRadius;

  final BlurStyle blurStyle;

  @override
  Paint toPaint() {
    final Paint result = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(blurStyle, blurSigma);
    assert(() {
      if (debugDisableShadows) {
        result.maskFilter = null;
      }
      return true;
    }());
    return result;
  }

  @override
  BoxShadow scale(double factor) {
    return BoxShadow(
      color: color,
      offset: offset * factor,
      blurRadius: blurRadius * factor,
      spreadRadius: spreadRadius * factor,
      blurStyle: blurStyle,
    );
  }

  static BoxShadow? lerp(BoxShadow? a, BoxShadow? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!.scale(t);
    }
    if (b == null) {
      return a.scale(1.0 - t);
    }
    return BoxShadow(
      color: Color.lerp(a.color, b.color, t)!,
      offset: Offset.lerp(a.offset, b.offset, t)!,
      blurRadius: ui.lerpDouble(a.blurRadius, b.blurRadius, t)!,
      spreadRadius: ui.lerpDouble(a.spreadRadius, b.spreadRadius, t)!,
      blurStyle: a.blurStyle == BlurStyle.normal ? b.blurStyle : a.blurStyle,
    );
  }

  static List<BoxShadow>? lerpList(List<BoxShadow>? a, List<BoxShadow>? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    a ??= <BoxShadow>[];
    b ??= <BoxShadow>[];
    final int commonLength = math.min(a.length, b.length);
    return <BoxShadow>[
      for (int i = 0; i < commonLength; i += 1) BoxShadow.lerp(a[i], b[i], t)!,
      for (int i = commonLength; i < a.length; i += 1) a[i].scale(1.0 - t),
      for (int i = commonLength; i < b.length; i += 1) b[i].scale(t),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BoxShadow
        && other.color == color
        && other.offset == offset
        && other.blurRadius == blurRadius
        && other.spreadRadius == spreadRadius
        && other.blurStyle == blurStyle;
  }

  @override
  int get hashCode => Object.hash(color, offset, blurRadius, spreadRadius, blurStyle);

  @override
  String toString() => 'BoxShadow($color, $offset, ${debugFormatDouble(blurRadius)}, ${debugFormatDouble(spreadRadius)}, $blurStyle)';
}