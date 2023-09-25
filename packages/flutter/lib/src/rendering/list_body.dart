// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'box.dart';
import 'object.dart';

class ListBodyParentData extends ContainerBoxParentData<RenderBox> { }

typedef _ChildSizingFunction = double Function(RenderBox child);

class RenderListBody extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ListBodyParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, ListBodyParentData> {
  RenderListBody({
    List<RenderBox>? children,
    AxisDirection axisDirection = AxisDirection.down,
  }) : _axisDirection = axisDirection {
    addAll(children);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ListBodyParentData) {
      child.parentData = ListBodyParentData();
    }
  }

  AxisDirection get axisDirection => _axisDirection;
  AxisDirection _axisDirection;
  set axisDirection(AxisDirection value) {
    if (_axisDirection == value) {
      return;
    }
    _axisDirection = value;
    markNeedsLayout();
  }

  Axis get mainAxis => axisDirectionToAxis(axisDirection);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(_debugCheckConstraints(constraints));
    double mainAxisExtent = 0.0;
    RenderBox? child = firstChild;
    switch (axisDirection) {
      case AxisDirection.right:
      case AxisDirection.left:
        final BoxConstraints innerConstraints = BoxConstraints.tightFor(height: constraints.maxHeight);
        while (child != null) {
          final Size childSize = child.getDryLayout(innerConstraints);
          mainAxisExtent += childSize.width;
          child = childAfter(child);
        }
        return constraints.constrain(Size(mainAxisExtent, constraints.maxHeight));
      case AxisDirection.up:
      case AxisDirection.down:
        final BoxConstraints innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth);
        while (child != null) {
          final Size childSize = child.getDryLayout(innerConstraints);
          mainAxisExtent += childSize.height;
          child = childAfter(child);
        }
        return constraints.constrain(Size(constraints.maxWidth, mainAxisExtent));
    }
  }

  bool _debugCheckConstraints(BoxConstraints constraints) {
    assert(() {
      switch (mainAxis) {
        case Axis.horizontal:
          if (!constraints.hasBoundedWidth) {
            return true;
          }
        case Axis.vertical:
          if (!constraints.hasBoundedHeight) {
            return true;
          }
      }
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('RenderListBody must have unlimited space along its main axis.'),
        ErrorDescription(
          'RenderListBody does not clip or resize its children, so it must be '
          'placed in a parent that does not constrain the main '
          'axis.',
        ),
        ErrorHint(
          'You probably want to put the RenderListBody inside a '
          'RenderViewport with a matching main axis.',
        ),
      ]);
    }());
    assert(() {
      switch (mainAxis) {
        case Axis.horizontal:
          if (constraints.hasBoundedHeight) {
            return true;
          }
        case Axis.vertical:
          if (constraints.hasBoundedWidth) {
            return true;
          }
      }
      // TODO(ianh): Detect if we're actually nested blocks and say something
      // more specific to the exact situation in that case, and don't mention
      // nesting blocks in the negative case.
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('RenderListBody must have a bounded constraint for its cross axis.'),
        ErrorDescription(
          "RenderListBody forces its children to expand to fit the RenderListBody's container, "
          'so it must be placed in a parent that constrains the cross '
          'axis to a finite dimension.',
        ),
        // TODO(jacobr): this hint is a great candidate to promote to being an
        // automated quick fix in the future.
        ErrorHint(
          'If you are attempting to nest a RenderListBody with '
          'one direction inside one of another direction, you will want to '
          'wrap the inner one inside a box that fixes the dimension in that direction, '
          'for example, a RenderIntrinsicWidth or RenderIntrinsicHeight object. '
          'This is relatively expensive, however.', // (that's why we don't do it automatically)
        ),
      ]);
    }());
    return true;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    assert(_debugCheckConstraints(constraints));
    double mainAxisExtent = 0.0;
    RenderBox? child = firstChild;
    switch (axisDirection) {
      case AxisDirection.right:
        final BoxConstraints innerConstraints = BoxConstraints.tightFor(height: constraints.maxHeight);
        while (child != null) {
          child.layout(innerConstraints, parentUsesSize: true);
          final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
          childParentData.offset = Offset(mainAxisExtent, 0.0);
          mainAxisExtent += child.size.width;
          assert(child.parentData == childParentData);
          child = childParentData.nextSibling;
        }
        size = constraints.constrain(Size(mainAxisExtent, constraints.maxHeight));
      case AxisDirection.left:
        final BoxConstraints innerConstraints = BoxConstraints.tightFor(height: constraints.maxHeight);
        while (child != null) {
          child.layout(innerConstraints, parentUsesSize: true);
          final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
          mainAxisExtent += child.size.width;
          assert(child.parentData == childParentData);
          child = childParentData.nextSibling;
        }
        double position = 0.0;
        child = firstChild;
        while (child != null) {
          final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
          position += child.size.width;
          childParentData.offset = Offset(mainAxisExtent - position, 0.0);
          assert(child.parentData == childParentData);
          child = childParentData.nextSibling;
        }
        size = constraints.constrain(Size(mainAxisExtent, constraints.maxHeight));
      case AxisDirection.down:
        final BoxConstraints innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth);
        while (child != null) {
          child.layout(innerConstraints, parentUsesSize: true);
          final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
          childParentData.offset = Offset(0.0, mainAxisExtent);
          mainAxisExtent += child.size.height;
          assert(child.parentData == childParentData);
          child = childParentData.nextSibling;
        }
        size = constraints.constrain(Size(constraints.maxWidth, mainAxisExtent));
      case AxisDirection.up:
        final BoxConstraints innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth);
        while (child != null) {
          child.layout(innerConstraints, parentUsesSize: true);
          final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
          mainAxisExtent += child.size.height;
          assert(child.parentData == childParentData);
          child = childParentData.nextSibling;
        }
        double position = 0.0;
        child = firstChild;
        while (child != null) {
          final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
          position += child.size.height;
          childParentData.offset = Offset(0.0, mainAxisExtent - position);
          assert(child.parentData == childParentData);
          child = childParentData.nextSibling;
        }
        size = constraints.constrain(Size(constraints.maxWidth, mainAxisExtent));
    }
    assert(size.isFinite);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', axisDirection));
  }

  double _getIntrinsicCrossAxis(_ChildSizingFunction childSize) {
    double extent = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      extent = math.max(extent, childSize(child));
      final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
      child = childParentData.nextSibling;
    }
    return extent;
  }

  double _getIntrinsicMainAxis(_ChildSizingFunction childSize) {
    double extent = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      extent += childSize(child);
      final ListBodyParentData childParentData = child.parentData! as ListBodyParentData;
      child = childParentData.nextSibling;
    }
    return extent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    switch (mainAxis) {
      case Axis.horizontal:
        return _getIntrinsicMainAxis((RenderBox child) => child.getMinIntrinsicWidth(height));
      case Axis.vertical:
        return _getIntrinsicCrossAxis((RenderBox child) => child.getMinIntrinsicWidth(height));
    }
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    switch (mainAxis) {
      case Axis.horizontal:
        return _getIntrinsicMainAxis((RenderBox child) => child.getMaxIntrinsicWidth(height));
      case Axis.vertical:
        return _getIntrinsicCrossAxis((RenderBox child) => child.getMaxIntrinsicWidth(height));
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    switch (mainAxis) {
      case Axis.horizontal:
        return _getIntrinsicMainAxis((RenderBox child) => child.getMinIntrinsicHeight(width));
      case Axis.vertical:
        return _getIntrinsicCrossAxis((RenderBox child) => child.getMinIntrinsicHeight(width));
    }
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    switch (mainAxis) {
      case Axis.horizontal:
        return _getIntrinsicMainAxis((RenderBox child) => child.getMaxIntrinsicHeight(width));
      case Axis.vertical:
        return _getIntrinsicCrossAxis((RenderBox child) => child.getMaxIntrinsicHeight(width));
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return defaultHitTestChildren(result, position: position);
  }

}