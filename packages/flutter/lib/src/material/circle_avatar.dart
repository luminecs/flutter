// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'constants.dart';
import 'theme.dart';

// Examples can assume:
// late String userAvatarUrl;

class CircleAvatar extends StatelessWidget {
  const CircleAvatar({
    super.key,
    this.child,
    this.backgroundColor,
    this.backgroundImage,
    this.foregroundImage,
    this.onBackgroundImageError,
    this.onForegroundImageError,
    this.foregroundColor,
    this.radius,
    this.minRadius,
    this.maxRadius,
  }) : assert(radius == null || (minRadius == null && maxRadius == null)),
       assert(backgroundImage != null || onBackgroundImageError == null),
       assert(foregroundImage != null || onForegroundImageError== null);

  final Widget? child;

  final Color? backgroundColor;

  final Color? foregroundColor;

  final ImageProvider? backgroundImage;

  final ImageProvider? foregroundImage;

  final ImageErrorListener? onBackgroundImageError;

  final ImageErrorListener? onForegroundImageError;

  final double? radius;

  final double? minRadius;

  final double? maxRadius;

  // The default radius if nothing is specified.
  static const double _defaultRadius = 20.0;

  // The default min if only the max is specified.
  static const double _defaultMinRadius = 0.0;

  // The default max if only the min is specified.
  static const double _defaultMaxRadius = double.infinity;

  double get _minDiameter {
    if (radius == null && minRadius == null && maxRadius == null) {
      return _defaultRadius * 2.0;
    }
    return 2.0 * (radius ?? minRadius ?? _defaultMinRadius);
  }

  double get _maxDiameter {
    if (radius == null && minRadius == null && maxRadius == null) {
      return _defaultRadius * 2.0;
    }
    return 2.0 * (radius ?? maxRadius ?? _defaultMaxRadius);
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final ThemeData theme = Theme.of(context);
    final Color? effectiveForegroundColor = foregroundColor
      ?? (theme.useMaterial3 ? theme.colorScheme.onPrimaryContainer : null);
    final TextStyle effectiveTextStyle = theme.useMaterial3
      ? theme.textTheme.titleMedium!
      : theme.primaryTextTheme.titleMedium!;
    TextStyle textStyle = effectiveTextStyle.copyWith(color: effectiveForegroundColor);
    Color? effectiveBackgroundColor = backgroundColor
      ?? (theme.useMaterial3 ? theme.colorScheme.primaryContainer : null);
    if (effectiveBackgroundColor == null) {
      switch (ThemeData.estimateBrightnessForColor(textStyle.color!)) {
        case Brightness.dark:
          effectiveBackgroundColor = theme.primaryColorLight;
        case Brightness.light:
          effectiveBackgroundColor = theme.primaryColorDark;
      }
    } else if (effectiveForegroundColor == null) {
      switch (ThemeData.estimateBrightnessForColor(backgroundColor!)) {
        case Brightness.dark:
          textStyle = textStyle.copyWith(color: theme.primaryColorLight);
        case Brightness.light:
          textStyle = textStyle.copyWith(color: theme.primaryColorDark);
      }
    }
    final double minDiameter = _minDiameter;
    final double maxDiameter = _maxDiameter;
    return AnimatedContainer(
      constraints: BoxConstraints(
        minHeight: minDiameter,
        minWidth: minDiameter,
        maxWidth: maxDiameter,
        maxHeight: maxDiameter,
      ),
      duration: kThemeChangeDuration,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        image: backgroundImage != null
          ? DecorationImage(
              image: backgroundImage!,
              onError: onBackgroundImageError,
              fit: BoxFit.cover,
            )
          : null,
        shape: BoxShape.circle,
      ),
      foregroundDecoration: foregroundImage != null
          ? BoxDecoration(
              image: DecorationImage(
                image: foregroundImage!,
                onError: onForegroundImageError,
                fit: BoxFit.cover,
              ),
              shape: BoxShape.circle,
            )
          : null,
      child: child == null
          ? null
          : Center(
              // Need to disable text scaling here so that the text doesn't
              // escape the avatar when the textScaleFactor is large.
              child: MediaQuery.withNoTextScaling(
                child: IconTheme(
                  data: theme.iconTheme.copyWith(color: textStyle.color),
                  child: DefaultTextStyle(
                    style: textStyle,
                    child: child!,
                  ),
                ),
              ),
            ),
    );
  }
}