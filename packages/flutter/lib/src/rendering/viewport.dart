import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'box.dart';
import 'debug.dart';
import 'layer.dart';
import 'object.dart';
import 'sliver.dart';
import 'viewport_offset.dart';

enum CacheExtentStyle {
  pixel,
  viewport,
}

abstract interface class RenderAbstractViewport extends RenderObject {
  static RenderAbstractViewport? maybeOf(RenderObject? object) {
    while (object != null) {
      if (object is RenderAbstractViewport) {
        return object;
      }
      object = object.parent;
    }
    return null;
  }

  static RenderAbstractViewport of(RenderObject? object) {
    final RenderAbstractViewport? viewport = maybeOf(object);
    assert(() {
      if (viewport == null) {
        throw FlutterError(
          'RenderAbstractViewport.of() was called with a render object that was '
          'not a descendant of a RenderAbstractViewport.\n'
          'No RenderAbstractViewport render object ancestor could be found starting '
          'from the object that was passed to RenderAbstractViewport.of().\n'
          'The render object where the viewport search started was:\n'
          '  $object',
        );
      }
      return true;
    }());
    return viewport!;
  }

  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, { Rect? rect });

  static const double defaultCacheExtent = 250.0;
}

class RevealedOffset {
  const RevealedOffset({
    required this.offset,
    required this.rect,
  });

  final double offset;

  final Rect rect;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'RevealedOffset')}(offset: $offset, rect: $rect)';
  }
}

abstract class RenderViewportBase<ParentDataClass extends ContainerParentDataMixin<RenderSliver>>
    extends RenderBox with ContainerRenderObjectMixin<RenderSliver, ParentDataClass>
    implements RenderAbstractViewport {
  RenderViewportBase({
    AxisDirection axisDirection = AxisDirection.down,
    required AxisDirection crossAxisDirection,
    required ViewportOffset offset,
    double? cacheExtent,
    CacheExtentStyle cacheExtentStyle = CacheExtentStyle.pixel,
    Clip clipBehavior = Clip.hardEdge,
  }) : assert(axisDirectionToAxis(axisDirection) != axisDirectionToAxis(crossAxisDirection)),
       assert(cacheExtent != null || cacheExtentStyle == CacheExtentStyle.pixel),
       _axisDirection = axisDirection,
       _crossAxisDirection = crossAxisDirection,
       _offset = offset,
       _cacheExtent = cacheExtent ?? RenderAbstractViewport.defaultCacheExtent,
       _cacheExtentStyle = cacheExtentStyle,
       _clipBehavior = clipBehavior;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);

    config.addTagForChildren(RenderViewport.useTwoPaneSemantics);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    childrenInPaintOrder
        .where((RenderSliver sliver) => sliver.geometry!.visible || sliver.geometry!.cacheExtent > 0.0)
        .forEach(visitor);
  }

  AxisDirection get axisDirection => _axisDirection;
  AxisDirection _axisDirection;
  set axisDirection(AxisDirection value) {
    if (value == _axisDirection) {
      return;
    }
    _axisDirection = value;
    markNeedsLayout();
  }

  AxisDirection get crossAxisDirection => _crossAxisDirection;
  AxisDirection _crossAxisDirection;
  set crossAxisDirection(AxisDirection value) {
    if (value == _crossAxisDirection) {
      return;
    }
    _crossAxisDirection = value;
    markNeedsLayout();
  }

  Axis get axis => axisDirectionToAxis(axisDirection);

  ViewportOffset get offset => _offset;
  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) {
      return;
    }
    if (attached) {
      _offset.removeListener(markNeedsLayout);
    }
    _offset = value;
    if (attached) {
      _offset.addListener(markNeedsLayout);
    }
    // We need to go through layout even if the new offset has the same pixels
    // value as the old offset so that we will apply our viewport and content
    // dimensions.
    markNeedsLayout();
  }

  // TODO(ianh): cacheExtent/cacheExtentStyle should be a single
  // object that specifies both the scalar value and the unit, not a
  // pair of independent setters. Changing that would allow a more
  // rational API and would let us make the getter non-nullable.

  double? get cacheExtent => _cacheExtent;
  double _cacheExtent;
  set cacheExtent(double? value) {
    value ??= RenderAbstractViewport.defaultCacheExtent;
    if (value == _cacheExtent) {
      return;
    }
    _cacheExtent = value;
    markNeedsLayout();
  }

  double? _calculatedCacheExtent;

  CacheExtentStyle get cacheExtentStyle => _cacheExtentStyle;
  CacheExtentStyle _cacheExtentStyle;
  set cacheExtentStyle(CacheExtentStyle value) {
    if (value == _cacheExtentStyle) {
      return;
    }
    _cacheExtentStyle = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;
  set clipBehavior(Clip value) {
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _offset.removeListener(markNeedsLayout);
    super.detach();
  }

  @protected
  bool debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        assert(this is! RenderShrinkWrappingViewport); // it has its own message
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType does not support returning intrinsic dimensions.'),
          ErrorDescription(
            'Calculating the intrinsic dimensions would require instantiating every child of '
            'the viewport, which defeats the point of viewports being lazy.',
          ),
          ErrorHint(
            'If you are merely trying to shrink-wrap the viewport in the main axis direction, '
            'consider a RenderShrinkWrappingViewport render object (ShrinkWrappingViewport widget), '
            'which achieves that effect without implementing the intrinsic dimension API.',
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  bool get isRepaintBoundary => true;

  @protected
  double layoutChildSequence({
    required RenderSliver? child,
    required double scrollOffset,
    required double overlap,
    required double layoutOffset,
    required double remainingPaintExtent,
    required double mainAxisExtent,
    required double crossAxisExtent,
    required GrowthDirection growthDirection,
    required RenderSliver? Function(RenderSliver child) advance,
    required double remainingCacheExtent,
    required double cacheOrigin,
  }) {
    assert(scrollOffset.isFinite);
    assert(scrollOffset >= 0.0);
    final double initialLayoutOffset = layoutOffset;
    final ScrollDirection adjustedUserScrollDirection =
        applyGrowthDirectionToScrollDirection(offset.userScrollDirection, growthDirection);
    double maxPaintOffset = layoutOffset + overlap;
    double precedingScrollExtent = 0.0;

    while (child != null) {
      final double sliverScrollOffset = scrollOffset <= 0.0 ? 0.0 : scrollOffset;
      // If the scrollOffset is too small we adjust the paddedOrigin because it
      // doesn't make sense to ask a sliver for content before its scroll
      // offset.
      final double correctedCacheOrigin = math.max(cacheOrigin, -sliverScrollOffset);
      final double cacheExtentCorrection = cacheOrigin - correctedCacheOrigin;

      assert(sliverScrollOffset >= correctedCacheOrigin.abs());
      assert(correctedCacheOrigin <= 0.0);
      assert(sliverScrollOffset >= 0.0);
      assert(cacheExtentCorrection <= 0.0);

      child.layout(SliverConstraints(
        axisDirection: axisDirection,
        growthDirection: growthDirection,
        userScrollDirection: adjustedUserScrollDirection,
        scrollOffset: sliverScrollOffset,
        precedingScrollExtent: precedingScrollExtent,
        overlap: maxPaintOffset - layoutOffset,
        remainingPaintExtent: math.max(0.0, remainingPaintExtent - layoutOffset + initialLayoutOffset),
        crossAxisExtent: crossAxisExtent,
        crossAxisDirection: crossAxisDirection,
        viewportMainAxisExtent: mainAxisExtent,
        remainingCacheExtent: math.max(0.0, remainingCacheExtent + cacheExtentCorrection),
        cacheOrigin: correctedCacheOrigin,
      ), parentUsesSize: true);

      final SliverGeometry childLayoutGeometry = child.geometry!;
      assert(childLayoutGeometry.debugAssertIsValid());

      // If there is a correction to apply, we'll have to start over.
      if (childLayoutGeometry.scrollOffsetCorrection != null) {
        return childLayoutGeometry.scrollOffsetCorrection!;
      }

      // We use the child's paint origin in our coordinate system as the
      // layoutOffset we store in the child's parent data.
      final double effectiveLayoutOffset = layoutOffset + childLayoutGeometry.paintOrigin;

      // `effectiveLayoutOffset` becomes meaningless once we moved past the trailing edge
      // because `childLayoutGeometry.layoutExtent` is zero. Using the still increasing
      // 'scrollOffset` to roughly position these invisible slivers in the right order.
      if (childLayoutGeometry.visible || scrollOffset > 0) {
        updateChildLayoutOffset(child, effectiveLayoutOffset, growthDirection);
      } else {
        updateChildLayoutOffset(child, -scrollOffset + initialLayoutOffset, growthDirection);
      }

      maxPaintOffset = math.max(effectiveLayoutOffset + childLayoutGeometry.paintExtent, maxPaintOffset);
      scrollOffset -= childLayoutGeometry.scrollExtent;
      precedingScrollExtent += childLayoutGeometry.scrollExtent;
      layoutOffset += childLayoutGeometry.layoutExtent;
      if (childLayoutGeometry.cacheExtent != 0.0) {
        remainingCacheExtent -= childLayoutGeometry.cacheExtent - cacheExtentCorrection;
        cacheOrigin = math.min(correctedCacheOrigin + childLayoutGeometry.cacheExtent, 0.0);
      }

      updateOutOfBandData(growthDirection, childLayoutGeometry);

      // move on to the next child
      child = advance(child);
    }

    // we made it without a correction, whee!
    return 0.0;
  }

  @override
  Rect? describeApproximatePaintClip(RenderSliver child) {
    switch (clipBehavior) {
      case Clip.none:
        return null;
      case Clip.hardEdge:
      case Clip.antiAlias:
      case Clip.antiAliasWithSaveLayer:
        break;
    }

    final Rect viewportClip = Offset.zero & size;
    // The child's viewportMainAxisExtent can be infinite when a
    // RenderShrinkWrappingViewport is given infinite constraints, such as when
    // it is the child of a Row or Column (depending on orientation).
    //
    // For example, a shrink wrapping render sliver may have infinite
    // constraints along the viewport's main axis but may also have bouncing
    // scroll physics, which will allow for some scrolling effect to occur.
    // We should just use the viewportClip - the start of the overlap is at
    // double.infinity and so it is effectively meaningless.
    if (child.constraints.overlap == 0 || !child.constraints.viewportMainAxisExtent.isFinite) {
      return viewportClip;
    }

    // Adjust the clip rect for this sliver by the overlap from the previous sliver.
    double left = viewportClip.left;
    double right = viewportClip.right;
    double top = viewportClip.top;
    double bottom = viewportClip.bottom;
    final double startOfOverlap = child.constraints.viewportMainAxisExtent - child.constraints.remainingPaintExtent;
    final double overlapCorrection = startOfOverlap + child.constraints.overlap;
    switch (applyGrowthDirectionToAxisDirection(axisDirection, child.constraints.growthDirection)) {
      case AxisDirection.down:
        top += overlapCorrection;
      case AxisDirection.up:
        bottom -= overlapCorrection;
      case AxisDirection.right:
        left += overlapCorrection;
      case AxisDirection.left:
        right -= overlapCorrection;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Rect describeSemanticsClip(RenderSliver? child) {

    if (_calculatedCacheExtent == null) {
      return semanticBounds;
    }

    switch (axis) {
      case Axis.vertical:
        return Rect.fromLTRB(
          semanticBounds.left,
          semanticBounds.top - _calculatedCacheExtent!,
          semanticBounds.right,
          semanticBounds.bottom + _calculatedCacheExtent!,
        );
      case Axis.horizontal:
        return Rect.fromLTRB(
          semanticBounds.left - _calculatedCacheExtent!,
          semanticBounds.top,
          semanticBounds.right + _calculatedCacheExtent!,
          semanticBounds.bottom,
        );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) {
      return;
    }
    if (hasVisualOverflow && clipBehavior != Clip.none) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        _paintContents,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      _paintContents(context, offset);
    }
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  void _paintContents(PaintingContext context, Offset offset) {
    for (final RenderSliver child in childrenInPaintOrder) {
      if (child.geometry!.visible) {
        context.paintChild(child, offset + paintOffsetOf(child));
      }
    }
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      super.debugPaintSize(context, offset);
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF00FF00);
      final Canvas canvas = context.canvas;
      RenderSliver? child = firstChild;
      while (child != null) {
        final Size size;
        switch (axis) {
          case Axis.vertical:
            size = Size(child.constraints.crossAxisExtent, child.geometry!.layoutExtent);
          case Axis.horizontal:
            size = Size(child.geometry!.layoutExtent, child.constraints.crossAxisExtent);
        }
        canvas.drawRect(((offset + paintOffsetOf(child)) & size).deflate(0.5), paint);
        child = childAfter(child);
      }
      return true;
    }());
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    double mainAxisPosition, crossAxisPosition;
    switch (axis) {
      case Axis.vertical:
        mainAxisPosition = position.dy;
        crossAxisPosition = position.dx;
      case Axis.horizontal:
        mainAxisPosition = position.dx;
        crossAxisPosition = position.dy;
    }
    final SliverHitTestResult sliverResult = SliverHitTestResult.wrap(result);
    for (final RenderSliver child in childrenInHitTestOrder) {
      if (!child.geometry!.visible) {
        continue;
      }
      final Matrix4 transform = Matrix4.identity();
      applyPaintTransform(child, transform); // must be invertible
      final bool isHit = result.addWithOutOfBandPosition(
        paintTransform: transform,
        hitTest: (BoxHitTestResult result) {
          return child.hitTest(
            sliverResult,
            mainAxisPosition: computeChildMainAxisPosition(child, mainAxisPosition),
            crossAxisPosition: crossAxisPosition,
          );
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, { Rect? rect }) {
    // Steps to convert `rect` (from a RenderBox coordinate system) to its
    // scroll offset within this viewport (not in the exact order):
    //
    // 1. Pick the outermost RenderBox (between which, and the viewport, there
    // is nothing but RenderSlivers) as an intermediate reference frame
    // (the `pivot`), convert `rect` to that coordinate space.
    //
    // 2. Convert `rect` from the `pivot` coordinate space to its sliver
    // parent's sliver coordinate system (i.e., to a scroll offset), based on
    // the axis direction and growth direction of the parent.
    //
    // 3. Convert the scroll offset to its sliver parent's coordinate space
    // using `childScrollOffset`, until we reach the viewport.
    //
    // 4. Make the final conversion from the outmost sliver to the viewport
    // using `scrollOffsetOf`.

    double leadingScrollOffset = 0.0;
    // Starting at `target` and walking towards the root:
    //  - `child` will be the last object before we reach this viewport, and
    //  - `pivot` will be the last RenderBox before we reach this viewport.
    RenderObject child = target;
    RenderBox? pivot;
    bool onlySlivers = target is RenderSliver; // ... between viewport and `target` (`target` included).
    while (child.parent != this) {
      final RenderObject parent = child.parent!;
      if (child is RenderBox) {
        pivot = child;
      }
      if (parent is RenderSliver) {
        leadingScrollOffset += parent.childScrollOffset(child)!;
      } else {
        onlySlivers = false;
        leadingScrollOffset = 0.0;
      }
      child = parent;
    }

    // `rect` in the new intermediate coordinate system.
    final Rect rectLocal;
    // Our new reference frame render object's main axis extent.
    final double pivotExtent;
    final GrowthDirection growthDirection;

    // `leadingScrollOffset` is currently the scrollOffset of our new reference
    // frame (`pivot` or `target`), within `child`.
    if (pivot != null) {
      assert(pivot.parent != null);
      assert(pivot.parent != this);
      assert(pivot != this);
      assert(pivot.parent is RenderSliver);  // TODO(abarth): Support other kinds of render objects besides slivers.
      final RenderSliver pivotParent = pivot.parent! as RenderSliver;
      growthDirection = pivotParent.constraints.growthDirection;
      switch (axis) {
        case Axis.horizontal:
          pivotExtent = pivot.size.width;
        case Axis.vertical:
          pivotExtent = pivot.size.height;
      }
      rect ??= target.paintBounds;
      rectLocal = MatrixUtils.transformRect(target.getTransformTo(pivot), rect);
    } else if (onlySlivers) {
      // `pivot` does not exist. We'll have to make up one from `target`, the
      // innermost sliver.
      final RenderSliver targetSliver = target as RenderSliver;
      growthDirection = targetSliver.constraints.growthDirection;
      // TODO(LongCatIsLooong): make sure this works if `targetSliver` is a
      // persistent header, when #56413 relands.
      pivotExtent = targetSliver.geometry!.scrollExtent;
      if (rect == null) {
        switch (axis) {
          case Axis.horizontal:
            rect = Rect.fromLTWH(
              0, 0,
              targetSliver.geometry!.scrollExtent,
              targetSliver.constraints.crossAxisExtent,
            );
          case Axis.vertical:
            rect = Rect.fromLTWH(
              0, 0,
              targetSliver.constraints.crossAxisExtent,
              targetSliver.geometry!.scrollExtent,
            );
        }
      }
      rectLocal = rect;
    } else {
      assert(rect != null);
      return RevealedOffset(offset: offset.pixels, rect: rect!);
    }

    assert(child.parent == this);
    assert(child is RenderSliver);
    final RenderSliver sliver = child as RenderSliver;

    final double targetMainAxisExtent;
    // The scroll offset of `rect` within `child`.
    switch (applyGrowthDirectionToAxisDirection(axisDirection, growthDirection)) {
      case AxisDirection.up:
        leadingScrollOffset += pivotExtent - rectLocal.bottom;
        targetMainAxisExtent = rectLocal.height;
      case AxisDirection.right:
        leadingScrollOffset += rectLocal.left;
        targetMainAxisExtent = rectLocal.width;
      case AxisDirection.down:
        leadingScrollOffset += rectLocal.top;
        targetMainAxisExtent = rectLocal.height;
      case AxisDirection.left:
        leadingScrollOffset += pivotExtent - rectLocal.right;
        targetMainAxisExtent = rectLocal.width;
    }

    // So far leadingScrollOffset is the scroll offset of `rect` in the `child`
    // sliver's sliver coordinate system. The sign of this value indicates
    // whether the `rect` protrudes the leading edge of the `child` sliver. When
    // this value is non-negative and `child`'s `maxScrollObstructionExtent` is
    // greater than 0, we assume `rect` can't be obstructed by the leading edge
    // of the viewport (i.e. its pinned to the leading edge).
    final bool isPinned = sliver.geometry!.maxScrollObstructionExtent > 0 && leadingScrollOffset >= 0;

    // The scroll offset in the viewport to `rect`.
    leadingScrollOffset = scrollOffsetOf(sliver, leadingScrollOffset);

    // This step assumes the viewport's layout is up-to-date, i.e., if
    // offset.pixels is changed after the last performLayout, the new scroll
    // position will not be accounted for.
    final Matrix4 transform = target.getTransformTo(this);
    Rect targetRect = MatrixUtils.transformRect(transform, rect);
    final double extentOfPinnedSlivers = maxScrollObstructionExtentBefore(sliver);

    switch (sliver.constraints.growthDirection) {
      case GrowthDirection.forward:
        if (isPinned && alignment <= 0) {
          return RevealedOffset(offset: double.infinity, rect: targetRect);
        }
        leadingScrollOffset -= extentOfPinnedSlivers;
      case GrowthDirection.reverse:
        if (isPinned && alignment >= 1) {
          return RevealedOffset(offset: double.negativeInfinity, rect: targetRect);
        }
        // If child's growth direction is reverse, when viewport.offset is
        // `leadingScrollOffset`, it is positioned just outside of the leading
        // edge of the viewport.
        switch (axis) {
          case Axis.vertical:
            leadingScrollOffset -= targetRect.height;
          case Axis.horizontal:
            leadingScrollOffset -= targetRect.width;
        }
    }

    final double mainAxisExtent;
    switch (axis) {
      case Axis.horizontal:
        mainAxisExtent = size.width - extentOfPinnedSlivers;
      case Axis.vertical:
        mainAxisExtent = size.height - extentOfPinnedSlivers;
    }

    final double targetOffset = leadingScrollOffset - (mainAxisExtent - targetMainAxisExtent) * alignment;
    final double offsetDifference = offset.pixels - targetOffset;

    switch (axisDirection) {
      case AxisDirection.down:
        targetRect = targetRect.translate(0.0, offsetDifference);
      case AxisDirection.right:
        targetRect = targetRect.translate(offsetDifference, 0.0);
      case AxisDirection.up:
        targetRect = targetRect.translate(0.0, -offsetDifference);
      case AxisDirection.left:
        targetRect = targetRect.translate(-offsetDifference, 0.0);
    }

    return RevealedOffset(offset: targetOffset, rect: targetRect);
  }

  @protected
  Offset computeAbsolutePaintOffset(RenderSliver child, double layoutOffset, GrowthDirection growthDirection) {
    assert(hasSize); // this is only usable once we have a size
    assert(child.geometry != null);
    switch (applyGrowthDirectionToAxisDirection(axisDirection, growthDirection)) {
      case AxisDirection.up:
        return Offset(0.0, size.height - (layoutOffset + child.geometry!.paintExtent));
      case AxisDirection.right:
        return Offset(layoutOffset, 0.0);
      case AxisDirection.down:
        return Offset(0.0, layoutOffset);
      case AxisDirection.left:
        return Offset(size.width - (layoutOffset + child.geometry!.paintExtent), 0.0);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', axisDirection));
    properties.add(EnumProperty<AxisDirection>('crossAxisDirection', crossAxisDirection));
    properties.add(DiagnosticsProperty<ViewportOffset>('offset', offset));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    RenderSliver? child = firstChild;
    if (child == null) {
      return children;
    }

    int count = indexOfFirstChild;
    while (true) {
      children.add(child!.toDiagnosticsNode(name: labelForChild(count)));
      if (child == lastChild) {
        break;
      }
      count += 1;
      child = childAfter(child);
    }
    return children;
  }

  // API TO BE IMPLEMENTED BY SUBCLASSES

  // setupParentData

  // performLayout (and optionally sizedByParent and performResize)

  @protected
  bool get hasVisualOverflow;

  @protected
  void updateOutOfBandData(GrowthDirection growthDirection, SliverGeometry childLayoutGeometry);

  @protected
  void updateChildLayoutOffset(RenderSliver child, double layoutOffset, GrowthDirection growthDirection);

  @protected
  Offset paintOffsetOf(RenderSliver child);

  @protected
  double scrollOffsetOf(RenderSliver child, double scrollOffsetWithinChild);

  @protected
  double maxScrollObstructionExtentBefore(RenderSliver child);

  @protected
  double computeChildMainAxisPosition(RenderSliver child, double parentMainAxisPosition);

  @protected
  int get indexOfFirstChild;

  @protected
  String labelForChild(int index);

  @protected
  Iterable<RenderSliver> get childrenInPaintOrder;

  @protected
  Iterable<RenderSliver> get childrenInHitTestOrder;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (!offset.allowImplicitScrolling) {
      return super.showOnScreen(
        descendant: descendant,
        rect: rect,
        duration: duration,
        curve: curve,
      );
    }

    final Rect? newRect = RenderViewportBase.showInViewport(
      descendant: descendant,
      viewport: this,
      offset: offset,
      rect: rect,
      duration: duration,
      curve: curve,
    );
    super.showOnScreen(
      rect: newRect,
      duration: duration,
      curve: curve,
    );
  }

  static Rect? showInViewport({
    RenderObject? descendant,
    Rect? rect,
    required RenderAbstractViewport viewport,
    required ViewportOffset offset,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (descendant == null) {
      return rect;
    }
    final RevealedOffset leadingEdgeOffset = viewport.getOffsetToReveal(descendant, 0.0, rect: rect);
    final RevealedOffset trailingEdgeOffset = viewport.getOffsetToReveal(descendant, 1.0, rect: rect);
    final double currentOffset = offset.pixels;

    //           scrollOffset
    //                       0 +---------+
    //                         |         |
    //                       _ |         |
    //    viewport position |  |         |
    // with `descendant` at |  |         | _
    //        trailing edge |_ | xxxxxxx |  | viewport position
    //                         |         |  | with `descendant` at
    //                         |         | _| leading edge
    //                         |         |
    //                     800 +---------+
    //
    // `trailingEdgeOffset`: Distance from scrollOffset 0 to the start of the
    //                       viewport on the left in image above.
    // `leadingEdgeOffset`: Distance from scrollOffset 0 to the start of the
    //                      viewport on the right in image above.
    //
    // The viewport position on the left is achieved by setting `offset.pixels`
    // to `trailingEdgeOffset`, the one on the right by setting it to
    // `leadingEdgeOffset`.

    final RevealedOffset targetOffset;
    if (leadingEdgeOffset.offset < trailingEdgeOffset.offset) {
      // `descendant` is too big to be visible on screen in its entirety. Let's
      // align it with the edge that requires the least amount of scrolling.
      final double leadingEdgeDiff = (offset.pixels - leadingEdgeOffset.offset).abs();
      final double trailingEdgeDiff = (offset.pixels - trailingEdgeOffset.offset).abs();
      targetOffset = leadingEdgeDiff < trailingEdgeDiff ? leadingEdgeOffset : trailingEdgeOffset;
    } else if (currentOffset > leadingEdgeOffset.offset) {
      // `descendant` currently starts above the leading edge and can be shown
      // fully on screen by scrolling down (which means: moving viewport up).
      targetOffset = leadingEdgeOffset;
    } else if (currentOffset < trailingEdgeOffset.offset) {
      // `descendant currently ends below the trailing edge and can be shown
      // fully on screen by scrolling up (which means: moving viewport down)
      targetOffset = trailingEdgeOffset;
    } else {
      // `descendant` is between leading and trailing edge and hence already
      //  fully shown on screen. No action necessary.
      assert(viewport.parent != null);
      final Matrix4 transform = descendant.getTransformTo(viewport.parent);
      return MatrixUtils.transformRect(transform, rect ?? descendant.paintBounds);
    }


    offset.moveTo(targetOffset.offset, duration: duration, curve: curve);
    return targetOffset.rect;
  }
}

class RenderViewport extends RenderViewportBase<SliverPhysicalContainerParentData> {
  RenderViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    double anchor = 0.0,
    List<RenderSliver>? children,
    RenderSliver? center,
    super.cacheExtent,
    super.cacheExtentStyle,
    super.clipBehavior,
  }) : assert(anchor >= 0.0 && anchor <= 1.0),
       assert(cacheExtentStyle != CacheExtentStyle.viewport || cacheExtent != null),
       _anchor = anchor,
       _center = center {
    addAll(children);
    if (center == null && firstChild != null) {
      _center = firstChild;
    }
  }

  static const SemanticsTag useTwoPaneSemantics = SemanticsTag('RenderViewport.twoPane');

  static const SemanticsTag excludeFromScrolling = SemanticsTag('RenderViewport.excludeFromScrolling');

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalContainerParentData) {
      child.parentData = SliverPhysicalContainerParentData();
    }
  }

  double get anchor => _anchor;
  double _anchor;
  set anchor(double value) {
    assert(value >= 0.0 && value <= 1.0);
    if (value == _anchor) {
      return;
    }
    _anchor = value;
    markNeedsLayout();
  }

  RenderSliver? get center => _center;
  RenderSliver? _center;
  set center(RenderSliver? value) {
    if (value == _center) {
      return;
    }
    _center = value;
    markNeedsLayout();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCheckHasBoundedAxis(axis, constraints));
    return constraints.biggest;
  }

  static const int _maxLayoutCycles = 10;

  // Out-of-band data computed during layout.
  late double _minScrollExtent;
  late double _maxScrollExtent;
  bool _hasVisualOverflow = false;

  @override
  void performLayout() {
    // Ignore the return value of applyViewportDimension because we are
    // doing a layout regardless.
    switch (axis) {
      case Axis.vertical:
        offset.applyViewportDimension(size.height);
      case Axis.horizontal:
        offset.applyViewportDimension(size.width);
    }

    if (center == null) {
      assert(firstChild == null);
      _minScrollExtent = 0.0;
      _maxScrollExtent = 0.0;
      _hasVisualOverflow = false;
      offset.applyContentDimensions(0.0, 0.0);
      return;
    }
    assert(center!.parent == this);

    final double mainAxisExtent;
    final double crossAxisExtent;
    switch (axis) {
      case Axis.vertical:
        mainAxisExtent = size.height;
        crossAxisExtent = size.width;
      case Axis.horizontal:
        mainAxisExtent = size.width;
        crossAxisExtent = size.height;
    }

    final double centerOffsetAdjustment = center!.centerOffsetAdjustment;

    double correction;
    int count = 0;
    do {
      correction = _attemptLayout(mainAxisExtent, crossAxisExtent, offset.pixels + centerOffsetAdjustment);
      if (correction != 0.0) {
        offset.correctBy(correction);
      } else {
        if (offset.applyContentDimensions(
              math.min(0.0, _minScrollExtent + mainAxisExtent * anchor),
              math.max(0.0, _maxScrollExtent - mainAxisExtent * (1.0 - anchor)),
           )) {
          break;
        }
      }
      count += 1;
    } while (count < _maxLayoutCycles);
    assert(() {
      if (count >= _maxLayoutCycles) {
        assert(count != 1);
        throw FlutterError(
          'A RenderViewport exceeded its maximum number of layout cycles.\n'
          'RenderViewport render objects, during layout, can retry if either their '
          'slivers or their ViewportOffset decide that the offset should be corrected '
          'to take into account information collected during that layout.\n'
          'In the case of this RenderViewport object, however, this happened $count '
          'times and still there was no consensus on the scroll offset. This usually '
          'indicates a bug. Specifically, it means that one of the following three '
          'problems is being experienced by the RenderViewport object:\n'
          ' * One of the RenderSliver children or the ViewportOffset have a bug such'
          ' that they always think that they need to correct the offset regardless.\n'
          ' * Some combination of the RenderSliver children and the ViewportOffset'
          ' have a bad interaction such that one applies a correction then another'
          ' applies a reverse correction, leading to an infinite loop of corrections.\n'
          ' * There is a pathological case that would eventually resolve, but it is'
          ' so complicated that it cannot be resolved in any reasonable number of'
          ' layout passes.',
        );
      }
      return true;
    }());
  }

  double _attemptLayout(double mainAxisExtent, double crossAxisExtent, double correctedOffset) {
    assert(!mainAxisExtent.isNaN);
    assert(mainAxisExtent >= 0.0);
    assert(crossAxisExtent.isFinite);
    assert(crossAxisExtent >= 0.0);
    assert(correctedOffset.isFinite);
    _minScrollExtent = 0.0;
    _maxScrollExtent = 0.0;
    _hasVisualOverflow = false;

    // centerOffset is the offset from the leading edge of the RenderViewport
    // to the zero scroll offset (the line between the forward slivers and the
    // reverse slivers).
    final double centerOffset = mainAxisExtent * anchor - correctedOffset;
    final double reverseDirectionRemainingPaintExtent = clampDouble(centerOffset, 0.0, mainAxisExtent);
    final double forwardDirectionRemainingPaintExtent = clampDouble(mainAxisExtent - centerOffset, 0.0, mainAxisExtent);

    switch (cacheExtentStyle) {
      case CacheExtentStyle.pixel:
        _calculatedCacheExtent = cacheExtent;
      case CacheExtentStyle.viewport:
        _calculatedCacheExtent = mainAxisExtent * _cacheExtent;
    }

    final double fullCacheExtent = mainAxisExtent + 2 * _calculatedCacheExtent!;
    final double centerCacheOffset = centerOffset + _calculatedCacheExtent!;
    final double reverseDirectionRemainingCacheExtent = clampDouble(centerCacheOffset, 0.0, fullCacheExtent);
    final double forwardDirectionRemainingCacheExtent = clampDouble(fullCacheExtent - centerCacheOffset, 0.0, fullCacheExtent);

    final RenderSliver? leadingNegativeChild = childBefore(center!);

    if (leadingNegativeChild != null) {
      // negative scroll offsets
      final double result = layoutChildSequence(
        child: leadingNegativeChild,
        scrollOffset: math.max(mainAxisExtent, centerOffset) - mainAxisExtent,
        overlap: 0.0,
        layoutOffset: forwardDirectionRemainingPaintExtent,
        remainingPaintExtent: reverseDirectionRemainingPaintExtent,
        mainAxisExtent: mainAxisExtent,
        crossAxisExtent: crossAxisExtent,
        growthDirection: GrowthDirection.reverse,
        advance: childBefore,
        remainingCacheExtent: reverseDirectionRemainingCacheExtent,
        cacheOrigin: clampDouble(mainAxisExtent - centerOffset, -_calculatedCacheExtent!, 0.0),
      );
      if (result != 0.0) {
        return -result;
      }
    }

    // positive scroll offsets
    return layoutChildSequence(
      child: center,
      scrollOffset: math.max(0.0, -centerOffset),
      overlap: leadingNegativeChild == null ? math.min(0.0, -centerOffset) : 0.0,
      layoutOffset: centerOffset >= mainAxisExtent ? centerOffset: reverseDirectionRemainingPaintExtent,
      remainingPaintExtent: forwardDirectionRemainingPaintExtent,
      mainAxisExtent: mainAxisExtent,
      crossAxisExtent: crossAxisExtent,
      growthDirection: GrowthDirection.forward,
      advance: childAfter,
      remainingCacheExtent: forwardDirectionRemainingCacheExtent,
      cacheOrigin: clampDouble(centerOffset, -_calculatedCacheExtent!, 0.0),
    );
  }

  @override
  bool get hasVisualOverflow => _hasVisualOverflow;

  @override
  void updateOutOfBandData(GrowthDirection growthDirection, SliverGeometry childLayoutGeometry) {
    switch (growthDirection) {
      case GrowthDirection.forward:
        _maxScrollExtent += childLayoutGeometry.scrollExtent;
      case GrowthDirection.reverse:
        _minScrollExtent -= childLayoutGeometry.scrollExtent;
    }
    if (childLayoutGeometry.hasVisualOverflow) {
      _hasVisualOverflow = true;
    }
  }

  @override
  void updateChildLayoutOffset(RenderSliver child, double layoutOffset, GrowthDirection growthDirection) {
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    childParentData.paintOffset = computeAbsolutePaintOffset(child, layoutOffset, growthDirection);
  }

  @override
  Offset paintOffsetOf(RenderSliver child) {
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    return childParentData.paintOffset;
  }

  @override
  double scrollOffsetOf(RenderSliver child, double scrollOffsetWithinChild) {
    assert(child.parent == this);
    final GrowthDirection growthDirection = child.constraints.growthDirection;
    switch (growthDirection) {
      case GrowthDirection.forward:
        double scrollOffsetToChild = 0.0;
        RenderSliver? current = center;
        while (current != child) {
          scrollOffsetToChild += current!.geometry!.scrollExtent;
          current = childAfter(current);
        }
        return scrollOffsetToChild + scrollOffsetWithinChild;
      case GrowthDirection.reverse:
        double scrollOffsetToChild = 0.0;
        RenderSliver? current = childBefore(center!);
        while (current != child) {
          scrollOffsetToChild -= current!.geometry!.scrollExtent;
          current = childBefore(current);
        }
        return scrollOffsetToChild - scrollOffsetWithinChild;
    }
  }

  @override
  double maxScrollObstructionExtentBefore(RenderSliver child) {
    assert(child.parent == this);
    final GrowthDirection growthDirection = child.constraints.growthDirection;
    switch (growthDirection) {
      case GrowthDirection.forward:
        double pinnedExtent = 0.0;
        RenderSliver? current = center;
        while (current != child) {
          pinnedExtent += current!.geometry!.maxScrollObstructionExtent;
          current = childAfter(current);
        }
        return pinnedExtent;
      case GrowthDirection.reverse:
        double pinnedExtent = 0.0;
        RenderSliver? current = childBefore(center!);
        while (current != child) {
          pinnedExtent += current!.geometry!.maxScrollObstructionExtent;
          current = childBefore(current);
        }
        return pinnedExtent;
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    // Hit test logic relies on this always providing an invertible matrix.
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    childParentData.applyPaintTransform(transform);
  }

  @override
  double computeChildMainAxisPosition(RenderSliver child, double parentMainAxisPosition) {
    final SliverPhysicalParentData childParentData = child.parentData! as SliverPhysicalParentData;
    switch (applyGrowthDirectionToAxisDirection(child.constraints.axisDirection, child.constraints.growthDirection)) {
      case AxisDirection.down:
        return parentMainAxisPosition - childParentData.paintOffset.dy;
      case AxisDirection.right:
        return parentMainAxisPosition - childParentData.paintOffset.dx;
      case AxisDirection.up:
        return child.geometry!.paintExtent - (parentMainAxisPosition - childParentData.paintOffset.dy);
      case AxisDirection.left:
        return child.geometry!.paintExtent - (parentMainAxisPosition - childParentData.paintOffset.dx);
    }
  }

  @override
  int get indexOfFirstChild {
    assert(center != null);
    assert(center!.parent == this);
    assert(firstChild != null);
    int count = 0;
    RenderSliver? child = center;
    while (child != firstChild) {
      count -= 1;
      child = childBefore(child!);
    }
    return count;
  }

  @override
  String labelForChild(int index) {
    if (index == 0) {
      return 'center child';
    }
    return 'child $index';
  }

  @override
  Iterable<RenderSliver> get childrenInPaintOrder {
    final List<RenderSliver> children = <RenderSliver>[];
    if (firstChild == null) {
      return children;
    }
    RenderSliver? child = firstChild;
    while (child != center) {
      children.add(child!);
      child = childAfter(child);
    }
    child = lastChild;
    while (true) {
      children.add(child!);
      if (child == center) {
        return children;
      }
      child = childBefore(child);
    }
  }

  @override
  Iterable<RenderSliver> get childrenInHitTestOrder {
    final List<RenderSliver> children = <RenderSliver>[];
    if (firstChild == null) {
      return children;
    }
    RenderSliver? child = center;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    child = childBefore(center!);
    while (child != null) {
      children.add(child);
      child = childBefore(child);
    }
    return children;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('anchor', anchor));
  }
}

class RenderShrinkWrappingViewport extends RenderViewportBase<SliverLogicalContainerParentData> {
  RenderShrinkWrappingViewport({
    super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    super.clipBehavior,
    List<RenderSliver>? children,
  }) {
    addAll(children);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverLogicalContainerParentData) {
      child.parentData = SliverLogicalContainerParentData();
    }
  }

  @override
  bool debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$runtimeType does not support returning intrinsic dimensions.'),
          ErrorDescription(
           'Calculating the intrinsic dimensions would require instantiating every child of '
           'the viewport, which defeats the point of viewports being lazy.',
          ),
          ErrorHint(
            'If you are merely trying to shrink-wrap the viewport in the main axis direction, '
            'you should be able to achieve that effect by just giving the viewport loose '
            'constraints, without needing to measure its intrinsic dimensions.',
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  // Out-of-band data computed during layout.
  late double _maxScrollExtent;
  late double _shrinkWrapExtent;
  bool _hasVisualOverflow = false;

  bool _debugCheckHasBoundedCrossAxis() {
    assert(() {
      switch (axis) {
        case Axis.vertical:
          if (!constraints.hasBoundedWidth) {
            throw FlutterError(
              'Vertical viewport was given unbounded width.\n'
              'Viewports expand in the cross axis to fill their container and '
              'constrain their children to match their extent in the cross axis. '
              'In this case, a vertical shrinkwrapping viewport was given an '
              'unlimited amount of horizontal space in which to expand.',
            );
          }
        case Axis.horizontal:
          if (!constraints.hasBoundedHeight) {
            throw FlutterError(
              'Horizontal viewport was given unbounded height.\n'
              'Viewports expand in the cross axis to fill their container and '
              'constrain their children to match their extent in the cross axis. '
              'In this case, a horizontal shrinkwrapping viewport was given an '
              'unlimited amount of vertical space in which to expand.',
            );
          }
      }
      return true;
    }());
    return true;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    if (firstChild == null) {
      // Shrinkwrapping viewport only requires the cross axis to be bounded.
      assert(_debugCheckHasBoundedCrossAxis());
      switch (axis) {
        case Axis.vertical:
          size = Size(constraints.maxWidth, constraints.minHeight);
        case Axis.horizontal:
          size = Size(constraints.minWidth, constraints.maxHeight);
      }
      offset.applyViewportDimension(0.0);
      _maxScrollExtent = 0.0;
      _shrinkWrapExtent = 0.0;
      _hasVisualOverflow = false;
      offset.applyContentDimensions(0.0, 0.0);
      return;
    }

    final double mainAxisExtent;
    final double crossAxisExtent;
    // Shrinkwrapping viewport only requires the cross axis to be bounded.
    assert(_debugCheckHasBoundedCrossAxis());
    switch (axis) {
      case Axis.vertical:
        mainAxisExtent = constraints.maxHeight;
        crossAxisExtent = constraints.maxWidth;
      case Axis.horizontal:
        mainAxisExtent = constraints.maxWidth;
        crossAxisExtent = constraints.maxHeight;
    }

    double correction;
    double effectiveExtent;
    while (true) {
      correction = _attemptLayout(mainAxisExtent, crossAxisExtent, offset.pixels);
      if (correction != 0.0) {
        offset.correctBy(correction);
      } else {
        switch (axis) {
          case Axis.vertical:
            effectiveExtent = constraints.constrainHeight(_shrinkWrapExtent);
          case Axis.horizontal:
            effectiveExtent = constraints.constrainWidth(_shrinkWrapExtent);
        }
        final bool didAcceptViewportDimension = offset.applyViewportDimension(effectiveExtent);
        final bool didAcceptContentDimension = offset.applyContentDimensions(0.0, math.max(0.0, _maxScrollExtent - effectiveExtent));
        if (didAcceptViewportDimension && didAcceptContentDimension) {
          break;
        }
      }
    }
    switch (axis) {
      case Axis.vertical:
        size = constraints.constrainDimensions(crossAxisExtent, effectiveExtent);
      case Axis.horizontal:
        size = constraints.constrainDimensions(effectiveExtent, crossAxisExtent);
    }
  }

  double _attemptLayout(double mainAxisExtent, double crossAxisExtent, double correctedOffset) {
    // We can't assert mainAxisExtent is finite, because it could be infinite if
    // it is within a column or row for example. In such a case, there's not
    // even any scrolling to do, although some scroll physics (i.e.
    // BouncingScrollPhysics) could still temporarily scroll the content in a
    // simulation.
    assert(!mainAxisExtent.isNaN);
    assert(mainAxisExtent >= 0.0);
    assert(crossAxisExtent.isFinite);
    assert(crossAxisExtent >= 0.0);
    assert(correctedOffset.isFinite);
    _maxScrollExtent = 0.0;
    _shrinkWrapExtent = 0.0;
    // Since the viewport is shrinkwrapped, we know that any negative overscroll
    // into the potentially infinite mainAxisExtent will overflow the end of
    // the viewport.
    _hasVisualOverflow = correctedOffset < 0.0;
    switch (cacheExtentStyle) {
      case CacheExtentStyle.pixel:
        _calculatedCacheExtent = cacheExtent;
      case CacheExtentStyle.viewport:
        _calculatedCacheExtent = mainAxisExtent * _cacheExtent;
    }

    return layoutChildSequence(
      child: firstChild,
      scrollOffset: math.max(0.0, correctedOffset),
      overlap: math.min(0.0, correctedOffset),
      layoutOffset: math.max(0.0, -correctedOffset),
      remainingPaintExtent: mainAxisExtent + math.min(0.0, correctedOffset),
      mainAxisExtent: mainAxisExtent,
      crossAxisExtent: crossAxisExtent,
      growthDirection: GrowthDirection.forward,
      advance: childAfter,
      remainingCacheExtent: mainAxisExtent + 2 * _calculatedCacheExtent!,
      cacheOrigin: -_calculatedCacheExtent!,
    );
  }

  @override
  bool get hasVisualOverflow => _hasVisualOverflow;

  @override
  void updateOutOfBandData(GrowthDirection growthDirection, SliverGeometry childLayoutGeometry) {
    assert(growthDirection == GrowthDirection.forward);
    _maxScrollExtent += childLayoutGeometry.scrollExtent;
    if (childLayoutGeometry.hasVisualOverflow) {
      _hasVisualOverflow = true;
    }
    _shrinkWrapExtent += childLayoutGeometry.maxPaintExtent;
  }

  @override
  void updateChildLayoutOffset(RenderSliver child, double layoutOffset, GrowthDirection growthDirection) {
    assert(growthDirection == GrowthDirection.forward);
    final SliverLogicalParentData childParentData = child.parentData! as SliverLogicalParentData;
    childParentData.layoutOffset = layoutOffset;
  }

  @override
  Offset paintOffsetOf(RenderSliver child) {
    final SliverLogicalParentData childParentData = child.parentData! as SliverLogicalParentData;
    return computeAbsolutePaintOffset(child, childParentData.layoutOffset!, GrowthDirection.forward);
  }

  @override
  double scrollOffsetOf(RenderSliver child, double scrollOffsetWithinChild) {
    assert(child.parent == this);
    assert(child.constraints.growthDirection == GrowthDirection.forward);
    double scrollOffsetToChild = 0.0;
    RenderSliver? current = firstChild;
    while (current != child) {
      scrollOffsetToChild += current!.geometry!.scrollExtent;
      current = childAfter(current);
    }
    return scrollOffsetToChild + scrollOffsetWithinChild;
  }

  @override
  double maxScrollObstructionExtentBefore(RenderSliver child) {
    assert(child.parent == this);
    assert(child.constraints.growthDirection == GrowthDirection.forward);
    double pinnedExtent = 0.0;
    RenderSliver? current = firstChild;
    while (current != child) {
      pinnedExtent += current!.geometry!.maxScrollObstructionExtent;
      current = childAfter(current);
    }
    return pinnedExtent;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    // Hit test logic relies on this always providing an invertible matrix.
    final Offset offset = paintOffsetOf(child as RenderSliver);
    transform.translate(offset.dx, offset.dy);
  }

  @override
  double computeChildMainAxisPosition(RenderSliver child, double parentMainAxisPosition) {
    assert(hasSize);
    final SliverLogicalParentData childParentData = child.parentData! as SliverLogicalParentData;
    switch (applyGrowthDirectionToAxisDirection(child.constraints.axisDirection, child.constraints.growthDirection)) {
      case AxisDirection.down:
      case AxisDirection.right:
        return parentMainAxisPosition - childParentData.layoutOffset!;
      case AxisDirection.up:
        return (size.height - parentMainAxisPosition) - childParentData.layoutOffset!;
      case AxisDirection.left:
        return (size.width - parentMainAxisPosition) - childParentData.layoutOffset!;
    }
  }

  @override
  int get indexOfFirstChild => 0;

  @override
  String labelForChild(int index) => 'child $index';

  @override
  Iterable<RenderSliver> get childrenInPaintOrder {
    final List<RenderSliver> children = <RenderSliver>[];
    RenderSliver? child = lastChild;
    while (child != null) {
      children.add(child);
      child = childBefore(child);
    }
    return children;
  }

  @override
  Iterable<RenderSliver> get childrenInHitTestOrder {
    final List<RenderSliver> children = <RenderSliver>[];
    RenderSliver? child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    return children;
  }
}