import 'dart:math' show max, min;

import 'package:flutter/foundation.dart';

@immutable
abstract class TextScaler {
  const TextScaler();

  const factory TextScaler.linear(double textScaleFactor) = _LinearTextScaler;

  static const TextScaler noScaling = _LinearTextScaler(1.0);

  double scale(double fontSize);

  @Deprecated(
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor;

  TextScaler clamp({ double minScaleFactor = 0, double maxScaleFactor = double.infinity }) {
    assert(maxScaleFactor >= minScaleFactor);
    assert(!maxScaleFactor.isNaN);
    assert(minScaleFactor.isFinite);
    assert(minScaleFactor >= 0);

    return minScaleFactor == maxScaleFactor
      ? TextScaler.linear(minScaleFactor)
      : _ClampedTextScaler(this, minScaleFactor, maxScaleFactor);
  }
}

final class _LinearTextScaler implements TextScaler {
  const _LinearTextScaler(this.textScaleFactor) : assert(textScaleFactor >= 0);

  @override
  final double textScaleFactor;

  @override
  double scale(double fontSize) {
    assert(fontSize >= 0);
    assert(fontSize.isFinite);
    return fontSize * textScaleFactor;
  }

  @override
  TextScaler clamp({ double minScaleFactor = 0, double maxScaleFactor = double.infinity }) {
    assert(maxScaleFactor >= minScaleFactor);
    assert(!maxScaleFactor.isNaN);
    assert(minScaleFactor.isFinite);
    assert(minScaleFactor >= 0);

    final double newScaleFactor = clampDouble(textScaleFactor, minScaleFactor, maxScaleFactor);
    return newScaleFactor == textScaleFactor ? this : _LinearTextScaler(newScaleFactor);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _LinearTextScaler && other.textScaleFactor == textScaleFactor;
  }

  @override
  int get hashCode => textScaleFactor.hashCode;

  @override
  String toString() => textScaleFactor == 1.0 ? 'no scaling' : 'linear (${textScaleFactor}x)';
}

final class _ClampedTextScaler implements TextScaler {
  const _ClampedTextScaler(this.scaler, this.minScale, this.maxScale) : assert(maxScale > minScale);
  final TextScaler scaler;
  final double minScale;
  final double maxScale;

  @override
  double get textScaleFactor => clampDouble(scaler.textScaleFactor, minScale, maxScale);

  @override
  double scale(double fontSize) {
    assert(fontSize >= 0);
    assert(fontSize.isFinite);
    return minScale == maxScale
      ? minScale * fontSize
      : clampDouble(scaler.scale(fontSize), minScale * fontSize, maxScale * fontSize);
  }

  @override
  TextScaler clamp({ double minScaleFactor = 0, double maxScaleFactor = double.infinity }) {
    return minScaleFactor == maxScaleFactor
      ? _LinearTextScaler(minScaleFactor)
      : _ClampedTextScaler(scaler, max(minScaleFactor, minScale), min(maxScaleFactor, maxScale));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _ClampedTextScaler
        && minScale == other.minScale
        && maxScale == other.maxScale
        && (minScale == maxScale || scaler == other.scaler);
  }

  @override
  int get hashCode => minScale == maxScale ? minScale.hashCode : Object.hash(scaler, minScale, maxScale);
}