import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'actions.dart';
import 'basic.dart';
import 'framework.dart';
import 'primary_scroll_controller.dart';
import 'scroll_configuration.dart';
import 'scroll_controller.dart';
import 'scroll_metrics.dart';
import 'scroll_physics.dart';
import 'scrollable.dart';

export 'package:flutter/physics.dart' show Tolerance;

@immutable
class ScrollableDetails {
  const ScrollableDetails({
    required this.direction,
    this.controller,
    this.physics,
    @Deprecated('Migrate to decorationClipBehavior. '
        'This property was deprecated so that its application is clearer. This clip '
        'applies to decorators, and does not directly clip a scroll view. '
        'This feature was deprecated after v3.9.0-1.0.pre.')
    Clip? clipBehavior,
    Clip? decorationClipBehavior,
  }) : decorationClipBehavior = clipBehavior ?? decorationClipBehavior;

  const ScrollableDetails.vertical({
    bool reverse = false,
    this.controller,
    this.physics,
    this.decorationClipBehavior,
  }) : direction = reverse ? AxisDirection.up : AxisDirection.down;

  const ScrollableDetails.horizontal({
    bool reverse = false,
    this.controller,
    this.physics,
    this.decorationClipBehavior,
  }) : direction = reverse ? AxisDirection.left : AxisDirection.right;

  final AxisDirection direction;

  final ScrollController? controller;

  final ScrollPhysics? physics;

  final Clip? decorationClipBehavior;

  @Deprecated('Migrate to decorationClipBehavior. '
      'This property was deprecated so that its application is clearer. This clip '
      'applies to decorators, and does not directly clip a scroll view. '
      'This feature was deprecated after v3.9.0-1.0.pre.')
  Clip? get clipBehavior => decorationClipBehavior;

  ScrollableDetails copyWith({
    AxisDirection? direction,
    ScrollController? controller,
    ScrollPhysics? physics,
    Clip? decorationClipBehavior,
  }) {
    return ScrollableDetails(
      direction: direction ?? this.direction,
      controller: controller ?? this.controller,
      physics: physics ?? this.physics,
      decorationClipBehavior:
          decorationClipBehavior ?? this.decorationClipBehavior,
    );
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    description.add('axisDirection: $direction');

    void addIfNonNull(String prefix, Object? value) {
      if (value != null) {
        description.add(prefix + value.toString());
      }
    }

    addIfNonNull('scroll controller: ', controller);
    addIfNonNull('scroll physics: ', physics);
    addIfNonNull('decorationClipBehavior: ', decorationClipBehavior);
    return '${describeIdentity(this)}(${description.join(", ")})';
  }

  @override
  int get hashCode => Object.hash(
        direction,
        controller,
        physics,
        decorationClipBehavior,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ScrollableDetails &&
        other.direction == direction &&
        other.controller == controller &&
        other.physics == physics &&
        other.decorationClipBehavior == decorationClipBehavior;
  }
}

class EdgeDraggingAutoScroller {
  EdgeDraggingAutoScroller(
    this.scrollable, {
    this.onScrollViewScrolled,
    required this.velocityScalar,
  });

  final ScrollableState scrollable;

  final VoidCallback? onScrollViewScrolled;

  final double velocityScalar;

  late Rect _dragTargetRelatedToScrollOrigin;

  bool get scrolling => _scrolling;
  bool _scrolling = false;

  double _offsetExtent(Offset offset, Axis scrollDirection) {
    switch (scrollDirection) {
      case Axis.horizontal:
        return offset.dx;
      case Axis.vertical:
        return offset.dy;
    }
  }

  double _sizeExtent(Size size, Axis scrollDirection) {
    switch (scrollDirection) {
      case Axis.horizontal:
        return size.width;
      case Axis.vertical:
        return size.height;
    }
  }

  AxisDirection get _axisDirection => scrollable.axisDirection;
  Axis get _scrollDirection => axisDirectionToAxis(_axisDirection);

  void startAutoScrollIfNecessary(Rect dragTarget) {
    final Offset deltaToOrigin = scrollable.deltaToScrollOrigin;
    _dragTargetRelatedToScrollOrigin =
        dragTarget.translate(deltaToOrigin.dx, deltaToOrigin.dy);
    if (_scrolling) {
      // The change will be picked up in the next scroll.
      return;
    }
    assert(!_scrolling);
    _scroll();
  }

  void stopAutoScroll() {
    _scrolling = false;
  }

  Future<void> _scroll() async {
    final RenderBox scrollRenderBox =
        scrollable.context.findRenderObject()! as RenderBox;
    final Rect globalRect = MatrixUtils.transformRect(
      scrollRenderBox.getTransformTo(null),
      Rect.fromLTWH(
          0, 0, scrollRenderBox.size.width, scrollRenderBox.size.height),
    );
    assert(
      globalRect.size.width >= _dragTargetRelatedToScrollOrigin.size.width &&
          globalRect.size.height >=
              _dragTargetRelatedToScrollOrigin.size.height,
      'Drag target size is larger than scrollable size, which may cause bouncing',
    );
    _scrolling = true;
    double? newOffset;
    const double overDragMax = 20.0;

    final Offset deltaToOrigin = scrollable.deltaToScrollOrigin;
    final Offset viewportOrigin =
        globalRect.topLeft.translate(deltaToOrigin.dx, deltaToOrigin.dy);
    final double viewportStart =
        _offsetExtent(viewportOrigin, _scrollDirection);
    final double viewportEnd =
        viewportStart + _sizeExtent(globalRect.size, _scrollDirection);

    final double proxyStart = _offsetExtent(
        _dragTargetRelatedToScrollOrigin.topLeft, _scrollDirection);
    final double proxyEnd = _offsetExtent(
        _dragTargetRelatedToScrollOrigin.bottomRight, _scrollDirection);
    switch (_axisDirection) {
      case AxisDirection.up:
      case AxisDirection.left:
        if (proxyEnd > viewportEnd &&
            scrollable.position.pixels > scrollable.position.minScrollExtent) {
          final double overDrag = math.min(proxyEnd - viewportEnd, overDragMax);
          newOffset = math.max(scrollable.position.minScrollExtent,
              scrollable.position.pixels - overDrag);
        } else if (proxyStart < viewportStart &&
            scrollable.position.pixels < scrollable.position.maxScrollExtent) {
          final double overDrag =
              math.min(viewportStart - proxyStart, overDragMax);
          newOffset = math.min(scrollable.position.maxScrollExtent,
              scrollable.position.pixels + overDrag);
        }
      case AxisDirection.right:
      case AxisDirection.down:
        if (proxyStart < viewportStart &&
            scrollable.position.pixels > scrollable.position.minScrollExtent) {
          final double overDrag =
              math.min(viewportStart - proxyStart, overDragMax);
          newOffset = math.max(scrollable.position.minScrollExtent,
              scrollable.position.pixels - overDrag);
        } else if (proxyEnd > viewportEnd &&
            scrollable.position.pixels < scrollable.position.maxScrollExtent) {
          final double overDrag = math.min(proxyEnd - viewportEnd, overDragMax);
          newOffset = math.min(scrollable.position.maxScrollExtent,
              scrollable.position.pixels + overDrag);
        }
    }

    if (newOffset == null ||
        (newOffset - scrollable.position.pixels).abs() < 1.0) {
      // Drag should not trigger scroll.
      _scrolling = false;
      return;
    }
    final Duration duration =
        Duration(milliseconds: (1000 / velocityScalar).round());
    await scrollable.position.animateTo(
      newOffset,
      duration: duration,
      curve: Curves.linear,
    );
    if (onScrollViewScrolled != null) {
      onScrollViewScrolled!();
    }
    if (_scrolling) {
      await _scroll();
    }
  }
}

typedef ScrollIncrementCalculator = double Function(
    ScrollIncrementDetails details);

enum ScrollIncrementType {
  line,

  page,
}

class ScrollIncrementDetails {
  const ScrollIncrementDetails({
    required this.type,
    required this.metrics,
  });

  final ScrollIncrementType type;

  final ScrollMetrics metrics;
}

class ScrollIntent extends Intent {
  const ScrollIntent({
    required this.direction,
    this.type = ScrollIncrementType.line,
  });

  final AxisDirection direction;

  final ScrollIncrementType type;
}

class ScrollAction extends ContextAction<ScrollIntent> {
  @override
  bool isEnabled(ScrollIntent intent, [BuildContext? context]) {
    if (context == null) {
      return false;
    }
    if (Scrollable.maybeOf(context) != null) {
      return true;
    }
    final ScrollController? primaryScrollController =
        PrimaryScrollController.maybeOf(context);
    return (primaryScrollController != null) &&
        (primaryScrollController.hasClients);
  }

  static double _calculateScrollIncrement(ScrollableState state,
      {ScrollIncrementType type = ScrollIncrementType.line}) {
    assert(state.position.hasPixels);
    assert(state.resolvedPhysics == null ||
        state.resolvedPhysics!.shouldAcceptUserOffset(state.position));
    if (state.widget.incrementCalculator != null) {
      return state.widget.incrementCalculator!(
        ScrollIncrementDetails(
          type: type,
          metrics: state.position,
        ),
      );
    }
    switch (type) {
      case ScrollIncrementType.line:
        return 50.0;
      case ScrollIncrementType.page:
        return 0.8 * state.position.viewportDimension;
    }
  }

  static double getDirectionalIncrement(
      ScrollableState state, ScrollIntent intent) {
    final double increment =
        _calculateScrollIncrement(state, type: intent.type);
    switch (intent.direction) {
      case AxisDirection.down:
        switch (state.axisDirection) {
          case AxisDirection.up:
            return -increment;
          case AxisDirection.down:
            return increment;
          case AxisDirection.right:
          case AxisDirection.left:
            return 0.0;
        }
      case AxisDirection.up:
        switch (state.axisDirection) {
          case AxisDirection.up:
            return increment;
          case AxisDirection.down:
            return -increment;
          case AxisDirection.right:
          case AxisDirection.left:
            return 0.0;
        }
      case AxisDirection.left:
        switch (state.axisDirection) {
          case AxisDirection.right:
            return -increment;
          case AxisDirection.left:
            return increment;
          case AxisDirection.up:
          case AxisDirection.down:
            return 0.0;
        }
      case AxisDirection.right:
        switch (state.axisDirection) {
          case AxisDirection.right:
            return increment;
          case AxisDirection.left:
            return -increment;
          case AxisDirection.up:
          case AxisDirection.down:
            return 0.0;
        }
    }
  }

  @override
  void invoke(ScrollIntent intent, [BuildContext? context]) {
    assert(context != null, 'Cannot scroll without a context.');
    ScrollableState? state = Scrollable.maybeOf(context!);
    if (state == null) {
      final ScrollController primaryScrollController =
          PrimaryScrollController.of(context);
      assert(() {
        if (primaryScrollController.positions.length != 1) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'A ScrollAction was invoked with the PrimaryScrollController, but '
              'more than one ScrollPosition is attached.',
            ),
            ErrorDescription(
              'Only one ScrollPosition can be manipulated by a ScrollAction at '
              'a time.',
            ),
            ErrorHint(
              'The PrimaryScrollController can be inherited automatically by '
              'descendant ScrollViews based on the TargetPlatform and scroll '
              'direction. By default, the PrimaryScrollController is '
              'automatically inherited on mobile platforms for vertical '
              'ScrollViews. ScrollView.primary can also override this behavior.',
            ),
          ]);
        }
        return true;
      }());

      if (primaryScrollController.position.context.notificationContext ==
              null &&
          Scrollable.maybeOf(primaryScrollController
                  .position.context.notificationContext!) ==
              null) {
        return;
      }
      state = Scrollable.maybeOf(
          primaryScrollController.position.context.notificationContext!);
    }
    assert(state != null,
        '$ScrollAction was invoked on a context that has no scrollable parent');
    assert(state!.position.hasPixels,
        'Scrollable must be laid out before it can be scrolled via a ScrollAction');

    // Don't do anything if the user isn't allowed to scroll.
    if (state!.resolvedPhysics != null &&
        !state.resolvedPhysics!.shouldAcceptUserOffset(state.position)) {
      return;
    }
    final double increment = getDirectionalIncrement(state, intent);
    if (increment == 0.0) {
      return;
    }
    state.position.moveTo(
      state.position.pixels + increment,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
    );
  }
}
