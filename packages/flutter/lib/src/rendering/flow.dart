import 'dart:ui' as ui show Color;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'box.dart';
import 'layer.dart';
import 'object.dart';

abstract class FlowPaintingContext {
  Size get size;

  int get childCount;

  Size? getChildSize(int i);

  void paintChild(int i, {Matrix4 transform, double opacity = 1.0});
}

abstract class FlowDelegate {
  const FlowDelegate({Listenable? repaint}) : _repaint = repaint;

  final Listenable? _repaint;

  Size getSize(BoxConstraints constraints) => constraints.biggest;

  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      constraints;

  void paintChildren(FlowPaintingContext context);

  bool shouldRelayout(covariant FlowDelegate oldDelegate) => false;

  bool shouldRepaint(covariant FlowDelegate oldDelegate);

  @override
  String toString() => objectRuntimeType(this, 'FlowDelegate');
}

class FlowParentData extends ContainerBoxParentData<RenderBox> {
  Matrix4? _transform;
}

class RenderFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FlowParentData>
    implements FlowPaintingContext {
  RenderFlow({
    List<RenderBox>? children,
    required FlowDelegate delegate,
    Clip clipBehavior = Clip.hardEdge,
  })  : _delegate = delegate,
        _clipBehavior = clipBehavior {
    addAll(children);
  }

  @override
  void setupParentData(RenderBox child) {
    final ParentData? childParentData = child.parentData;
    if (childParentData is FlowParentData) {
      childParentData._transform = null;
    } else {
      child.parentData = FlowParentData();
    }
  }

  FlowDelegate get delegate => _delegate;
  FlowDelegate _delegate;
  set delegate(FlowDelegate newDelegate) {
    if (_delegate == newDelegate) {
      return;
    }
    final FlowDelegate oldDelegate = _delegate;
    _delegate = newDelegate;

    if (newDelegate.runtimeType != oldDelegate.runtimeType ||
        newDelegate.shouldRelayout(oldDelegate)) {
      markNeedsLayout();
    } else if (newDelegate.shouldRepaint(oldDelegate)) {
      markNeedsPaint();
    }

    if (attached) {
      oldDelegate._repaint?.removeListener(markNeedsPaint);
      newDelegate._repaint?.addListener(markNeedsPaint);
    }
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
    _delegate._repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _delegate._repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  Size _getSize(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.constrain(_delegate.getSize(constraints));
  }

  @override
  bool get isRepaintBoundary => true;

  // TODO(ianh): It's a bit dubious to be using the getSize function from the delegate to
  // figure out the intrinsic dimensions. We really should either not support intrinsics,
  // or we should expose intrinsic delegate callbacks and throw if they're not implemented.

  @override
  double computeMinIntrinsicWidth(double height) {
    final double width =
        _getSize(BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite) {
      return width;
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double width =
        _getSize(BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite) {
      return width;
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double height =
        _getSize(BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite) {
      return height;
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double height =
        _getSize(BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite) {
      return height;
    }
    return 0.0;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _getSize(constraints);
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    size = _getSize(constraints);
    int i = 0;
    _randomAccessChildren.clear();
    RenderBox? child = firstChild;
    while (child != null) {
      _randomAccessChildren.add(child);
      final BoxConstraints innerConstraints =
          _delegate.getConstraintsForChild(i, constraints);
      child.layout(innerConstraints, parentUsesSize: true);
      final FlowParentData childParentData =
          child.parentData! as FlowParentData;
      childParentData.offset = Offset.zero;
      child = childParentData.nextSibling;
      i += 1;
    }
  }

  // Updated during layout. Only valid if layout is not dirty.
  final List<RenderBox> _randomAccessChildren = <RenderBox>[];

  // Updated during paint.
  final List<int> _lastPaintOrder = <int>[];

  // Only valid during paint.
  PaintingContext? _paintingContext;
  Offset? _paintingOffset;

  @override
  Size? getChildSize(int i) {
    if (i < 0 || i >= _randomAccessChildren.length) {
      return null;
    }
    return _randomAccessChildren[i].size;
  }

  @override
  void paintChild(int i, {Matrix4? transform, double opacity = 1.0}) {
    transform ??= Matrix4.identity();
    final RenderBox child = _randomAccessChildren[i];
    final FlowParentData childParentData = child.parentData! as FlowParentData;
    assert(() {
      if (childParentData._transform != null) {
        throw FlutterError(
          'Cannot call paintChild twice for the same child.\n'
          'The flow delegate of type ${_delegate.runtimeType} attempted to '
          'paint child $i multiple times, which is not permitted.',
        );
      }
      return true;
    }());
    _lastPaintOrder.add(i);
    childParentData._transform = transform;

    // We return after assigning _transform so that the transparent child can
    // still be hit tested at the correct location.
    if (opacity == 0.0) {
      return;
    }

    void painter(PaintingContext context, Offset offset) {
      context.paintChild(child, offset);
    }

    if (opacity == 1.0) {
      _paintingContext!.pushTransform(
          needsCompositing, _paintingOffset!, transform, painter);
    } else {
      _paintingContext!
          .pushOpacity(_paintingOffset!, ui.Color.getAlphaFromOpacity(opacity),
              (PaintingContext context, Offset offset) {
        context.pushTransform(needsCompositing, offset, transform!, painter);
      });
    }
  }

  void _paintWithDelegate(PaintingContext context, Offset offset) {
    _lastPaintOrder.clear();
    _paintingContext = context;
    _paintingOffset = offset;
    for (final RenderBox child in _randomAccessChildren) {
      final FlowParentData childParentData =
          child.parentData! as FlowParentData;
      childParentData._transform = null;
    }
    try {
      _delegate.paintChildren(this);
    } finally {
      _paintingContext = null;
      _paintingOffset = null;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clipRectLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintWithDelegate,
      clipBehavior: clipBehavior,
      oldLayer: _clipRectLayer.layer,
    );
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final List<RenderBox> children = getChildrenAsList();
    for (int i = _lastPaintOrder.length - 1; i >= 0; --i) {
      final int childIndex = _lastPaintOrder[i];
      if (childIndex >= children.length) {
        continue;
      }
      final RenderBox child = children[childIndex];
      final FlowParentData childParentData =
          child.parentData! as FlowParentData;
      final Matrix4? transform = childParentData._transform;
      if (transform == null) {
        continue;
      }
      final bool absorbed = result.addWithPaintTransform(
        transform: transform,
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) {
          return child.hitTest(result, position: position);
        },
      );
      if (absorbed) {
        return true;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final FlowParentData childParentData = child.parentData! as FlowParentData;
    if (childParentData._transform != null) {
      transform.multiply(childParentData._transform!);
    }
    super.applyPaintTransform(child, transform);
  }
}
