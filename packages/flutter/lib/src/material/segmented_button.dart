// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'button_style.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'icons.dart';
import 'material.dart';
import 'material_state.dart';
import 'segmented_button_theme.dart';
import 'text_button.dart';
import 'text_button_theme.dart';
import 'theme.dart';
import 'tooltip.dart';

class ButtonSegment<T> {
  const ButtonSegment({
    required this.value,
    this.icon,
    this.label,
    this.tooltip,
    this.enabled = true,
  }) : assert(icon != null || label != null);

  final T value;

  final Widget? icon;

  final Widget? label;

  final String? tooltip;

  final bool enabled;
}

class SegmentedButton<T> extends StatefulWidget {
  const SegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.style,
    this.showSelectedIcon = true,
    this.selectedIcon,
  })  : assert(segments.length > 0),
        assert(selected.length > 0 || emptySelectionAllowed),
        assert(selected.length < 2 || multiSelectionEnabled);

  final List<ButtonSegment<T>> segments;

  final Set<T> selected;

  final void Function(Set<T>)? onSelectionChanged;

  final bool multiSelectionEnabled;

  final bool emptySelectionAllowed;

  final ButtonStyle? style;

  final bool showSelectedIcon;

  final Widget? selectedIcon;

  @override
  State<SegmentedButton<T>> createState() => SegmentedButtonState<T>();
}

@visibleForTesting
class SegmentedButtonState<T> extends State<SegmentedButton<T>> {
  bool get _enabled => widget.onSelectionChanged != null;

  @visibleForTesting
  final Map<ButtonSegment<T>, MaterialStatesController> statesControllers = <ButtonSegment<T>, MaterialStatesController>{};

  @override
  void didUpdateWidget(covariant SegmentedButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget != widget) {
      statesControllers.removeWhere((ButtonSegment<T> segment, MaterialStatesController controller) {
        if (widget.segments.contains(segment)) {
          return false;
        } else {
          controller.dispose();
          return true;
        }
      });
    }
  }

  void _handleOnPressed(T segmentValue) {
    if (!_enabled) {
      return;
    }
    final bool onlySelectedSegment = widget.selected.length == 1 && widget.selected.contains(segmentValue);
    final bool validChange = widget.emptySelectionAllowed || !onlySelectedSegment;
    if (validChange) {
      final bool toggle = widget.multiSelectionEnabled || (widget.emptySelectionAllowed && onlySelectedSegment);
      final Set<T> pressedSegment = <T>{segmentValue};
      late final Set<T> updatedSelection;
      if (toggle) {
        updatedSelection = widget.selected.contains(segmentValue)
          ? widget.selected.difference(pressedSegment)
          : widget.selected.union(pressedSegment);
      } else {
        updatedSelection = pressedSegment;
      }
      if (!setEquals(updatedSelection, widget.selected)) {
        widget.onSelectionChanged!(updatedSelection);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SegmentedButtonThemeData theme = SegmentedButtonTheme.of(context);
    final SegmentedButtonThemeData defaults = _SegmentedButtonDefaultsM3(context);
    final TextDirection direction = Directionality.of(context);

    const Set<MaterialState> enabledState = <MaterialState>{};
    const Set<MaterialState> disabledState = <MaterialState>{ MaterialState.disabled };
    final Set<MaterialState> currentState = _enabled ? enabledState : disabledState;

    P? effectiveValue<P>(P? Function(ButtonStyle? style) getProperty) {
      late final P? widgetValue  = getProperty(widget.style);
      late final P? themeValue   = getProperty(theme.style);
      late final P? defaultValue = getProperty(defaults.style);
      return widgetValue ?? themeValue ?? defaultValue;
    }

    P? resolve<P>(MaterialStateProperty<P>? Function(ButtonStyle? style) getProperty, [Set<MaterialState>? states]) {
      return effectiveValue(
        (ButtonStyle? style) => getProperty(style)?.resolve(states ?? currentState),
      );
    }

    ButtonStyle segmentStyleFor(ButtonStyle? style) {
      return ButtonStyle(
        textStyle: style?.textStyle,
        backgroundColor: style?.backgroundColor,
        foregroundColor: style?.foregroundColor,
        overlayColor: style?.overlayColor,
        surfaceTintColor: style?.surfaceTintColor,
        elevation: style?.elevation,
        padding: style?.padding,
        iconColor: style?.iconColor,
        iconSize: style?.iconSize,
        shape: const MaterialStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder()),
        mouseCursor: style?.mouseCursor,
        visualDensity: style?.visualDensity,
        tapTargetSize: style?.tapTargetSize,
        animationDuration: style?.animationDuration,
        enableFeedback: style?.enableFeedback,
        alignment: style?.alignment,
        splashFactory: style?.splashFactory,
      );
    }

    final ButtonStyle segmentStyle = segmentStyleFor(widget.style);
    final ButtonStyle segmentThemeStyle = segmentStyleFor(theme.style).merge(segmentStyleFor(defaults.style));
    final Widget? selectedIcon = widget.showSelectedIcon
      ? widget.selectedIcon ?? theme.selectedIcon ?? defaults.selectedIcon
      : null;

    Widget buttonFor(ButtonSegment<T> segment) {
      final Widget label = segment.label ?? segment.icon ?? const SizedBox.shrink();
      final bool segmentSelected = widget.selected.contains(segment.value);
      final Widget? icon = (segmentSelected && widget.showSelectedIcon)
        ? selectedIcon
        : segment.label != null
          ? segment.icon
          : null;
      final MaterialStatesController controller = statesControllers.putIfAbsent(segment, () => MaterialStatesController());
      controller.value = <MaterialState>{
          if (segmentSelected) MaterialState.selected,
      };

      final Widget button = icon != null
        ? TextButton.icon(
            style: segmentStyle,
            statesController: controller,
            onPressed: (_enabled && segment.enabled) ? () => _handleOnPressed(segment.value) : null,
            icon: icon,
            label: label,
          )
        : TextButton(
            style: segmentStyle,
            statesController: controller,
            onPressed: (_enabled && segment.enabled) ? () => _handleOnPressed(segment.value) : null,
            child: label,
          );

      final Widget buttonWithTooltip = segment.tooltip != null
        ? Tooltip(
            message: segment.tooltip,
            child: button,
          )
        : button;

      return MergeSemantics(
        child: Semantics(
          checked: segmentSelected,
          inMutuallyExclusiveGroup: widget.multiSelectionEnabled ? null : true,
          child: buttonWithTooltip,
        ),
      );
    }

    final OutlinedBorder resolvedEnabledBorder = resolve<OutlinedBorder?>((ButtonStyle? style) => style?.shape, disabledState) ?? const RoundedRectangleBorder();
    final OutlinedBorder resolvedDisabledBorder = resolve<OutlinedBorder?>((ButtonStyle? style) => style?.shape, disabledState)?? const RoundedRectangleBorder();
    final BorderSide enabledSide = resolve<BorderSide?>((ButtonStyle? style) => style?.side, enabledState) ?? BorderSide.none;
    final BorderSide disabledSide = resolve<BorderSide?>((ButtonStyle? style) => style?.side, disabledState) ?? BorderSide.none;
    final OutlinedBorder enabledBorder = resolvedEnabledBorder.copyWith(side: enabledSide);
    final OutlinedBorder disabledBorder = resolvedDisabledBorder.copyWith(side: disabledSide);

    final List<Widget> buttons = widget.segments.map(buttonFor).toList();

    return Material(
      type: MaterialType.transparency,
      shape: enabledBorder.copyWith(side: BorderSide.none),
      elevation: resolve<double?>((ButtonStyle? style) => style?.elevation)!,
      shadowColor: resolve<Color?>((ButtonStyle? style) => style?.shadowColor),
      surfaceTintColor: resolve<Color?>((ButtonStyle? style) => style?.surfaceTintColor),
      child: TextButtonTheme(
        data: TextButtonThemeData(style: segmentThemeStyle),
        child: _SegmentedButtonRenderWidget<T>(
          segments: widget.segments,
          enabledBorder: _enabled ? enabledBorder : disabledBorder,
          disabledBorder: disabledBorder,
          direction: direction,
          children: buttons,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final MaterialStatesController controller in statesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
class _SegmentedButtonRenderWidget<T> extends MultiChildRenderObjectWidget {
  const _SegmentedButtonRenderWidget({
    super.key,
    required this.segments,
    required this.enabledBorder,
    required this.disabledBorder,
    required this.direction,
    required super.children,
  }) : assert(children.length == segments.length);

  final List<ButtonSegment<T>> segments;
  final OutlinedBorder enabledBorder;
  final OutlinedBorder disabledBorder;
  final TextDirection direction;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSegmentedButton<T>(
      segments: segments,
      enabledBorder: enabledBorder,
      disabledBorder: disabledBorder,
      textDirection: direction,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderSegmentedButton<T> renderObject) {
    renderObject
      ..segments = segments
      ..enabledBorder = enabledBorder
      ..disabledBorder = disabledBorder
      ..textDirection = direction;
  }
}

class _SegmentedButtonContainerBoxParentData extends ContainerBoxParentData<RenderBox> {
  RRect? surroundingRect;
}

typedef _NextChild = RenderBox? Function(RenderBox child);

class _RenderSegmentedButton<T> extends RenderBox with
     ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>,
     RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  _RenderSegmentedButton({
    required List<ButtonSegment<T>> segments,
    required OutlinedBorder enabledBorder,
    required OutlinedBorder disabledBorder,
    required TextDirection textDirection,
  }) : _segments = segments,
       _enabledBorder = enabledBorder,
       _disabledBorder = disabledBorder,
       _textDirection = textDirection;

  List<ButtonSegment<T>> get segments => _segments;
  List<ButtonSegment<T>> _segments;
  set segments(List<ButtonSegment<T>> value) {
    if (listEquals(segments, value)) {
      return;
    }
    _segments = value;
    markNeedsLayout();
  }

  OutlinedBorder get enabledBorder => _enabledBorder;
  OutlinedBorder _enabledBorder;
  set enabledBorder(OutlinedBorder value) {
    if (_enabledBorder == value) {
      return;
    }
    _enabledBorder = value;
    markNeedsLayout();
  }

  OutlinedBorder get disabledBorder => _disabledBorder;
  OutlinedBorder _disabledBorder;
  set disabledBorder(OutlinedBorder value) {
    if (_disabledBorder == value) {
      return;
    }
    _disabledBorder = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double minWidth = 0.0;
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      final double childWidth = child.getMinIntrinsicWidth(height);
      minWidth = math.max(minWidth, childWidth);
      child = childParentData.nextSibling;
    }
    return minWidth * childCount;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    RenderBox? child = firstChild;
    double maxWidth = 0.0;
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      final double childWidth = child.getMaxIntrinsicWidth(height);
      maxWidth = math.max(maxWidth, childWidth);
      child = childParentData.nextSibling;
    }
    return maxWidth * childCount;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    RenderBox? child = firstChild;
    double minHeight = 0.0;
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      final double childHeight = child.getMinIntrinsicHeight(width);
      minHeight = math.max(minHeight, childHeight);
      child = childParentData.nextSibling;
    }
    return minHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    RenderBox? child = firstChild;
    double maxHeight = 0.0;
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      final double childHeight = child.getMaxIntrinsicHeight(width);
      maxHeight = math.max(maxHeight, childHeight);
      child = childParentData.nextSibling;
    }
    return maxHeight;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SegmentedButtonContainerBoxParentData) {
      child.parentData = _SegmentedButtonContainerBoxParentData();
    }
  }

  void _layoutRects(_NextChild nextChild, RenderBox? leftChild, RenderBox? rightChild) {
    RenderBox? child = leftChild;
    double start = 0.0;
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      final Offset childOffset = Offset(start, 0.0);
      childParentData.offset = childOffset;
      final Rect childRect = Rect.fromLTWH(start, 0.0, child.size.width, child.size.height);
      final RRect rChildRect = RRect.fromRectAndCorners(childRect);
      childParentData.surroundingRect = rChildRect;
      start += child.size.width;
      child = nextChild(child);
    }
  }

  Size _calculateChildSize(BoxConstraints constraints) {
    double maxHeight = 0;
    double childWidth = constraints.minWidth / childCount;
    RenderBox? child = firstChild;
    while (child != null) {
      childWidth = math.max(childWidth, child.getMaxIntrinsicWidth(double.infinity));
      child = childAfter(child);
    }
    childWidth = math.min(childWidth, constraints.maxWidth / childCount);
    child = firstChild;
    while (child != null) {
      final double boxHeight = child.getMaxIntrinsicHeight(childWidth);
      maxHeight = math.max(maxHeight, boxHeight);
      child = childAfter(child);
    }
    return Size(childWidth, maxHeight);
  }

  Size _computeOverallSizeFromChildSize(Size childSize) {
    return constraints.constrain(Size(childSize.width * childCount, childSize.height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final Size childSize = _calculateChildSize(constraints);
    return _computeOverallSizeFromChildSize(childSize);
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    final Size childSize = _calculateChildSize(constraints);

    final BoxConstraints childConstraints = BoxConstraints.tightFor(
      width: childSize.width,
      height: childSize.height,
    );

    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      child = childAfter(child);
    }

    switch (textDirection) {
      case TextDirection.rtl:
        _layoutRects(
          childBefore,
          lastChild,
          firstChild,
        );
      case TextDirection.ltr:
        _layoutRects(
          childAfter,
          firstChild,
          lastChild,
        );
    }

    size = _computeOverallSizeFromChildSize(childSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final Rect borderRect = offset & size;
    final Path borderClipPath = enabledBorder.getInnerPath(borderRect, textDirection: textDirection);
    RenderBox? child = firstChild;
    RenderBox? previousChild;
    int index = 0;
    Path? enabledClipPath;
    Path? disabledClipPath;

    canvas..save()..clipPath(borderClipPath);
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      final Rect childRect = childParentData.surroundingRect!.outerRect.shift(offset);

      canvas..save()..clipRect(childRect);
      context.paintChild(child, childParentData.offset + offset);
      canvas.restore();

      // Compute a clip rect for the outer border of the child.
      late final double segmentLeft;
      late final double segmentRight;
      late final double dividerPos;
      final double borderOutset = math.max(enabledBorder.side.strokeOutset, disabledBorder.side.strokeOutset);
      switch (textDirection) {
        case TextDirection.rtl:
          segmentLeft = child == lastChild ? borderRect.left - borderOutset : childRect.left;
          segmentRight = child == firstChild ? borderRect.right + borderOutset : childRect.right;
          dividerPos = segmentRight;
        case TextDirection.ltr:
          segmentLeft = child == firstChild ? borderRect.left - borderOutset : childRect.left;
          segmentRight = child == lastChild ? borderRect.right + borderOutset : childRect.right;
          dividerPos = segmentLeft;
      }
      final Rect segmentClipRect = Rect.fromLTRB(
        segmentLeft, borderRect.top - borderOutset,
        segmentRight, borderRect.bottom + borderOutset);

      // Add the clip rect to the appropriate border clip path
      if (segments[index].enabled) {
        enabledClipPath = (enabledClipPath ?? Path())..addRect(segmentClipRect);
      } else {
        disabledClipPath = (disabledClipPath ?? Path())..addRect(segmentClipRect);
      }

      // Paint the divider between this segment and the previous one.
      if (previousChild != null) {
        final BorderSide divider = segments[index - 1].enabled || segments[index].enabled
          ? enabledBorder.side.copyWith(strokeAlign: 0.0)
          : disabledBorder.side.copyWith(strokeAlign: 0.0);
        final Offset top = Offset(dividerPos, childRect.top);
        final Offset bottom = Offset(dividerPos, childRect.bottom);
        canvas.drawLine(top, bottom, divider.toPaint());
      }

      previousChild = child;
      child = childAfter(child);
      index += 1;
    }
    canvas.restore();

    // Paint the outer border for both disabled and enabled clip rect if needed.
    if (disabledClipPath == null) {
      // Just paint the enabled border with no clip.
      enabledBorder.paint(context.canvas, borderRect, textDirection: textDirection);
    } else if (enabledClipPath == null) {
      // Just paint the disabled border with no.
      disabledBorder.paint(context.canvas, borderRect, textDirection: textDirection);
    } else {
      // Paint both of them clipped appropriately for the children segments.
      canvas..save()..clipPath(enabledClipPath);
      enabledBorder.paint(context.canvas, borderRect, textDirection: textDirection);
      canvas..restore()..save()..clipPath(disabledClipPath);
      disabledBorder.paint(context.canvas, borderRect, textDirection: textDirection);
      canvas.restore();
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    RenderBox? child = lastChild;
    while (child != null) {
      final _SegmentedButtonContainerBoxParentData childParentData = child.parentData! as _SegmentedButtonContainerBoxParentData;
      if (childParentData.surroundingRect!.contains(position)) {
        return result.addWithPaintOffset(
          offset: childParentData.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset localOffset) {
            assert(localOffset == position - childParentData.offset);
            return child!.hitTest(result, position: localOffset);
          },
        );
      }
      child = childParentData.previousSibling;
    }
    return false;
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - SegmentedButton

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _SegmentedButtonDefaultsM3 extends SegmentedButtonThemeData {
  _SegmentedButtonDefaultsM3(this.context);
  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;
  @override ButtonStyle? get style {
    return ButtonStyle(
      textStyle: MaterialStatePropertyAll<TextStyle?>(Theme.of(context).textTheme.labelLarge),
      backgroundColor: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.disabled)) {
          return null;
        }
        if (states.contains(MaterialState.selected)) {
          return _colors.secondaryContainer;
        }
        return null;
      }),
      foregroundColor: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.disabled)) {
          return _colors.onSurface.withOpacity(0.38);
        }
        if (states.contains(MaterialState.selected)) {
          if (states.contains(MaterialState.pressed)) {
            return _colors.onSecondaryContainer;
          }
          if (states.contains(MaterialState.hovered)) {
            return _colors.onSecondaryContainer;
          }
          if (states.contains(MaterialState.focused)) {
            return _colors.onSecondaryContainer;
          }
          return _colors.onSecondaryContainer;
        } else {
          if (states.contains(MaterialState.pressed)) {
            return _colors.onSurface;
          }
          if (states.contains(MaterialState.hovered)) {
            return _colors.onSurface;
          }
          if (states.contains(MaterialState.focused)) {
            return _colors.onSurface;
          }
          return _colors.onSurface;
        }
      }),
      overlayColor: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          if (states.contains(MaterialState.pressed)) {
            return _colors.onSecondaryContainer.withOpacity(0.12);
          }
          if (states.contains(MaterialState.hovered)) {
            return _colors.onSecondaryContainer.withOpacity(0.08);
          }
          if (states.contains(MaterialState.focused)) {
            return _colors.onSecondaryContainer.withOpacity(0.12);
          }
        } else {
          if (states.contains(MaterialState.pressed)) {
            return _colors.onSurface.withOpacity(0.12);
          }
          if (states.contains(MaterialState.hovered)) {
            return _colors.onSurface.withOpacity(0.08);
          }
          if (states.contains(MaterialState.focused)) {
            return _colors.onSurface.withOpacity(0.12);
          }
        }
        return null;
      }),
      surfaceTintColor: const MaterialStatePropertyAll<Color>(Colors.transparent),
      elevation: const MaterialStatePropertyAll<double>(0),
      iconSize: const MaterialStatePropertyAll<double?>(18.0),
      side: MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        if (states.contains(MaterialState.disabled)) {
          return BorderSide(color: _colors.onSurface.withOpacity(0.12));
        }
        return BorderSide(color: _colors.outline);
      }),
      shape: const MaterialStatePropertyAll<OutlinedBorder>(StadiumBorder()),
      minimumSize: const MaterialStatePropertyAll<Size?>(Size.fromHeight(40.0)),
    );
  }
  @override
  Widget? get selectedIcon => const Icon(Icons.check);
}

// END GENERATED TOKEN PROPERTIES - SegmentedButton