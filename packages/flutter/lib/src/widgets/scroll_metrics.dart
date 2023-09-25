
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

mixin ScrollMetrics {
  ScrollMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    double? devicePixelRatio,
  }) {
    return FixedScrollMetrics(
      minScrollExtent: minScrollExtent ?? (hasContentDimensions ? this.minScrollExtent : null),
      maxScrollExtent: maxScrollExtent ?? (hasContentDimensions ? this.maxScrollExtent : null),
      pixels: pixels ?? (hasPixels ? this.pixels : null),
      viewportDimension: viewportDimension ?? (hasViewportDimension ? this.viewportDimension : null),
      axisDirection: axisDirection ?? this.axisDirection,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }

  double get minScrollExtent;

  double get maxScrollExtent;

  bool get hasContentDimensions;

  double get pixels;

  bool get hasPixels;

  double get viewportDimension;

  bool get hasViewportDimension;

  AxisDirection get axisDirection;

  Axis get axis => axisDirectionToAxis(axisDirection);

  bool get outOfRange => pixels < minScrollExtent || pixels > maxScrollExtent;

  bool get atEdge => pixels == minScrollExtent || pixels == maxScrollExtent;

  double get extentBefore => math.max(pixels - minScrollExtent, 0.0);

  double get extentInside {
    assert(minScrollExtent <= maxScrollExtent);
    return viewportDimension
      // "above" overscroll value
      - clampDouble(minScrollExtent - pixels, 0, viewportDimension)
      // "below" overscroll value
      - clampDouble(pixels - maxScrollExtent, 0, viewportDimension);
  }

  double get extentAfter => math.max(maxScrollExtent - pixels, 0.0);

  double get extentTotal => maxScrollExtent - minScrollExtent + viewportDimension;

  double get devicePixelRatio;
}

class FixedScrollMetrics with ScrollMetrics {
  FixedScrollMetrics({
    required double? minScrollExtent,
    required double? maxScrollExtent,
    required double? pixels,
    required double? viewportDimension,
    required this.axisDirection,
    required this.devicePixelRatio,
  }) : _minScrollExtent = minScrollExtent,
       _maxScrollExtent = maxScrollExtent,
       _pixels = pixels,
       _viewportDimension = viewportDimension;

  @override
  double get minScrollExtent => _minScrollExtent!;
  final double? _minScrollExtent;

  @override
  double get maxScrollExtent => _maxScrollExtent!;
  final double? _maxScrollExtent;

  @override
  bool get hasContentDimensions => _minScrollExtent != null && _maxScrollExtent != null;

  @override
  double get pixels => _pixels!;
  final double? _pixels;

  @override
  bool get hasPixels => _pixels != null;

  @override
  double get viewportDimension => _viewportDimension!;
  final double? _viewportDimension;

  @override
  bool get hasViewportDimension => _viewportDimension != null;

  @override
  final AxisDirection axisDirection;

  @override
  final double devicePixelRatio;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'FixedScrollMetrics')}(${extentBefore.toStringAsFixed(1)}..[${extentInside.toStringAsFixed(1)}]..${extentAfter.toStringAsFixed(1)})';
  }
}