// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'badge_theme.dart';
import 'color_scheme.dart';
import 'theme.dart';

class Badge extends StatelessWidget {
  const Badge({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.smallSize,
    this.largeSize,
    this.textStyle,
    this.padding,
    this.alignment,
    this.offset,
    this.label,
    this.isLabelVisible = true,
    this.child,
  });

  Badge.count({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.smallSize,
    this.largeSize,
    this.textStyle,
    this.padding,
    this.alignment,
    this.offset,
    required int count,
    this.isLabelVisible = true,
    this.child,
  }) : label = Text(count > 999 ? '999+' : '$count');

  final Color? backgroundColor;

  final Color? textColor;

  final double? smallSize;

  final double? largeSize;

  final TextStyle? textStyle;

  final EdgeInsetsGeometry? padding;

  final AlignmentGeometry? alignment;

  final Offset? offset;

  final Widget? label;

  final bool isLabelVisible;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!isLabelVisible) {
      return child ?? const SizedBox();
    }

    final BadgeThemeData badgeTheme = BadgeTheme.of(context);
    final BadgeThemeData defaults = _BadgeDefaultsM3(context);
    final double effectiveSmallSize = smallSize ?? badgeTheme.smallSize ?? defaults.smallSize!;
    final double effectiveLargeSize = largeSize ?? badgeTheme.largeSize ?? defaults.largeSize!;

    final Widget badge = DefaultTextStyle(
      style: (textStyle ?? badgeTheme.textStyle ?? defaults.textStyle!).copyWith(
        color: textColor ?? badgeTheme.textColor ?? defaults.textColor!,
      ),
      child: IntrinsicWidth(
        child: Container(
          height: label == null ? effectiveSmallSize : effectiveLargeSize,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: backgroundColor ?? badgeTheme.backgroundColor ?? defaults.backgroundColor!,
            shape: const StadiumBorder(),
          ),
          padding: label == null ? null : (padding ?? badgeTheme.padding ?? defaults.padding!),
          alignment: label == null ? null : Alignment.center,
          child: label ?? SizedBox(width: effectiveSmallSize, height: effectiveSmallSize),
        ),
      ),
    );

    if (child == null) {
      return badge;
    }

    final AlignmentGeometry effectiveAlignment = alignment ?? badgeTheme.alignment ?? defaults.alignment!;
    final TextDirection textDirection = Directionality.of(context);
    final Offset defaultOffset = textDirection == TextDirection.ltr ? const Offset(4, -4) : const Offset(-4, -4);
    final Offset effectiveOffset = offset ?? badgeTheme.offset ?? defaultOffset;

    return
      Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          child!,
          Positioned.fill(
            child: _Badge(
              alignment: effectiveAlignment,
              offset: label == null ? Offset.zero : effectiveOffset,
              textDirection: textDirection,
              child: badge,
            ),
          ),
        ],
      );
  }
}

class _Badge extends SingleChildRenderObjectWidget {
  const _Badge({
    required this.alignment,
    required this.offset,
    required this.textDirection,
    super.child, // the badge
  });

  final AlignmentGeometry alignment;
  final Offset offset;
  final TextDirection textDirection;

  @override
  _RenderBadge createRenderObject(BuildContext context) {
    return _RenderBadge(
      alignment: alignment,
      offset: offset,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBadge renderObject) {
    renderObject
      ..alignment = alignment
      ..offset = offset
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
  }
}

class _RenderBadge extends RenderAligningShiftedBox {
  _RenderBadge({
    super.textDirection,
    super.alignment,
    required Offset offset,
  }) : _offset = offset;

  Offset get offset => _offset;
  Offset _offset;
  set offset(Offset value) {
    if (_offset == value) {
      return;
    }
    _offset = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    assert(constraints.hasBoundedWidth);
    assert(constraints.hasBoundedHeight);
    size = constraints.biggest;

    child!.layout(const BoxConstraints(), parentUsesSize: true);
    final double badgeSize = child!.size.height;
    final Alignment resolvedAlignment = alignment.resolve(textDirection);
    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    childParentData.offset = offset + resolvedAlignment.alongOffset(Offset(size.width - badgeSize, size.height - badgeSize));
  }
}


// BEGIN GENERATED TOKEN PROPERTIES - Badge

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _BadgeDefaultsM3 extends BadgeThemeData {
  _BadgeDefaultsM3(this.context) : super(
    smallSize: 6.0,
    largeSize: 16.0,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: AlignmentDirectional.topEnd,
  );

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _colors = _theme.colorScheme;

  @override
  Color? get backgroundColor => _colors.error;

  @override
  Color? get textColor => _colors.onError;

  @override
  TextStyle? get textStyle => Theme.of(context).textTheme.labelSmall;
}

// END GENERATED TOKEN PROPERTIES - Badge