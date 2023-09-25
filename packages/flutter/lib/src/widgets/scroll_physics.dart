import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart' show AxisDirection;
import 'package:flutter/physics.dart';

import 'binding.dart' show WidgetsBinding;
import 'framework.dart';
import 'overscroll_indicator.dart';
import 'scroll_metrics.dart';
import 'scroll_simulation.dart';
import 'view.dart';

export 'package:flutter/physics.dart' show ScrollSpringSimulation, Simulation, Tolerance;

enum ScrollDecelerationRate {
  normal,
  fast
}

// Examples can assume:
// class FooScrollPhysics extends ScrollPhysics {
//   const FooScrollPhysics({ super.parent });
//   @override
//   FooScrollPhysics applyTo(ScrollPhysics? ancestor) {
//     return FooScrollPhysics(parent: buildParent(ancestor));
//   }
// }
// class BarScrollPhysics extends ScrollPhysics {
//   const BarScrollPhysics({ super.parent });
// }

@immutable
class ScrollPhysics {
  const ScrollPhysics({ this.parent });

  final ScrollPhysics? parent;

  @protected
  ScrollPhysics? buildParent(ScrollPhysics? ancestor) => parent?.applyTo(ancestor) ?? ancestor;

  ScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ScrollPhysics(parent: buildParent(ancestor));
  }

  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (parent == null) {
      return offset;
    }
    return parent!.applyPhysicsToUserOffset(position, offset);
  }

  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (!allowUserScrolling) {
      return false;
    }

    if (parent == null) {
      return position.pixels != 0.0 || position.minScrollExtent != position.maxScrollExtent;
    }
    return parent!.shouldAcceptUserOffset(position);
  }

  bool recommendDeferredLoading(double velocity, ScrollMetrics metrics, BuildContext context) {
    if (parent == null) {
      final double maxPhysicalPixels = View.of(context).physicalSize.longestSide;
      return velocity.abs() > maxPhysicalPixels;
    }
    return parent!.recommendDeferredLoading(velocity, metrics, context);
  }

  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (parent == null) {
      return 0.0;
    }
    return parent!.applyBoundaryConditions(position, value);
  }

  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (parent == null) {
      return newPosition.pixels;
    }
    return parent!.adjustPositionForNewDimensions(oldPosition: oldPosition, newPosition: newPosition, isScrolling: isScrolling, velocity: velocity);
  }

  // TODO(gnprice): Some scroll physics in the framework violate that invariant; fix them.
  //   An audit found three cases violating the invariant:
  //     https://github.com/flutter/flutter/issues/120338
  //     https://github.com/flutter/flutter/issues/120340
  //     https://github.com/flutter/flutter/issues/109675
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (parent == null) {
      return null;
    }
    return parent!.createBallisticSimulation(position, velocity);
  }

  static final SpringDescription _kDefaultSpring = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 100.0,
    ratio: 1.1,
  );

  SpringDescription get spring => parent?.spring ?? _kDefaultSpring;

  @Deprecated(
    'Call toleranceFor instead. '
    'This feature was deprecated after v3.7.0-13.0.pre.',
  )
  Tolerance get tolerance {
    return toleranceFor(FixedScrollMetrics(
      minScrollExtent: null,
      maxScrollExtent: null,
      pixels: null,
      viewportDimension: null,
      axisDirection: AxisDirection.down,
      devicePixelRatio: WidgetsBinding.instance.window.devicePixelRatio,
    ));
  }

  Tolerance toleranceFor(ScrollMetrics metrics) {
    return parent?.toleranceFor(metrics) ?? Tolerance(
      velocity: 1.0 / (0.050 * metrics.devicePixelRatio), // logical pixels per second
      distance: 1.0 / metrics.devicePixelRatio, // logical pixels
    );
  }

  double get minFlingDistance => parent?.minFlingDistance ?? kTouchSlop;

  double get minFlingVelocity => parent?.minFlingVelocity ?? kMinFlingVelocity;

  double get maxFlingVelocity => parent?.maxFlingVelocity ?? kMaxFlingVelocity;

  double carriedMomentum(double existingVelocity) {
    if (parent == null) {
      return 0.0;
    }
    return parent!.carriedMomentum(existingVelocity);
  }

  double? get dragStartDistanceMotionThreshold => parent?.dragStartDistanceMotionThreshold;

  bool get allowImplicitScrolling => true;

  bool get allowUserScrolling => true;

  @override
  String toString() {
    if (parent == null) {
      return objectRuntimeType(this, 'ScrollPhysics');
    }
    return '${objectRuntimeType(this, 'ScrollPhysics')} -> $parent';
  }
}

class RangeMaintainingScrollPhysics extends ScrollPhysics {
  const RangeMaintainingScrollPhysics({ super.parent });

  @override
  RangeMaintainingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RangeMaintainingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    bool maintainOverscroll = true;
    bool enforceBoundary = true;
    if (velocity != 0.0) {
      // Don't try to adjust an animating position, the jumping around
      // would be distracting.
      maintainOverscroll = false;
      enforceBoundary = false;
    }
    if ((oldPosition.minScrollExtent == newPosition.minScrollExtent) &&
        (oldPosition.maxScrollExtent == newPosition.maxScrollExtent)) {
      // If the extents haven't changed then ignore overscroll.
      maintainOverscroll = false;
    }
    if (oldPosition.pixels != newPosition.pixels) {
      // If the position has been changed already, then it might have
      // been adjusted to expect new overscroll, so don't try to
      // maintain the relative overscroll.
      maintainOverscroll = false;
      if (oldPosition.minScrollExtent.isFinite && oldPosition.maxScrollExtent.isFinite &&
          newPosition.minScrollExtent.isFinite && newPosition.maxScrollExtent.isFinite) {
        // In addition, if the position changed then we don't enforce the new
        // boundary if both the new and previous boundaries are entirely finite.
        // A common case where the position changes while one
        // of the extents is infinite is a lazily-loaded list. (If the
        // boundaries were finite, and the position changed, then we
        // assume it was intentional.)
        enforceBoundary = false;
      }
    }
    if ((oldPosition.pixels < oldPosition.minScrollExtent) ||
        (oldPosition.pixels > oldPosition.maxScrollExtent)) {
      // If the old position was out of range, then we should
      // not try to keep the new position in range.
      enforceBoundary = false;
    }
    if (maintainOverscroll) {
      // Force the new position to be no more out of range than it was before, if:
      //  * it was overscrolled, and
      //  * the extents have decreased, meaning that some content was removed. The
      //    reason for this condition is that when new content is added, keeping
      //    the same overscroll would mean that instead of showing it to the user,
      //    all of it is being skipped by jumping right to the max extent.
      if (oldPosition.pixels < oldPosition.minScrollExtent &&
          newPosition.minScrollExtent > oldPosition.minScrollExtent) {
        final double oldDelta = oldPosition.minScrollExtent - oldPosition.pixels;
        return newPosition.minScrollExtent - oldDelta;
      }
      if (oldPosition.pixels > oldPosition.maxScrollExtent &&
          newPosition.maxScrollExtent < oldPosition.maxScrollExtent) {
        final double oldDelta = oldPosition.pixels - oldPosition.maxScrollExtent;
        return newPosition.maxScrollExtent + oldDelta;
      }
    }
    // If we're not forcing the overscroll, defer to other physics.
    double result = super.adjustPositionForNewDimensions(oldPosition: oldPosition, newPosition: newPosition, isScrolling: isScrolling, velocity: velocity);
    if (enforceBoundary) {
      // ...but if they put us out of range then reinforce the boundary.
      result = clampDouble(result, newPosition.minScrollExtent, newPosition.maxScrollExtent);
    }
    return result;
  }
}

class BouncingScrollPhysics extends ScrollPhysics {
  const BouncingScrollPhysics({
    this.decelerationRate = ScrollDecelerationRate.normal,
    super.parent,
  });

  final ScrollDecelerationRate decelerationRate;

  @override
  BouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BouncingScrollPhysics(
      parent: buildParent(ancestor),
      decelerationRate: decelerationRate
    );
  }

  double frictionFactor(double overscrollFraction) {
    switch (decelerationRate) {
      case ScrollDecelerationRate.fast:
        return 0.26 * math.pow(1 - overscrollFraction, 2);
      case ScrollDecelerationRate.normal:
        return 0.52 * math.pow(1 - overscrollFraction, 2);
    }
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    assert(offset != 0.0);
    assert(position.minScrollExtent <= position.maxScrollExtent);

    if (!position.outOfRange) {
      return offset;
    }

    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast = math.max(overscrollPastStart, overscrollPastEnd);
    final bool easing = (overscrollPastStart > 0.0 && offset < 0.0)
        || (overscrollPastEnd > 0.0 && offset > 0.0);

    final double friction = easing
        // Apply less resistance when easing the overscroll vs tensioning.
        ? frictionFactor((overscrollPast - offset.abs()) / position.viewportDimension)
        : frictionFactor(overscrollPast / position.viewportDimension);
    final double direction = offset.sign;

    if (easing && decelerationRate == ScrollDecelerationRate.fast) {
      return direction * offset.abs();
    }
    return direction * _applyFriction(overscrollPast, offset.abs(), friction);
  }

  static double _applyFriction(double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) {
        return absDelta * gamma;
      }
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) => 0.0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      double constantDeceleration;
      switch (decelerationRate) {
        case ScrollDecelerationRate.fast:
          constantDeceleration = 1400;
        case ScrollDecelerationRate.normal:
          constantDeceleration = 0;
      }
      return BouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: velocity,
        leadingExtent: position.minScrollExtent,
        trailingExtent: position.maxScrollExtent,
        tolerance: tolerance,
        constantDeceleration: constantDeceleration
      );
    }
    return null;
  }

  // The ballistic simulation here decelerates more slowly than the one for
  // ClampingScrollPhysics so we require a more deliberate input gesture
  // to trigger a fling.
  @override
  double get minFlingVelocity => kMinFlingVelocity * 2.0;

  // Methodology:
  // 1- Use https://github.com/flutter/platform_tests/tree/master/scroll_overlay to test with
  //    Flutter and platform scroll views superimposed.
  // 3- If the scrollables stopped overlapping at any moment, adjust the desired
  //    output value of this function at that input speed.
  // 4- Feed new input/output set into a power curve fitter. Change function
  //    and repeat from 2.
  // 5- Repeat from 2 with medium and slow flings.
  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign *
        math.min(0.000816 * math.pow(existingVelocity.abs(), 1.967).toDouble(), 40000.0);
  }

  // Eyeballed from observation to counter the effect of an unintended scroll
  // from the natural motion of lifting the finger after a scroll.
  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  double get maxFlingVelocity {
    switch (decelerationRate) {
      case ScrollDecelerationRate.fast:
        return kMaxFlingVelocity * 8.0;
      case ScrollDecelerationRate.normal:
        return super.maxFlingVelocity;
    }
  }

  @override
  SpringDescription get spring {
    switch (decelerationRate) {
      case ScrollDecelerationRate.fast:
        return SpringDescription.withDampingRatio(
          mass: 0.3,
          stiffness: 75.0,
          ratio: 1.3,
        );
      case ScrollDecelerationRate.normal:
        return super.spring;
    }
  }
}

class ClampingScrollPhysics extends ScrollPhysics {
  const ClampingScrollPhysics({ super.parent });

  @override
  ClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ClampingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    assert(() {
      if (value == position.pixels) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType.applyBoundaryConditions() was called redundantly.'),
          ErrorDescription(
            'The proposed new position, $value, is exactly equal to the current position of the '
            'given ${position.runtimeType}, ${position.pixels}.\n'
            'The applyBoundaryConditions method should only be called when the value is '
            'going to actually change the pixels, otherwise it is redundant.',
          ),
          DiagnosticsProperty<ScrollPhysics>('The physics object in question was', this, style: DiagnosticsTreeStyle.errorProperty),
          DiagnosticsProperty<ScrollMetrics>('The position object in question was', position, style: DiagnosticsTreeStyle.errorProperty),
        ]);
      }
      return true;
    }());
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      // Underscroll.
      return value - position.pixels;
    }
    if (position.maxScrollExtent <= position.pixels && position.pixels < value) {
      // Overscroll.
      return value - position.pixels;
    }
    if (value < position.minScrollExtent && position.minScrollExtent < position.pixels) {
      // Hit top edge.
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent && position.maxScrollExtent < value) {
      // Hit bottom edge.
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }
      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }
      assert(end != null);
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        end!,
        math.min(0.0, velocity),
        tolerance: tolerance,
      );
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
  }
}

class AlwaysScrollableScrollPhysics extends ScrollPhysics {
  const AlwaysScrollableScrollPhysics({ super.parent });

  @override
  AlwaysScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return AlwaysScrollableScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}

class NeverScrollableScrollPhysics extends ScrollPhysics {
  const NeverScrollableScrollPhysics({ super.parent });

  @override
  NeverScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return NeverScrollableScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool get allowUserScrolling => false;

  @override
  bool get allowImplicitScrolling => false;
}