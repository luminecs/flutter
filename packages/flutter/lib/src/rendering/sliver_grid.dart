// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'box.dart';
import 'object.dart';
import 'sliver.dart';
import 'sliver_multi_box_adaptor.dart';

@immutable
class SliverGridGeometry {
  const SliverGridGeometry({
    required this.scrollOffset,
    required this.crossAxisOffset,
    required this.mainAxisExtent,
    required this.crossAxisExtent,
  });

  final double scrollOffset;

  final double crossAxisOffset;

  final double mainAxisExtent;

  final double crossAxisExtent;

  double get trailingScrollOffset => scrollOffset + mainAxisExtent;

  BoxConstraints getBoxConstraints(SliverConstraints constraints) {
    return constraints.asBoxConstraints(
      minExtent: mainAxisExtent,
      maxExtent: mainAxisExtent,
      crossAxisExtent: crossAxisExtent,
    );
  }

  @override
  String toString() {
    final List<String> properties = <String>[
      'scrollOffset: $scrollOffset',
      'crossAxisOffset: $crossAxisOffset',
      'mainAxisExtent: $mainAxisExtent',
      'crossAxisExtent: $crossAxisExtent',
    ];
    return 'SliverGridGeometry(${properties.join(', ')})';
  }
}

@immutable
abstract class SliverGridLayout {
  const SliverGridLayout();

  int getMinChildIndexForScrollOffset(double scrollOffset);

  int getMaxChildIndexForScrollOffset(double scrollOffset);

  SliverGridGeometry getGeometryForChildIndex(int index);

  double computeMaxScrollOffset(int childCount);
}

class SliverGridRegularTileLayout extends SliverGridLayout {
  const SliverGridRegularTileLayout({
    required this.crossAxisCount,
    required this.mainAxisStride,
    required this.crossAxisStride,
    required this.childMainAxisExtent,
    required this.childCrossAxisExtent,
    required this.reverseCrossAxis,
  }) : assert(crossAxisCount > 0),
       assert(mainAxisStride >= 0),
       assert(crossAxisStride >= 0),
       assert(childMainAxisExtent >= 0),
       assert(childCrossAxisExtent >= 0);

  final int crossAxisCount;

  final double mainAxisStride;

  final double crossAxisStride;

  final double childMainAxisExtent;

  final double childCrossAxisExtent;

  final bool reverseCrossAxis;

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    return mainAxisStride > precisionErrorTolerance ? crossAxisCount * (scrollOffset ~/ mainAxisStride) : 0;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    if (mainAxisStride > 0.0) {
      final int mainAxisCount = (scrollOffset / mainAxisStride).ceil();
      return math.max(0, crossAxisCount * mainAxisCount - 1);
    }
    return 0;
  }

  double _getOffsetFromStartInCrossAxis(double crossAxisStart) {
    if (reverseCrossAxis) {
      return crossAxisCount * crossAxisStride - crossAxisStart - childCrossAxisExtent - (crossAxisStride - childCrossAxisExtent);
    }
    return crossAxisStart;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final double crossAxisStart = (index % crossAxisCount) * crossAxisStride;
    return SliverGridGeometry(
      scrollOffset: (index ~/ crossAxisCount) * mainAxisStride,
      crossAxisOffset: _getOffsetFromStartInCrossAxis(crossAxisStart),
      mainAxisExtent: childMainAxisExtent,
      crossAxisExtent: childCrossAxisExtent,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0) {
      // There are no children in the grid. The max scroll offset should be
      // zero.
      return 0.0;
    }
    final int mainAxisCount = ((childCount - 1) ~/ crossAxisCount) + 1;
    final double mainAxisSpacing = mainAxisStride - childMainAxisExtent;
    return mainAxisStride * mainAxisCount - mainAxisSpacing;
  }
}

abstract class SliverGridDelegate {
  const SliverGridDelegate();

  SliverGridLayout getLayout(SliverConstraints constraints);

  bool shouldRelayout(covariant SliverGridDelegate oldDelegate);
}

class SliverGridDelegateWithFixedCrossAxisCount extends SliverGridDelegate {
  const SliverGridDelegateWithFixedCrossAxisCount({
    required this.crossAxisCount,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
  }) : assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0);

  final int crossAxisCount;

  final double mainAxisSpacing;

  final double crossAxisSpacing;

  final double childAspectRatio;

  final double? mainAxisExtent;

  bool _debugAssertIsValid() {
    assert(crossAxisCount > 0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    assert(_debugAssertIsValid());
    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = mainAxisExtent ?? childCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithFixedCrossAxisCount oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount
        || oldDelegate.mainAxisSpacing != mainAxisSpacing
        || oldDelegate.crossAxisSpacing != crossAxisSpacing
        || oldDelegate.childAspectRatio != childAspectRatio
        || oldDelegate.mainAxisExtent != mainAxisExtent;
  }
}

class SliverGridDelegateWithMaxCrossAxisExtent extends SliverGridDelegate {
  const SliverGridDelegateWithMaxCrossAxisExtent({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
  }) : assert(maxCrossAxisExtent > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0);

  final double maxCrossAxisExtent;

  final double mainAxisSpacing;

  final double crossAxisSpacing;

  final double childAspectRatio;

  final double? mainAxisExtent;

  bool _debugAssertIsValid(double crossAxisExtent) {
    assert(crossAxisExtent > 0.0);
    assert(maxCrossAxisExtent > 0.0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    assert(_debugAssertIsValid(constraints.crossAxisExtent));
    int crossAxisCount = (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing)).ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = math.max(1, crossAxisCount);
    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = mainAxisExtent ?? childCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithMaxCrossAxisExtent oldDelegate) {
    return oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent
        || oldDelegate.mainAxisSpacing != mainAxisSpacing
        || oldDelegate.crossAxisSpacing != crossAxisSpacing
        || oldDelegate.childAspectRatio != childAspectRatio
        || oldDelegate.mainAxisExtent != mainAxisExtent;
  }
}

class SliverGridParentData extends SliverMultiBoxAdaptorParentData {
  double? crossAxisOffset;

  @override
  String toString() => 'crossAxisOffset=$crossAxisOffset; ${super.toString()}';
}

class RenderSliverGrid extends RenderSliverMultiBoxAdaptor {
  RenderSliverGrid({
    required super.childManager,
    required SliverGridDelegate gridDelegate,
  }) : _gridDelegate = gridDelegate;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverGridParentData) {
      child.parentData = SliverGridParentData();
    }
  }

  SliverGridDelegate get gridDelegate => _gridDelegate;
  SliverGridDelegate _gridDelegate;
  set gridDelegate(SliverGridDelegate value) {
    if (_gridDelegate == value) {
      return;
    }
    if (value.runtimeType != _gridDelegate.runtimeType ||
        value.shouldRelayout(_gridDelegate)) {
      markNeedsLayout();
    }
    _gridDelegate = value;
  }

  @override
  double childCrossAxisPosition(RenderBox child) {
    final SliverGridParentData childParentData = child.parentData! as SliverGridParentData;
    return childParentData.crossAxisOffset!;
  }

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;

    final SliverGridLayout layout = _gridDelegate.getLayout(constraints);

    final int firstIndex = layout.getMinChildIndexForScrollOffset(scrollOffset);
    final int? targetLastIndex = targetEndScrollOffset.isFinite ?
      layout.getMaxChildIndexForScrollOffset(targetEndScrollOffset) : null;

    if (firstChild != null) {
      final int oldFirstIndex = indexOf(firstChild!);
      final int oldLastIndex = indexOf(lastChild!);
      final int leadingGarbage = (firstIndex - oldFirstIndex).clamp(0, childCount); // ignore_clamp_double_lint
      final int trailingGarbage = targetLastIndex == null
        ? 0
        : (oldLastIndex - targetLastIndex).clamp(0, childCount); // ignore_clamp_double_lint
      collectGarbage(leadingGarbage, trailingGarbage);
    } else {
      collectGarbage(0, 0);
    }

    final SliverGridGeometry firstChildGridGeometry = layout.getGeometryForChildIndex(firstIndex);

    if (firstChild == null) {
      if (!addInitialChild(index: firstIndex, layoutOffset: firstChildGridGeometry.scrollOffset)) {
        // There are either no children, or we are past the end of all our children.
        final double max = layout.computeMaxScrollOffset(childManager.childCount);
        geometry = SliverGeometry(
          scrollExtent: max,
          maxPaintExtent: max,
        );
        childManager.didFinishLayout();
        return;
      }
    }

    final double leadingScrollOffset = firstChildGridGeometry.scrollOffset;
    double trailingScrollOffset = firstChildGridGeometry.trailingScrollOffset;
    RenderBox? trailingChildWithLayout;
    bool reachedEnd = false;

    for (int index = indexOf(firstChild!) - 1; index >= firstIndex; --index) {
      final SliverGridGeometry gridGeometry = layout.getGeometryForChildIndex(index);
      final RenderBox child = insertAndLayoutLeadingChild(
        gridGeometry.getBoxConstraints(constraints),
      )!;
      final SliverGridParentData childParentData = child.parentData! as SliverGridParentData;
      childParentData.layoutOffset = gridGeometry.scrollOffset;
      childParentData.crossAxisOffset = gridGeometry.crossAxisOffset;
      assert(childParentData.index == index);
      trailingChildWithLayout ??= child;
      trailingScrollOffset = math.max(trailingScrollOffset, gridGeometry.trailingScrollOffset);
    }

    if (trailingChildWithLayout == null) {
      firstChild!.layout(firstChildGridGeometry.getBoxConstraints(constraints));
      final SliverGridParentData childParentData = firstChild!.parentData! as SliverGridParentData;
      childParentData.layoutOffset = firstChildGridGeometry.scrollOffset;
      childParentData.crossAxisOffset = firstChildGridGeometry.crossAxisOffset;
      trailingChildWithLayout = firstChild;
    }

    for (int index = indexOf(trailingChildWithLayout!) + 1; targetLastIndex == null || index <= targetLastIndex; ++index) {
      final SliverGridGeometry gridGeometry = layout.getGeometryForChildIndex(index);
      final BoxConstraints childConstraints = gridGeometry.getBoxConstraints(constraints);
      RenderBox? child = childAfter(trailingChildWithLayout!);
      if (child == null || indexOf(child) != index) {
        child = insertAndLayoutChild(childConstraints, after: trailingChildWithLayout);
        if (child == null) {
          reachedEnd = true;
          // We have run out of children.
          break;
        }
      } else {
        child.layout(childConstraints);
      }
      trailingChildWithLayout = child;
      final SliverGridParentData childParentData = child.parentData! as SliverGridParentData;
      childParentData.layoutOffset = gridGeometry.scrollOffset;
      childParentData.crossAxisOffset = gridGeometry.crossAxisOffset;
      assert(childParentData.index == index);
      trailingScrollOffset = math.max(trailingScrollOffset, gridGeometry.trailingScrollOffset);
    }

    final int lastIndex = indexOf(lastChild!);

    assert(debugAssertChildListIsNonEmptyAndContiguous());
    assert(indexOf(firstChild!) == firstIndex);
    assert(targetLastIndex == null || lastIndex <= targetLastIndex);

    final double estimatedTotalExtent = reachedEnd
      ? trailingScrollOffset
      : childManager.estimateMaxScrollOffset(
          constraints,
          firstIndex: firstIndex,
          lastIndex: lastIndex,
          leadingScrollOffset: leadingScrollOffset,
          trailingScrollOffset: trailingScrollOffset,
        );
    final double paintExtent = calculatePaintOffset(
      constraints,
      from: math.min(constraints.scrollOffset, leadingScrollOffset),
      to: trailingScrollOffset,
    );
    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    geometry = SliverGeometry(
      scrollExtent: estimatedTotalExtent,
      paintExtent: paintExtent,
      maxPaintExtent: estimatedTotalExtent,
      cacheExtent: cacheExtent,
      hasVisualOverflow: estimatedTotalExtent > paintExtent || constraints.scrollOffset > 0.0 || constraints.overlap != 0.0,
    );

    // We may have started the layout while scrolled to the end, which
    // would not expose a new child.
    if (estimatedTotalExtent == trailingScrollOffset) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }
}