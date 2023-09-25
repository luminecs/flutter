// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'box.dart';
import 'object.dart';
import 'sliver.dart';
import 'sliver_fixed_extent_list.dart';

class RenderSliverFillViewport extends RenderSliverFixedExtentBoxAdaptor {
  RenderSliverFillViewport({
    required super.childManager,
    double viewportFraction = 1.0,
  }) : assert(viewportFraction > 0.0),
       _viewportFraction = viewportFraction;

  @override
  double get itemExtent => constraints.viewportMainAxisExtent * viewportFraction;

  double get viewportFraction => _viewportFraction;
  double _viewportFraction;
  set viewportFraction(double value) {
    if (_viewportFraction == value) {
      return;
    }
    _viewportFraction = value;
    markNeedsLayout();
  }
}

class RenderSliverFillRemainingWithScrollable extends RenderSliverSingleBoxAdapter {
  RenderSliverFillRemainingWithScrollable({ super.child });

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    final double extent = constraints.remainingPaintExtent - math.min(constraints.overlap, 0.0);

    if (child != null) {
      child!.layout(constraints.asBoxConstraints(
        minExtent: extent,
        maxExtent: extent,
      ));
    }

    final double paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: extent);
    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      scrollExtent: constraints.viewportMainAxisExtent,
      paintExtent: paintedChildSize,
      maxPaintExtent: paintedChildSize,
      hasVisualOverflow: extent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0,
    );
    if (child != null) {
      setChildParentData(child!, constraints, geometry!);
    }
  }
}

class RenderSliverFillRemaining extends RenderSliverSingleBoxAdapter {
  RenderSliverFillRemaining({ super.child });

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    // The remaining space in the viewportMainAxisExtent. Can be <= 0 if we have
    // scrolled beyond the extent of the screen.
    double extent = constraints.viewportMainAxisExtent - constraints.precedingScrollExtent;

    if (child != null) {
      final double childExtent;
      switch (constraints.axis) {
        case Axis.horizontal:
          childExtent = child!.getMaxIntrinsicWidth(constraints.crossAxisExtent);
        case Axis.vertical:
          childExtent = child!.getMaxIntrinsicHeight(constraints.crossAxisExtent);
      }

      // If the childExtent is greater than the computed extent, we want to use
      // that instead of potentially cutting off the child. This allows us to
      // safely specify a maxExtent.
      extent = math.max(extent, childExtent);
      child!.layout(constraints.asBoxConstraints(
        minExtent: extent,
        maxExtent: extent,
      ));
    }

    assert(extent.isFinite,
      'The calculated extent for the child of SliverFillRemaining is not finite. '
      'This can happen if the child is a scrollable, in which case, the '
      'hasScrollBody property of SliverFillRemaining should not be set to '
      'false.',
    );
    final double paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: extent);
    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: paintedChildSize,
      maxPaintExtent: paintedChildSize,
      hasVisualOverflow: extent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0,
    );
    if (child != null) {
      setChildParentData(child!, constraints, geometry!);
    }
  }
}

class RenderSliverFillRemainingAndOverscroll extends RenderSliverSingleBoxAdapter {
  RenderSliverFillRemainingAndOverscroll({ super.child });

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    // The remaining space in the viewportMainAxisExtent. Can be <= 0 if we have
    // scrolled beyond the extent of the screen.
    double extent = constraints.viewportMainAxisExtent - constraints.precedingScrollExtent;
    // The maxExtent includes any overscrolled area. Can be < 0 if we have
    // overscroll in the opposite direction, away from the end of the list.
    double maxExtent = constraints.remainingPaintExtent - math.min(constraints.overlap, 0.0);

    if (child != null) {
      final double childExtent;
      switch (constraints.axis) {
        case Axis.horizontal:
          childExtent = child!.getMaxIntrinsicWidth(constraints.crossAxisExtent);
        case Axis.vertical:
          childExtent = child!.getMaxIntrinsicHeight(constraints.crossAxisExtent);
      }

      // If the childExtent is greater than the computed extent, we want to use
      // that instead of potentially cutting off the child. This allows us to
      // safely specify a maxExtent.
      extent = math.max(extent, childExtent);
      // The extent could be larger than the maxExtent due to a larger child
      // size or overscrolling at the top of the scrollable (rather than at the
      // end where this sliver is).
      maxExtent = math.max(extent, maxExtent);
      child!.layout(constraints.asBoxConstraints(minExtent: extent, maxExtent: maxExtent));
    }

    assert(extent.isFinite,
      'The calculated extent for the child of SliverFillRemaining is not finite. '
      'This can happen if the child is a scrollable, in which case, the '
      'hasScrollBody property of SliverFillRemaining should not be set to '
      'false.',
    );
    final double paintedChildSize = calculatePaintOffset(constraints, from: 0.0, to: extent);
    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: math.min(maxExtent, constraints.remainingPaintExtent),
      maxPaintExtent: maxExtent,
      hasVisualOverflow: extent > constraints.remainingPaintExtent || constraints.scrollOffset > 0.0,
    );
    if (child != null) {
      setChildParentData(child!, constraints, geometry!);
    }
  }
}