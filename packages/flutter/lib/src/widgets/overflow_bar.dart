import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';

enum OverflowBarAlignment {
  start,

  end,

  center,
}

class OverflowBar extends MultiChildRenderObjectWidget {
  const OverflowBar({
    super.key,
    this.spacing = 0.0,
    this.alignment,
    this.overflowSpacing = 0.0,
    this.overflowAlignment = OverflowBarAlignment.start,
    this.overflowDirection = VerticalDirection.down,
    this.textDirection,
    this.clipBehavior = Clip.none,
    super.children,
  });

  final double spacing;

  final MainAxisAlignment? alignment;

  final double overflowSpacing;

  final OverflowBarAlignment overflowAlignment;

  final VerticalDirection overflowDirection;

  final TextDirection? textDirection;

  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOverflowBar(
      spacing: spacing,
      alignment: alignment,
      overflowSpacing: overflowSpacing,
      overflowAlignment: overflowAlignment,
      overflowDirection: overflowDirection,
      textDirection: textDirection ?? Directionality.of(context),
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderOverflowBar)
      ..spacing = spacing
      ..alignment = alignment
      ..overflowSpacing = overflowSpacing
      ..overflowAlignment = overflowAlignment
      ..overflowDirection = overflowDirection
      ..textDirection = textDirection ?? Directionality.of(context)
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('spacing', spacing, defaultValue: 0));
    properties.add(EnumProperty<MainAxisAlignment>('alignment', alignment,
        defaultValue: null));
    properties.add(
        DoubleProperty('overflowSpacing', overflowSpacing, defaultValue: 0));
    properties.add(EnumProperty<OverflowBarAlignment>(
        'overflowAlignment', overflowAlignment,
        defaultValue: OverflowBarAlignment.start));
    properties.add(EnumProperty<VerticalDirection>(
        'overflowDirection', overflowDirection,
        defaultValue: VerticalDirection.down));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
  }
}

class _OverflowBarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderOverflowBar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverflowBarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverflowBarParentData> {
  _RenderOverflowBar({
    List<RenderBox>? children,
    double spacing = 0.0,
    MainAxisAlignment? alignment,
    double overflowSpacing = 0.0,
    OverflowBarAlignment overflowAlignment = OverflowBarAlignment.start,
    VerticalDirection overflowDirection = VerticalDirection.down,
    required TextDirection textDirection,
    Clip clipBehavior = Clip.none,
  })  : _spacing = spacing,
        _alignment = alignment,
        _overflowSpacing = overflowSpacing,
        _overflowAlignment = overflowAlignment,
        _overflowDirection = overflowDirection,
        _textDirection = textDirection,
        _clipBehavior = clipBehavior {
    addAll(children);
  }

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) {
      return;
    }
    _spacing = value;
    markNeedsLayout();
  }

  MainAxisAlignment? get alignment => _alignment;
  MainAxisAlignment? _alignment;
  set alignment(MainAxisAlignment? value) {
    if (_alignment == value) {
      return;
    }
    _alignment = value;
    markNeedsLayout();
  }

  double get overflowSpacing => _overflowSpacing;
  double _overflowSpacing;
  set overflowSpacing(double value) {
    if (_overflowSpacing == value) {
      return;
    }
    _overflowSpacing = value;
    markNeedsLayout();
  }

  OverflowBarAlignment get overflowAlignment => _overflowAlignment;
  OverflowBarAlignment _overflowAlignment;
  set overflowAlignment(OverflowBarAlignment value) {
    if (_overflowAlignment == value) {
      return;
    }
    _overflowAlignment = value;
    markNeedsLayout();
  }

  VerticalDirection get overflowDirection => _overflowDirection;
  VerticalDirection _overflowDirection;
  set overflowDirection(VerticalDirection value) {
    if (_overflowDirection == value) {
      return;
    }
    _overflowDirection = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.none;
  set clipBehavior(Clip value) {
    if (value == _clipBehavior) {
      return;
    }
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverflowBarParentData) {
      child.parentData = _OverflowBarParentData();
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    RenderBox? child = firstChild;
    if (child == null) {
      return 0;
    }
    double barWidth = 0.0;
    while (child != null) {
      barWidth += child.getMinIntrinsicWidth(double.infinity);
      child = childAfter(child);
    }
    barWidth += spacing * (childCount - 1);

    double height = 0.0;
    if (barWidth > width) {
      child = firstChild;
      while (child != null) {
        height += child.getMinIntrinsicHeight(width);
        child = childAfter(child);
      }
      return height + overflowSpacing * (childCount - 1);
    } else {
      child = firstChild;
      while (child != null) {
        height = math.max(height, child.getMinIntrinsicHeight(width));
        child = childAfter(child);
      }
      return height;
    }
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    RenderBox? child = firstChild;
    if (child == null) {
      return 0;
    }
    double barWidth = 0.0;
    while (child != null) {
      barWidth += child.getMinIntrinsicWidth(double.infinity);
      child = childAfter(child);
    }
    barWidth += spacing * (childCount - 1);

    double height = 0.0;
    if (barWidth > width) {
      child = firstChild;
      while (child != null) {
        height += child.getMaxIntrinsicHeight(width);
        child = childAfter(child);
      }
      return height + overflowSpacing * (childCount - 1);
    } else {
      child = firstChild;
      while (child != null) {
        height = math.max(height, child.getMaxIntrinsicHeight(width));
        child = childAfter(child);
      }
      return height;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    if (child == null) {
      return 0;
    }
    double width = 0.0;
    while (child != null) {
      width += child.getMinIntrinsicWidth(double.infinity);
      child = childAfter(child);
    }
    return width + spacing * (childCount - 1);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    if (child == null) {
      return 0;
    }
    double width = 0.0;
    while (child != null) {
      width += child.getMaxIntrinsicWidth(double.infinity);
      child = childAfter(child);
    }
    return width + spacing * (childCount - 1);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    RenderBox? child = firstChild;
    if (child == null) {
      return constraints.smallest;
    }
    final BoxConstraints childConstraints = constraints.loosen();
    double childrenWidth = 0.0;
    double maxChildHeight = 0.0;
    double y = 0.0;
    while (child != null) {
      final Size childSize = child.getDryLayout(childConstraints);
      childrenWidth += childSize.width;
      maxChildHeight = math.max(maxChildHeight, childSize.height);
      y += childSize.height + overflowSpacing;
      child = childAfter(child);
    }
    final double actualWidth = childrenWidth + spacing * (childCount - 1);
    if (actualWidth > constraints.maxWidth) {
      return constraints
          .constrain(Size(constraints.maxWidth, y - overflowSpacing));
    } else {
      final double overallWidth =
          alignment == null ? actualWidth : constraints.maxWidth;
      return constraints.constrain(Size(overallWidth, maxChildHeight));
    }
  }

  @override
  void performLayout() {
    RenderBox? child = firstChild;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    final BoxConstraints childConstraints = constraints.loosen();
    double childrenWidth = 0;
    double maxChildHeight = 0;
    double maxChildWidth = 0;

    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      childrenWidth += child.size.width;
      maxChildHeight = math.max(maxChildHeight, child.size.height);
      maxChildWidth = math.max(maxChildWidth, child.size.width);
      child = childAfter(child);
    }

    final bool rtl = textDirection == TextDirection.rtl;
    final double actualWidth = childrenWidth + spacing * (childCount - 1);

    if (actualWidth > constraints.maxWidth) {
      // Overflow vertical layout
      child =
          overflowDirection == VerticalDirection.down ? firstChild : lastChild;
      RenderBox? nextChild() => overflowDirection == VerticalDirection.down
          ? childAfter(child!)
          : childBefore(child!);
      double y = 0;
      while (child != null) {
        final _OverflowBarParentData childParentData =
            child.parentData! as _OverflowBarParentData;
        double x = 0;
        switch (overflowAlignment) {
          case OverflowBarAlignment.start:
            x = rtl ? constraints.maxWidth - child.size.width : 0;
          case OverflowBarAlignment.center:
            x = (constraints.maxWidth - child.size.width) / 2;
          case OverflowBarAlignment.end:
            x = rtl ? 0 : constraints.maxWidth - child.size.width;
        }
        childParentData.offset = Offset(x, y);
        y += child.size.height + overflowSpacing;
        child = nextChild();
      }
      size = constraints
          .constrain(Size(constraints.maxWidth, y - overflowSpacing));
    } else {
      // Default horizontal layout
      child = firstChild;
      final double firstChildWidth = child!.size.width;
      final double overallWidth =
          alignment == null ? actualWidth : constraints.maxWidth;
      size = constraints.constrain(Size(overallWidth, maxChildHeight));

      late double x; // initial value: origin of the first child
      double layoutSpacing = spacing; // space between children
      switch (alignment) {
        case null:
          x = rtl ? size.width - firstChildWidth : 0;
        case MainAxisAlignment.start:
          x = rtl ? size.width - firstChildWidth : 0;
        case MainAxisAlignment.center:
          final double halfRemainingWidth = (size.width - actualWidth) / 2;
          x = rtl
              ? size.width - halfRemainingWidth - firstChildWidth
              : halfRemainingWidth;
        case MainAxisAlignment.end:
          x = rtl ? actualWidth - firstChildWidth : size.width - actualWidth;
        case MainAxisAlignment.spaceBetween:
          layoutSpacing = (size.width - childrenWidth) / (childCount - 1);
          x = rtl ? size.width - firstChildWidth : 0;
        case MainAxisAlignment.spaceAround:
          layoutSpacing =
              childCount > 0 ? (size.width - childrenWidth) / childCount : 0;
          x = rtl
              ? size.width - layoutSpacing / 2 - firstChildWidth
              : layoutSpacing / 2;
        case MainAxisAlignment.spaceEvenly:
          layoutSpacing = (size.width - childrenWidth) / (childCount + 1);
          x = rtl
              ? size.width - layoutSpacing - firstChildWidth
              : layoutSpacing;
      }

      while (child != null) {
        final _OverflowBarParentData childParentData =
            child.parentData! as _OverflowBarParentData;
        childParentData.offset =
            Offset(x, (maxChildHeight - child.size.height) / 2);
        // x is the horizontal origin of child. To advance x to the next child's
        // origin for LTR: add the width of the current child. To advance x to
        // the origin of the next child for RTL: subtract the width of the next
        // child (if there is one).
        if (!rtl) {
          x += child.size.width + layoutSpacing;
        }
        child = childAfter(child);
        if (rtl && child != null) {
          x -= child.size.width + layoutSpacing;
        }
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('spacing', spacing, defaultValue: 0));
    properties.add(
        DoubleProperty('overflowSpacing', overflowSpacing, defaultValue: 0));
    properties.add(EnumProperty<OverflowBarAlignment>(
        'overflowAlignment', overflowAlignment,
        defaultValue: OverflowBarAlignment.start));
    properties.add(EnumProperty<VerticalDirection>(
        'overflowDirection', overflowDirection,
        defaultValue: VerticalDirection.down));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
  }
}
