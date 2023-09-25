// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'button.dart';
import 'button_theme.dart';
import 'constants.dart';
import 'ink_well.dart';
import 'material.dart';
import 'theme.dart';
import 'theme_data.dart';

class MaterialButton extends StatelessWidget {
  const MaterialButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.onHighlightChanged,
    this.mouseCursor,
    this.textTheme,
    this.textColor,
    this.disabledTextColor,
    this.color,
    this.disabledColor,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.colorBrightness,
    this.elevation,
    this.focusElevation,
    this.hoverElevation,
    this.highlightElevation,
    this.disabledElevation,
    this.padding,
    this.visualDensity,
    this.shape,
    this.clipBehavior = Clip.none,
    this.focusNode,
    this.autofocus = false,
    this.materialTapTargetSize,
    this.animationDuration,
    this.minWidth,
    this.height,
    this.enableFeedback = true,
    this.child,
  }) : assert(elevation == null || elevation >= 0.0),
       assert(focusElevation == null || focusElevation >= 0.0),
       assert(hoverElevation == null || hoverElevation >= 0.0),
       assert(highlightElevation == null || highlightElevation >= 0.0),
       assert(disabledElevation == null || disabledElevation >= 0.0);

  final VoidCallback? onPressed;

  final VoidCallback? onLongPress;

  final ValueChanged<bool>? onHighlightChanged;

  final MouseCursor? mouseCursor;

  final ButtonTextTheme? textTheme;

  final Color? textColor;

  final Color? disabledTextColor;

  final Color? color;

  final Color? disabledColor;

  final Color? splashColor;

  final Color? focusColor;

  final Color? hoverColor;

  final Color? highlightColor;

  final double? elevation;

  final double? hoverElevation;

  final double? focusElevation;

  final double? highlightElevation;

  final double? disabledElevation;

  final Brightness? colorBrightness;

  final Widget? child;

  bool get enabled => onPressed != null || onLongPress != null;

  final EdgeInsetsGeometry? padding;

  final VisualDensity? visualDensity;

  final ShapeBorder? shape;

  final Clip clipBehavior;

  final FocusNode? focusNode;

  final bool autofocus;

  final Duration? animationDuration;

  final MaterialTapTargetSize? materialTapTargetSize;

  final double? minWidth;

  final double? height;

  final bool enableFeedback;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ButtonThemeData buttonTheme = ButtonTheme.of(context);

    return RawMaterialButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      enableFeedback: enableFeedback,
      onHighlightChanged: onHighlightChanged,
      mouseCursor: mouseCursor,
      fillColor: buttonTheme.getFillColor(this),
      textStyle: theme.textTheme.labelLarge!.copyWith(color: buttonTheme.getTextColor(this)),
      focusColor: focusColor ?? buttonTheme.getFocusColor(this),
      hoverColor: hoverColor ?? buttonTheme.getHoverColor(this),
      highlightColor: highlightColor ?? theme.highlightColor,
      splashColor: splashColor ?? theme.splashColor,
      elevation: buttonTheme.getElevation(this),
      focusElevation: buttonTheme.getFocusElevation(this),
      hoverElevation: buttonTheme.getHoverElevation(this),
      highlightElevation: buttonTheme.getHighlightElevation(this),
      padding: buttonTheme.getPadding(this),
      visualDensity: visualDensity ?? theme.visualDensity,
      constraints: buttonTheme.getConstraints(this).copyWith(
        minWidth: minWidth,
        minHeight: height,
      ),
      shape: buttonTheme.getShape(this),
      clipBehavior: clipBehavior,
      focusNode: focusNode,
      autofocus: autofocus,
      animationDuration: buttonTheme.getAnimationDuration(this),
      materialTapTargetSize: materialTapTargetSize ?? theme.materialTapTargetSize,
      disabledElevation: disabledElevation ?? 0.0,
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(DiagnosticsProperty<ButtonTextTheme>('textTheme', textTheme, defaultValue: null));
    properties.add(ColorProperty('textColor', textColor, defaultValue: null));
    properties.add(ColorProperty('disabledTextColor', disabledTextColor, defaultValue: null));
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(ColorProperty('disabledColor', disabledColor, defaultValue: null));
    properties.add(ColorProperty('focusColor', focusColor, defaultValue: null));
    properties.add(ColorProperty('hoverColor', hoverColor, defaultValue: null));
    properties.add(ColorProperty('highlightColor', highlightColor, defaultValue: null));
    properties.add(ColorProperty('splashColor', splashColor, defaultValue: null));
    properties.add(DiagnosticsProperty<Brightness>('colorBrightness', colorBrightness, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialTapTargetSize>('materialTapTargetSize', materialTapTargetSize, defaultValue: null));
  }
}