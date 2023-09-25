// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'color_scheme.dart';
import 'colors.dart';
import 'constants.dart';
import 'debug.dart';
import 'material_state.dart';
import 'radio_theme.dart';
import 'theme.dart';
import 'theme_data.dart';
import 'toggleable.dart';

// Examples can assume:
// late BuildContext context;
// enum SingingCharacter { lafayette }
// late SingingCharacter? _character;
// late StateSetter setState;

enum _RadioType { material, adaptive }

const double _kOuterRadius = 8.0;
const double _kInnerRadius = 4.5;

class Radio<T> extends StatefulWidget {
  const Radio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.mouseCursor,
    this.toggleable = false,
    this.activeColor,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
  }) : _radioType = _RadioType.material,
       useCupertinoCheckmarkStyle = false;

  const Radio.adaptive({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.mouseCursor,
    this.toggleable = false,
    this.activeColor,
    this.fillColor,
    this.focusColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.useCupertinoCheckmarkStyle = false
  }) : _radioType = _RadioType.adaptive;

  final T value;

  final T? groupValue;

  final ValueChanged<T?>? onChanged;

  final MouseCursor? mouseCursor;

  final bool toggleable;

  final Color? activeColor;

  final MaterialStateProperty<Color?>? fillColor;

  final MaterialTapTargetSize? materialTapTargetSize;

  final VisualDensity? visualDensity;

  final Color? focusColor;

  final Color? hoverColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final FocusNode? focusNode;

  final bool autofocus;

  final bool useCupertinoCheckmarkStyle;

  final _RadioType _radioType;

  bool get _selected => value == groupValue;

  @override
  State<Radio<T>> createState() => _RadioState<T>();
}

class _RadioState<T> extends State<Radio<T>> with TickerProviderStateMixin, ToggleableStateMixin {
  final _RadioPainter _painter = _RadioPainter();

  void _handleChanged(bool? selected) {
    if (selected == null) {
      widget.onChanged!(null);
      return;
    }
    if (selected) {
      widget.onChanged!(widget.value);
    }
  }

  @override
  void didUpdateWidget(Radio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._selected != oldWidget._selected) {
      animateToValue();
    }
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  @override
  ValueChanged<bool?>? get onChanged => widget.onChanged != null ? _handleChanged : null;

  @override
  bool get tristate => widget.toggleable;

  @override
  bool? get value => widget._selected;

  MaterialStateProperty<Color?> get _widgetFillColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return null;
      }
      if (states.contains(MaterialState.selected)) {
        return widget.activeColor;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    switch (widget._radioType) {
      case _RadioType.material:
        break;

      case _RadioType.adaptive:
        final ThemeData theme = Theme.of(context);
        switch (theme.platform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            break;
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            return CupertinoRadio<T>(
              value: widget.value,
              groupValue: widget.groupValue,
              onChanged: widget.onChanged,
              toggleable: widget.toggleable,
              activeColor: widget.activeColor,
              focusColor: widget.focusColor,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              useCheckmarkStyle: widget.useCupertinoCheckmarkStyle,
            );
        }
    }

    final RadioThemeData radioTheme = RadioTheme.of(context);
    final RadioThemeData defaults = Theme.of(context).useMaterial3 ? _RadioDefaultsM3(context) : _RadioDefaultsM2(context);
    final MaterialTapTargetSize effectiveMaterialTapTargetSize = widget.materialTapTargetSize
      ?? radioTheme.materialTapTargetSize
      ?? defaults.materialTapTargetSize!;
    final VisualDensity effectiveVisualDensity = widget.visualDensity
      ?? radioTheme.visualDensity
      ?? defaults.visualDensity!;
    Size size;
    switch (effectiveMaterialTapTargetSize) {
      case MaterialTapTargetSize.padded:
        size = const Size(kMinInteractiveDimension, kMinInteractiveDimension);
      case MaterialTapTargetSize.shrinkWrap:
        size = const Size(kMinInteractiveDimension - 8.0, kMinInteractiveDimension - 8.0);
    }
    size += effectiveVisualDensity.baseSizeAdjustment;

    final MaterialStateProperty<MouseCursor> effectiveMouseCursor = MaterialStateProperty.resolveWith<MouseCursor>((Set<MaterialState> states) {
      return MaterialStateProperty.resolveAs<MouseCursor?>(widget.mouseCursor, states)
        ?? radioTheme.mouseCursor?.resolve(states)
        ?? MaterialStateProperty.resolveAs<MouseCursor>(MaterialStateMouseCursor.clickable, states);
    });

    // Colors need to be resolved in selected and non selected states separately
    // so that they can be lerped between.
    final Set<MaterialState> activeStates = states..add(MaterialState.selected);
    final Set<MaterialState> inactiveStates = states..remove(MaterialState.selected);
    final Color? activeColor = widget.fillColor?.resolve(activeStates)
      ?? _widgetFillColor.resolve(activeStates)
      ?? radioTheme.fillColor?.resolve(activeStates);
    final Color effectiveActiveColor = activeColor ?? defaults.fillColor!.resolve(activeStates)!;
    final Color? inactiveColor = widget.fillColor?.resolve(inactiveStates)
      ?? _widgetFillColor.resolve(inactiveStates)
      ?? radioTheme.fillColor?.resolve(inactiveStates);
    final Color effectiveInactiveColor = inactiveColor ?? defaults.fillColor!.resolve(inactiveStates)!;

    final Set<MaterialState> focusedStates = states..add(MaterialState.focused);
    Color effectiveFocusOverlayColor = widget.overlayColor?.resolve(focusedStates)
      ?? widget.focusColor
      ?? radioTheme.overlayColor?.resolve(focusedStates)
      ?? defaults.overlayColor!.resolve(focusedStates)!;

    final Set<MaterialState> hoveredStates = states..add(MaterialState.hovered);
    Color effectiveHoverOverlayColor = widget.overlayColor?.resolve(hoveredStates)
      ?? widget.hoverColor
      ?? radioTheme.overlayColor?.resolve(hoveredStates)
      ?? defaults.overlayColor!.resolve(hoveredStates)!;

    final Set<MaterialState> activePressedStates = activeStates..add(MaterialState.pressed);
    final Color effectiveActivePressedOverlayColor = widget.overlayColor?.resolve(activePressedStates)
      ?? radioTheme.overlayColor?.resolve(activePressedStates)
      ?? activeColor?.withAlpha(kRadialReactionAlpha)
      ?? defaults.overlayColor!.resolve(activePressedStates)!;

    final Set<MaterialState> inactivePressedStates = inactiveStates..add(MaterialState.pressed);
    final Color effectiveInactivePressedOverlayColor = widget.overlayColor?.resolve(inactivePressedStates)
      ?? radioTheme.overlayColor?.resolve(inactivePressedStates)
      ?? inactiveColor?.withAlpha(kRadialReactionAlpha)
      ?? defaults.overlayColor!.resolve(inactivePressedStates)!;

    if (downPosition != null) {
      effectiveHoverOverlayColor = states.contains(MaterialState.selected)
        ? effectiveActivePressedOverlayColor
        : effectiveInactivePressedOverlayColor;
      effectiveFocusOverlayColor = states.contains(MaterialState.selected)
        ? effectiveActivePressedOverlayColor
        : effectiveInactivePressedOverlayColor;
    }
    final bool? accessibilitySelected;
    // Apple devices also use `selected` to annotate radio button's semantics
    // state.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        accessibilitySelected = null;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        accessibilitySelected = widget._selected;
    }

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: widget._selected,
      selected: accessibilitySelected,
      child: buildToggleable(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: effectiveMouseCursor,
        size: size,
        painter: _painter
          ..position = position
          ..reaction = reaction
          ..reactionFocusFade = reactionFocusFade
          ..reactionHoverFade = reactionHoverFade
          ..inactiveReactionColor = effectiveInactivePressedOverlayColor
          ..reactionColor = effectiveActivePressedOverlayColor
          ..hoverColor = effectiveHoverOverlayColor
          ..focusColor = effectiveFocusOverlayColor
          ..splashRadius = widget.splashRadius ?? radioTheme.splashRadius ?? kRadialReactionRadius
          ..downPosition = downPosition
          ..isFocused = states.contains(MaterialState.focused)
          ..isHovered = states.contains(MaterialState.hovered)
          ..activeColor = effectiveActiveColor
          ..inactiveColor = effectiveInactiveColor,
      ),
    );
  }
}

class _RadioPainter extends ToggleablePainter {
  @override
  void paint(Canvas canvas, Size size) {
    paintRadialReaction(canvas: canvas, origin: size.center(Offset.zero));

    final Offset center = (Offset.zero & size).center;

    // Outer circle
    final Paint paint = Paint()
      ..color = Color.lerp(inactiveColor, activeColor, position.value)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, _kOuterRadius, paint);

    // Inner circle
    if (!position.isDismissed) {
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(center, _kInnerRadius * position.value, paint);
    }
  }
}

// Hand coded defaults based on Material Design 2.
class _RadioDefaultsM2 extends RadioThemeData {
  _RadioDefaultsM2(this.context);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;

  @override
  MaterialStateProperty<Color> get fillColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return _theme.disabledColor;
      }
      if (states.contains(MaterialState.selected)) {
        return _colors.secondary;
      }
      return _theme.unselectedWidgetColor;
    });
  }

  @override
  MaterialStateProperty<Color> get overlayColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) {
        return fillColor.resolve(states).withAlpha(kRadialReactionAlpha);
      }
      if (states.contains(MaterialState.hovered)) {
        return _theme.hoverColor;
      }
      if (states.contains(MaterialState.focused)) {
        return _theme.focusColor;
      }
      return Colors.transparent;
    });
  }

  @override
  MaterialTapTargetSize get materialTapTargetSize => _theme.materialTapTargetSize;

  @override
  VisualDensity get visualDensity => _theme.visualDensity;
}

// BEGIN GENERATED TOKEN PROPERTIES - Radio<T>

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _RadioDefaultsM3 extends RadioThemeData {
  _RadioDefaultsM3(this.context);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;

  @override
  MaterialStateProperty<Color> get fillColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.disabled)) {
          return _colors.onSurface.withOpacity(0.38);
        }
        if (states.contains(MaterialState.pressed)) {
          return _colors.primary;
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.primary;
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.primary;
        }
        return _colors.primary;
      }
      if (states.contains(MaterialState.disabled)) {
        return _colors.onSurface.withOpacity(0.38);
      }
      if (states.contains(MaterialState.pressed)) {
        return _colors.onSurface;
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onSurface;
      }
      if (states.contains(MaterialState.focused)) {
        return _colors.onSurface;
      }
      return _colors.onSurfaceVariant;
    });
  }

  @override
  MaterialStateProperty<Color> get overlayColor {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        if (states.contains(MaterialState.pressed)) {
          return _colors.onSurface.withOpacity(0.12);
        }
        if (states.contains(MaterialState.hovered)) {
          return _colors.primary.withOpacity(0.08);
        }
        if (states.contains(MaterialState.focused)) {
          return _colors.primary.withOpacity(0.12);
        }
        return Colors.transparent;
      }
      if (states.contains(MaterialState.pressed)) {
        return _colors.primary.withOpacity(0.12);
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onSurface.withOpacity(0.08);
      }
      if (states.contains(MaterialState.focused)) {
        return _colors.onSurface.withOpacity(0.12);
      }
      return Colors.transparent;
    });
  }

  @override
  MaterialTapTargetSize get materialTapTargetSize => _theme.materialTapTargetSize;

  @override
  VisualDensity get visualDensity => _theme.visualDensity;
}

// END GENERATED TOKEN PROPERTIES - Radio<T>