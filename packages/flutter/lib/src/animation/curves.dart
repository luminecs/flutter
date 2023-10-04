import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

export 'dart:ui' show Offset;

abstract class ParametricCurve<T> {
  const ParametricCurve();

  T transform(double t) {
    assert(t >= 0.0 && t <= 1.0,
        'parametric value $t is outside of [0, 1] range.');
    return transformInternal(t);
  }

  @protected
  T transformInternal(double t) {
    throw UnimplementedError();
  }

  @override
  String toString() => objectRuntimeType(this, 'ParametricCurve');
}

@immutable
abstract class Curve extends ParametricCurve<double> {
  const Curve();

  @override
  double transform(double t) {
    if (t == 0.0 || t == 1.0) {
      return t;
    }
    return super.transform(t);
  }

  Curve get flipped => FlippedCurve(this);
}

class _Linear extends Curve {
  const _Linear._();

  @override
  double transformInternal(double t) => t;
}

class SawTooth extends Curve {
  const SawTooth(this.count);

  final int count;

  @override
  double transformInternal(double t) {
    t *= count;
    return t - t.truncateToDouble();
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'SawTooth')}($count)';
  }
}

class Interval extends Curve {
  const Interval(this.begin, this.end, {this.curve = Curves.linear});

  final double begin;

  final double end;

  final Curve curve;

  @override
  double transformInternal(double t) {
    assert(begin >= 0.0);
    assert(begin <= 1.0);
    assert(end >= 0.0);
    assert(end <= 1.0);
    assert(end >= begin);
    t = clampDouble((t - begin) / (end - begin), 0.0, 1.0);
    if (t == 0.0 || t == 1.0) {
      return t;
    }
    return curve.transform(t);
  }

  @override
  String toString() {
    if (curve is! _Linear) {
      return '${objectRuntimeType(this, 'Interval')}($begin\u22EF$end)\u27A9$curve';
    }
    return '${objectRuntimeType(this, 'Interval')}($begin\u22EF$end)';
  }
}

class Threshold extends Curve {
  const Threshold(this.threshold);

  final double threshold;

  @override
  double transformInternal(double t) {
    assert(threshold >= 0.0);
    assert(threshold <= 1.0);
    return t < threshold ? 0.0 : 1.0;
  }
}

class Cubic extends Curve {
  const Cubic(this.a, this.b, this.c, this.d);

  final double a;

  final double b;

  final double c;

  final double d;

  static const double _cubicErrorBound = 0.001;

  double _evaluateCubic(double a, double b, double m) {
    return 3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m;
  }

  @override
  double transformInternal(double t) {
    double start = 0.0;
    double end = 1.0;
    while (true) {
      final double midpoint = (start + end) / 2;
      final double estimate = _evaluateCubic(a, c, midpoint);
      if ((t - estimate).abs() < _cubicErrorBound) {
        return _evaluateCubic(b, d, midpoint);
      }
      if (estimate < t) {
        start = midpoint;
      } else {
        end = midpoint;
      }
    }
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'Cubic')}(${a.toStringAsFixed(2)}, ${b.toStringAsFixed(2)}, ${c.toStringAsFixed(2)}, ${d.toStringAsFixed(2)})';
  }
}

class ThreePointCubic extends Curve {
  const ThreePointCubic(this.a1, this.b1, this.midpoint, this.a2, this.b2);

  final Offset a1;

  final Offset b1;

  final Offset midpoint;

  final Offset a2;

  final Offset b2;

  @override
  double transformInternal(double t) {
    final bool firstCurve = t < midpoint.dx;
    final double scaleX = firstCurve ? midpoint.dx : 1.0 - midpoint.dx;
    final double scaleY = firstCurve ? midpoint.dy : 1.0 - midpoint.dy;
    final double scaledT = (t - (firstCurve ? 0.0 : midpoint.dx)) / scaleX;
    if (firstCurve) {
      return Cubic(
            a1.dx / scaleX,
            a1.dy / scaleY,
            b1.dx / scaleX,
            b1.dy / scaleY,
          ).transform(scaledT) *
          scaleY;
    } else {
      return Cubic(
                (a2.dx - midpoint.dx) / scaleX,
                (a2.dy - midpoint.dy) / scaleY,
                (b2.dx - midpoint.dx) / scaleX,
                (b2.dy - midpoint.dy) / scaleY,
              ).transform(scaledT) *
              scaleY +
          midpoint.dy;
    }
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ThreePointCubic($a1, $b1, $midpoint, $a2, $b2)')} ';
  }
}

abstract class Curve2D extends ParametricCurve<Offset> {
  const Curve2D();

  Iterable<Curve2DSample> generateSamples({
    double start = 0.0,
    double end = 1.0,
    double tolerance = 1e-10,
  }) {
    // The sampling algorithm is:
    // 1. Evaluate the area of the triangle (a proxy for the "flatness" of the
    //    curve) formed by two points and a test point.
    // 2. If the area of the triangle is small enough (below tolerance), then
    //    the two points form the final segment.
    // 3. If the area is still too large, divide the interval into two parts
    //    using a random subdivision point to avoid aliasing.
    // 4. Recursively sample the two parts.
    //
    // This algorithm concentrates samples in areas of high curvature.
    assert(end > start);
    // We want to pick a random seed that will keep the result stable if
    // evaluated again, so we use the first non-generated control point.
    final math.Random rand = math.Random(samplingSeed);
    bool isFlat(Offset p, Offset q, Offset r) {
      // Calculates the area of the triangle given by the three points.
      final Offset pr = p - r;
      final Offset qr = q - r;
      final double z = pr.dx * qr.dy - qr.dx * pr.dy;
      return (z * z) < tolerance;
    }

    final Curve2DSample first = Curve2DSample(start, transform(start));
    final Curve2DSample last = Curve2DSample(end, transform(end));
    final List<Curve2DSample> samples = <Curve2DSample>[first];
    void sample(Curve2DSample p, Curve2DSample q,
        {bool forceSubdivide = false}) {
      // Pick a random point somewhat near the center, which avoids aliasing
      // problems with periodic curves.
      final double t = p.t + (0.45 + 0.1 * rand.nextDouble()) * (q.t - p.t);
      final Curve2DSample r = Curve2DSample(t, transform(t));

      if (!forceSubdivide && isFlat(p.value, q.value, r.value)) {
        samples.add(q);
      } else {
        sample(p, r);
        sample(r, q);
      }
    }

    // If the curve starts and ends on the same point, then we force it to
    // subdivide at least once, because otherwise it will terminate immediately.
    sample(
      first,
      last,
      forceSubdivide: (first.value.dx - last.value.dx).abs() < tolerance &&
          (first.value.dy - last.value.dy).abs() < tolerance,
    );
    return samples;
  }

  @protected
  int get samplingSeed => 0;

  double findInverse(double x) {
    double start = 0.0;
    double end = 1.0;
    late double mid;
    double offsetToOrigin(double pos) => x - transform(pos).dx;
    // Use a binary search to find the inverse point within 1e-6, or 100
    // subdivisions, whichever comes first.
    const double errorLimit = 1e-6;
    int count = 100;
    final double startValue = offsetToOrigin(start);
    while ((end - start) / 2.0 > errorLimit && count > 0) {
      mid = (end + start) / 2.0;
      final double value = offsetToOrigin(mid);
      if (value.sign == startValue.sign) {
        start = mid;
      } else {
        end = mid;
      }
      count--;
    }
    return mid;
  }
}

class Curve2DSample {
  const Curve2DSample(this.t, this.value);

  final double t;

  final Offset value;

  @override
  String toString() {
    return '[(${value.dx.toStringAsFixed(2)}, ${value.dy.toStringAsFixed(2)}), ${t.toStringAsFixed(2)}]';
  }
}

class CatmullRomSpline extends Curve2D {
  CatmullRomSpline(
    List<Offset> controlPoints, {
    double tension = 0.0,
    Offset? startHandle,
    Offset? endHandle,
  })  : assert(
            tension <= 1.0, 'tension $tension must not be greater than 1.0.'),
        assert(tension >= 0.0, 'tension $tension must not be negative.'),
        assert(controlPoints.length > 3,
            'There must be at least four control points to create a CatmullRomSpline.'),
        _controlPoints = controlPoints,
        _startHandle = startHandle,
        _endHandle = endHandle,
        _tension = tension,
        _cubicSegments = <List<Offset>>[];

  CatmullRomSpline.precompute(
    List<Offset> controlPoints, {
    double tension = 0.0,
    Offset? startHandle,
    Offset? endHandle,
  })  : assert(
            tension <= 1.0, 'tension $tension must not be greater than 1.0.'),
        assert(tension >= 0.0, 'tension $tension must not be negative.'),
        assert(controlPoints.length > 3,
            'There must be at least four control points to create a CatmullRomSpline.'),
        _controlPoints = null,
        _startHandle = null,
        _endHandle = null,
        _tension = null,
        _cubicSegments = _computeSegments(controlPoints, tension,
            startHandle: startHandle, endHandle: endHandle);

  static List<List<Offset>> _computeSegments(
    List<Offset> controlPoints,
    double tension, {
    Offset? startHandle,
    Offset? endHandle,
  }) {
    assert(
        startHandle == null || startHandle.isFinite,
        'The provided startHandle of CatmullRomSpline must be finite. The '
        'startHandle given was $startHandle.');
    assert(
        endHandle == null || endHandle.isFinite,
        'The provided endHandle of CatmullRomSpline must be finite. The endHandle '
        'given was $endHandle.');
    assert(() {
      for (int index = 0; index < controlPoints.length; index++) {
        if (!controlPoints[index].isFinite) {
          throw FlutterError(
              'The provided CatmullRomSpline control point at index $index is not '
              'finite. The control point given was ${controlPoints[index]}.');
        }
      }
      return true;
    }());
    // If not specified, select the first and last control points (which are
    // handles: they are not intersected by the resulting curve) so that they
    // extend the first and last segments, respectively.
    startHandle ??= controlPoints[0] * 2.0 - controlPoints[1];
    endHandle ??=
        controlPoints.last * 2.0 - controlPoints[controlPoints.length - 2];
    final List<Offset> allPoints = <Offset>[
      startHandle,
      ...controlPoints,
      endHandle,
    ];

    // An alpha of 0.5 is what makes it a centripetal Catmull-Rom spline. A
    // value of 0.0 would make it a uniform Catmull-Rom spline, and a value of
    // 1.0 would make it a chordal Catmull-Rom spline. Non-centripetal values
    // for alpha can give self-intersecting behavior or looping within a
    // segment.
    const double alpha = 0.5;
    final double reverseTension = 1.0 - tension;
    final List<List<Offset>> result = <List<Offset>>[];
    for (int i = 0; i < allPoints.length - 3; ++i) {
      final List<Offset> curve = <Offset>[
        allPoints[i],
        allPoints[i + 1],
        allPoints[i + 2],
        allPoints[i + 3]
      ];
      final Offset diffCurve10 = curve[1] - curve[0];
      final Offset diffCurve21 = curve[2] - curve[1];
      final Offset diffCurve32 = curve[3] - curve[2];
      final double t01 = math.pow(diffCurve10.distance, alpha).toDouble();
      final double t12 = math.pow(diffCurve21.distance, alpha).toDouble();
      final double t23 = math.pow(diffCurve32.distance, alpha).toDouble();

      final Offset m1 = (diffCurve21 +
              (diffCurve10 / t01 - (curve[2] - curve[0]) / (t01 + t12)) * t12) *
          reverseTension;
      final Offset m2 = (diffCurve21 +
              (diffCurve32 / t23 - (curve[3] - curve[1]) / (t12 + t23)) * t12) *
          reverseTension;
      final Offset sumM12 = m1 + m2;

      final List<Offset> segment = <Offset>[
        diffCurve21 * -2.0 + sumM12,
        diffCurve21 * 3.0 - m1 - sumM12,
        m1,
        curve[1],
      ];
      result.add(segment);
    }
    return result;
  }

  // The list of control point lists for each cubic segment of the spline.
  final List<List<Offset>> _cubicSegments;

  // This is non-empty only if the _cubicSegments are being computed lazily.
  final List<Offset>? _controlPoints;
  final Offset? _startHandle;
  final Offset? _endHandle;
  final double? _tension;

  void _initializeIfNeeded() {
    if (_cubicSegments.isNotEmpty) {
      return;
    }
    _cubicSegments.addAll(
      _computeSegments(_controlPoints!, _tension!,
          startHandle: _startHandle, endHandle: _endHandle),
    );
  }

  @override
  @protected
  int get samplingSeed {
    _initializeIfNeeded();
    final Offset seedPoint = _cubicSegments[0][1];
    return ((seedPoint.dx + seedPoint.dy) * 10000).round();
  }

  @override
  Offset transformInternal(double t) {
    _initializeIfNeeded();
    final double length = _cubicSegments.length.toDouble();
    final double position;
    final double localT;
    final int index;
    if (t < 1.0) {
      position = t * length;
      localT = position % 1.0;
      index = position.floor();
    } else {
      position = length;
      localT = 1.0;
      index = _cubicSegments.length - 1;
    }
    final List<Offset> cubicControlPoints = _cubicSegments[index];
    final double localT2 = localT * localT;
    return cubicControlPoints[0] * localT2 * localT +
        cubicControlPoints[1] * localT2 +
        cubicControlPoints[2] * localT +
        cubicControlPoints[3];
  }
}

class CatmullRomCurve extends Curve {
  CatmullRomCurve(this.controlPoints, {this.tension = 0.0})
      : assert(() {
          return validateControlPoints(
            controlPoints,
            tension: tension,
            reasons: _debugAssertReasons..clear(),
          );
        }(),
            'control points $controlPoints could not be validated:\n  ${_debugAssertReasons.join('\n  ')}'),
        // Pre-compute samples so that we don't have to evaluate the spline's inverse
        // all the time in transformInternal.
        _precomputedSamples = <Curve2DSample>[];

  CatmullRomCurve.precompute(this.controlPoints, {this.tension = 0.0})
      : assert(() {
          return validateControlPoints(
            controlPoints,
            tension: tension,
            reasons: _debugAssertReasons..clear(),
          );
        }(),
            'control points $controlPoints could not be validated:\n  ${_debugAssertReasons.join('\n  ')}'),
        // Pre-compute samples so that we don't have to evaluate the spline's inverse
        // all the time in transformInternal.
        _precomputedSamples = _computeSamples(controlPoints, tension);

  static List<Curve2DSample> _computeSamples(
      List<Offset> controlPoints, double tension) {
    return CatmullRomSpline.precompute(
      // Force the first and last control points for the spline to be (0, 0)
      // and (1, 1), respectively.
      <Offset>[Offset.zero, ...controlPoints, const Offset(1.0, 1.0)],
      tension: tension,
    ).generateSamples(tolerance: 1e-12).toList();
  }

  static final List<String> _debugAssertReasons = <String>[];

  // The precomputed approximation curve, so that evaluation of the curve is
  // efficient.
  //
  // If the curve is constructed lazily, then this will be empty, and will be filled
  // the first time transform is called.
  final List<Curve2DSample> _precomputedSamples;

  final List<Offset> controlPoints;

  final double tension;

  static bool validateControlPoints(
    List<Offset>? controlPoints, {
    double tension = 0.0,
    List<String>? reasons,
  }) {
    if (controlPoints == null) {
      assert(() {
        reasons?.add('Supplied control points cannot be null');
        return true;
      }());
      return false;
    }

    if (controlPoints.length < 2) {
      assert(() {
        reasons?.add(
            'There must be at least two points supplied to create a valid curve.');
        return true;
      }());
      return false;
    }

    controlPoints = <Offset>[
      Offset.zero,
      ...controlPoints,
      const Offset(1.0, 1.0)
    ];
    final Offset startHandle = controlPoints[0] * 2.0 - controlPoints[1];
    final Offset endHandle =
        controlPoints.last * 2.0 - controlPoints[controlPoints.length - 2];
    controlPoints = <Offset>[startHandle, ...controlPoints, endHandle];
    double lastX = -double.infinity;
    for (int i = 0; i < controlPoints.length; ++i) {
      if (i > 1 &&
          i < controlPoints.length - 2 &&
          (controlPoints[i].dx <= 0.0 || controlPoints[i].dx >= 1.0)) {
        assert(() {
          reasons?.add(
            'Control points must have X values between 0.0 and 1.0, exclusive. '
            'Point $i has an x value (${controlPoints![i].dx}) which is outside the range.',
          );
          return true;
        }());
        return false;
      }
      if (controlPoints[i].dx <= lastX) {
        assert(() {
          reasons?.add(
            'Each X coordinate must be greater than the preceding X coordinate '
            '(i.e. must be monotonically increasing in X). Point $i has an x value of '
            '${controlPoints![i].dx}, which is not greater than $lastX',
          );
          return true;
        }());
        return false;
      }
      lastX = controlPoints[i].dx;
    }

    bool success = true;

    // An empirical test to make sure things are single-valued in X.
    lastX = -double.infinity;
    const double tolerance = 1e-3;
    final CatmullRomSpline testSpline =
        CatmullRomSpline(controlPoints, tension: tension);
    final double start = testSpline.findInverse(0.0);
    final double end = testSpline.findInverse(1.0);
    final Iterable<Curve2DSample> samplePoints =
        testSpline.generateSamples(start: start, end: end);
    if (samplePoints.first.value.dy.abs() > tolerance ||
        (1.0 - samplePoints.last.value.dy).abs() > tolerance) {
      bool bail = true;
      success = false;
      assert(() {
        reasons?.add(
          'The curve has more than one Y value at X = ${samplePoints.first.value.dx}. '
          'Try moving some control points further away from this value of X, or increasing '
          'the tension.',
        );
        // No need to keep going if we're not giving reasons.
        bail = reasons == null;
        return true;
      }());
      if (bail) {
        // If we're not in debug mode, then we want to bail immediately
        // instead of checking everything else.
        return false;
      }
    }
    for (final Curve2DSample sample in samplePoints) {
      final Offset point = sample.value;
      final double t = sample.t;
      final double x = point.dx;
      if (t >= start && t <= end && (x < -1e-3 || x > 1.0 + 1e-3)) {
        bool bail = true;
        success = false;
        assert(() {
          reasons?.add(
            'The resulting curve has an X value ($x) which is outside '
            'the range [0.0, 1.0], inclusive.',
          );
          // No need to keep going if we're not giving reasons.
          bail = reasons == null;
          return true;
        }());
        if (bail) {
          // If we're not in debug mode, then we want to bail immediately
          // instead of checking all the segments.
          return false;
        }
      }
      if (x < lastX) {
        bool bail = true;
        success = false;
        assert(() {
          reasons?.add(
            'The curve has more than one Y value at x = $x. Try moving '
            'some control points further apart in X, or increasing the tension.',
          );
          // No need to keep going if we're not giving reasons.
          bail = reasons == null;
          return true;
        }());
        if (bail) {
          // If we're not in debug mode, then we want to bail immediately
          // instead of checking all the segments.
          return false;
        }
      }
      lastX = x;
    }
    return success;
  }

  @override
  double transformInternal(double t) {
    // Linearly interpolate between the two closest samples generated when the
    // curve was created.
    if (_precomputedSamples.isEmpty) {
      // Compute the samples now if we were constructed lazily.
      _precomputedSamples.addAll(_computeSamples(controlPoints, tension));
    }
    int start = 0;
    int end = _precomputedSamples.length - 1;
    int mid;
    Offset value;
    Offset startValue = _precomputedSamples[start].value;
    Offset endValue = _precomputedSamples[end].value;
    // Use a binary search to find the index of the sample point that is just
    // before t.
    while (end - start > 1) {
      mid = (end + start) ~/ 2;
      value = _precomputedSamples[mid].value;
      if (t >= value.dx) {
        start = mid;
        startValue = value;
      } else {
        end = mid;
        endValue = value;
      }
    }

    // Now interpolate between the found sample and the next one.
    final double t2 = (t - startValue.dx) / (endValue.dx - startValue.dx);
    return lerpDouble(startValue.dy, endValue.dy, t2)!;
  }
}

class FlippedCurve extends Curve {
  const FlippedCurve(this.curve);

  final Curve curve;

  @override
  double transformInternal(double t) => 1.0 - curve.transform(1.0 - t);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'FlippedCurve')}($curve)';
  }
}

class _DecelerateCurve extends Curve {
  const _DecelerateCurve._();

  @override
  double transformInternal(double t) {
    // Intended to match the behavior of:
    // https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/view/animation/DecelerateInterpolator.java
    // ...as of December 2016.
    t = 1.0 - t;
    return 1.0 - t * t;
  }
}

// BOUNCE CURVES

double _bounce(double t) {
  if (t < 1.0 / 2.75) {
    return 7.5625 * t * t;
  } else if (t < 2 / 2.75) {
    t -= 1.5 / 2.75;
    return 7.5625 * t * t + 0.75;
  } else if (t < 2.5 / 2.75) {
    t -= 2.25 / 2.75;
    return 7.5625 * t * t + 0.9375;
  }
  t -= 2.625 / 2.75;
  return 7.5625 * t * t + 0.984375;
}

class _BounceInCurve extends Curve {
  const _BounceInCurve._();

  @override
  double transformInternal(double t) {
    return 1.0 - _bounce(1.0 - t);
  }
}

class _BounceOutCurve extends Curve {
  const _BounceOutCurve._();

  @override
  double transformInternal(double t) {
    return _bounce(t);
  }
}

class _BounceInOutCurve extends Curve {
  const _BounceInOutCurve._();

  @override
  double transformInternal(double t) {
    if (t < 0.5) {
      return (1.0 - _bounce(1.0 - t * 2.0)) * 0.5;
    } else {
      return _bounce(t * 2.0 - 1.0) * 0.5 + 0.5;
    }
  }
}

// ELASTIC CURVES

class ElasticInCurve extends Curve {
  const ElasticInCurve([this.period = 0.4]);

  final double period;

  @override
  double transformInternal(double t) {
    final double s = period / 4.0;
    t = t - 1.0;
    return -math.pow(2.0, 10.0 * t) *
        math.sin((t - s) * (math.pi * 2.0) / period);
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ElasticInCurve')}($period)';
  }
}

class ElasticOutCurve extends Curve {
  const ElasticOutCurve([this.period = 0.4]);

  final double period;

  @override
  double transformInternal(double t) {
    final double s = period / 4.0;
    return math.pow(2.0, -10 * t) *
            math.sin((t - s) * (math.pi * 2.0) / period) +
        1.0;
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ElasticOutCurve')}($period)';
  }
}

class ElasticInOutCurve extends Curve {
  const ElasticInOutCurve([this.period = 0.4]);

  final double period;

  @override
  double transformInternal(double t) {
    final double s = period / 4.0;
    t = 2.0 * t - 1.0;
    if (t < 0.0) {
      return -0.5 *
          math.pow(2.0, 10.0 * t) *
          math.sin((t - s) * (math.pi * 2.0) / period);
    } else {
      return math.pow(2.0, -10.0 * t) *
              math.sin((t - s) * (math.pi * 2.0) / period) *
              0.5 +
          1.0;
    }
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'ElasticInOutCurve')}($period)';
  }
}

// PREDEFINED CURVES

abstract final class Curves {
  static const Curve linear = _Linear._();

  static const Curve decelerate = _DecelerateCurve._();

  static const Cubic fastLinearToSlowEaseIn = Cubic(0.18, 1.0, 0.04, 1.0);

  static const ThreePointCubic fastEaseInToSlowEaseOut = ThreePointCubic(
    Offset(0.056, 0.024),
    Offset(0.108, 0.3085),
    Offset(0.198, 0.541),
    Offset(0.3655, 1.0),
    Offset(0.5465, 0.989),
  );

  static const Cubic ease = Cubic(0.25, 0.1, 0.25, 1.0);

  static const Cubic easeIn = Cubic(0.42, 0.0, 1.0, 1.0);

  static const Cubic easeInToLinear = Cubic(0.67, 0.03, 0.65, 0.09);

  static const Cubic easeInSine = Cubic(0.47, 0.0, 0.745, 0.715);

  static const Cubic easeInQuad = Cubic(0.55, 0.085, 0.68, 0.53);

  static const Cubic easeInCubic = Cubic(0.55, 0.055, 0.675, 0.19);

  static const Cubic easeInQuart = Cubic(0.895, 0.03, 0.685, 0.22);

  static const Cubic easeInQuint = Cubic(0.755, 0.05, 0.855, 0.06);

  static const Cubic easeInExpo = Cubic(0.95, 0.05, 0.795, 0.035);

  static const Cubic easeInCirc = Cubic(0.6, 0.04, 0.98, 0.335);

  static const Cubic easeInBack = Cubic(0.6, -0.28, 0.735, 0.045);

  static const Cubic easeOut = Cubic(0.0, 0.0, 0.58, 1.0);

  static const Cubic linearToEaseOut = Cubic(0.35, 0.91, 0.33, 0.97);

  static const Cubic easeOutSine = Cubic(0.39, 0.575, 0.565, 1.0);

  static const Cubic easeOutQuad = Cubic(0.25, 0.46, 0.45, 0.94);

  static const Cubic easeOutCubic = Cubic(0.215, 0.61, 0.355, 1.0);

  static const Cubic easeOutQuart = Cubic(0.165, 0.84, 0.44, 1.0);

  static const Cubic easeOutQuint = Cubic(0.23, 1.0, 0.32, 1.0);

  static const Cubic easeOutExpo = Cubic(0.19, 1.0, 0.22, 1.0);

  static const Cubic easeOutCirc = Cubic(0.075, 0.82, 0.165, 1.0);

  static const Cubic easeOutBack = Cubic(0.175, 0.885, 0.32, 1.275);

  static const Cubic easeInOut = Cubic(0.42, 0.0, 0.58, 1.0);

  static const Cubic easeInOutSine = Cubic(0.445, 0.05, 0.55, 0.95);

  static const Cubic easeInOutQuad = Cubic(0.455, 0.03, 0.515, 0.955);

  static const Cubic easeInOutCubic = Cubic(0.645, 0.045, 0.355, 1.0);

  static const ThreePointCubic easeInOutCubicEmphasized = ThreePointCubic(
    Offset(0.05, 0),
    Offset(0.133333, 0.06),
    Offset(0.166666, 0.4),
    Offset(0.208333, 0.82),
    Offset(0.25, 1),
  );

  static const Cubic easeInOutQuart = Cubic(0.77, 0.0, 0.175, 1.0);

  static const Cubic easeInOutQuint = Cubic(0.86, 0.0, 0.07, 1.0);

  static const Cubic easeInOutExpo = Cubic(1.0, 0.0, 0.0, 1.0);

  static const Cubic easeInOutCirc = Cubic(0.785, 0.135, 0.15, 0.86);

  static const Cubic easeInOutBack = Cubic(0.68, -0.55, 0.265, 1.55);

  static const Cubic fastOutSlowIn = Cubic(0.4, 0.0, 0.2, 1.0);

  static const Cubic slowMiddle = Cubic(0.15, 0.85, 0.85, 0.15);

  static const Curve bounceIn = _BounceInCurve._();

  static const Curve bounceOut = _BounceOutCurve._();

  static const Curve bounceInOut = _BounceInOutCurve._();

  static const ElasticInCurve elasticIn = ElasticInCurve();

  static const ElasticOutCurve elasticOut = ElasticOutCurve();

  static const ElasticInOutCurve elasticInOut = ElasticInOutCurve();
}
