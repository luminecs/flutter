// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'chip_theme.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'constants.dart';
import 'debug.dart';
import 'icons.dart';
import 'ink_decoration.dart';
import 'ink_well.dart';
import 'material.dart';
import 'material_localizations.dart';
import 'material_state.dart';
import 'material_state_mixin.dart';
import 'text_theme.dart';
import 'theme.dart';
import 'theme_data.dart';
import 'tooltip.dart';

// Some design constants
const double _kChipHeight = 32.0;
const double _kDeleteIconSize = 18.0;

const int _kCheckmarkAlpha = 0xde; // 87%
const int _kDisabledAlpha = 0x61; // 38%
const double _kCheckmarkStrokeWidth = 2.0;

const Duration _kSelectDuration = Duration(milliseconds: 195);
const Duration _kCheckmarkDuration = Duration(milliseconds: 150);
const Duration _kCheckmarkReverseDuration = Duration(milliseconds: 50);
const Duration _kDrawerDuration = Duration(milliseconds: 150);
const Duration _kReverseDrawerDuration = Duration(milliseconds: 100);
const Duration _kDisableDuration = Duration(milliseconds: 75);

const Color _kSelectScrimColor = Color(0x60191919);
const Icon _kDefaultDeleteIcon = Icon(Icons.cancel, size: _kDeleteIconSize);

abstract interface class ChipAttributes {
  Widget get label;

  Widget? get avatar;

  //
  TextStyle? get labelStyle;

  BorderSide? get side;

  OutlinedBorder? get shape;

  Clip get clipBehavior;

  FocusNode? get focusNode;

  bool get autofocus;

  MaterialStateProperty<Color?>? get color;

  Color? get backgroundColor;

  EdgeInsetsGeometry? get padding;

  VisualDensity? get visualDensity;

  EdgeInsetsGeometry? get labelPadding;

  MaterialTapTargetSize? get materialTapTargetSize;

  double? get elevation;

  Color? get shadowColor;

  Color? get surfaceTintColor;

  IconThemeData? get iconTheme;
}

abstract interface class DeletableChipAttributes {
  Widget? get deleteIcon;

  VoidCallback? get onDeleted;

  Color? get deleteIconColor;

  String? get deleteButtonTooltipMessage;
}

abstract interface class CheckmarkableChipAttributes {
  bool? get showCheckmark;

  Color? get checkmarkColor;
}

abstract interface class SelectableChipAttributes {
  bool get selected;

  ValueChanged<bool>? get onSelected;

  double? get pressElevation;

  Color? get selectedColor;

  Color? get selectedShadowColor;

  String? get tooltip;

  ShapeBorder get avatarBorder;
}

abstract interface class DisabledChipAttributes {
  bool get isEnabled;

  Color? get disabledColor;
}

abstract interface class TappableChipAttributes {
  VoidCallback? get onPressed;

  double? get pressElevation;

  String? get tooltip;
}

class Chip extends StatelessWidget implements ChipAttributes, DeletableChipAttributes {
  const Chip({
    super.key,
    this.avatar,
    required this.label,
    this.labelStyle,
    this.labelPadding,
    this.deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
    this.side,
    this.shape,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.autofocus = false,
    this.color,
    this.backgroundColor,
    this.padding,
    this.visualDensity,
    this.materialTapTargetSize,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.iconTheme,
  }) : assert(elevation == null || elevation >= 0.0);

  @override
  final Widget? avatar;
  @override
  final Widget label;
  @override
  final TextStyle? labelStyle;
  @override
  final EdgeInsetsGeometry? labelPadding;
  @override
  final BorderSide? side;
  @override
  final OutlinedBorder? shape;
  @override
  final Clip clipBehavior;
  @override
  final FocusNode? focusNode;
  @override
  final bool autofocus;
  @override
  final MaterialStateProperty<Color?>? color;
  @override
  final Color? backgroundColor;
  @override
  final EdgeInsetsGeometry? padding;
  @override
  final VisualDensity? visualDensity;
  @override
  final Widget? deleteIcon;
  @override
  final VoidCallback? onDeleted;
  @override
  final Color? deleteIconColor;
  @override
  final String? deleteButtonTooltipMessage;
  @override
  final MaterialTapTargetSize? materialTapTargetSize;
  @override
  final double? elevation;
  @override
  final Color? shadowColor;
  @override
  final Color? surfaceTintColor;
  @override
  final IconThemeData? iconTheme;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    return RawChip(
      avatar: avatar,
      label: label,
      labelStyle: labelStyle,
      labelPadding: labelPadding,
      deleteIcon: deleteIcon,
      onDeleted: onDeleted,
      deleteIconColor: deleteIconColor,
      deleteButtonTooltipMessage: deleteButtonTooltipMessage,
      tapEnabled: false,
      side: side,
      shape: shape,
      clipBehavior: clipBehavior,
      focusNode: focusNode,
      autofocus: autofocus,
      color: color,
      backgroundColor: backgroundColor,
      padding: padding,
      visualDensity: visualDensity,
      materialTapTargetSize: materialTapTargetSize,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
    );
  }
}

class RawChip extends StatefulWidget
    implements
        ChipAttributes,
        DeletableChipAttributes,
        SelectableChipAttributes,
        CheckmarkableChipAttributes,
        DisabledChipAttributes,
        TappableChipAttributes {
  const RawChip({
    super.key,
    this.defaultProperties,
    this.avatar,
    required this.label,
    this.labelStyle,
    this.padding,
    this.visualDensity,
    this.labelPadding,
    Widget? deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
    this.onPressed,
    this.onSelected,
    this.pressElevation,
    this.tapEnabled = true,
    this.selected = false,
    this.isEnabled = true,
    this.disabledColor,
    this.selectedColor,
    this.tooltip,
    this.side,
    this.shape,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.autofocus = false,
    this.color,
    this.backgroundColor,
    this.materialTapTargetSize,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.iconTheme,
    this.selectedShadowColor,
    this.showCheckmark,
    this.checkmarkColor,
    this.avatarBorder = const CircleBorder(),
  }) : assert(pressElevation == null || pressElevation >= 0.0),
       assert(elevation == null || elevation >= 0.0),
       deleteIcon = deleteIcon ?? _kDefaultDeleteIcon;

  final ChipThemeData? defaultProperties;

  @override
  final Widget? avatar;
  @override
  final Widget label;
  @override
  final TextStyle? labelStyle;
  @override
  final EdgeInsetsGeometry? labelPadding;
  @override
  final Widget deleteIcon;
  @override
  final VoidCallback? onDeleted;
  @override
  final Color? deleteIconColor;
  @override
  final String? deleteButtonTooltipMessage;
  @override
  final ValueChanged<bool>? onSelected;
  @override
  final VoidCallback? onPressed;
  @override
  final double? pressElevation;
  @override
  final bool selected;
  @override
  final bool isEnabled;
  @override
  final Color? disabledColor;
  @override
  final Color? selectedColor;
  @override
  final String? tooltip;
  @override
  final BorderSide? side;
  @override
  final OutlinedBorder? shape;
  @override
  final Clip clipBehavior;
  @override
  final FocusNode? focusNode;
  @override
  final bool autofocus;
  @override
  final MaterialStateProperty<Color?>? color;
  @override
  final Color? backgroundColor;
  @override
  final EdgeInsetsGeometry? padding;
  @override
  final VisualDensity? visualDensity;
  @override
  final MaterialTapTargetSize? materialTapTargetSize;
  @override
  final double? elevation;
  @override
  final Color? shadowColor;
  @override
  final Color? surfaceTintColor;
  @override
  final IconThemeData? iconTheme;
  @override
  final Color? selectedShadowColor;
  @override
  final bool? showCheckmark;
  @override
  final Color? checkmarkColor;
  @override
  final ShapeBorder avatarBorder;

  final bool tapEnabled;

  @override
  State<RawChip> createState() => _RawChipState();
}

class _RawChipState extends State<RawChip> with MaterialStateMixin, TickerProviderStateMixin<RawChip> {
  static const Duration pressedAnimationDuration = Duration(milliseconds: 75);

  late AnimationController selectController;
  late AnimationController avatarDrawerController;
  late AnimationController deleteDrawerController;
  late AnimationController enableController;
  late Animation<double> checkmarkAnimation;
  late Animation<double> avatarDrawerAnimation;
  late Animation<double> deleteDrawerAnimation;
  late Animation<double> enableAnimation;
  late Animation<double> selectionFade;

  bool get hasDeleteButton => widget.onDeleted != null;
  bool get hasAvatar => widget.avatar != null;

  bool get canTap {
    return widget.isEnabled
        && widget.tapEnabled
        && (widget.onPressed != null || widget.onSelected != null);
  }

  bool _isTapping = false;
  bool get isTapping => canTap && _isTapping;

  @override
  void initState() {
    assert(widget.onSelected == null || widget.onPressed == null);
    super.initState();
    setMaterialState(MaterialState.disabled, !widget.isEnabled);
    setMaterialState(MaterialState.selected, widget.selected);
    selectController = AnimationController(
      duration: _kSelectDuration,
      value: widget.selected ? 1.0 : 0.0,
      vsync: this,
    );
    selectionFade = CurvedAnimation(
      parent: selectController,
      curve: Curves.fastOutSlowIn,
    );
    avatarDrawerController = AnimationController(
      duration: _kDrawerDuration,
      value: hasAvatar || widget.selected ? 1.0 : 0.0,
      vsync: this,
    );
    deleteDrawerController = AnimationController(
      duration: _kDrawerDuration,
      value: hasDeleteButton ? 1.0 : 0.0,
      vsync: this,
    );
    enableController = AnimationController(
      duration: _kDisableDuration,
      value: widget.isEnabled ? 1.0 : 0.0,
      vsync: this,
    );

    // These will delay the start of some animations, and/or reduce their
    // length compared to the overall select animation, using Intervals.
    final double checkmarkPercentage = _kCheckmarkDuration.inMilliseconds /
        _kSelectDuration.inMilliseconds;
    final double checkmarkReversePercentage = _kCheckmarkReverseDuration.inMilliseconds /
        _kSelectDuration.inMilliseconds;
    final double avatarDrawerReversePercentage = _kReverseDrawerDuration.inMilliseconds /
        _kSelectDuration.inMilliseconds;
    checkmarkAnimation = CurvedAnimation(
      parent: selectController,
      curve: Interval(1.0 - checkmarkPercentage, 1.0, curve: Curves.fastOutSlowIn),
      reverseCurve: Interval(
        1.0 - checkmarkReversePercentage,
        1.0,
        curve: Curves.fastOutSlowIn,
      ),
    );
    deleteDrawerAnimation = CurvedAnimation(
      parent: deleteDrawerController,
      curve: Curves.fastOutSlowIn,
    );
    avatarDrawerAnimation = CurvedAnimation(
      parent: avatarDrawerController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Interval(
        1.0 - avatarDrawerReversePercentage,
        1.0,
        curve: Curves.fastOutSlowIn,
      ),
    );
    enableAnimation = CurvedAnimation(
      parent: enableController,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    selectController.dispose();
    avatarDrawerController.dispose();
    deleteDrawerController.dispose();
    enableController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!canTap) {
      return;
    }
    setMaterialState(MaterialState.pressed, true);
    setState(() {
      _isTapping = true;
    });
  }

  void _handleTapCancel() {
    if (!canTap) {
      return;
    }
    setMaterialState(MaterialState.pressed, false);
    setState(() {
      _isTapping = false;
    });
  }

  void _handleTap() {
    if (!canTap) {
      return;
    }
    setMaterialState(MaterialState.pressed, false);
    setState(() {
      _isTapping = false;
    });
    // Only one of these can be set, so only one will be called.
    widget.onSelected?.call(!widget.selected);
    widget.onPressed?.call();
  }

  OutlinedBorder _getShape(ThemeData theme, ChipThemeData chipTheme, ChipThemeData chipDefaults) {
    final BorderSide? resolvedSide = MaterialStateProperty.resolveAs<BorderSide?>(widget.side, materialStates)
      ?? MaterialStateProperty.resolveAs<BorderSide?>(chipTheme.side, materialStates);
    final OutlinedBorder resolvedShape = MaterialStateProperty.resolveAs<OutlinedBorder?>(widget.shape, materialStates)
      ?? MaterialStateProperty.resolveAs<OutlinedBorder?>(chipTheme.shape, materialStates)
      ?? MaterialStateProperty.resolveAs<OutlinedBorder?>(chipDefaults.shape, materialStates)
      // TODO(tahatesser): Remove this fallback when Material 2 is deprecated.
      ?? const StadiumBorder();
    // If the side is provided, shape uses the provided side.
    if (resolvedSide != null) {
      return resolvedShape.copyWith(side: resolvedSide);
    }
    // If the side is not provided and the shape's side is not [BorderSide.none],
    // then the shape's side is used. Otherwise, the default side is used.
    return resolvedShape.side != BorderSide.none
      ? resolvedShape
      : resolvedShape.copyWith(side: chipDefaults.side);
  }

  Color? resolveColor({
    MaterialStateProperty<Color?>? color,
    Color? selectedColor,
    Color? backgroundColor,
    Color? disabledColor,
    MaterialStateProperty<Color?>? defaultColor,
  }) {
    return _IndividualOverrides(
      color: color,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      disabledColor: disabledColor,
    ).resolve(materialStates) ?? defaultColor?.resolve(materialStates);
  }

  Color? _getBackgroundColor(ThemeData theme, ChipThemeData chipTheme, ChipThemeData chipDefaults) {
    if (theme.useMaterial3) {
      final Color? disabledColor = resolveColor(
        color: widget.color ?? chipTheme.color,
        disabledColor: widget.disabledColor ?? chipTheme.disabledColor,
        defaultColor: chipDefaults.color,
      );
      final Color? backgroundColor = resolveColor(
        color: widget.color ?? chipTheme.color,
        backgroundColor: widget.backgroundColor ?? chipTheme.backgroundColor,
        defaultColor: chipDefaults.color,
      );
      final Color? selectedColor = resolveColor(
        color: widget.color ?? chipTheme.color,
        selectedColor: widget.selectedColor ?? chipTheme.selectedColor,
        defaultColor: chipDefaults.color,
      );
      final ColorTween backgroundTween = ColorTween(
        begin: disabledColor,
        end: backgroundColor,
      );
      final ColorTween selectTween = ColorTween(
        begin: backgroundTween.evaluate(enableController),
        end: selectedColor,
      );
      return selectTween.evaluate(selectionFade);
    } else {
      final ColorTween backgroundTween = ColorTween(
        begin: widget.disabledColor
            ?? chipTheme.disabledColor
            ?? theme.disabledColor,
        end: widget.backgroundColor
            ?? chipTheme.backgroundColor
            ?? theme.chipTheme.backgroundColor
            ?? chipDefaults.backgroundColor,
      );
      final ColorTween selectTween = ColorTween(
        begin: backgroundTween.evaluate(enableController),
        end: widget.selectedColor
            ?? chipTheme.selectedColor
            ?? theme.chipTheme.selectedColor
            ?? chipDefaults.selectedColor,
      );
      return selectTween.evaluate(selectionFade);
    }
  }

  @override
  void didUpdateWidget(RawChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEnabled != widget.isEnabled) {
      setState(() {
        setMaterialState(MaterialState.disabled, !widget.isEnabled);
        if (widget.isEnabled) {
          enableController.forward();
        } else {
          enableController.reverse();
        }
      });
    }
    if (oldWidget.avatar != widget.avatar || oldWidget.selected != widget.selected) {
      setState(() {
        if (hasAvatar || widget.selected) {
          avatarDrawerController.forward();
        } else {
          avatarDrawerController.reverse();
        }
      });
    }
    if (oldWidget.selected != widget.selected) {
      setState(() {
        setMaterialState(MaterialState.selected, widget.selected);
        if (widget.selected) {
          selectController.forward();
        } else {
          selectController.reverse();
        }
      });
    }
    if (oldWidget.onDeleted != widget.onDeleted) {
      setState(() {
        if (hasDeleteButton) {
          deleteDrawerController.forward();
        } else {
          deleteDrawerController.reverse();
        }
      });
    }
  }

  Widget? _wrapWithTooltip({String? tooltip, bool enabled = true, Widget? child}) {
    if (child == null || !enabled || tooltip == null) {
      return child;
    }
    return Tooltip(
      message: tooltip,
      child: child,
    );
  }

  Widget? _buildDeleteIcon(
    BuildContext context,
    ThemeData theme,
    ChipThemeData chipTheme,
    ChipThemeData chipDefaults,
  ) {
    if (!hasDeleteButton) {
      return null;
    }
    return Semantics(
      container: true,
      button: true,
      child: _wrapWithTooltip(
        tooltip: widget.deleteButtonTooltipMessage
          ?? MaterialLocalizations.of(context).deleteButtonTooltip,
        enabled: widget.onDeleted != null,
        child: InkWell(
          // Radius should be slightly less than the full size of the chip.
          radius: (_kChipHeight + (widget.padding?.vertical ?? 0.0)) * .45,
          // Keeps the splash from being constrained to the icon alone.
          splashFactory: _UnconstrainedInkSplashFactory(Theme.of(context).splashFactory),
          onTap: widget.isEnabled ? widget.onDeleted : null,
          child: IconTheme(
            data: theme.iconTheme.copyWith(
              color: widget.deleteIconColor
                ?? chipTheme.deleteIconColor
                ?? theme.chipTheme.deleteIconColor
                ?? chipDefaults.deleteIconColor,
            ),
            child: widget.deleteIcon,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasDirectionality(context));
    assert(debugCheckHasMaterialLocalizations(context));

    final EdgeInsetsGeometry defaultLabelPadding = EdgeInsets.lerp(
      const EdgeInsets.symmetric(horizontal: 8.0),
      const EdgeInsets.symmetric(horizontal: 4.0),
      clampDouble(MediaQuery.textScalerOf(context).textScaleFactor - 1.0, 0.0, 1.0),
    )!;

    final ThemeData theme = Theme.of(context);
    final ChipThemeData chipTheme = ChipTheme.of(context);
    final Brightness brightness = chipTheme.brightness ?? theme.brightness;
    final ChipThemeData chipDefaults = widget.defaultProperties ??
      (theme.useMaterial3
        ? _ChipDefaultsM3(context, widget.isEnabled)
        : ChipThemeData.fromDefaults(
            brightness: brightness,
            secondaryColor: brightness == Brightness.dark ? Colors.tealAccent[200]! : theme.primaryColor,
            labelStyle: theme.textTheme.bodyLarge!,
          )
        );
    final TextDirection? textDirection = Directionality.maybeOf(context);
    final OutlinedBorder resolvedShape = _getShape(theme, chipTheme, chipDefaults);

    final double elevation = widget.elevation
      ?? chipTheme.elevation
      ?? chipDefaults.elevation
      ?? 0;
    final double pressElevation = widget.pressElevation
      ?? chipTheme.pressElevation
      ?? chipDefaults.pressElevation
      ?? 0;
    final Color? shadowColor = widget.shadowColor
      ?? chipTheme.shadowColor
      ?? chipDefaults.shadowColor;
    final Color? surfaceTintColor = widget.surfaceTintColor
      ?? chipTheme.surfaceTintColor
      ?? chipDefaults.surfaceTintColor;
    final Color? selectedShadowColor = widget.selectedShadowColor
      ?? chipTheme.selectedShadowColor
      ?? chipDefaults.selectedShadowColor;
    final Color? checkmarkColor = widget.checkmarkColor
      ?? chipTheme.checkmarkColor
      ?? chipDefaults.checkmarkColor;
    final bool showCheckmark = widget.showCheckmark
      ?? chipTheme.showCheckmark
      ?? chipDefaults.showCheckmark!;
    final EdgeInsetsGeometry padding = widget.padding
      ?? chipTheme.padding
      ?? chipDefaults.padding!;
    // Widget's label style is merged with this below.
    final TextStyle labelStyle = chipTheme.labelStyle
      ?? chipDefaults.labelStyle!;
    final EdgeInsetsGeometry labelPadding = widget.labelPadding
      ?? chipTheme.labelPadding
      ?? chipDefaults.labelPadding
      ?? defaultLabelPadding;
    final IconThemeData? iconTheme = widget.iconTheme
      ?? chipTheme.iconTheme
      ?? chipDefaults.iconTheme;

    final TextStyle effectiveLabelStyle = labelStyle.merge(widget.labelStyle);
    final Color? resolvedLabelColor = MaterialStateProperty.resolveAs<Color?>(effectiveLabelStyle.color, materialStates);
    final TextStyle resolvedLabelStyle = effectiveLabelStyle.copyWith(color: resolvedLabelColor);
    final Widget? avatar = iconTheme != null && hasAvatar
      ? IconTheme(data: iconTheme, child: widget.avatar!)
      : widget.avatar;

    Widget result = Material(
      elevation: isTapping ? pressElevation : elevation,
      shadowColor: widget.selected ? selectedShadowColor : shadowColor,
      surfaceTintColor: surfaceTintColor,
      animationDuration: pressedAnimationDuration,
      shape: resolvedShape,
      clipBehavior: widget.clipBehavior,
      child: InkWell(
        onFocusChange: updateMaterialState(MaterialState.focused),
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: widget.isEnabled,
        onTap: canTap ? _handleTap : null,
        onTapDown: canTap ? _handleTapDown : null,
        onTapCancel: canTap ? _handleTapCancel : null,
        onHover: canTap ? updateMaterialState(MaterialState.hovered) : null,
        customBorder: resolvedShape,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[selectController, enableController]),
          builder: (BuildContext context, Widget? child) {
            return Ink(
              decoration: ShapeDecoration(
                shape: resolvedShape,
                color: _getBackgroundColor(theme, chipTheme, chipDefaults),
              ),
              child: child,
            );
          },
          child: _wrapWithTooltip(
            tooltip: widget.tooltip,
            enabled: widget.onPressed != null || widget.onSelected != null,
            child: _ChipRenderWidget(
              theme: _ChipRenderTheme(
                label: DefaultTextStyle(
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  softWrap: false,
                  style: resolvedLabelStyle,
                  child: widget.label,
                ),
                avatar: AnimatedSwitcher(
                  duration: _kDrawerDuration,
                  switchInCurve: Curves.fastOutSlowIn,
                  child: avatar,
                ),
                deleteIcon: AnimatedSwitcher(
                  duration: _kDrawerDuration,
                  switchInCurve: Curves.fastOutSlowIn,
                  child: _buildDeleteIcon(context, theme, chipTheme, chipDefaults),
                ),
                brightness: brightness,
                padding: padding.resolve(textDirection),
                visualDensity: widget.visualDensity ?? theme.visualDensity,
                labelPadding: labelPadding.resolve(textDirection),
                showAvatar: hasAvatar,
                showCheckmark: showCheckmark,
                checkmarkColor: checkmarkColor,
                canTapBody: canTap,
              ),
              value: widget.selected,
              checkmarkAnimation: checkmarkAnimation,
              enableAnimation: enableAnimation,
              avatarDrawerAnimation: avatarDrawerAnimation,
              deleteDrawerAnimation: deleteDrawerAnimation,
              isEnabled: widget.isEnabled,
              avatarBorder: widget.avatarBorder,
            ),
          ),
        ),
      ),
    );

    final BoxConstraints constraints;
    final Offset densityAdjustment = (widget.visualDensity ?? theme.visualDensity).baseSizeAdjustment;
    switch (widget.materialTapTargetSize ?? theme.materialTapTargetSize) {
      case MaterialTapTargetSize.padded:
        constraints = BoxConstraints(
          minWidth: kMinInteractiveDimension + densityAdjustment.dx,
          minHeight: kMinInteractiveDimension + densityAdjustment.dy,
        );
      case MaterialTapTargetSize.shrinkWrap:
        constraints = const BoxConstraints();
    }
    result = _ChipRedirectingHitDetectionWidget(
      constraints: constraints,
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: result,
      ),
    );
    return Semantics(
      button: widget.tapEnabled,
      container: true,
      selected: widget.selected,
      enabled: widget.tapEnabled ? canTap : null,
      child: result,
    );
  }
}

class _IndividualOverrides extends MaterialStateProperty<Color?> {
  _IndividualOverrides({
    this.color,
    this.backgroundColor,
    this.selectedColor,
    this.disabledColor,
  });

  final MaterialStateProperty<Color?>? color;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? disabledColor;

  @override
  Color? resolve(Set<MaterialState> states) {
    if (color != null) {
      return color!.resolve(states);
    }
    if (states.contains(MaterialState.selected) && states.contains(MaterialState.disabled)) {
      return selectedColor;
    }
    if (states.contains(MaterialState.disabled)) {
      return disabledColor;
    }
    if (states.contains(MaterialState.selected)) {
      return selectedColor;
    }
    return backgroundColor;
  }
}

class _ChipRedirectingHitDetectionWidget extends SingleChildRenderObjectWidget {
  const _ChipRedirectingHitDetectionWidget({
    super.child,
    required this.constraints,
  });

  final BoxConstraints constraints;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderChipRedirectingHitDetection(constraints);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderChipRedirectingHitDetection renderObject) {
    renderObject.additionalConstraints = constraints;
  }
}

class _RenderChipRedirectingHitDetection extends RenderConstrainedBox {
  _RenderChipRedirectingHitDetection(BoxConstraints additionalConstraints) : super(additionalConstraints: additionalConstraints);

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (!size.contains(position)) {
      return false;
    }
    // Only redirects hit detection which occurs above and below the render object.
    // In order to make this assumption true, I have removed the minimum width
    // constraints, since any reasonable chip would be at least that wide.
    final Offset offset = Offset(position.dx, size.height / 2);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(offset),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        assert(position == offset);
        return child!.hitTest(result, position: offset);
      },
    );
  }
}

class _ChipRenderWidget extends SlottedMultiChildRenderObjectWidget<_ChipSlot, RenderBox> {
  const _ChipRenderWidget({
    required this.theme,
    this.value,
    this.isEnabled,
    required this.checkmarkAnimation,
    required this.avatarDrawerAnimation,
    required this.deleteDrawerAnimation,
    required this.enableAnimation,
    this.avatarBorder,
  });

  final _ChipRenderTheme theme;
  final bool? value;
  final bool? isEnabled;
  final Animation<double> checkmarkAnimation;
  final Animation<double> avatarDrawerAnimation;
  final Animation<double> deleteDrawerAnimation;
  final Animation<double> enableAnimation;
  final ShapeBorder? avatarBorder;

  @override
  Iterable<_ChipSlot> get slots => _ChipSlot.values;

  @override
  Widget? childForSlot(_ChipSlot slot) {
    switch (slot) {
      case _ChipSlot.label:
        return theme.label;
      case _ChipSlot.avatar:
        return theme.avatar;
      case _ChipSlot.deleteIcon:
        return theme.deleteIcon;
    }
  }

  @override
  void updateRenderObject(BuildContext context, _RenderChip renderObject) {
    renderObject
      ..theme = theme
      ..textDirection = Directionality.of(context)
      ..value = value
      ..isEnabled = isEnabled
      ..checkmarkAnimation = checkmarkAnimation
      ..avatarDrawerAnimation = avatarDrawerAnimation
      ..deleteDrawerAnimation = deleteDrawerAnimation
      ..enableAnimation = enableAnimation
      ..avatarBorder = avatarBorder;
  }

  @override
  SlottedContainerRenderObjectMixin<_ChipSlot, RenderBox> createRenderObject(BuildContext context) {
    return _RenderChip(
      theme: theme,
      textDirection: Directionality.of(context),
      value: value,
      isEnabled: isEnabled,
      checkmarkAnimation: checkmarkAnimation,
      avatarDrawerAnimation: avatarDrawerAnimation,
      deleteDrawerAnimation: deleteDrawerAnimation,
      enableAnimation: enableAnimation,
      avatarBorder: avatarBorder,
    );
  }
}

enum _ChipSlot {
  label,
  avatar,
  deleteIcon,
}

@immutable
class _ChipRenderTheme {
  const _ChipRenderTheme({
    required this.avatar,
    required this.label,
    required this.deleteIcon,
    required this.brightness,
    required this.padding,
    required this.visualDensity,
    required this.labelPadding,
    required this.showAvatar,
    required this.showCheckmark,
    required this.checkmarkColor,
    required this.canTapBody,
  });

  final Widget avatar;
  final Widget label;
  final Widget deleteIcon;
  final Brightness brightness;
  final EdgeInsets padding;
  final VisualDensity visualDensity;
  final EdgeInsets labelPadding;
  final bool showAvatar;
  final bool showCheckmark;
  final Color? checkmarkColor;
  final bool canTapBody;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _ChipRenderTheme
        && other.avatar == avatar
        && other.label == label
        && other.deleteIcon == deleteIcon
        && other.brightness == brightness
        && other.padding == padding
        && other.labelPadding == labelPadding
        && other.showAvatar == showAvatar
        && other.showCheckmark == showCheckmark
        && other.checkmarkColor == checkmarkColor
        && other.canTapBody == canTapBody;
  }

  @override
  int get hashCode => Object.hash(
    avatar,
    label,
    deleteIcon,
    brightness,
    padding,
    labelPadding,
    showAvatar,
    showCheckmark,
    checkmarkColor,
    canTapBody,
  );
}

class _RenderChip extends RenderBox with SlottedContainerRenderObjectMixin<_ChipSlot, RenderBox> {
  _RenderChip({
    required _ChipRenderTheme theme,
    required TextDirection textDirection,
    this.value,
    this.isEnabled,
    required this.checkmarkAnimation,
    required this.avatarDrawerAnimation,
    required this.deleteDrawerAnimation,
    required this.enableAnimation,
    this.avatarBorder,
  }) : _theme = theme,
       _textDirection = textDirection {
    checkmarkAnimation.addListener(markNeedsPaint);
    avatarDrawerAnimation.addListener(markNeedsLayout);
    deleteDrawerAnimation.addListener(markNeedsLayout);
    enableAnimation.addListener(markNeedsPaint);
  }

  bool? value;
  bool? isEnabled;
  late Rect _deleteButtonRect;
  late Rect _pressRect;
  Animation<double> checkmarkAnimation;
  Animation<double> avatarDrawerAnimation;
  Animation<double> deleteDrawerAnimation;
  Animation<double> enableAnimation;
  ShapeBorder? avatarBorder;

  RenderBox? get avatar => childForSlot(_ChipSlot.avatar);
  RenderBox? get deleteIcon => childForSlot(_ChipSlot.deleteIcon);
  RenderBox? get label => childForSlot(_ChipSlot.label);

  _ChipRenderTheme get theme => _theme;
  _ChipRenderTheme _theme;
  set theme(_ChipRenderTheme value) {
    if (_theme == value) {
      return;
    }
    _theme = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  // The returned list is ordered for hit testing.
  @override
  Iterable<RenderBox> get children {
    return <RenderBox>[
      if (avatar != null)
        avatar!,
      if (label != null)
        label!,
      if (deleteIcon != null)
        deleteIcon!,
    ];
  }

  bool get isDrawingCheckmark => theme.showCheckmark && !checkmarkAnimation.isDismissed;
  bool get deleteIconShowing => !deleteDrawerAnimation.isDismissed;

  @override
  bool get sizedByParent => false;

  static double _minWidth(RenderBox? box, double height) {
    return box == null ? 0.0 : box.getMinIntrinsicWidth(height);
  }

  static double _maxWidth(RenderBox? box, double height) {
    return box == null ? 0.0 : box.getMaxIntrinsicWidth(height);
  }

  static double _minHeight(RenderBox? box, double width) {
    return box == null ? 0.0 : box.getMinIntrinsicHeight(width);
  }

  static Size _boxSize(RenderBox? box) => box == null ? Size.zero : box.size;

  static Rect _boxRect(RenderBox? box) => box == null ? Rect.zero : _boxParentData(box).offset & box.size;

  static BoxParentData _boxParentData(RenderBox box) => box.parentData! as BoxParentData;

  @override
  double computeMinIntrinsicWidth(double height) {
    // The overall padding isn't affected by missing avatar or delete icon
    // because we add the padding regardless to give extra padding for the label
    // when they're missing.
    final double overallPadding = theme.padding.horizontal +
        theme.labelPadding.horizontal;
    return overallPadding +
        _minWidth(avatar, height) +
        _minWidth(label, height) +
        _minWidth(deleteIcon, height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double overallPadding = theme.padding.horizontal +
        theme.labelPadding.horizontal;
    return overallPadding +
        _maxWidth(avatar, height) +
        _maxWidth(label, height) +
        _maxWidth(deleteIcon, height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return math.max(
      _kChipHeight,
      theme.padding.vertical + theme.labelPadding.vertical + _minHeight(label, width),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    // The baseline of this widget is the baseline of the label.
    return label!.getDistanceToActualBaseline(baseline);
  }

  Size _layoutLabel(BoxConstraints contentConstraints, double iconSizes, Size size, Size rawSize, [ChildLayouter layoutChild = ChildLayoutHelper.layoutChild]) {
    // Now that we know the label height and the width of the icons, we can
    // determine how much to shrink the width constraints for the "real" layout.
    if (contentConstraints.maxWidth.isFinite) {
      final double maxWidth = math.max(
        0.0,
        contentConstraints.maxWidth
        - iconSizes
        - theme.labelPadding.horizontal
        - theme.padding.horizontal,
      );
      final Size updatedSize = layoutChild(
        label!,
        BoxConstraints(
          maxWidth: maxWidth,
          minHeight: rawSize.height,
          maxHeight: size.height,
        ),
      );

      return Size(
        updatedSize.width + theme.labelPadding.horizontal,
        updatedSize.height + theme.labelPadding.vertical,
      );
    }

    final Size updatedSize = layoutChild(
      label!,
      BoxConstraints(
        minHeight: rawSize.height,
        maxHeight: size.height,
        maxWidth: size.width,
      ),
    );

    return Size(
      updatedSize.width + theme.labelPadding.horizontal,
      updatedSize.height + theme.labelPadding.vertical,
    );
  }

  Size _layoutAvatar(BoxConstraints contentConstraints, double contentSize, [ChildLayouter layoutChild = ChildLayoutHelper.layoutChild]) {
    final double requestedSize = math.max(0.0, contentSize);
    final BoxConstraints avatarConstraints = BoxConstraints.tightFor(
      width: requestedSize,
      height: requestedSize,
    );
    final Size avatarBoxSize = layoutChild(avatar!, avatarConstraints);
    if (!theme.showCheckmark && !theme.showAvatar) {
      return Size(0.0, contentSize);
    }
    double avatarWidth = 0.0;
    double avatarHeight = 0.0;
    if (theme.showAvatar) {
      avatarWidth += avatarDrawerAnimation.value * avatarBoxSize.width;
    } else {
      avatarWidth += avatarDrawerAnimation.value * contentSize;
    }
    avatarHeight += avatarBoxSize.height;
    return Size(avatarWidth, avatarHeight);
  }

  Size _layoutDeleteIcon(BoxConstraints contentConstraints, double contentSize, [ChildLayouter layoutChild = ChildLayoutHelper.layoutChild]) {
    final double requestedSize = math.max(0.0, contentSize);
    final BoxConstraints deleteIconConstraints = BoxConstraints.tightFor(
      width: requestedSize,
      height: requestedSize,
    );
    final Size boxSize = layoutChild(deleteIcon!, deleteIconConstraints);
    if (!deleteIconShowing) {
      return Size(0.0, contentSize);
    }
    double deleteIconWidth = 0.0;
    double deleteIconHeight = 0.0;
    deleteIconWidth += deleteDrawerAnimation.value * boxSize.width;
    deleteIconHeight += boxSize.height;
    return Size(deleteIconWidth, deleteIconHeight);
  }

  @override
  bool hitTest(BoxHitTestResult result, { required Offset position }) {
    if (!size.contains(position)) {
      return false;
    }
    final bool hitIsOnDeleteIcon = deleteIcon != null && _hitIsOnDeleteIcon(
      padding: theme.padding,
      labelPadding: theme.labelPadding,
      tapPosition: position,
      chipSize: size,
      deleteButtonSize: deleteIcon!.size,
      textDirection: textDirection!,
    );
    final RenderBox? hitTestChild = hitIsOnDeleteIcon
        ? (deleteIcon ?? label ?? avatar)
        : (label ?? avatar);

    if (hitTestChild != null) {
      final Offset center = hitTestChild.size.center(Offset.zero);
      return result.addWithRawTransform(
        transform: MatrixUtils.forceToPoint(center),
        position: position,
        hitTest: (BoxHitTestResult result, Offset position) {
          assert(position == center);
          return hitTestChild.hitTest(result, position: center);
        },
      );
    }
    return false;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSizes(constraints, ChildLayoutHelper.dryLayoutChild).size;
  }

  _ChipSizes _computeSizes(BoxConstraints constraints, ChildLayouter layoutChild) {
    final BoxConstraints contentConstraints = constraints.loosen();
    // Find out the height of the label within the constraints.
    final Offset densityAdjustment = Offset(0.0, theme.visualDensity.baseSizeAdjustment.dy / 2.0);
    final Size rawLabelSize = layoutChild(label!, contentConstraints);
    final double contentSize = math.max(
      _kChipHeight - theme.padding.vertical + theme.labelPadding.vertical,
      rawLabelSize.height + theme.labelPadding.vertical,
    );
    final Size avatarSize = _layoutAvatar(contentConstraints, contentSize, layoutChild);
    final Size deleteIconSize = _layoutDeleteIcon(contentConstraints, contentSize, layoutChild);
    final Size labelSize = _layoutLabel(
      contentConstraints,
      avatarSize.width + deleteIconSize.width,
      Size(rawLabelSize.width, contentSize),
      rawLabelSize,
      layoutChild,
    );

    // This is the overall size of the content: it doesn't include
    // theme.padding, that is added in at the end.
    final Size overallSize = Size(
      avatarSize.width + labelSize.width + deleteIconSize.width,
      contentSize,
    ) + densityAdjustment;
    final Size paddedSize = Size(
      overallSize.width + theme.padding.horizontal,
      overallSize.height + theme.padding.vertical,
    );

    return _ChipSizes(
      size: constraints.constrain(paddedSize),
      overall: overallSize,
      content: contentSize,
      densityAdjustment: densityAdjustment,
      avatar: avatarSize,
      label: labelSize,
      deleteIcon: deleteIconSize,
    );
  }

  @override
  void performLayout() {
    final _ChipSizes sizes = _computeSizes(constraints, ChildLayoutHelper.layoutChild);

    // Now we have all of the dimensions. Place the children where they belong.

    const double left = 0.0;
    final double right = sizes.overall.width;

    Offset centerLayout(Size boxSize, double x) {
      assert(sizes.content >= boxSize.height);
      switch (textDirection!) {
        case TextDirection.rtl:
          return Offset(x - boxSize.width, (sizes.content - boxSize.height + sizes.densityAdjustment.dy) / 2.0);
        case TextDirection.ltr:
          return Offset(x, (sizes.content - boxSize.height + sizes.densityAdjustment.dy) / 2.0);
      }
    }

    // These are the offsets to the upper left corners of the boxes (including
    // the child's padding) containing the children, for each child, but not
    // including the overall padding.
    Offset avatarOffset = Offset.zero;
    Offset labelOffset = Offset.zero;
    Offset deleteIconOffset = Offset.zero;
    switch (textDirection!) {
      case TextDirection.rtl:
        double start = right;
        if (theme.showCheckmark || theme.showAvatar) {
          avatarOffset = centerLayout(sizes.avatar, start);
          start -= sizes.avatar.width;
        }
        labelOffset = centerLayout(sizes.label, start);
        start -= sizes.label.width;
        if (deleteIconShowing) {
          _deleteButtonRect = Rect.fromLTWH(
            0.0,
            0.0,
            sizes.deleteIcon.width + theme.padding.right,
            sizes.overall.height + theme.padding.vertical,
          );
          deleteIconOffset = centerLayout(sizes.deleteIcon, start);
        } else {
          _deleteButtonRect = Rect.zero;
        }
        start -= sizes.deleteIcon.width;
        if (theme.canTapBody) {
          _pressRect = Rect.fromLTWH(
            _deleteButtonRect.width,
            0.0,
            sizes.overall.width - _deleteButtonRect.width + theme.padding.horizontal,
            sizes.overall.height + theme.padding.vertical,
          );
        } else {
          _pressRect = Rect.zero;
        }
      case TextDirection.ltr:
        double start = left;
        if (theme.showCheckmark || theme.showAvatar) {
          avatarOffset = centerLayout(sizes.avatar, start - _boxSize(avatar).width + sizes.avatar.width);
          start += sizes.avatar.width;
        }
        labelOffset = centerLayout(sizes.label, start);
        start += sizes.label.width;
        if (theme.canTapBody) {
          _pressRect = Rect.fromLTWH(
            0.0,
            0.0,
            deleteIconShowing
                ? start + theme.padding.left
                : sizes.overall.width + theme.padding.horizontal,
            sizes.overall.height + theme.padding.vertical,
          );
        } else {
          _pressRect = Rect.zero;
        }
        start -= _boxSize(deleteIcon).width - sizes.deleteIcon.width;
        if (deleteIconShowing) {
          deleteIconOffset = centerLayout(sizes.deleteIcon, start);
          _deleteButtonRect = Rect.fromLTWH(
            start + theme.padding.left,
            0.0,
            sizes.deleteIcon.width + theme.padding.right,
            sizes.overall.height + theme.padding.vertical,
          );
        } else {
          _deleteButtonRect = Rect.zero;
        }
    }
    // Center the label vertically.
    labelOffset = labelOffset +
        Offset(
          0.0,
          ((sizes.label.height - theme.labelPadding.vertical) - _boxSize(label).height) / 2.0,
        );
    _boxParentData(avatar!).offset = theme.padding.topLeft + avatarOffset;
    _boxParentData(label!).offset = theme.padding.topLeft + labelOffset + theme.labelPadding.topLeft;
    _boxParentData(deleteIcon!).offset = theme.padding.topLeft + deleteIconOffset;
    final Size paddedSize = Size(
      sizes.overall.width + theme.padding.horizontal,
      sizes.overall.height + theme.padding.vertical,
    );
    size = constraints.constrain(paddedSize);
    assert(
      size.height == constraints.constrainHeight(paddedSize.height),
      "Constrained height ${size.height} doesn't match expected height "
      '${constraints.constrainWidth(paddedSize.height)}',
    );
    assert(
      size.width == constraints.constrainWidth(paddedSize.width),
      "Constrained width ${size.width} doesn't match expected width "
      '${constraints.constrainWidth(paddedSize.width)}',
    );
  }

  static final ColorTween selectionScrimTween = ColorTween(
    begin: Colors.transparent,
    end: _kSelectScrimColor,
  );

  Color get _disabledColor {
    if (enableAnimation.isCompleted) {
      return Colors.white;
    }
    final ColorTween enableTween;
    switch (theme.brightness) {
      case Brightness.light:
        enableTween = ColorTween(
          begin: Colors.white.withAlpha(_kDisabledAlpha),
          end: Colors.white,
        );
      case Brightness.dark:
        enableTween = ColorTween(
          begin: Colors.black.withAlpha(_kDisabledAlpha),
          end: Colors.black,
        );
    }
    return enableTween.evaluate(enableAnimation)!;
  }

  void _paintCheck(Canvas canvas, Offset origin, double size) {
    Color? paintColor;
    if (theme.checkmarkColor != null) {
      paintColor = theme.checkmarkColor;
    } else {
      switch (theme.brightness) {
        case Brightness.light:
          paintColor = theme.showAvatar ? Colors.white : Colors.black.withAlpha(_kCheckmarkAlpha);
        case Brightness.dark:
          paintColor = theme.showAvatar ? Colors.black : Colors.white.withAlpha(_kCheckmarkAlpha);
      }
    }

    final ColorTween fadeTween = ColorTween(begin: Colors.transparent, end: paintColor);

    paintColor = checkmarkAnimation.status == AnimationStatus.reverse
        ? fadeTween.evaluate(checkmarkAnimation)
        : paintColor;

    final Paint paint = Paint()
      ..color = paintColor!
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kCheckmarkStrokeWidth * (avatar != null ? avatar!.size.height / 24.0 : 1.0);
    final double t = checkmarkAnimation.status == AnimationStatus.reverse
        ? 1.0
        : checkmarkAnimation.value;
    if (t == 0.0) {
      // Nothing to draw.
      return;
    }
    assert(t > 0.0 && t <= 1.0);
    // As t goes from 0.0 to 1.0, animate the two check mark strokes from the
    // short side to the long side.
    final Path path = Path();
    final Offset start = Offset(size * 0.15, size * 0.45);
    final Offset mid = Offset(size * 0.4, size * 0.7);
    final Offset end = Offset(size * 0.85, size * 0.25);
    if (t < 0.5) {
      final double strokeT = t * 2.0;
      final Offset drawMid = Offset.lerp(start, mid, strokeT)!;
      path.moveTo(origin.dx + start.dx, origin.dy + start.dy);
      path.lineTo(origin.dx + drawMid.dx, origin.dy + drawMid.dy);
    } else {
      final double strokeT = (t - 0.5) * 2.0;
      final Offset drawEnd = Offset.lerp(mid, end, strokeT)!;
      path.moveTo(origin.dx + start.dx, origin.dy + start.dy);
      path.lineTo(origin.dx + mid.dx, origin.dy + mid.dy);
      path.lineTo(origin.dx + drawEnd.dx, origin.dy + drawEnd.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintSelectionOverlay(PaintingContext context, Offset offset) {
    if (isDrawingCheckmark) {
      if (theme.showAvatar) {
        final Rect avatarRect = _boxRect(avatar).shift(offset);
        final Paint darkenPaint = Paint()
          ..color = selectionScrimTween.evaluate(checkmarkAnimation)!
          ..blendMode = BlendMode.srcATop;
        final Path path =  avatarBorder!.getOuterPath(avatarRect);
        context.canvas.drawPath(path, darkenPaint);
      }
      // Need to make the check mark be a little smaller than the avatar.
      final double checkSize = avatar!.size.height * 0.75;
      final Offset checkOffset = _boxParentData(avatar!).offset +
          Offset(avatar!.size.height * 0.125, avatar!.size.height * 0.125);
      _paintCheck(context.canvas, offset + checkOffset, checkSize);
    }
  }

  final LayerHandle<OpacityLayer> _avatarOpacityLayerHandler = LayerHandle<OpacityLayer>();

  void _paintAvatar(PaintingContext context, Offset offset) {
    void paintWithOverlay(PaintingContext context, Offset offset) {
      context.paintChild(avatar!, _boxParentData(avatar!).offset + offset);
      _paintSelectionOverlay(context, offset);
    }

    if (!theme.showAvatar && avatarDrawerAnimation.isDismissed) {
      _avatarOpacityLayerHandler.layer = null;
      return;
    }
    final Color disabledColor = _disabledColor;
    final int disabledColorAlpha = disabledColor.alpha;
    if (needsCompositing) {
       _avatarOpacityLayerHandler.layer = context.pushOpacity(offset, disabledColorAlpha, paintWithOverlay, oldLayer: _avatarOpacityLayerHandler.layer);
    } else {
      _avatarOpacityLayerHandler.layer = null;
      if (disabledColorAlpha != 0xff) {
        context.canvas.saveLayer(
          _boxRect(avatar).shift(offset).inflate(20.0),
          Paint()..color = disabledColor,
        );
      }
      paintWithOverlay(context, offset);
      if (disabledColorAlpha != 0xff) {
        context.canvas.restore();
      }
    }
  }

  final LayerHandle<OpacityLayer> _childOpacityLayerHandler = LayerHandle<OpacityLayer>();

  void _paintChild(PaintingContext context, Offset offset, RenderBox? child, bool? isEnabled) {
    if (child == null) {
      _childOpacityLayerHandler.layer = null;
      return;
    }
    final int disabledColorAlpha = _disabledColor.alpha;
    if (!enableAnimation.isCompleted) {
      if (needsCompositing) {
        _childOpacityLayerHandler.layer = context.pushOpacity(
          offset,
          disabledColorAlpha,
          (PaintingContext context, Offset offset) {
            context.paintChild(child, _boxParentData(child).offset + offset);
          },
          oldLayer: _childOpacityLayerHandler.layer,
        );
      } else {
        _childOpacityLayerHandler.layer = null;
        final Rect childRect = _boxRect(child).shift(offset);
        context.canvas.saveLayer(childRect.inflate(20.0), Paint()..color = _disabledColor);
        context.paintChild(child, _boxParentData(child).offset + offset);
        context.canvas.restore();
      }
    } else {
      context.paintChild(child, _boxParentData(child).offset + offset);
    }
  }

  @override
  void dispose() {
    _childOpacityLayerHandler.layer = null;
    _avatarOpacityLayerHandler.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintAvatar(context, offset);
    if (deleteIconShowing) {
      _paintChild(context, offset, deleteIcon, isEnabled);
    }
    _paintChild(context, offset, label, isEnabled);
  }

  // Set this to true to have outlines of the tap targets drawn over
  // the chip. This should never be checked in while set to 'true'.
  static const bool _debugShowTapTargetOutlines = false;

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    assert(!_debugShowTapTargetOutlines || () {
      // Draws a rect around the tap targets to help with visualizing where
      // they really are.
      final Paint outlinePaint = Paint()
        ..color = const Color(0xff800000)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      if (deleteIconShowing) {
        context.canvas.drawRect(_deleteButtonRect.shift(offset), outlinePaint);
      }
      context.canvas.drawRect(
        _pressRect.shift(offset),
        outlinePaint..color = const Color(0xff008000),
      );
      return true;
    }());
  }

  @override
  bool hitTestSelf(Offset position) => _deleteButtonRect.contains(position) || _pressRect.contains(position);
}

class _ChipSizes {
  _ChipSizes({
    required this.size,
    required this.overall,
    required this.content,
    required this.avatar,
    required this.label,
    required this.deleteIcon,
    required this.densityAdjustment,
});
  final Size size;
  final Size overall;
  final double content;
  final Size avatar;
  final Size label;
  final Size deleteIcon;
  final Offset densityAdjustment;
}

class _UnconstrainedInkSplashFactory extends InteractiveInkFeatureFactory {
  const _UnconstrainedInkSplashFactory(this.parentFactory);

  final InteractiveInkFeatureFactory parentFactory;

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return parentFactory.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
      textDirection: textDirection,
    );
  }
}

bool _hitIsOnDeleteIcon({
  required EdgeInsetsGeometry padding,
  required EdgeInsetsGeometry labelPadding,
  required Offset tapPosition,
  required Size chipSize,
  required Size deleteButtonSize,
  required TextDirection textDirection,
}) {
  // The chipSize includes the padding, so we need to deflate the size and adjust the
  // tap position to account for the padding.
  final EdgeInsets resolvedPadding = padding.resolve(textDirection);
  final Size deflatedSize = resolvedPadding.deflateSize(chipSize);
  final Offset adjustedPosition = tapPosition - Offset(resolvedPadding.left, resolvedPadding.top);
  // The delete button hit area should be at least the width of the delete
  // button and right label padding, but, if there's room, up to 24 pixels
  // from the center of the delete icon (corresponding to part of a 48x48 square
  // that Material would prefer for touch targets), but no more than approximately
  // half of the overall size of the chip when the chip is small.
  //
  // This isn't affected by materialTapTargetSize because it only applies to the
  // width of the tappable region within the chip, not outside of the chip,
  // which is handled elsewhere. Also because delete buttons aren't specified to
  // be used on touch devices, only desktop devices.

  // Max out at not quite half, so that tests that tap on the center of a small
  // chip will still hit the chip, not the delete button.
  final double accessibleDeleteButtonWidth = math.min(
    deflatedSize.width * 0.499,
    math.min(labelPadding.resolve(textDirection).right + deleteButtonSize.width, 24.0 + deleteButtonSize.width / 2.0),
  );
  switch (textDirection) {
    case TextDirection.ltr:
      return adjustedPosition.dx >= deflatedSize.width - accessibleDeleteButtonWidth;
    case TextDirection.rtl:
      return adjustedPosition.dx <= accessibleDeleteButtonWidth;
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - Chip

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _ChipDefaultsM3 extends ChipThemeData {
  _ChipDefaultsM3(this.context, this.isEnabled)
    : super(
        elevation: 0.0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8.0))),
        showCheckmark: true,
      );

  final BuildContext context;
  final bool isEnabled;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  TextStyle? get labelStyle => _textTheme.labelLarge;

  @override
  MaterialStateProperty<Color?>? get color => null; // Subclasses override this getter

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  Color? get checkmarkColor => null;

  @override
  Color? get deleteIconColor => null;

  @override
  BorderSide? get side => isEnabled
    ? BorderSide(color: _colors.outline)
    : BorderSide(color: _colors.onSurface.withOpacity(0.12));

  @override
  IconThemeData? get iconTheme => IconThemeData(
    color: isEnabled
      ? _colors.primary
      : _colors.onSurface,
    size: 18.0,
  );

  @override
  EdgeInsetsGeometry? get padding => const EdgeInsets.all(8.0);

  @override
  EdgeInsetsGeometry? get labelPadding => EdgeInsets.lerp(
    const EdgeInsets.symmetric(horizontal: 8.0),
    const EdgeInsets.symmetric(horizontal: 4.0),
    clampDouble(MediaQuery.textScalerOf(context).textScaleFactor - 1.0, 0.0, 1.0),
  )!;
}

// END GENERATED TOKEN PROPERTIES - Chip