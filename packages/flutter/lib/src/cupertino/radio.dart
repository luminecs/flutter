// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'toggleable.dart';

// Examples can assume:
// late BuildContext context;
// enum SingingCharacter { lafayette }
// late SingingCharacter? _character;
// late StateSetter setState;

const Size _size = Size(18.0, 18.0);
const double _kOuterRadius = 7.0;
const double _kInnerRadius = 2.975;

// The relative values needed to transform a color to its equivilant focus
// outline color.
const double _kCupertinoFocusColorOpacity = 0.80;
const double _kCupertinoFocusColorBrightness = 0.69;
const double _kCupertinoFocusColorSaturation = 0.835;

class CupertinoRadio<T> extends StatefulWidget {
  const CupertinoRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.toggleable = false,
    this.activeColor,
    this.inactiveColor,
    this.fillColor,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.useCheckmarkStyle = false,
  });

  final T value;

  final T? groupValue;

  final ValueChanged<T?>? onChanged;

  final bool toggleable;

  final bool useCheckmarkStyle;

  final Color? activeColor;

  final Color? inactiveColor;

  final Color? fillColor;

  final Color? focusColor;

  final FocusNode? focusNode;

  final bool autofocus;

  bool get _selected => value == groupValue;

  @override
  State<CupertinoRadio<T>> createState() => _CupertinoRadioState<T>();
}

class _CupertinoRadioState<T> extends State<CupertinoRadio<T>> with TickerProviderStateMixin, ToggleableStateMixin {
  final _RadioPainter _painter = _RadioPainter();

  bool focused = false;

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

  void onFocusChange(bool value) {
    if (focused != value) {
      focused = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveActiveColor = widget.activeColor
      ?? CupertinoColors.activeBlue;
    final Color effectiveInactiveColor = widget.inactiveColor
      ?? CupertinoColors.white;

    final Color effectiveFocusOverlayColor = widget.focusColor
      ?? HSLColor
          .fromColor(effectiveActiveColor.withOpacity(_kCupertinoFocusColorOpacity))
          .withLightness(_kCupertinoFocusColorBrightness)
          .withSaturation(_kCupertinoFocusColorSaturation)
          .toColor();

    final Color effectiveActivePressedOverlayColor =
      HSLColor.fromColor(effectiveActiveColor).withLightness(0.45).toColor();

    final Color effectiveFillColor = widget.fillColor ?? CupertinoColors.white;

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
        onFocusChange: onFocusChange,
        size: _size,
        painter: _painter
          ..focusColor = effectiveFocusOverlayColor
          ..downPosition = downPosition
          ..isFocused = focused
          ..activeColor = downPosition != null ? effectiveActivePressedOverlayColor : effectiveActiveColor
          ..inactiveColor = effectiveInactiveColor
          ..fillColor = effectiveFillColor
          ..value = value
          ..checkmarkStyle = widget.useCheckmarkStyle,
      ),
    );
  }
}

class _RadioPainter extends ToggleablePainter {
  bool? get value => _value;
  bool? _value;
  set value(bool? value) {
    if (_value == value) {
      return;
    }
    _value = value;
    notifyListeners();
  }

  Color get fillColor => _fillColor!;
  Color? _fillColor;
  set fillColor(Color value) {
    if (value == _fillColor) {
      return;
    }
    _fillColor = value;
    notifyListeners();
  }

  bool get checkmarkStyle => _checkmarkStyle;
  bool _checkmarkStyle = false;
  set checkmarkStyle(bool value) {
    if (value == _checkmarkStyle) {
      return;
    }
    _checkmarkStyle = value;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size) {

    final Offset center = (Offset.zero & size).center;

    final Paint paint = Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.fill
        ..strokeWidth = 0.1;

    if (checkmarkStyle) {
      if (value ?? false) {
        final Path path = Path();
        final Paint checkPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        final double width = _size.width;
        final Offset origin = Offset(center.dx - (width/2), center.dy - (width/2));
        final Offset start = Offset(width * 0.25, width * 0.52);
        final Offset mid = Offset(width * 0.46, width * 0.75);
        final Offset end = Offset(width * 0.85, width * 0.29);
        path.moveTo(origin.dx + start.dx, origin.dy + start.dy);
        path.lineTo(origin.dx + mid.dx, origin.dy + mid.dy);
        canvas.drawPath(path, checkPaint);
        path.moveTo(origin.dx + mid.dx, origin.dy + mid.dy);
        path.lineTo(origin.dx + end.dx, origin.dy + end.dy);
        canvas.drawPath(path, checkPaint);
      }
    } else {
      // Outer border
      canvas.drawCircle(center, _kOuterRadius, paint);

      paint.style = PaintingStyle.stroke;
      paint.color = CupertinoColors.inactiveGray;
      canvas.drawCircle(center, _kOuterRadius, paint);

      if (value ?? false) {
        paint.style = PaintingStyle.fill;
        paint.color = activeColor;
        canvas.drawCircle(center, _kOuterRadius, paint);
        paint.color = fillColor;
        canvas.drawCircle(center, _kInnerRadius, paint);
      }
    }

    if (isFocused) {
      paint.style = PaintingStyle.stroke;
      paint.color = focusColor;
      paint.strokeWidth = 3.0;
      canvas.drawCircle(center, _kOuterRadius + 1.5, paint);
    }
  }
}