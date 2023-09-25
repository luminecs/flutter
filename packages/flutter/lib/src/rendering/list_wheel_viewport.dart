import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'box.dart';
import 'layer.dart';
import 'object.dart';
import 'proxy_box.dart';
import 'viewport.dart';
import 'viewport_offset.dart';

typedef _ChildSizingFunction = double Function(RenderBox child);

abstract class ListWheelChildManager {
  int? get childCount;

  bool childExistsAt(int index);

  void createChild(int index, { required RenderBox? after });

  void removeChild(RenderBox child);
}

class ListWheelParentData extends ContainerBoxParentData<RenderBox> {
  int? index;

  Matrix4? transform;
}

class RenderListWheelViewport
    extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ListWheelParentData>
    implements RenderAbstractViewport {
  RenderListWheelViewport({
    required this.childManager,
    required ViewportOffset offset,
    double diameterRatio = defaultDiameterRatio,
    double perspective = defaultPerspective,
    double offAxisFraction = 0,
    bool useMagnifier = false,
    double magnification = 1,
    double overAndUnderCenterOpacity = 1,
    required double itemExtent,
    double squeeze = 1,
    bool renderChildrenOutsideViewport = false,
    Clip clipBehavior = Clip.none,
    List<RenderBox>? children,
  }) : assert(diameterRatio > 0, diameterRatioZeroMessage),
       assert(perspective > 0),
       assert(perspective <= 0.01, perspectiveTooHighMessage),
       assert(magnification > 0),
       assert(overAndUnderCenterOpacity >= 0 && overAndUnderCenterOpacity <= 1),
       assert(squeeze > 0),
       assert(itemExtent > 0),
       assert(
         !renderChildrenOutsideViewport || clipBehavior == Clip.none,
         clipBehaviorAndRenderChildrenOutsideViewportConflict,
       ),
       _offset = offset,
       _diameterRatio = diameterRatio,
       _perspective = perspective,
       _offAxisFraction = offAxisFraction,
       _useMagnifier = useMagnifier,
       _magnification = magnification,
       _overAndUnderCenterOpacity = overAndUnderCenterOpacity,
       _itemExtent = itemExtent,
       _squeeze = squeeze,
       _renderChildrenOutsideViewport = renderChildrenOutsideViewport,
       _clipBehavior = clipBehavior {
    addAll(children);
  }

  static const double defaultDiameterRatio = 2.0;

  static const double defaultPerspective = 0.003;

  static const String diameterRatioZeroMessage = "You can't set a diameterRatio "
      'of 0 or of a negative number. It would imply a cylinder of 0 in diameter '
      'in which case nothing will be drawn.';

  static const String perspectiveTooHighMessage = 'A perspective too high will '
      'be clipped in the z-axis and therefore not renderable. Value must be '
      'between 0 and 0.01.';

  static const String clipBehaviorAndRenderChildrenOutsideViewportConflict =
      'Cannot renderChildrenOutsideViewport and clip since children '
      'rendered outside will be clipped anyway.';

  final ListWheelChildManager childManager;

  ViewportOffset get offset => _offset;
  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) {
      return;
    }
    if (attached) {
      _offset.removeListener(_hasScrolled);
    }
    _offset = value;
    if (attached) {
      _offset.addListener(_hasScrolled);
    }
    markNeedsLayout();
  }

  double get diameterRatio => _diameterRatio;
  double _diameterRatio;
  set diameterRatio(double value) {
    assert(
      value > 0,
      diameterRatioZeroMessage,
    );
    if (value == _diameterRatio) {
      return;
    }
    _diameterRatio = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  double get perspective => _perspective;
  double _perspective;
  set perspective(double value) {
    assert(value > 0);
    assert(
      value <= 0.01,
      perspectiveTooHighMessage,
    );
    if (value == _perspective) {
      return;
    }
    _perspective = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }


  double get offAxisFraction => _offAxisFraction;
  double _offAxisFraction = 0.0;
  set offAxisFraction(double value) {
    if (value == _offAxisFraction) {
      return;
    }
    _offAxisFraction = value;
    markNeedsPaint();
  }

  bool get useMagnifier => _useMagnifier;
  bool _useMagnifier = false;
  set useMagnifier(bool value) {
    if (value == _useMagnifier) {
      return;
    }
    _useMagnifier = value;
    markNeedsPaint();
  }
  double get magnification => _magnification;
  double _magnification = 1.0;
  set magnification(double value) {
    assert(value > 0);
    if (value == _magnification) {
      return;
    }
    _magnification = value;
    markNeedsPaint();
  }

  double get overAndUnderCenterOpacity => _overAndUnderCenterOpacity;
  double _overAndUnderCenterOpacity = 1.0;
  set overAndUnderCenterOpacity(double value) {
    assert(value >= 0 && value <= 1);
    if (value == _overAndUnderCenterOpacity) {
      return;
    }
    _overAndUnderCenterOpacity = value;
    markNeedsPaint();
  }

  double get itemExtent => _itemExtent;
  double _itemExtent;
  set itemExtent(double value) {
    assert(value > 0);
    if (value == _itemExtent) {
      return;
    }
    _itemExtent = value;
    markNeedsLayout();
  }


  double get squeeze => _squeeze;
  double _squeeze;
  set squeeze(double value) {
    assert(value > 0);
    if (value == _squeeze) {
      return;
    }
    _squeeze = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  bool get renderChildrenOutsideViewport => _renderChildrenOutsideViewport;
  bool _renderChildrenOutsideViewport;
  set renderChildrenOutsideViewport(bool value) {
    assert(
      !renderChildrenOutsideViewport || clipBehavior == Clip.none,
      clipBehaviorAndRenderChildrenOutsideViewportConflict,
    );
    if (value == _renderChildrenOutsideViewport) {
      return;
    }
    _renderChildrenOutsideViewport = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
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

  void _hasScrolled() {
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! ListWheelParentData) {
      child.parentData = ListWheelParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_hasScrolled);
  }

  @override
  void detach() {
    _offset.removeListener(_hasScrolled);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  double get _viewportExtent {
    assert(hasSize);
    return size.height;
  }

  double get _minEstimatedScrollExtent {
    assert(hasSize);
    if (childManager.childCount == null) {
      return double.negativeInfinity;
    }
    return 0.0;
  }

  double get _maxEstimatedScrollExtent {
    assert(hasSize);
    if (childManager.childCount == null) {
      return double.infinity;
    }

    return math.max(0.0, (childManager.childCount! - 1) * _itemExtent);
  }

  double get _topScrollMarginExtent {
    assert(hasSize);
    // Consider adding alignment options other than center.
    return -size.height / 2.0 + _itemExtent / 2.0;
  }

  double _getUntransformedPaintingCoordinateY(double layoutCoordinateY) {
    return layoutCoordinateY - _topScrollMarginExtent - offset.pixels;
  }

  double get _maxVisibleRadian {
    if (_diameterRatio < 1.0) {
      return math.pi / 2.0;
    }
    return math.asin(1.0 / _diameterRatio);
  }

  double _getIntrinsicCrossAxis(_ChildSizingFunction childSize) {
    double extent = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      extent = math.max(extent, childSize(child));
      child = childAfter(child);
    }
    return extent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _getIntrinsicCrossAxis(
      (RenderBox child) => child.getMinIntrinsicWidth(height),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _getIntrinsicCrossAxis(
      (RenderBox child) => child.getMaxIntrinsicWidth(height),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (childManager.childCount == null) {
      return 0.0;
    }
    return childManager.childCount! * _itemExtent;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (childManager.childCount == null) {
      return 0.0;
    }
    return childManager.childCount! * _itemExtent;
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  int indexOf(RenderBox child) {
    final ListWheelParentData childParentData = child.parentData! as ListWheelParentData;
    assert(childParentData.index != null);
    return childParentData.index!;
  }

  int scrollOffsetToIndex(double scrollOffset) => (scrollOffset / itemExtent).floor();

  double indexToScrollOffset(int index) => index * itemExtent;

  void _createChild(int index, { RenderBox? after }) {
    invokeLayoutCallback<BoxConstraints>((BoxConstraints constraints) {
      assert(constraints == this.constraints);
      childManager.createChild(index, after: after);
    });
  }

  void _destroyChild(RenderBox child) {
    invokeLayoutCallback<BoxConstraints>((BoxConstraints constraints) {
      assert(constraints == this.constraints);
      childManager.removeChild(child);
    });
  }

  void _layoutChild(RenderBox child, BoxConstraints constraints, int index) {
    child.layout(constraints, parentUsesSize: true);
    final ListWheelParentData childParentData = child.parentData! as ListWheelParentData;
    // Centers the child horizontally.
    final double crossPosition = size.width / 2.0 - child.size.width / 2.0;
    childParentData.offset = Offset(crossPosition, indexToScrollOffset(index));
  }

  @override
  void performLayout() {
    offset.applyViewportDimension(_viewportExtent);
    // Apply the content dimensions first if it has exact dimensions in case it
    // changes the scroll offset which determines what should be shown. Such as
    // if the child count decrease, we should correct the pixels first, otherwise,
    // it may be shown blank null children.
    if (childManager.childCount != null) {
      offset.applyContentDimensions(_minEstimatedScrollExtent, _maxEstimatedScrollExtent);
    }

    // The height, in pixel, that children will be visible and might be laid out
    // and painted.
    double visibleHeight = size.height * _squeeze;
    // If renderChildrenOutsideViewport is true, we spawn extra children by
    // doubling the visibility range, those that are in the backside of the
    // cylinder won't be painted anyway.
    if (renderChildrenOutsideViewport) {
      visibleHeight *= 2;
    }

    final double firstVisibleOffset =
      offset.pixels + _itemExtent / 2 - visibleHeight / 2;
    final double lastVisibleOffset = firstVisibleOffset + visibleHeight;

    // The index range that we want to spawn children. We find indexes that
    // are in the interval [firstVisibleOffset, lastVisibleOffset).
    int targetFirstIndex = scrollOffsetToIndex(firstVisibleOffset);
    int targetLastIndex = scrollOffsetToIndex(lastVisibleOffset);
    // Because we exclude lastVisibleOffset, if there's a new child starting at
    // that offset, it is removed.
    if (targetLastIndex * _itemExtent == lastVisibleOffset) {
      targetLastIndex--;
    }

    // Validates the target index range.
    while (!childManager.childExistsAt(targetFirstIndex) && targetFirstIndex <= targetLastIndex) {
      targetFirstIndex++;
    }
    while (!childManager.childExistsAt(targetLastIndex) && targetFirstIndex <= targetLastIndex) {
      targetLastIndex--;
    }

    // If it turns out there's no children to layout, we remove old children and
    // return.
    if (targetFirstIndex > targetLastIndex) {
      while (firstChild != null) {
        _destroyChild(firstChild!);
      }
      return;
    }

    // Now there are 2 cases:
    //  - The target index range and our current index range have intersection:
    //    We shorten and extend our current child list so that the two lists
    //    match. Most of the time we are in this case.
    //  - The target list and our current child list have no intersection:
    //    We first remove all children and then add one child from the target
    //    list => this case becomes the other case.

    // Case when there is no intersection.
    if (childCount > 0 &&
        (indexOf(firstChild!) > targetLastIndex || indexOf(lastChild!) < targetFirstIndex)) {
      while (firstChild != null) {
        _destroyChild(firstChild!);
      }
    }

    final BoxConstraints childConstraints = constraints.copyWith(
        minHeight: _itemExtent,
        maxHeight: _itemExtent,
        minWidth: 0.0,
      );
    // If there is no child at this stage, we add the first one that is in
    // target range.
    if (childCount == 0) {
      _createChild(targetFirstIndex);
      _layoutChild(firstChild!, childConstraints, targetFirstIndex);
    }

    int currentFirstIndex = indexOf(firstChild!);
    int currentLastIndex = indexOf(lastChild!);

    // Remove all unnecessary children by shortening the current child list, in
    // both directions.
    while (currentFirstIndex < targetFirstIndex) {
      _destroyChild(firstChild!);
      currentFirstIndex++;
    }
    while (currentLastIndex > targetLastIndex) {
      _destroyChild(lastChild!);
      currentLastIndex--;
    }

    // Relayout all active children.
    RenderBox? child = firstChild;
    int index = currentFirstIndex;
    while (child != null) {
      _layoutChild(child, childConstraints, index++);
      child = childAfter(child);
    }

    // Spawning new children that are actually visible but not in child list yet.
    while (currentFirstIndex > targetFirstIndex) {
      _createChild(currentFirstIndex - 1);
      _layoutChild(firstChild!, childConstraints, --currentFirstIndex);
    }
    while (currentLastIndex < targetLastIndex) {
      _createChild(currentLastIndex + 1, after: lastChild);
      _layoutChild(lastChild!, childConstraints, ++currentLastIndex);
    }

    // Applying content dimensions bases on how the childManager builds widgets:
    // if it is available to provide a child just out of target range, then
    // we don't know whether there's a limit yet, and set the dimension to the
    // estimated value. Otherwise, we set the dimension limited to our target
    // range.
    final double minScrollExtent = childManager.childExistsAt(targetFirstIndex - 1)
      ? _minEstimatedScrollExtent
      : indexToScrollOffset(targetFirstIndex);
    final double maxScrollExtent = childManager.childExistsAt(targetLastIndex + 1)
      ? _maxEstimatedScrollExtent
      : indexToScrollOffset(targetLastIndex);
    offset.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }

  bool _shouldClipAtCurrentOffset() {
    final double highestUntransformedPaintY =
      _getUntransformedPaintingCoordinateY(0.0);
    return highestUntransformedPaintY < 0.0
      || size.height < highestUntransformedPaintY + _maxEstimatedScrollExtent + _itemExtent;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (childCount > 0) {
      if (_shouldClipAtCurrentOffset() && clipBehavior != Clip.none) {
        _clipRectLayer.layer = context.pushClipRect(
          needsCompositing,
          offset,
          Offset.zero & size,
          _paintVisibleChildren,
          clipBehavior: clipBehavior,
          oldLayer: _clipRectLayer.layer,
        );
      } else {
        _clipRectLayer.layer = null;
        _paintVisibleChildren(context, offset);
      }
    }
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  void _paintVisibleChildren(PaintingContext context, Offset offset) {
    // The magnifier cannot be turned off if the opacity is less than 1.0.
    if (overAndUnderCenterOpacity >= 1) {
      _paintAllChildren(context, offset);
      return;
    }

    // In order to reduce the number of opacity layers, we first paint all
    // partially opaque children, then finally paint the fully opaque children.
    context.pushOpacity(offset, (overAndUnderCenterOpacity * 255).round(), (PaintingContext context, Offset offset) {
      _paintAllChildren(context, offset, center: false);
    });
    _paintAllChildren(context, offset, center: true);
  }

  void _paintAllChildren(PaintingContext context, Offset offset, { bool? center }) {
    RenderBox? childToPaint = firstChild;
    while (childToPaint != null) {
      final ListWheelParentData childParentData = childToPaint.parentData! as ListWheelParentData;
      _paintTransformedChild(childToPaint, context, offset, childParentData.offset, center: center);
      childToPaint = childAfter(childToPaint);
    }
  }

  // Takes in a child with a **scrollable layout offset** and paints it in the
  // **transformed cylindrical space viewport painting coordinates**.
  //
  // The value of `center` is passed through to _paintChildWithMagnifier only
  // if the magnifier is enabled and/or opacity is < 1.0.
  void _paintTransformedChild(
    RenderBox child,
    PaintingContext context,
    Offset offset,
    Offset layoutOffset, {
    required bool? center,
  }) {
    final Offset untransformedPaintingCoordinates = offset
        + Offset(
            layoutOffset.dx,
            _getUntransformedPaintingCoordinateY(layoutOffset.dy),
        );

    // Get child's center as a fraction of the viewport's height.
    final double fractionalY =
        (untransformedPaintingCoordinates.dy + _itemExtent / 2.0) / size.height;
    final double angle = -(fractionalY - 0.5) * 2.0 * _maxVisibleRadian / squeeze;
    // Don't paint the backside of the cylinder when
    // renderChildrenOutsideViewport is true. Otherwise, only children within
    // suitable angles (via _first/lastVisibleLayoutOffset) reach the paint
    // phase.
    if (angle > math.pi / 2.0 || angle < -math.pi / 2.0) {
      return;
    }

    final Matrix4 transform = MatrixUtils.createCylindricalProjectionTransform(
      radius: size.height * _diameterRatio / 2.0,
      angle: angle,
      perspective: _perspective,
    );

    // Offset that helps painting everything in the center (e.g. angle = 0).
    final Offset offsetToCenter = Offset(
      untransformedPaintingCoordinates.dx,
      -_topScrollMarginExtent,
    );

    final bool shouldApplyOffCenterDim = overAndUnderCenterOpacity < 1;
    if (useMagnifier || shouldApplyOffCenterDim) {
      _paintChildWithMagnifier(context, offset, child, transform, offsetToCenter, untransformedPaintingCoordinates, center: center);
    } else {
      assert(center == null);
      _paintChildCylindrically(context, offset, child, transform, offsetToCenter);
    }
  }

  // Paint child with the magnifier active - the child will be rendered
  // differently if it intersects with the magnifier.
  //
  // `center` controls how items that partially intersect the center magnifier
  // are rendered. If `center` is false, items are only painted cynlindrically.
  // If `center` is true, only the clipped magnifier items are painted.
  // If `center` is null, partially intersecting items are painted both as the
  // magnifier and cynlidrical item, while non-intersecting items are painted
  // only cylindrically.
  //
  // This property is used to lift the opacity that would be applied to each
  // cylindrical item into a single layer, reducing the rendering cost of the
  // pickers which use this viewport.
  void _paintChildWithMagnifier(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    Matrix4 cylindricalTransform,
    Offset offsetToCenter,
    Offset untransformedPaintingCoordinates, {
    required bool? center,
  }) {
    final double magnifierTopLinePosition =
        size.height / 2 - _itemExtent * _magnification / 2;
    final double magnifierBottomLinePosition =
        size.height / 2 + _itemExtent * _magnification / 2;

    final bool isAfterMagnifierTopLine = untransformedPaintingCoordinates.dy
        >= magnifierTopLinePosition - _itemExtent * _magnification;
    final bool isBeforeMagnifierBottomLine = untransformedPaintingCoordinates.dy
        <= magnifierBottomLinePosition;

    final Rect centerRect = Rect.fromLTWH(
      0.0,
      magnifierTopLinePosition,
      size.width,
      _itemExtent * _magnification,
    );
    final Rect topHalfRect = Rect.fromLTWH(
      0.0,
      0.0,
      size.width,
      magnifierTopLinePosition,
    );
    final Rect bottomHalfRect = Rect.fromLTWH(
      0.0,
      magnifierBottomLinePosition,
      size.width,
      magnifierTopLinePosition,
    );
    // Some part of the child is in the center magnifier.
    final bool inCenter = isAfterMagnifierTopLine && isBeforeMagnifierBottomLine;

    if ((center == null || center) && inCenter) {
      // Clipping the part in the center.
      context.pushClipRect(
        needsCompositing,
        offset,
        centerRect,
        (PaintingContext context, Offset offset) {
          context.pushTransform(
            needsCompositing,
            offset,
            _magnifyTransform(),
            (PaintingContext context, Offset offset) {
              context.paintChild(child, offset + untransformedPaintingCoordinates);
            },
          );
        },
      );
    }

    // Clipping the part in either the top-half or bottom-half of the wheel.
    if ((center == null || !center) && inCenter) {
      context.pushClipRect(
        needsCompositing,
        offset,
        untransformedPaintingCoordinates.dy <= magnifierTopLinePosition
          ? topHalfRect
          : bottomHalfRect,
        (PaintingContext context, Offset offset) {
            _paintChildCylindrically(
              context,
              offset,
              child,
              cylindricalTransform,
              offsetToCenter,
            );
        },
      );
    }

    if ((center == null || !center) && !inCenter) {
      _paintChildCylindrically(
        context,
        offset,
        child,
        cylindricalTransform,
        offsetToCenter,
      );
    }
  }

  // / Paint the child cylindrically at given offset.
  void _paintChildCylindrically(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    Matrix4 cylindricalTransform,
    Offset offsetToCenter,
  ) {
    final Offset paintOriginOffset = offset + offsetToCenter;

    // Paint child cylindrically, without [overAndUnderCenterOpacity].
    void painter(PaintingContext context, Offset offset) {
      context.paintChild(
        child,
        // Paint everything in the center (e.g. angle = 0), then transform.
        paintOriginOffset,
      );
    }

    context.pushTransform(
      needsCompositing,
      offset,
      _centerOriginTransform(cylindricalTransform),
      // Pre-transform painting function.
      painter,
    );

    final ListWheelParentData childParentData = child.parentData! as ListWheelParentData;
    // Save the final transform that accounts both for the offset and cylindrical transform.
    final Matrix4 transform = _centerOriginTransform(cylindricalTransform)
      ..translate(paintOriginOffset.dx, paintOriginOffset.dy);
    childParentData.transform = transform;
  }

  Matrix4 _magnifyTransform() {
    final Matrix4 magnify = Matrix4.identity();
    magnify.translate(size.width * (-_offAxisFraction + 0.5), size.height / 2);
    magnify.scale(_magnification, _magnification, _magnification);
    magnify.translate(-size.width * (-_offAxisFraction + 0.5), -size.height / 2);
    return magnify;
  }

  Matrix4 _centerOriginTransform(Matrix4 originalMatrix) {
    final Matrix4 result = Matrix4.identity();
    final Offset centerOriginTranslation = Alignment.center.alongSize(size);
    result.translate(
      centerOriginTranslation.dx * (-_offAxisFraction * 2 + 1),
      centerOriginTranslation.dy,
    );
    result.multiply(originalMatrix);
    result.translate(
      -centerOriginTranslation.dx * (-_offAxisFraction * 2 + 1),
      -centerOriginTranslation.dy,
    );
    return result;
  }

  static bool _debugAssertValidHitTestOffsets(String context, Offset offset1, Offset offset2) {
    if (offset1 != offset2) {
      throw FlutterError("$context - hit test expected values didn't match: $offset1 != $offset2");
    }
    return true;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final ListWheelParentData parentData = child.parentData! as ListWheelParentData;
    final Matrix4? paintTransform = parentData.transform;
    if (paintTransform != null) {
      transform.multiply(paintTransform);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    if (_shouldClipAtCurrentOffset()) {
      return Offset.zero & size;
    }
    return null;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    RenderBox? child = lastChild;
    while (child != null) {
      final ListWheelParentData childParentData = child.parentData! as ListWheelParentData;
      final Matrix4? transform = childParentData.transform;
      // Skip not painted children
      if (transform != null) {
        final bool isHit = result.addWithPaintTransform(
          transform: transform,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) {
            assert(() {
              final Matrix4? inverted = Matrix4.tryInvert(PointerEvent.removePerspectiveTransform(transform));
              if (inverted == null) {
                return _debugAssertValidHitTestOffsets('Null inverted transform', transformed, position);
              }
              return _debugAssertValidHitTestOffsets('MatrixUtils.transformPoint', transformed, MatrixUtils.transformPoint(inverted, position));
            }());
            return child!.hitTest(result, position: transformed);
          },
        );
        if (isHit) {
          return true;
        }
      }
      child = childParentData.previousSibling;
    }
    return false;
  }

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, { Rect? rect }) {
    // `target` is only fully revealed when in the selected/center position. Therefore,
    // this method always returns the offset that shows `target` in the center position,
    // which is the same offset for all `alignment` values.

    rect ??= target.paintBounds;

    // `child` will be the last RenderObject before the viewport when walking up from `target`.
    RenderObject child = target;
    while (child.parent != this) {
      child = child.parent!;
    }

    final ListWheelParentData parentData = child.parentData! as ListWheelParentData;
    final double targetOffset = parentData.offset.dy; // the so-called "centerPosition"

    final Matrix4 transform = target.getTransformTo(child);
    final Rect bounds = MatrixUtils.transformRect(transform, rect);
    final Rect targetRect = bounds.translate(0.0, (size.height - itemExtent) / 2);

    return RevealedOffset(offset: targetOffset, rect: targetRect);
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (descendant != null) {
      // Shows the descendant in the selected/center position.
      final RevealedOffset revealedOffset = getOffsetToReveal(descendant, 0.5, rect: rect);
      if (duration == Duration.zero) {
        offset.jumpTo(revealedOffset.offset);
      } else {
        offset.animateTo(revealedOffset.offset, duration: duration, curve: curve);
      }
      rect = revealedOffset.rect;
    }

    super.showOnScreen(
      rect: rect,
      duration: duration,
      curve: curve,
    );
  }
}