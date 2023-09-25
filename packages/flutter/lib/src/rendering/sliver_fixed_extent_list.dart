import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'box.dart';
import 'sliver.dart';
import 'sliver_multi_box_adaptor.dart';

abstract class RenderSliverFixedExtentBoxAdaptor extends RenderSliverMultiBoxAdaptor {
  RenderSliverFixedExtentBoxAdaptor({
    required super.childManager,
  });

  double? get itemExtent;

  ItemExtentBuilder? get itemExtentBuilder => null;

  @protected
  double indexToLayoutOffset(double itemExtent, int index) {
    if (itemExtentBuilder == null) {
      return itemExtent * index;
    } else {
      double offset = 0.0;
      for (int i = 0; i < index; i++) {
        offset += itemExtentBuilder!(i, _currentLayoutDimensions);
      }
      return offset;
    }
  }

  @protected
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (itemExtentBuilder == null) {
      if (itemExtent > 0.0) {
        final double actual = scrollOffset / itemExtent;
        final int round = actual.round();
        if ((actual * itemExtent - round * itemExtent).abs() < precisionErrorTolerance) {
          return round;
        }
        return actual.floor();
      }
      return 0;
    } else {
      return _getChildIndexForScrollOffset(scrollOffset, itemExtentBuilder!);
    }
  }

  @protected
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (itemExtentBuilder == null) {
      if (itemExtent > 0.0) {
        final double actual = scrollOffset / itemExtent - 1;
        final int round = actual.round();
        if ((actual * itemExtent - round * itemExtent).abs() < precisionErrorTolerance) {
          return math.max(0, round);
        }
        return math.max(0, actual.ceil());
      }
      return 0;
    } else {
      return _getChildIndexForScrollOffset(scrollOffset, itemExtentBuilder!);
    }
  }

  @protected
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    return childManager.estimateMaxScrollOffset(
      constraints,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      leadingScrollOffset: leadingScrollOffset,
      trailingScrollOffset: trailingScrollOffset,
    );
  }

  @protected
  double computeMaxScrollOffset(SliverConstraints constraints, double itemExtent) {
    if (itemExtentBuilder == null) {
      return childManager.childCount * itemExtent;
    } else {
      double offset = 0.0;
      for (int i = 0; i < childManager.childCount; i++) {
        offset += itemExtentBuilder!(i, _currentLayoutDimensions);
      }
      return offset;
    }
  }

  int _calculateLeadingGarbage(int firstIndex) {
    RenderBox? walker = firstChild;
    int leadingGarbage = 0;
    while (walker != null && indexOf(walker) < firstIndex) {
      leadingGarbage += 1;
      walker = childAfter(walker);
    }
    return leadingGarbage;
  }

  int _calculateTrailingGarbage(int targetLastIndex) {
    RenderBox? walker = lastChild;
    int trailingGarbage = 0;
    while (walker != null && indexOf(walker) > targetLastIndex) {
      trailingGarbage += 1;
      walker = childBefore(walker);
    }
    return trailingGarbage;
  }

  int _getChildIndexForScrollOffset(double scrollOffset, ItemExtentBuilder callback) {
    if (scrollOffset == 0.0) {
      return 0;
    }
    double position = 0.0;
    int index = 0;
    while (position < scrollOffset) {
      position += callback(index, _currentLayoutDimensions);
      ++index;
    }
    return index - 1;
  }

  BoxConstraints _getChildConstraints(int index) {
    double extent;
    if (itemExtentBuilder == null) {
      extent = itemExtent!;
    } else {
      extent = itemExtentBuilder!(index, _currentLayoutDimensions);
    }
    return constraints.asBoxConstraints(
      minExtent: extent,
      maxExtent: extent,
    );
  }

  late SliverLayoutDimensions _currentLayoutDimensions;

  @override
  void performLayout() {
    assert((itemExtent != null && itemExtentBuilder == null) ||
        (itemExtent == null && itemExtentBuilder != null));
    assert(itemExtentBuilder != null || (itemExtent!.isFinite && itemExtent! >= 0));

    final SliverConstraints constraints = this.constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double itemFixedExtent = itemExtent ?? 0;
    final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);
    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);
    final double targetEndScrollOffset = scrollOffset + remainingExtent;

    _currentLayoutDimensions = SliverLayoutDimensions(
        scrollOffset: constraints.scrollOffset,
        precedingScrollExtent: constraints.precedingScrollExtent,
        viewportMainAxisExtent: constraints.viewportMainAxisExtent,
        crossAxisExtent: constraints.crossAxisExtent
    );

    final int firstIndex = getMinChildIndexForScrollOffset(scrollOffset, itemFixedExtent);
    final int? targetLastIndex = targetEndScrollOffset.isFinite ?
        getMaxChildIndexForScrollOffset(targetEndScrollOffset, itemFixedExtent) : null;

    if (firstChild != null) {
      final int leadingGarbage = _calculateLeadingGarbage(firstIndex);
      final int trailingGarbage = targetLastIndex != null ? _calculateTrailingGarbage(targetLastIndex) : 0;
      collectGarbage(leadingGarbage, trailingGarbage);
    } else {
      collectGarbage(0, 0);
    }

    if (firstChild == null) {
      if (!addInitialChild(index: firstIndex, layoutOffset: indexToLayoutOffset(itemFixedExtent, firstIndex))) {
        // There are either no children, or we are past the end of all our children.
        final double max;
        if (firstIndex <= 0) {
          max = 0.0;
        } else {
          max = computeMaxScrollOffset(constraints, itemFixedExtent);
        }
        geometry = SliverGeometry(
          scrollExtent: max,
          maxPaintExtent: max,
        );
        childManager.didFinishLayout();
        return;
      }
    }

    RenderBox? trailingChildWithLayout;

    for (int index = indexOf(firstChild!) - 1; index >= firstIndex; --index) {
      final RenderBox? child = insertAndLayoutLeadingChild(_getChildConstraints(index));
      if (child == null) {
        // Items before the previously first child are no longer present.
        // Reset the scroll offset to offset all items prior and up to the
        // missing item. Let parent re-layout everything.
        geometry = SliverGeometry(scrollOffsetCorrection: indexToLayoutOffset(itemFixedExtent, index));
        return;
      }
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = indexToLayoutOffset(itemFixedExtent, index);
      assert(childParentData.index == index);
      trailingChildWithLayout ??= child;
    }

    if (trailingChildWithLayout == null) {
      firstChild!.layout(_getChildConstraints(indexOf(firstChild!)));
      final SliverMultiBoxAdaptorParentData childParentData = firstChild!.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = indexToLayoutOffset(itemFixedExtent, firstIndex);
      trailingChildWithLayout = firstChild;
    }

    double estimatedMaxScrollOffset = double.infinity;
    for (int index = indexOf(trailingChildWithLayout!) + 1; targetLastIndex == null || index <= targetLastIndex; ++index) {
      RenderBox? child = childAfter(trailingChildWithLayout!);
      if (child == null || indexOf(child) != index) {
        child = insertAndLayoutChild(_getChildConstraints(index), after: trailingChildWithLayout);
        if (child == null) {
          // We have run out of children.
          estimatedMaxScrollOffset = indexToLayoutOffset(itemFixedExtent, index);
          break;
        }
      } else {
        child.layout(_getChildConstraints(index));
      }
      trailingChildWithLayout = child;
      final SliverMultiBoxAdaptorParentData childParentData = child.parentData! as SliverMultiBoxAdaptorParentData;
      assert(childParentData.index == index);
      childParentData.layoutOffset = indexToLayoutOffset(itemFixedExtent, childParentData.index!);
    }

    final int lastIndex = indexOf(lastChild!);
    final double leadingScrollOffset = indexToLayoutOffset(itemFixedExtent, firstIndex);
    final double trailingScrollOffset = indexToLayoutOffset(itemFixedExtent, lastIndex + 1);

    assert(firstIndex == 0 || childScrollOffset(firstChild!)! - scrollOffset <= precisionErrorTolerance);
    assert(debugAssertChildListIsNonEmptyAndContiguous());
    assert(indexOf(firstChild!) == firstIndex);
    assert(targetLastIndex == null || lastIndex <= targetLastIndex);

    estimatedMaxScrollOffset = math.min(
      estimatedMaxScrollOffset,
      estimateMaxScrollOffset(
        constraints,
        firstIndex: firstIndex,
        lastIndex: lastIndex,
        leadingScrollOffset: leadingScrollOffset,
        trailingScrollOffset: trailingScrollOffset,
      ),
    );

    final double paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    final double targetEndScrollOffsetForPaint = constraints.scrollOffset + constraints.remainingPaintExtent;
    final int? targetLastIndexForPaint = targetEndScrollOffsetForPaint.isFinite ?
        getMaxChildIndexForScrollOffset(targetEndScrollOffsetForPaint, itemFixedExtent) : null;

    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      // Conservative to avoid flickering away the clip during scroll.
      hasVisualOverflow: (targetLastIndexForPaint != null && lastIndex >= targetLastIndexForPaint)
        || constraints.scrollOffset > 0.0,
    );

    // We may have started the layout while scrolled to the end, which would not
    // expose a new child.
    if (estimatedMaxScrollOffset == trailingScrollOffset) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }
}

class RenderSliverFixedExtentList extends RenderSliverFixedExtentBoxAdaptor {
  RenderSliverFixedExtentList({
    required super.childManager,
    required double itemExtent,
  }) : _itemExtent = itemExtent;

  @override
  double get itemExtent => _itemExtent;
  double _itemExtent;
  set itemExtent(double value) {
    if (_itemExtent == value) {
      return;
    }
    _itemExtent = value;
    markNeedsLayout();
  }
}