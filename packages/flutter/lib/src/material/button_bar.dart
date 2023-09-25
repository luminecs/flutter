
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'button_bar_theme.dart';
import 'button_theme.dart';
import 'dialog.dart';

class ButtonBar extends StatelessWidget {
  const ButtonBar({
    super.key,
    this.alignment,
    this.mainAxisSize,
    this.buttonTextTheme,
    this.buttonMinWidth,
    this.buttonHeight,
    this.buttonPadding,
    this.buttonAlignedDropdown,
    this.layoutBehavior,
    this.overflowDirection,
    this.overflowButtonSpacing,
    this.children = const <Widget>[],
  }) : assert(buttonMinWidth == null || buttonMinWidth >= 0.0),
       assert(buttonHeight == null || buttonHeight >= 0.0),
       assert(overflowButtonSpacing == null || overflowButtonSpacing >= 0.0);

  final MainAxisAlignment? alignment;

  final MainAxisSize? mainAxisSize;

  final ButtonTextTheme? buttonTextTheme;

  final double? buttonMinWidth;

  final double? buttonHeight;

  final EdgeInsetsGeometry? buttonPadding;

  final bool? buttonAlignedDropdown;

  final ButtonBarLayoutBehavior? layoutBehavior;

  final VerticalDirection? overflowDirection;

  final double? overflowButtonSpacing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ButtonThemeData parentButtonTheme = ButtonTheme.of(context);
    final ButtonBarThemeData barTheme = ButtonBarTheme.of(context);

    final ButtonThemeData buttonTheme = parentButtonTheme.copyWith(
      textTheme: buttonTextTheme ?? barTheme.buttonTextTheme ?? ButtonTextTheme.primary,
      minWidth: buttonMinWidth ?? barTheme.buttonMinWidth ?? 64.0,
      height: buttonHeight ?? barTheme.buttonHeight ?? 36.0,
      padding: buttonPadding ?? barTheme.buttonPadding ?? const EdgeInsets.symmetric(horizontal: 8.0),
      alignedDropdown: buttonAlignedDropdown ?? barTheme.buttonAlignedDropdown ?? false,
      layoutBehavior: layoutBehavior ?? barTheme.layoutBehavior ?? ButtonBarLayoutBehavior.padded,
    );

    // We divide by 4.0 because we want half of the average of the left and right padding.
    final double paddingUnit = buttonTheme.padding.horizontal / 4.0;
    final Widget child = ButtonTheme.fromButtonThemeData(
      data: buttonTheme,
      child: _ButtonBarRow(
        mainAxisAlignment: alignment ?? barTheme.alignment ?? MainAxisAlignment.end,
        mainAxisSize: mainAxisSize ?? barTheme.mainAxisSize ?? MainAxisSize.max,
        overflowDirection: overflowDirection ?? barTheme.overflowDirection ?? VerticalDirection.down,
        overflowButtonSpacing: overflowButtonSpacing,
        children: children.map<Widget>((Widget child) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: paddingUnit),
            child: child,
          );
        }).toList(),
      ),
    );
    switch (buttonTheme.layoutBehavior) {
      case ButtonBarLayoutBehavior.padded:
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: 2.0 * paddingUnit,
            horizontal: paddingUnit,
          ),
          child: child,
        );
      case ButtonBarLayoutBehavior.constrained:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: paddingUnit),
          constraints: const BoxConstraints(minHeight: 52.0),
          alignment: Alignment.center,
          child: child,
        );
    }
  }
}

class _ButtonBarRow extends Flex {
  const _ButtonBarRow({
    required super.children,
    super.mainAxisSize,
    super.mainAxisAlignment,
    VerticalDirection overflowDirection = VerticalDirection.down,
    this.overflowButtonSpacing,
  }) : super(
    direction: Axis.horizontal,
    verticalDirection: overflowDirection,
  );

  final double? overflowButtonSpacing;

  @override
  _RenderButtonBarRow createRenderObject(BuildContext context) {
    return _RenderButtonBarRow(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: getEffectiveTextDirection(context)!,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      overflowButtonSpacing: overflowButtonSpacing,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderButtonBarRow renderObject) {
    renderObject
      ..direction = direction
      ..mainAxisAlignment = mainAxisAlignment
      ..mainAxisSize = mainAxisSize
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = getEffectiveTextDirection(context)
      ..verticalDirection = verticalDirection
      ..textBaseline = textBaseline
      ..overflowButtonSpacing = overflowButtonSpacing;
  }
}

class _RenderButtonBarRow extends RenderFlex {
  _RenderButtonBarRow({
    super.direction,
    super.mainAxisSize,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    required TextDirection super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    this.overflowButtonSpacing,
  }) : assert(overflowButtonSpacing == null || overflowButtonSpacing >= 0);

  bool _hasCheckedLayoutWidth = false;
  double? overflowButtonSpacing;

  @override
  BoxConstraints get constraints {
    if (_hasCheckedLayoutWidth) {
      return super.constraints;
    }
    return super.constraints.copyWith(maxWidth: double.infinity);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final Size size = super.computeDryLayout(constraints.copyWith(maxWidth: double.infinity));
    if (size.width <= constraints.maxWidth) {
      return super.computeDryLayout(constraints);
    }
    double currentHeight = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      final BoxConstraints childConstraints = constraints.copyWith(minWidth: 0.0);
      final Size childSize = child.getDryLayout(childConstraints);
      currentHeight += childSize.height;
      child = childAfter(child);
      if (overflowButtonSpacing != null && child != null) {
        currentHeight += overflowButtonSpacing!;
      }
    }
    return constraints.constrain(Size(constraints.maxWidth, currentHeight));
  }

  @override
  void performLayout() {
    // Set check layout width to false in reload or update cases.
    _hasCheckedLayoutWidth = false;

    // Perform layout to ensure that button bar knows how wide it would
    // ideally want to be.
    super.performLayout();
    _hasCheckedLayoutWidth = true;

    // If the button bar is constrained by width and it overflows, set the
    // buttons to align vertically. Otherwise, lay out the button bar
    // horizontally.
    if (size.width <= constraints.maxWidth) {
      // A second performLayout is required to ensure that the original maximum
      // width constraints are used. The original perform layout call assumes
      // a maximum width constraint of infinity.
      super.performLayout();
    } else {
      final BoxConstraints childConstraints = constraints.copyWith(minWidth: 0.0);
      RenderBox? child;
      double currentHeight = 0.0;
      switch (verticalDirection) {
        case VerticalDirection.down:
          child = firstChild;
        case VerticalDirection.up:
          child = lastChild;
      }

      while (child != null) {
        final FlexParentData childParentData = child.parentData! as FlexParentData;

        // Lay out the child with the button bar's original constraints, but
        // with minimum width set to zero.
        child.layout(childConstraints, parentUsesSize: true);

        // Set the cross axis alignment for the column to match the main axis
        // alignment for a row. For [MainAxisAlignment.spaceAround],
        // [MainAxisAlignment.spaceBetween] and [MainAxisAlignment.spaceEvenly]
        // cases, use [MainAxisAlignment.start].
        switch (textDirection!) {
          case TextDirection.ltr:
            switch (mainAxisAlignment) {
              case MainAxisAlignment.center:
                final double midpoint = (constraints.maxWidth - child.size.width) / 2.0;
                childParentData.offset = Offset(midpoint, currentHeight);
              case MainAxisAlignment.end:
                childParentData.offset = Offset(constraints.maxWidth - child.size.width, currentHeight);
              case MainAxisAlignment.spaceAround:
              case MainAxisAlignment.spaceBetween:
              case MainAxisAlignment.spaceEvenly:
              case MainAxisAlignment.start:
                childParentData.offset = Offset(0, currentHeight);
            }
          case TextDirection.rtl:
            switch (mainAxisAlignment) {
              case MainAxisAlignment.center:
                final double midpoint = constraints.maxWidth / 2.0 - child.size.width / 2.0;
                childParentData.offset = Offset(midpoint, currentHeight);
              case MainAxisAlignment.end:
                childParentData.offset = Offset(0, currentHeight);
              case MainAxisAlignment.spaceAround:
              case MainAxisAlignment.spaceBetween:
              case MainAxisAlignment.spaceEvenly:
              case MainAxisAlignment.start:
                childParentData.offset = Offset(constraints.maxWidth - child.size.width, currentHeight);
            }
        }
        currentHeight += child.size.height;
        switch (verticalDirection) {
          case VerticalDirection.down:
            child = childParentData.nextSibling;
          case VerticalDirection.up:
            child = childParentData.previousSibling;
        }

        if (overflowButtonSpacing != null && child != null) {
          currentHeight += overflowButtonSpacing!;
        }
      }
      size = constraints.constrain(Size(constraints.maxWidth, currentHeight));
    }
  }
}