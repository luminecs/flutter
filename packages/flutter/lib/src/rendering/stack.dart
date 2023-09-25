// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';

import 'box.dart';
import 'layer.dart';
import 'layout_helper.dart';
import 'object.dart';

@immutable
class RelativeRect {
  const RelativeRect.fromLTRB(this.left, this.top, this.right, this.bottom);

  factory RelativeRect.fromSize(Rect rect, Size container) {
    return RelativeRect.fromLTRB(rect.left, rect.top, container.width - rect.right, container.height - rect.bottom);
  }

  factory RelativeRect.fromRect(Rect rect, Rect container) {
    return RelativeRect.fromLTRB(
      rect.left - container.left,
      rect.top - container.top,
      container.right - rect.right,
      container.bottom - rect.bottom,
    );
  }

  factory RelativeRect.fromDirectional({
    required TextDirection textDirection,
    required double start,
    required double top,
    required double end,
    required double bottom,
  }) {
    double left;
    double right;
    switch (textDirection) {
      case TextDirection.rtl:
        left = end;
        right = start;
      case TextDirection.ltr:
        left = start;
        right = end;
    }

    return RelativeRect.fromLTRB(left, top, right, bottom);
  }

  static const RelativeRect fill = RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0);

  final double left;

  final double top;

  final double right;

  final double bottom;

  bool get hasInsets => left > 0.0 || top > 0.0 || right > 0.0 || bottom > 0.0;

  RelativeRect shift(Offset offset) {
    return RelativeRect.fromLTRB(left + offset.dx, top + offset.dy, right - offset.dx, bottom - offset.dy);
  }

  RelativeRect inflate(double delta) {
    return RelativeRect.fromLTRB(left - delta, top - delta, right - delta, bottom - delta);
  }

  RelativeRect deflate(double delta) {
    return inflate(-delta);
  }

  RelativeRect intersect(RelativeRect other) {
    return RelativeRect.fromLTRB(
      math.max(left, other.left),
      math.max(top, other.top),
      math.max(right, other.right),
      math.max(bottom, other.bottom),
    );
  }

  Rect toRect(Rect container) {
    return Rect.fromLTRB(left, top, container.width - right, container.height - bottom);
  }

  Size toSize(Size container) {
    return Size(container.width - left - right, container.height - top - bottom);
  }

  static RelativeRect? lerp(RelativeRect? a, RelativeRect? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return RelativeRect.fromLTRB(b!.left * t, b.top * t, b.right * t, b.bottom * t);
    }
    if (b == null) {
      final double k = 1.0 - t;
      return RelativeRect.fromLTRB(b!.left * k, b.top * k, b.right * k, b.bottom * k);
    }
    return RelativeRect.fromLTRB(
      lerpDouble(a.left, b.left, t)!,
      lerpDouble(a.top, b.top, t)!,
      lerpDouble(a.right, b.right, t)!,
      lerpDouble(a.bottom, b.bottom, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RelativeRect
        && other.left == left
        && other.top == top
        && other.right == right
        && other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'RelativeRect.fromLTRB(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, ${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)})';
}

class StackParentData extends ContainerBoxParentData<RenderBox> {
  double? top;

  double? right;

  double? bottom;

  double? left;

  double? width;

  double? height;

  RelativeRect get rect => RelativeRect.fromLTRB(left!, top!, right!, bottom!);
  set rect(RelativeRect value) {
    top = value.top;
    right = value.right;
    bottom = value.bottom;
    left = value.left;
  }

  bool get isPositioned => top != null || right != null || bottom != null || left != null || width != null || height != null;

  @override
  String toString() {
    final List<String> values = <String>[
      if (top != null) 'top=${debugFormatDouble(top)}',
      if (right != null) 'right=${debugFormatDouble(right)}',
      if (bottom != null) 'bottom=${debugFormatDouble(bottom)}',
      if (left != null) 'left=${debugFormatDouble(left)}',
      if (width != null) 'width=${debugFormatDouble(width)}',
      if (height != null) 'height=${debugFormatDouble(height)}',
    ];
    if (values.isEmpty) {
      values.add('not positioned');
    }
    values.add(super.toString());
    return values.join('; ');
  }
}

enum StackFit {
  loose,

  expand,

  passthrough,
}

class RenderStack extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, StackParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, StackParentData> {
  RenderStack({
    List<RenderBox>? children,
    AlignmentGeometry alignment = AlignmentDirectional.topStart,
    TextDirection? textDirection,
    StackFit fit = StackFit.loose,
    Clip clipBehavior = Clip.hardEdge,
  }) : _alignment = alignment,
       _textDirection = textDirection,
       _fit = fit,
       _clipBehavior = clipBehavior {
    addAll(children);
  }

  bool _hasVisualOverflow = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! StackParentData) {
      child.parentData = StackParentData();
    }
  }

  Alignment? _resolvedAlignment;

  void _resolve() {
    if (_resolvedAlignment != null) {
      return;
    }
    _resolvedAlignment = alignment.resolve(textDirection);
  }

  void _markNeedResolution() {
    _resolvedAlignment = null;
    markNeedsLayout();
  }

  AlignmentGeometry get alignment => _alignment;
  AlignmentGeometry _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    _markNeedResolution();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    _markNeedResolution();
  }

  StackFit get fit => _fit;
  StackFit _fit;
  set fit(StackFit value) {
    if (_fit != value) {
      _fit = value;
      markNeedsLayout();
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

  static double getIntrinsicDimension(RenderBox? firstChild, double Function(RenderBox child) mainChildSizeGetter) {
    double extent = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      final StackParentData childParentData = child.parentData! as StackParentData;
      if (!childParentData.isPositioned) {
        extent = math.max(extent, mainChildSizeGetter(child));
      }
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    return extent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMinIntrinsicWidth(height));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMaxIntrinsicWidth(height));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMaxIntrinsicHeight(width));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  static bool layoutPositionedChild(RenderBox child, StackParentData childParentData, Size size, Alignment alignment) {
    assert(childParentData.isPositioned);
    assert(child.parentData == childParentData);

    bool hasVisualOverflow = false;
    BoxConstraints childConstraints = const BoxConstraints();

    if (childParentData.left != null && childParentData.right != null) {
      childConstraints = childConstraints.tighten(width: size.width - childParentData.right! - childParentData.left!);
    } else if (childParentData.width != null) {
      childConstraints = childConstraints.tighten(width: childParentData.width);
    }

    if (childParentData.top != null && childParentData.bottom != null) {
      childConstraints = childConstraints.tighten(height: size.height - childParentData.bottom! - childParentData.top!);
    } else if (childParentData.height != null) {
      childConstraints = childConstraints.tighten(height: childParentData.height);
    }

    child.layout(childConstraints, parentUsesSize: true);

    final double x;
    if (childParentData.left != null) {
      x = childParentData.left!;
    } else if (childParentData.right != null) {
      x = size.width - childParentData.right! - child.size.width;
    } else {
      x = alignment.alongOffset(size - child.size as Offset).dx;
    }

    if (x < 0.0 || x + child.size.width > size.width) {
      hasVisualOverflow = true;
    }

    final double y;
    if (childParentData.top != null) {
      y = childParentData.top!;
    } else if (childParentData.bottom != null) {
      y = size.height - childParentData.bottom! - child.size.height;
    } else {
      y = alignment.alongOffset(size - child.size as Offset).dy;
    }

    if (y < 0.0 || y + child.size.height > size.height) {
      hasVisualOverflow = true;
    }

    childParentData.offset = Offset(x, y);

    return hasVisualOverflow;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    );
  }

  Size _computeSize({required BoxConstraints constraints, required ChildLayouter layoutChild}) {
    _resolve();
    assert(_resolvedAlignment != null);
    bool hasNonPositionedChildren = false;
    if (childCount == 0) {
      return (constraints.biggest.isFinite) ? constraints.biggest : constraints.smallest;
    }

    double width = constraints.minWidth;
    double height = constraints.minHeight;

    final BoxConstraints nonPositionedConstraints = switch (fit) {
      StackFit.loose => constraints.loosen(),
      StackFit.expand => BoxConstraints.tight(constraints.biggest),
      StackFit.passthrough => constraints,
    };

    RenderBox? child = firstChild;
    while (child != null) {
      final StackParentData childParentData = child.parentData! as StackParentData;

      if (!childParentData.isPositioned) {
        hasNonPositionedChildren = true;

        final Size childSize = layoutChild(child, nonPositionedConstraints);

        width = math.max(width, childSize.width);
        height = math.max(height, childSize.height);
      }

      child = childParentData.nextSibling;
    }

    final Size size;
    if (hasNonPositionedChildren) {
      size = Size(width, height);
      assert(size.width == constraints.constrainWidth(width));
      assert(size.height == constraints.constrainHeight(height));
    } else {
      size = constraints.biggest;
    }

    assert(size.isFinite);
    return size;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    _hasVisualOverflow = false;

    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );

    assert(_resolvedAlignment != null);
    RenderBox? child = firstChild;
    while (child != null) {
      final StackParentData childParentData = child.parentData! as StackParentData;

      if (!childParentData.isPositioned) {
        childParentData.offset = _resolvedAlignment!.alongOffset(size - child.size as Offset);
      } else {
        _hasVisualOverflow = layoutPositionedChild(child, childParentData, size, _resolvedAlignment!) || _hasVisualOverflow;
      }

      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return defaultHitTestChildren(result, position: position);
  }

  @protected
  void paintStack(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (clipBehavior != Clip.none && _hasVisualOverflow) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        paintStack,
        clipBehavior: clipBehavior,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      paintStack(context, offset);
    }
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    switch (clipBehavior) {
      case Clip.none:
        return null;
      case Clip.hardEdge:
      case Clip.antiAlias:
      case Clip.antiAliasWithSaveLayer:
        return _hasVisualOverflow ? Offset.zero & size : null;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(EnumProperty<StackFit>('fit', fit));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior, defaultValue: Clip.hardEdge));
  }
}

class RenderIndexedStack extends RenderStack {
  RenderIndexedStack({
    super.children,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
    int? index = 0,
  }) : _index = index;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (index != null && firstChild != null) {
      visitor(_childAtIndex());
    }
  }

  int? get index => _index;
  int? _index;
  set index(int? value) {
    if (_index != value) {
      _index = value;
      markNeedsLayout();
    }
  }

  RenderBox _childAtIndex() {
    assert(index != null);
    RenderBox? child = firstChild;
    int i = 0;
    while (child != null && i < index!) {
      final StackParentData childParentData = child.parentData! as StackParentData;
      child = childParentData.nextSibling;
      i += 1;
    }
    assert(i == index);
    assert(child != null);
    return child!;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    if (firstChild == null || index == null) {
      return false;
    }
    final RenderBox child = _childAtIndex();
    final StackParentData childParentData = child.parentData! as StackParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        assert(transformed == position - childParentData.offset);
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void paintStack(PaintingContext context, Offset offset) {
    if (firstChild == null || index == null) {
      return;
    }
    final RenderBox child = _childAtIndex();
    final StackParentData childParentData = child.parentData! as StackParentData;
    context.paintChild(child, childParentData.offset + offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('index', index));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    int i = 0;
    RenderObject? child = firstChild;
    while (child != null) {
      children.add(child.toDiagnosticsNode(
        name: 'child ${i + 1}',
        style: i != index ? DiagnosticsTreeStyle.offstage : null,
      ));
      child = (child.parentData! as StackParentData).nextSibling;
      i += 1;
    }
    return children;
  }
}