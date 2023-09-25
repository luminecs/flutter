import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'colors.dart';
import 'constants.dart';
import 'ink_well.dart';
import 'material.dart';
import 'material_state.dart';
import 'theme_data.dart';

abstract class ButtonStyleButton extends StatefulWidget {
  const ButtonStyleButton({
    super.key,
    required this.onPressed,
    required this.onLongPress,
    required this.onHover,
    required this.onFocusChange,
    required this.style,
    required this.focusNode,
    required this.autofocus,
    required this.clipBehavior,
    this.statesController,
    this.isSemanticButton = true,
    required this.child,
  });

  final VoidCallback? onPressed;

  final VoidCallback? onLongPress;

  final ValueChanged<bool>? onHover;

  final ValueChanged<bool>? onFocusChange;

  final ButtonStyle? style;

  final Clip clipBehavior;

  final FocusNode? focusNode;

  final bool autofocus;

  final MaterialStatesController? statesController;

  final bool? isSemanticButton;

  final Widget? child;

  @protected
  ButtonStyle defaultStyleOf(BuildContext context);

  @protected
  ButtonStyle? themeStyleOf(BuildContext context);

  bool get enabled => onPressed != null || onLongPress != null;

  @override
  State<ButtonStyleButton> createState() => _ButtonStyleState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
  }

  static MaterialStateProperty<T>? allOrNull<T>(T? value) => value == null ? null : MaterialStatePropertyAll<T>(value);

  static EdgeInsetsGeometry scaledPadding(
    EdgeInsetsGeometry geometry1x,
    EdgeInsetsGeometry geometry2x,
    EdgeInsetsGeometry geometry3x,
    double textScaleFactor,
  ) {
    return switch (textScaleFactor) {
      <= 1 => geometry1x,
      < 2  => EdgeInsetsGeometry.lerp(geometry1x, geometry2x, textScaleFactor - 1)!,
      < 3  => EdgeInsetsGeometry.lerp(geometry2x, geometry3x, textScaleFactor - 2)!,
      _    => geometry3x,
    };
  }
}

class _ButtonStyleState extends State<ButtonStyleButton> with TickerProviderStateMixin {
  AnimationController? controller;
  double? elevation;
  Color? backgroundColor;
  MaterialStatesController? internalStatesController;

  void handleStatesControllerChange() {
    // Force a rebuild to resolve MaterialStateProperty properties
    setState(() { });
  }

  MaterialStatesController get statesController => widget.statesController ?? internalStatesController!;

  void initStatesController() {
    if (widget.statesController == null) {
      internalStatesController = MaterialStatesController();
    }
    statesController.update(MaterialState.disabled, !widget.enabled);
    statesController.addListener(handleStatesControllerChange);
  }

  @override
  void initState() {
    super.initState();
    initStatesController();
  }

  @override
  void didUpdateWidget(ButtonStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statesController != oldWidget.statesController) {
      oldWidget.statesController?.removeListener(handleStatesControllerChange);
      if (widget.statesController != null) {
        internalStatesController?.dispose();
        internalStatesController = null;
      }
      initStatesController();
    }
    if (widget.enabled != oldWidget.enabled) {
      statesController.update(MaterialState.disabled, !widget.enabled);
      if (!widget.enabled) {
        // The button may have been disabled while a press gesture is currently underway.
        statesController.update(MaterialState.pressed, false);
      }
    }
  }

  @override
  void dispose() {
    statesController.removeListener(handleStatesControllerChange);
    internalStatesController?.dispose();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle? widgetStyle = widget.style;
    final ButtonStyle? themeStyle = widget.themeStyleOf(context);
    final ButtonStyle defaultStyle = widget.defaultStyleOf(context);

    T? effectiveValue<T>(T? Function(ButtonStyle? style) getProperty) {
      final T? widgetValue  = getProperty(widgetStyle);
      final T? themeValue   = getProperty(themeStyle);
      final T? defaultValue = getProperty(defaultStyle);
      return widgetValue ?? themeValue ?? defaultValue;
    }

    T? resolve<T>(MaterialStateProperty<T>? Function(ButtonStyle? style) getProperty) {
      return effectiveValue(
        (ButtonStyle? style) {
          return getProperty(style)?.resolve(statesController.value);
        },
      );
    }

    final double? resolvedElevation = resolve<double?>((ButtonStyle? style) => style?.elevation);
    final TextStyle? resolvedTextStyle = resolve<TextStyle?>((ButtonStyle? style) => style?.textStyle);
    Color? resolvedBackgroundColor = resolve<Color?>((ButtonStyle? style) => style?.backgroundColor);
    final Color? resolvedForegroundColor = resolve<Color?>((ButtonStyle? style) => style?.foregroundColor);
    final Color? resolvedShadowColor = resolve<Color?>((ButtonStyle? style) => style?.shadowColor);
    final Color? resolvedSurfaceTintColor = resolve<Color?>((ButtonStyle? style) => style?.surfaceTintColor);
    final EdgeInsetsGeometry? resolvedPadding = resolve<EdgeInsetsGeometry?>((ButtonStyle? style) => style?.padding);
    final Size? resolvedMinimumSize = resolve<Size?>((ButtonStyle? style) => style?.minimumSize);
    final Size? resolvedFixedSize = resolve<Size?>((ButtonStyle? style) => style?.fixedSize);
    final Size? resolvedMaximumSize = resolve<Size?>((ButtonStyle? style) => style?.maximumSize);
    final Color? resolvedIconColor = resolve<Color?>((ButtonStyle? style) => style?.iconColor);
    final double? resolvedIconSize = resolve<double?>((ButtonStyle? style) => style?.iconSize);
    final BorderSide? resolvedSide = resolve<BorderSide?>((ButtonStyle? style) => style?.side);
    final OutlinedBorder? resolvedShape = resolve<OutlinedBorder?>((ButtonStyle? style) => style?.shape);

    final MaterialStateMouseCursor mouseCursor = _MouseCursor(
      (Set<MaterialState> states) => effectiveValue((ButtonStyle? style) => style?.mouseCursor?.resolve(states)),
    );

    final MaterialStateProperty<Color?> overlayColor = MaterialStateProperty.resolveWith<Color?>(
      (Set<MaterialState> states) => effectiveValue((ButtonStyle? style) => style?.overlayColor?.resolve(states)),
    );

    final VisualDensity? resolvedVisualDensity = effectiveValue((ButtonStyle? style) => style?.visualDensity);
    final MaterialTapTargetSize? resolvedTapTargetSize = effectiveValue((ButtonStyle? style) => style?.tapTargetSize);
    final Duration? resolvedAnimationDuration = effectiveValue((ButtonStyle? style) => style?.animationDuration);
    final bool? resolvedEnableFeedback = effectiveValue((ButtonStyle? style) => style?.enableFeedback);
    final AlignmentGeometry? resolvedAlignment = effectiveValue((ButtonStyle? style) => style?.alignment);
    final Offset densityAdjustment = resolvedVisualDensity!.baseSizeAdjustment;
    final InteractiveInkFeatureFactory? resolvedSplashFactory = effectiveValue((ButtonStyle? style) => style?.splashFactory);

    BoxConstraints effectiveConstraints = resolvedVisualDensity.effectiveConstraints(
      BoxConstraints(
        minWidth: resolvedMinimumSize!.width,
        minHeight: resolvedMinimumSize.height,
        maxWidth: resolvedMaximumSize!.width,
        maxHeight: resolvedMaximumSize.height,
      ),
    );
    if (resolvedFixedSize != null) {
      final Size size = effectiveConstraints.constrain(resolvedFixedSize);
      if (size.width.isFinite) {
        effectiveConstraints = effectiveConstraints.copyWith(
          minWidth: size.width,
          maxWidth: size.width,
        );
      }
      if (size.height.isFinite) {
        effectiveConstraints = effectiveConstraints.copyWith(
          minHeight: size.height,
          maxHeight: size.height,
        );
      }
    }

    // Per the Material Design team: don't allow the VisualDensity
    // adjustment to reduce the width of the left/right padding. If we
    // did, VisualDensity.compact, the default for desktop/web, would
    // reduce the horizontal padding to zero.
    final double dy = densityAdjustment.dy;
    final double dx = math.max(0, densityAdjustment.dx);
    final EdgeInsetsGeometry padding = resolvedPadding!
      .add(EdgeInsets.fromLTRB(dx, dy, dx, dy))
      .clamp(EdgeInsets.zero, EdgeInsetsGeometry.infinity); // ignore_clamp_double_lint

    // If an opaque button's background is becoming translucent while its
    // elevation is changing, change the elevation first. Material implicitly
    // animates its elevation but not its color. SKIA renders non-zero
    // elevations as a shadow colored fill behind the Material's background.
    if (resolvedAnimationDuration! > Duration.zero
        && elevation != null
        && backgroundColor != null
        && elevation != resolvedElevation
        && backgroundColor!.value != resolvedBackgroundColor!.value
        && backgroundColor!.opacity == 1
        && resolvedBackgroundColor.opacity < 1
        && resolvedElevation == 0) {
      if (controller?.duration != resolvedAnimationDuration) {
        controller?.dispose();
        controller = AnimationController(
          duration: resolvedAnimationDuration,
          vsync: this,
        )
        ..addStatusListener((AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            setState(() { }); // Rebuild with the final background color.
          }
        });
      }
      resolvedBackgroundColor = backgroundColor; // Defer changing the background color.
      controller!.value = 0;
      controller!.forward();
    }
    elevation = resolvedElevation;
    backgroundColor = resolvedBackgroundColor;

    final Widget result = ConstrainedBox(
      constraints: effectiveConstraints,
      child: Material(
        elevation: resolvedElevation!,
        textStyle: resolvedTextStyle?.copyWith(color: resolvedForegroundColor),
        shape: resolvedShape!.copyWith(side: resolvedSide),
        color: resolvedBackgroundColor,
        shadowColor: resolvedShadowColor,
        surfaceTintColor: resolvedSurfaceTintColor,
        type: resolvedBackgroundColor == null ? MaterialType.transparency : MaterialType.button,
        animationDuration: resolvedAnimationDuration,
        clipBehavior: widget.clipBehavior,
        child: InkWell(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onHover: widget.onHover,
          mouseCursor: mouseCursor,
          enableFeedback: resolvedEnableFeedback,
          focusNode: widget.focusNode,
          canRequestFocus: widget.enabled,
          onFocusChange: widget.onFocusChange,
          autofocus: widget.autofocus,
          splashFactory: resolvedSplashFactory,
          overlayColor: overlayColor,
          highlightColor: Colors.transparent,
          customBorder: resolvedShape.copyWith(side: resolvedSide),
          statesController: statesController,
          child: IconTheme.merge(
            data: IconThemeData(color: resolvedIconColor ?? resolvedForegroundColor, size: resolvedIconSize),
            child: Padding(
              padding: padding,
              child: Align(
                alignment: resolvedAlignment!,
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    final Size minSize;
    switch (resolvedTapTargetSize!) {
      case MaterialTapTargetSize.padded:
        minSize = Size(
          kMinInteractiveDimension + densityAdjustment.dx,
          kMinInteractiveDimension + densityAdjustment.dy,
        );
        assert(minSize.width >= 0.0);
        assert(minSize.height >= 0.0);
      case MaterialTapTargetSize.shrinkWrap:
        minSize = Size.zero;
    }

    return Semantics(
      container: true,
      button: widget.isSemanticButton,
      enabled: widget.enabled,
      child: _InputPadding(
        minSize: minSize,
        child: result,
      ),
    );
  }
}

class _MouseCursor extends MaterialStateMouseCursor {
  const _MouseCursor(this.resolveCallback);

  final MaterialPropertyResolver<MouseCursor?> resolveCallback;

  @override
  MouseCursor resolve(Set<MaterialState> states) => resolveCallback(states)!;

  @override
  String get debugDescription => 'ButtonStyleButton_MouseCursor';
}

class _InputPadding extends SingleChildRenderObjectWidget {
  const _InputPadding({
    super.child,
    required this.minSize,
  });

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderInputPadding(minSize);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderInputPadding renderObject) {
    renderObject.minSize = minSize;
  }
}

class _RenderInputPadding extends RenderShiftedBox {
  _RenderInputPadding(this._minSize, [RenderBox? child]) : super(child);

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) {
      return;
    }
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child != null) {
      return math.max(child!.getMinIntrinsicWidth(height), minSize.width);
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child != null) {
      return math.max(child!.getMinIntrinsicHeight(width), minSize.height);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child != null) {
      return math.max(child!.getMaxIntrinsicWidth(height), minSize.width);
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child != null) {
      return math.max(child!.getMaxIntrinsicHeight(width), minSize.height);
    }
    return 0.0;
  }

  Size _computeSize({required BoxConstraints constraints, required ChildLayouter layoutChild}) {
    if (child != null) {
      final Size childSize = layoutChild(child!, constraints);
      final double height = math.max(childSize.width, minSize.width);
      final double width = math.max(childSize.height, minSize.height);
      return constraints.constrain(Size(height, width));
    }
    return Size.zero;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    );
  }

  @override
  void performLayout() {
    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );
    if (child != null) {
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      childParentData.offset = Alignment.center.alongOffset(size - child!.size as Offset);
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (super.hitTest(result, position: position)) {
      return true;
    }
    final Offset center = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (BoxHitTestResult result, Offset position) {
        assert(position == center);
        return child!.hitTest(result, position: center);
      },
    );
  }
}