
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import 'box.dart';
import 'object.dart';
import 'sliver.dart';
import 'viewport.dart';
import 'viewport_offset.dart';

// Trims the specified edges of the given `Rect` [original], so that they do not
// exceed the given values.
Rect? _trim(
  Rect? original, {
  double top = -double.infinity,
  double right = double.infinity,
  double bottom = double.infinity,
  double left = -double.infinity,
}) => original?.intersect(Rect.fromLTRB(left, top, right, bottom));

class OverScrollHeaderStretchConfiguration {
  OverScrollHeaderStretchConfiguration({
    this.stretchTriggerOffset = 100.0,
    this.onStretchTrigger,
  });

  final double stretchTriggerOffset;

  final AsyncCallback? onStretchTrigger;
}

@immutable
class PersistentHeaderShowOnScreenConfiguration {
  const PersistentHeaderShowOnScreenConfiguration({
    this.minShowOnScreenExtent = double.negativeInfinity,
    this.maxShowOnScreenExtent = double.infinity,
  }) : assert(minShowOnScreenExtent <= maxShowOnScreenExtent);

  final double minShowOnScreenExtent;

  final double maxShowOnScreenExtent;
}

abstract class RenderSliverPersistentHeader extends RenderSliver with RenderObjectWithChildMixin<RenderBox>, RenderSliverHelpers {
  RenderSliverPersistentHeader({
    RenderBox? child,
    this.stretchConfiguration,
  }) {
    this.child = child;
  }

  late double _lastStretchOffset;

  double get maxExtent;

  double get minExtent;

  @protected
  double get childExtent {
    if (child == null) {
      return 0.0;
    }
    assert(child!.hasSize);
    switch (constraints.axis) {
      case Axis.vertical:
        return child!.size.height;
      case Axis.horizontal:
        return child!.size.width;
    }
  }

  bool _needsUpdateChild = true;
  double _lastShrinkOffset = 0.0;
  bool _lastOverlapsContent = false;

  OverScrollHeaderStretchConfiguration? stretchConfiguration;

  @protected
  void updateChild(double shrinkOffset, bool overlapsContent) { }

  @override
  void markNeedsLayout() {
    // This is automatically called whenever the child's intrinsic dimensions
    // change, at which point we should remeasure them during the next layout.
    _needsUpdateChild = true;
    super.markNeedsLayout();
  }

  @protected
  void layoutChild(double scrollOffset, double maxExtent, { bool overlapsContent = false }) {
    final double shrinkOffset = math.min(scrollOffset, maxExtent);
    if (_needsUpdateChild || _lastShrinkOffset != shrinkOffset || _lastOverlapsContent != overlapsContent) {
      invokeLayoutCallback<SliverConstraints>((SliverConstraints constraints) {
        assert(constraints == this.constraints);
        updateChild(shrinkOffset, overlapsContent);
      });
      _lastShrinkOffset = shrinkOffset;
      _lastOverlapsContent = overlapsContent;
      _needsUpdateChild = false;
    }
    assert(() {
      if (minExtent <= maxExtent) {
        return true;
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('The maxExtent for this $runtimeType is less than its minExtent.'),
        DoubleProperty('The specified maxExtent was', maxExtent),
        DoubleProperty('The specified minExtent was', minExtent),
      ]);
    }());
    double stretchOffset = 0.0;
    if (stretchConfiguration != null && constraints.scrollOffset == 0.0) {
      stretchOffset += constraints.overlap.abs();
    }

    child?.layout(
      constraints.asBoxConstraints(
        maxExtent: math.max(minExtent, maxExtent - shrinkOffset) + stretchOffset,
      ),
      parentUsesSize: true,
    );

    if (stretchConfiguration != null &&
      stretchConfiguration!.onStretchTrigger != null &&
      stretchOffset >= stretchConfiguration!.stretchTriggerOffset &&
      _lastStretchOffset <= stretchConfiguration!.stretchTriggerOffset) {
      stretchConfiguration!.onStretchTrigger!();
    }
    _lastStretchOffset = stretchOffset;
  }

  @override
  double childMainAxisPosition(covariant RenderObject child) => super.childMainAxisPosition(child);

  @override
  bool hitTestChildren(SliverHitTestResult result, { required double mainAxisPosition, required double crossAxisPosition }) {
    assert(geometry!.hitTestExtent > 0.0);
    if (child != null) {
      return hitTestBoxChild(BoxHitTestResult.wrap(result), child!, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    assert(child == this.child);
    applyPaintTransformForBoxChild(child as RenderBox, transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && geometry!.visible) {
      switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
        case AxisDirection.up:
          offset += Offset(0.0, geometry!.paintExtent - childMainAxisPosition(child!) - childExtent);
        case AxisDirection.down:
          offset += Offset(0.0, childMainAxisPosition(child!));
        case AxisDirection.left:
          offset += Offset(geometry!.paintExtent - childMainAxisPosition(child!) - childExtent, 0.0);
        case AxisDirection.right:
          offset += Offset(childMainAxisPosition(child!), 0.0);
      }
      context.paintChild(child!, offset);
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.addTagForChildren(RenderViewport.excludeFromScrolling);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty.lazy('maxExtent', () => maxExtent));
    properties.add(DoubleProperty.lazy('child position', () => childMainAxisPosition(child!)));
  }
}

abstract class RenderSliverScrollingPersistentHeader extends RenderSliverPersistentHeader {
  RenderSliverScrollingPersistentHeader({
    super.child,
    super.stretchConfiguration,
  });

  // Distance from our leading edge to the child's leading edge, in the axis
  // direction. Negative if we're scrolled off the top.
  double? _childPosition;

  @protected
  double updateGeometry() {
    double stretchOffset = 0.0;
    if (stretchConfiguration != null) {
      stretchOffset += constraints.overlap.abs();
    }
    final double maxExtent = this.maxExtent;
    final double paintExtent = maxExtent - constraints.scrollOffset;
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: math.min(constraints.overlap, 0.0),
      paintExtent: clampDouble(paintExtent, 0.0, constraints.remainingPaintExtent),
      maxPaintExtent: maxExtent + stretchOffset,
      hasVisualOverflow: true, // Conservatively say we do have overflow to avoid complexity.
    );
    return stretchOffset > 0 ? 0.0 : math.min(0.0, paintExtent - childExtent);
  }


  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    final double maxExtent = this.maxExtent;
    layoutChild(constraints.scrollOffset, maxExtent);
    final double paintExtent = maxExtent - constraints.scrollOffset;
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: math.min(constraints.overlap, 0.0),
      paintExtent: clampDouble(paintExtent, 0.0, constraints.remainingPaintExtent),
      maxPaintExtent: maxExtent,
      hasVisualOverflow: true, // Conservatively say we do have overflow to avoid complexity.
    );
    _childPosition = updateGeometry();
  }

  @override
  double childMainAxisPosition(RenderBox child) {
    assert(child == this.child);
    assert(_childPosition != null);
    return _childPosition!;
  }
}

abstract class RenderSliverPinnedPersistentHeader extends RenderSliverPersistentHeader {
  RenderSliverPinnedPersistentHeader({
    super.child,
    super.stretchConfiguration,
    this.showOnScreenConfiguration = const PersistentHeaderShowOnScreenConfiguration(),
  });

  PersistentHeaderShowOnScreenConfiguration? showOnScreenConfiguration;

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    final double maxExtent = this.maxExtent;
    final bool overlapsContent = constraints.overlap > 0.0;
    layoutChild(constraints.scrollOffset, maxExtent, overlapsContent: overlapsContent);
    final double effectiveRemainingPaintExtent = math.max(0, constraints.remainingPaintExtent - constraints.overlap);
    final double layoutExtent = clampDouble(maxExtent - constraints.scrollOffset, 0.0, effectiveRemainingPaintExtent);
    final double stretchOffset = stretchConfiguration != null ?
      constraints.overlap.abs() :
      0.0;
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: constraints.overlap,
      paintExtent: math.min(childExtent, effectiveRemainingPaintExtent),
      layoutExtent: layoutExtent,
      maxPaintExtent: maxExtent + stretchOffset,
      maxScrollObstructionExtent: minExtent,
      cacheExtent: layoutExtent > 0.0 ? -constraints.cacheOrigin + layoutExtent : layoutExtent,
      hasVisualOverflow: true, // Conservatively say we do have overflow to avoid complexity.
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) => 0.0;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final Rect? localBounds = descendant != null
      ? MatrixUtils.transformRect(descendant.getTransformTo(this), rect ?? descendant.paintBounds)
      : rect;

    Rect? newRect;
    switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
      case AxisDirection.up:
        newRect = _trim(localBounds, bottom: childExtent);
      case AxisDirection.right:
        newRect = _trim(localBounds, left: 0);
      case AxisDirection.down:
        newRect = _trim(localBounds, top: 0);
      case AxisDirection.left:
        newRect = _trim(localBounds, right: childExtent);
    }

    super.showOnScreen(
      descendant: this,
      rect: newRect,
      duration: duration,
      curve: curve,
    );
  }
}

class FloatingHeaderSnapConfiguration {
  FloatingHeaderSnapConfiguration({
    this.curve = Curves.ease,
    this.duration = const Duration(milliseconds: 300),
  });

  final Curve curve;

  final Duration duration;
}

abstract class RenderSliverFloatingPersistentHeader extends RenderSliverPersistentHeader {
  RenderSliverFloatingPersistentHeader({
    super.child,
    TickerProvider? vsync,
    this.snapConfiguration,
    super.stretchConfiguration,
    required this.showOnScreenConfiguration,
  }) : _vsync = vsync;

  AnimationController? _controller;
  late Animation<double> _animation;
  double? _lastActualScrollOffset;
  double? _effectiveScrollOffset;
  // Important for pointer scrolling, which does not have the same concept of
  // a hold and release scroll movement, like dragging.
  // This keeps track of the last ScrollDirection when scrolling started.
  ScrollDirection? _lastStartedScrollDirection;

  // Distance from our leading edge to the child's leading edge, in the axis
  // direction. Negative if we're scrolled off the top.
  double? _childPosition;

  @override
  void detach() {
    _controller?.dispose();
    _controller = null; // lazily recreated if we're reattached.
    super.detach();
  }


  TickerProvider? get vsync => _vsync;
  TickerProvider? _vsync;
  set vsync(TickerProvider? value) {
    if (value == _vsync) {
      return;
    }
    _vsync = value;
    if (value == null) {
      _controller?.dispose();
      _controller = null;
    } else {
      _controller?.resync(value);
    }
  }

  FloatingHeaderSnapConfiguration? snapConfiguration;

  PersistentHeaderShowOnScreenConfiguration? showOnScreenConfiguration;

  @protected
  double updateGeometry() {
    double stretchOffset = 0.0;
    if (stretchConfiguration != null) {
      stretchOffset += constraints.overlap.abs();
    }
    final double maxExtent = this.maxExtent;
    final double paintExtent = maxExtent - _effectiveScrollOffset!;
    final double layoutExtent = maxExtent - constraints.scrollOffset;
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: math.min(constraints.overlap, 0.0),
      paintExtent: clampDouble(paintExtent, 0.0, constraints.remainingPaintExtent),
      layoutExtent: clampDouble(layoutExtent, 0.0, constraints.remainingPaintExtent),
      maxPaintExtent: maxExtent + stretchOffset,
      hasVisualOverflow: true, // Conservatively say we do have overflow to avoid complexity.
    );
    return stretchOffset > 0 ? 0.0 : math.min(0.0, paintExtent - childExtent);
  }

  void _updateAnimation(Duration duration, double endValue, Curve curve) {
    assert(
      vsync != null,
      'vsync must not be null if the floating header changes size animatedly.',
    );

    final AnimationController effectiveController =
      _controller ??= AnimationController(vsync: vsync!, duration: duration)
        ..addListener(() {
            if (_effectiveScrollOffset == _animation.value) {
              return;
            }
            _effectiveScrollOffset = _animation.value;
            markNeedsLayout();
          });

    _animation = effectiveController.drive(
      Tween<double>(
        begin: _effectiveScrollOffset,
        end: endValue,
      ).chain(CurveTween(curve: curve)),
    );
  }

  // ignore: use_setters_to_change_properties, (API predates enforcing the lint)
  void updateScrollStartDirection(ScrollDirection direction) {
    _lastStartedScrollDirection = direction;
  }

  void maybeStartSnapAnimation(ScrollDirection direction) {
    final FloatingHeaderSnapConfiguration? snap = snapConfiguration;
    if (snap == null) {
      return;
    }
    if (direction == ScrollDirection.forward && _effectiveScrollOffset! <= 0.0) {
      return;
    }
    if (direction == ScrollDirection.reverse && _effectiveScrollOffset! >= maxExtent) {
      return;
    }

    _updateAnimation(
      snap.duration,
      direction == ScrollDirection.forward ? 0.0 : maxExtent,
      snap.curve,
    );
    _controller?.forward(from: 0.0);
  }

  void maybeStopSnapAnimation(ScrollDirection direction) {
    _controller?.stop();
  }

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    final double maxExtent = this.maxExtent;
    if (_lastActualScrollOffset != null && // We've laid out at least once to get an initial position, and either
        ((constraints.scrollOffset < _lastActualScrollOffset!) || // we are scrolling back, so should reveal, or
         (_effectiveScrollOffset! < maxExtent))) { // some part of it is visible, so should shrink or reveal as appropriate.
      double delta = _lastActualScrollOffset! - constraints.scrollOffset;

      final bool allowFloatingExpansion = constraints.userScrollDirection == ScrollDirection.forward
        || (_lastStartedScrollDirection != null && _lastStartedScrollDirection == ScrollDirection.forward);
      if (allowFloatingExpansion) {
        if (_effectiveScrollOffset! > maxExtent) {
          // We're scrolled off-screen, but should reveal, so pretend we're just at the limit.
          _effectiveScrollOffset = maxExtent;
        }
      } else {
        if (delta > 0.0) {
          // Disallow the expansion. (But allow shrinking, i.e. delta < 0.0 is fine.)
          delta = 0.0;
        }
      }
      _effectiveScrollOffset = clampDouble(_effectiveScrollOffset! - delta, 0.0, constraints.scrollOffset);
    } else {
      _effectiveScrollOffset = constraints.scrollOffset;
    }
    final bool overlapsContent = _effectiveScrollOffset! < constraints.scrollOffset;

    layoutChild(
      _effectiveScrollOffset!,
      maxExtent,
      overlapsContent: overlapsContent,
    );
    _childPosition = updateGeometry();
    _lastActualScrollOffset = constraints.scrollOffset;
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final PersistentHeaderShowOnScreenConfiguration? showOnScreen = showOnScreenConfiguration;
    if (showOnScreen == null) {
      return super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
    }

    assert(child != null || descendant == null);
    // We prefer the child's coordinate space (instead of the sliver's) because
    // it's easier for us to convert the target rect into target extents: when
    // the sliver is sitting above the leading edge (not possible with pinned
    // headers), the leading edge of the sliver and the leading edge of the child
    // will not be aligned. The only exception is when child is null (and thus
    // descendant == null).
    final Rect? childBounds = descendant != null
      ? MatrixUtils.transformRect(descendant.getTransformTo(child), rect ?? descendant.paintBounds)
      : rect;

    double targetExtent;
    Rect? targetRect;
    switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
      case AxisDirection.up:
        targetExtent = childExtent - (childBounds?.top ?? 0);
        targetRect = _trim(childBounds, bottom: childExtent);
      case AxisDirection.right:
        targetExtent = childBounds?.right ?? childExtent;
        targetRect = _trim(childBounds, left: 0);
      case AxisDirection.down:
        targetExtent = childBounds?.bottom ?? childExtent;
        targetRect = _trim(childBounds, top: 0);
      case AxisDirection.left:
        targetExtent = childExtent - (childBounds?.left ?? 0);
        targetRect = _trim(childBounds, right: childExtent);
    }

    // A stretch header can have a bigger childExtent than maxExtent.
    final double effectiveMaxExtent = math.max(childExtent, maxExtent);

    targetExtent = clampDouble(
        clampDouble(
          targetExtent,
          showOnScreen.minShowOnScreenExtent,
          showOnScreen.maxShowOnScreenExtent,
        ),
        // Clamp the value back to the valid range after applying additional
        // constraints. Contracting is not allowed.
        childExtent,
        effectiveMaxExtent);

    // Expands the header if needed, with animation.
    if (targetExtent > childExtent) {
      final double targetScrollOffset = maxExtent - targetExtent;
      assert(
        vsync != null,
        'vsync must not be null if the floating header changes size animatedly.',
      );
      _updateAnimation(duration, targetScrollOffset, curve);
      _controller?.forward(from: 0.0);
    }

    super.showOnScreen(
      descendant: descendant == null ? this : child,
      rect: targetRect,
      duration: duration,
      curve: curve,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) {
    assert(child == this.child);
    return _childPosition ?? 0.0;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('effective scroll offset', _effectiveScrollOffset));
  }
}

abstract class RenderSliverFloatingPinnedPersistentHeader extends RenderSliverFloatingPersistentHeader {
  RenderSliverFloatingPinnedPersistentHeader({
    super.child,
    super.vsync,
    super.snapConfiguration,
    super.stretchConfiguration,
    super.showOnScreenConfiguration,
  });

  @override
  double updateGeometry() {
    final double minExtent = this.minExtent;
    final double minAllowedExtent = constraints.remainingPaintExtent > minExtent ?
      minExtent :
      constraints.remainingPaintExtent;
    final double maxExtent = this.maxExtent;
    final double paintExtent = maxExtent - _effectiveScrollOffset!;
    final double clampedPaintExtent = clampDouble(paintExtent,
      minAllowedExtent,
      constraints.remainingPaintExtent,
    );
    final double layoutExtent = maxExtent - constraints.scrollOffset;
    final double stretchOffset = stretchConfiguration != null ?
      constraints.overlap.abs() :
      0.0;
    geometry = SliverGeometry(
      scrollExtent: maxExtent,
      paintOrigin: math.min(constraints.overlap, 0.0),
      paintExtent: clampedPaintExtent,
      layoutExtent: clampDouble(layoutExtent, 0.0, clampedPaintExtent),
      maxPaintExtent: maxExtent + stretchOffset,
      maxScrollObstructionExtent: minExtent,
      hasVisualOverflow: true, // Conservatively say we do have overflow to avoid complexity.
    );
    return 0.0;
  }
}