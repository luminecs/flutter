// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:flutter/foundation.dart';

import 'events.dart';
import 'lsq_solver.dart';

export 'dart:ui' show Offset, PointerDeviceKind;

@immutable
class Velocity {
  const Velocity({
    required this.pixelsPerSecond,
  });

  static const Velocity zero = Velocity(pixelsPerSecond: Offset.zero);

  final Offset pixelsPerSecond;

  Velocity operator -() => Velocity(pixelsPerSecond: -pixelsPerSecond);

  Velocity operator -(Velocity other) {
    return Velocity(pixelsPerSecond: pixelsPerSecond - other.pixelsPerSecond);
  }

  Velocity operator +(Velocity other) {
    return Velocity(pixelsPerSecond: pixelsPerSecond + other.pixelsPerSecond);
  }

  Velocity clampMagnitude(double minValue, double maxValue) {
    assert(minValue >= 0.0);
    assert(maxValue >= 0.0 && maxValue >= minValue);
    final double valueSquared = pixelsPerSecond.distanceSquared;
    if (valueSquared > maxValue * maxValue) {
      return Velocity(pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) * maxValue);
    }
    if (valueSquared < minValue * minValue) {
      return Velocity(pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) * minValue);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    return other is Velocity
        && other.pixelsPerSecond == pixelsPerSecond;
  }

  @override
  int get hashCode => pixelsPerSecond.hashCode;

  @override
  String toString() => 'Velocity(${pixelsPerSecond.dx.toStringAsFixed(1)}, ${pixelsPerSecond.dy.toStringAsFixed(1)})';
}

class VelocityEstimate {
  const VelocityEstimate({
    required this.pixelsPerSecond,
    required this.confidence,
    required this.duration,
    required this.offset,
  });

  final Offset pixelsPerSecond;

  final double confidence;

  final Duration duration;

  final Offset offset;

  @override
  String toString() => 'VelocityEstimate(${pixelsPerSecond.dx.toStringAsFixed(1)}, ${pixelsPerSecond.dy.toStringAsFixed(1)}; offset: $offset, duration: $duration, confidence: ${confidence.toStringAsFixed(1)})';
}

class _PointAtTime {
  const _PointAtTime(this.point, this.time);

  final Duration time;
  final Offset point;

  @override
  String toString() => '_PointAtTime($point at $time)';
}

class VelocityTracker {

  VelocityTracker.withKind(this.kind);

  static const int _assumePointerMoveStoppedMilliseconds = 40;
  static const int _historySize = 20;
  static const int _horizonMilliseconds = 100;
  static const int _minSampleSize = 3;

  final PointerDeviceKind kind;

  // Circular buffer; current sample at _index.
  final List<_PointAtTime?> _samples = List<_PointAtTime?>.filled(_historySize, null);
  int _index = 0;

  void addPosition(Duration time, Offset position) {
    _index += 1;
    if (_index == _historySize) {
      _index = 0;
    }
    _samples[_index] = _PointAtTime(position, time);
  }

  VelocityEstimate? getVelocityEstimate() {
    final List<double> x = <double>[];
    final List<double> y = <double>[];
    final List<double> w = <double>[];
    final List<double> time = <double>[];
    int sampleCount = 0;
    int index = _index;

    final _PointAtTime? newestSample = _samples[index];
    if (newestSample == null) {
      return null;
    }

    _PointAtTime previousSample = newestSample;
    _PointAtTime oldestSample = newestSample;

    // Starting with the most recent PointAtTime sample, iterate backwards while
    // the samples represent continuous motion.
    do {
      final _PointAtTime? sample = _samples[index];
      if (sample == null) {
        break;
      }

      final double age = (newestSample.time - sample.time).inMicroseconds.toDouble() / 1000;
      final double delta = (sample.time - previousSample.time).inMicroseconds.abs().toDouble() / 1000;
      previousSample = sample;
      if (age > _horizonMilliseconds || delta > _assumePointerMoveStoppedMilliseconds) {
        break;
      }

      oldestSample = sample;
      final Offset position = sample.point;
      x.add(position.dx);
      y.add(position.dy);
      w.add(1.0);
      time.add(-age);
      index = (index == 0 ? _historySize : index) - 1;

      sampleCount += 1;
    } while (sampleCount < _historySize);

    if (sampleCount >= _minSampleSize) {
      final LeastSquaresSolver xSolver = LeastSquaresSolver(time, x, w);
      final PolynomialFit? xFit = xSolver.solve(2);
      if (xFit != null) {
        final LeastSquaresSolver ySolver = LeastSquaresSolver(time, y, w);
        final PolynomialFit? yFit = ySolver.solve(2);
        if (yFit != null) {
          return VelocityEstimate( // convert from pixels/ms to pixels/s
            pixelsPerSecond: Offset(xFit.coefficients[1] * 1000, yFit.coefficients[1] * 1000),
            confidence: xFit.confidence * yFit.confidence,
            duration: newestSample.time - oldestSample.time,
            offset: newestSample.point - oldestSample.point,
          );
        }
      }
    }

    // We're unable to make a velocity estimate but we did have at least one
    // valid pointer position.
    return VelocityEstimate(
      pixelsPerSecond: Offset.zero,
      confidence: 1.0,
      duration: newestSample.time - oldestSample.time,
      offset: newestSample.point - oldestSample.point,
    );
  }

  Velocity getVelocity() {
    final VelocityEstimate? estimate = getVelocityEstimate();
    if (estimate == null || estimate.pixelsPerSecond == Offset.zero) {
      return Velocity.zero;
    }
    return Velocity(pixelsPerSecond: estimate.pixelsPerSecond);
  }
}

class IOSScrollViewFlingVelocityTracker extends VelocityTracker {
  IOSScrollViewFlingVelocityTracker(super.kind) : super.withKind();

  static const int _sampleSize = 20;

  final List<_PointAtTime?> _touchSamples = List<_PointAtTime?>.filled(_sampleSize, null);

  @override
  void addPosition(Duration time, Offset position) {
    assert(() {
      final _PointAtTime? previousPoint = _touchSamples[_index];
      if (previousPoint == null || previousPoint.time <= time) {
        return true;
      }
      throw FlutterError(
        'The position being added ($position) has a smaller timestamp ($time) '
        'than its predecessor: $previousPoint.',
      );
    }());
    _index = (_index + 1) % _sampleSize;
    _touchSamples[_index] = _PointAtTime(position, time);
  }

  // Computes the velocity using 2 adjacent points in history. When index = 0,
  // it uses the latest point recorded and the point recorded immediately before
  // it. The smaller index is, the earlier in history the points used are.
  Offset _previousVelocityAt(int index) {
    final int endIndex = (_index + index) % _sampleSize;
    final int startIndex = (_index + index - 1) % _sampleSize;
    final _PointAtTime? end = _touchSamples[endIndex];
    final _PointAtTime? start = _touchSamples[startIndex];

    if (end == null || start == null) {
      return Offset.zero;
    }

    final int dt = (end.time - start.time).inMicroseconds;
    assert(dt >= 0);

    return dt > 0
      // Convert dt to milliseconds to preserve floating point precision.
      ? (end.point - start.point) * 1000 / (dt.toDouble() / 1000)
      : Offset.zero;
  }

  @override
  VelocityEstimate getVelocityEstimate() {
    // The velocity estimated using this expression is an approximation of the
    // scroll velocity of an iOS scroll view at the moment the user touch was
    // released, not the final velocity of the iOS pan gesture recognizer
    // installed on the scroll view would report. Typically in an iOS scroll
    // view the velocity values are different between the two, because the
    // scroll view usually slows down when the touch is released.
    final Offset estimatedVelocity = _previousVelocityAt(-2) * 0.6
                                   + _previousVelocityAt(-1) * 0.35
                                   + _previousVelocityAt(0) * 0.05;

    final _PointAtTime? newestSample = _touchSamples[_index];
    _PointAtTime? oldestNonNullSample;

    for (int i = 1; i <= _sampleSize; i += 1) {
      oldestNonNullSample = _touchSamples[(_index + i) % _sampleSize];
      if (oldestNonNullSample != null) {
        break;
      }
    }

    if (oldestNonNullSample == null || newestSample == null) {
      assert(false, 'There must be at least 1 point in _touchSamples: $_touchSamples');
      return const VelocityEstimate(
        pixelsPerSecond: Offset.zero,
        confidence: 0.0,
        duration: Duration.zero,
        offset: Offset.zero,
      );
    } else {
      return VelocityEstimate(
        pixelsPerSecond: estimatedVelocity,
        confidence: 1.0,
        duration: newestSample.time - oldestNonNullSample.time,
        offset: newestSample.point - oldestNonNullSample.point,
      );
    }
  }
}

class MacOSScrollViewFlingVelocityTracker extends IOSScrollViewFlingVelocityTracker {
  MacOSScrollViewFlingVelocityTracker(super.kind);

  @override
  VelocityEstimate getVelocityEstimate() {
    // The velocity estimated using this expression is an approximation of the
    // scroll velocity of a macOS scroll view at the moment the user touch was
    // released.
    final Offset estimatedVelocity = _previousVelocityAt(-2) * 0.15
                                   + _previousVelocityAt(-1) * 0.65
                                   + _previousVelocityAt(0) * 0.2;

    final _PointAtTime? newestSample = _touchSamples[_index];
    _PointAtTime? oldestNonNullSample;

    for (int i = 1; i <= IOSScrollViewFlingVelocityTracker._sampleSize; i += 1) {
      oldestNonNullSample = _touchSamples[(_index + i) % IOSScrollViewFlingVelocityTracker._sampleSize];
      if (oldestNonNullSample != null) {
        break;
      }
    }

    if (oldestNonNullSample == null || newestSample == null) {
      assert(false, 'There must be at least 1 point in _touchSamples: $_touchSamples');
      return const VelocityEstimate(
        pixelsPerSecond: Offset.zero,
        confidence: 0.0,
        duration: Duration.zero,
        offset: Offset.zero,
      );
    } else {
      return VelocityEstimate(
        pixelsPerSecond: estimatedVelocity,
        confidence: 1.0,
        duration: newestSample.time - oldestNonNullSample.time,
        offset: newestSample.point - oldestNonNullSample.point,
      );
    }
  }
}