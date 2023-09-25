// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'color_scheme.dart';
import 'material.dart';
import 'progress_indicator_theme.dart';
import 'theme.dart';

const double _kMinCircularProgressIndicatorSize = 36.0;
const int _kIndeterminateLinearDuration = 1800;
const int _kIndeterminateCircularDuration = 1333 * 2222;

enum _ActivityIndicatorType { material, adaptive }

abstract class ProgressIndicator extends StatefulWidget {
  const ProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;

  final Color? backgroundColor;

  final Color? color;

  final Animation<Color?>? valueColor;

  final String? semanticsLabel;

  final String? semanticsValue;

  Color _getValueColor(BuildContext context, {Color? defaultColor}) {
    return valueColor?.value ??
      color ??
      ProgressIndicatorTheme.of(context).color ??
      defaultColor ??
      Theme.of(context).colorScheme.primary;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(PercentProperty('value', value, showName: false, ifNull: '<indeterminate>'));
  }

  Widget _buildSemanticsWrapper({
    required BuildContext context,
    required Widget child,
  }) {
    String? expandedSemanticsValue = semanticsValue;
    if (value != null) {
      expandedSemanticsValue ??= '${(value! * 100).round()}%';
    }
    return Semantics(
      label: semanticsLabel,
      value: expandedSemanticsValue,
      child: child,
    );
  }
}

class _LinearProgressIndicatorPainter extends CustomPainter {
  const _LinearProgressIndicatorPainter({
    required this.backgroundColor,
    required this.valueColor,
    this.value,
    required this.animationValue,
    required this.textDirection,
    required this.indicatorBorderRadius,
  });

  final Color backgroundColor;
  final Color valueColor;
  final double? value;
  final double animationValue;
  final TextDirection textDirection;
  final BorderRadiusGeometry indicatorBorderRadius;

  // The indeterminate progress animation displays two lines whose leading (head)
  // and trailing (tail) endpoints are defined by the following four curves.
  static const Curve line1Head = Interval(
    0.0,
    750.0 / _kIndeterminateLinearDuration,
    curve: Cubic(0.2, 0.0, 0.8, 1.0),
  );
  static const Curve line1Tail = Interval(
    333.0 / _kIndeterminateLinearDuration,
    (333.0 + 750.0) / _kIndeterminateLinearDuration,
    curve: Cubic(0.4, 0.0, 1.0, 1.0),
  );
  static const Curve line2Head = Interval(
    1000.0 / _kIndeterminateLinearDuration,
    (1000.0 + 567.0) / _kIndeterminateLinearDuration,
    curve: Cubic(0.0, 0.0, 0.65, 1.0),
  );
  static const Curve line2Tail = Interval(
    1267.0 / _kIndeterminateLinearDuration,
    (1267.0 + 533.0) / _kIndeterminateLinearDuration,
    curve: Cubic(0.10, 0.0, 0.45, 1.0),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    paint.color = valueColor;

    void drawBar(double x, double width) {
      if (width <= 0.0) {
        return;
      }

      final double left;
      switch (textDirection) {
        case TextDirection.rtl:
          left = size.width - width - x;
        case TextDirection.ltr:
          left = x;
      }

      final Rect rect = Offset(left, 0.0) & Size(width, size.height);
      if (indicatorBorderRadius != BorderRadius.zero) {
        final RRect rrect = indicatorBorderRadius.resolve(textDirection).toRRect(rect);
        canvas.drawRRect(rrect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }
    }

    if (value != null) {
      drawBar(0.0, clampDouble(value!, 0.0, 1.0) * size.width);
    } else {
      final double x1 = size.width * line1Tail.transform(animationValue);
      final double width1 = size.width * line1Head.transform(animationValue) - x1;

      final double x2 = size.width * line2Tail.transform(animationValue);
      final double width2 = size.width * line2Head.transform(animationValue) - x2;

      drawBar(x1, width1);
      drawBar(x2, width2);
    }
  }

  @override
  bool shouldRepaint(_LinearProgressIndicatorPainter oldPainter) {
    return oldPainter.backgroundColor != backgroundColor
        || oldPainter.valueColor != valueColor
        || oldPainter.value != value
        || oldPainter.animationValue != animationValue
        || oldPainter.textDirection != textDirection
        || oldPainter.indicatorBorderRadius != indicatorBorderRadius;
  }
}

class LinearProgressIndicator extends ProgressIndicator {
  const LinearProgressIndicator({
    super.key,
    super.value,
    super.backgroundColor,
    super.color,
    super.valueColor,
    this.minHeight,
    super.semanticsLabel,
    super.semanticsValue,
    this.borderRadius = BorderRadius.zero,
  }) : assert(minHeight == null || minHeight > 0);

  @override
  Color? get backgroundColor => super.backgroundColor;

  final double? minHeight;

  final BorderRadiusGeometry borderRadius;

  @override
  State<LinearProgressIndicator> createState() => _LinearProgressIndicatorState();
}

class _LinearProgressIndicatorState extends State<LinearProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _kIndeterminateLinearDuration),
      vsync: this,
    );
    if (widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(LinearProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildIndicator(BuildContext context, double animationValue, TextDirection textDirection) {
    final ProgressIndicatorThemeData defaults = Theme.of(context).useMaterial3
      ? _LinearProgressIndicatorDefaultsM3(context)
      : _LinearProgressIndicatorDefaultsM2(context);

    final ProgressIndicatorThemeData indicatorTheme = ProgressIndicatorTheme.of(context);
    final Color trackColor = widget.backgroundColor ??
      indicatorTheme.linearTrackColor ??
      defaults.linearTrackColor!;
    final double minHeight = widget.minHeight ??
      indicatorTheme.linearMinHeight ??
      defaults.linearMinHeight!;

    return widget._buildSemanticsWrapper(
      context: context,
      child: Container(
        // Clip is only needed with indeterminate progress indicators
        clipBehavior: (widget.borderRadius != BorderRadius.zero && widget.value == null)
            ? Clip.antiAlias
            : Clip.none,
        decoration: ShapeDecoration(
          color: trackColor,
          shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
        ),
        constraints: BoxConstraints(
          minWidth: double.infinity,
          minHeight: minHeight,
        ),
        child: CustomPaint(
          painter: _LinearProgressIndicatorPainter(
            backgroundColor: trackColor,
            valueColor: widget._getValueColor(context, defaultColor: defaults.color),
            value: widget.value, // may be null
            animationValue: animationValue, // ignored if widget.value is not null
            textDirection: textDirection,
            indicatorBorderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);

    if (widget.value != null) {
      return _buildIndicator(context, _controller.value, textDirection);
    }

    return AnimatedBuilder(
      animation: _controller.view,
      builder: (BuildContext context, Widget? child) {
        return _buildIndicator(context, _controller.value, textDirection);
      },
    );
  }
}

class _CircularProgressIndicatorPainter extends CustomPainter {
  _CircularProgressIndicatorPainter({
    this.backgroundColor,
    required this.valueColor,
    required this.value,
    required this.headValue,
    required this.tailValue,
    required this.offsetValue,
    required this.rotationValue,
    required this.strokeWidth,
    required this.strokeAlign,
    this.strokeCap,
  }) : arcStart = value != null
         ? _startAngle
         : _startAngle + tailValue * 3 / 2 * math.pi + rotationValue * math.pi * 2.0 + offsetValue * 0.5 * math.pi,
       arcSweep = value != null
         ? clampDouble(value, 0.0, 1.0) * _sweep
         : math.max(headValue * 3 / 2 * math.pi - tailValue * 3 / 2 * math.pi, _epsilon);

  final Color? backgroundColor;
  final Color valueColor;
  final double? value;
  final double headValue;
  final double tailValue;
  final double offsetValue;
  final double rotationValue;
  final double strokeWidth;
  final double strokeAlign;
  final double arcStart;
  final double arcSweep;
  final StrokeCap? strokeCap;

  static const double _twoPi = math.pi * 2.0;
  static const double _epsilon = .001;
  // Canvas.drawArc(r, 0, 2*PI) doesn't draw anything, so just get close.
  static const double _sweep = _twoPi - _epsilon;
  static const double _startAngle = -math.pi / 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = valueColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Use the negative operator as intended to keep the exposed constant value
    // as users are already familiar with.
    final double strokeOffset = strokeWidth / 2 * -strokeAlign;
    final Offset arcBaseOffset = Offset(strokeOffset, strokeOffset);
    final Size arcActualSize = Size(
      size.width - strokeOffset * 2,
      size.height - strokeOffset * 2,
    );

    if (backgroundColor != null) {
      final Paint backgroundPaint = Paint()
        ..color = backgroundColor!
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        arcBaseOffset & arcActualSize,
        0,
        _sweep,
        false,
        backgroundPaint,
      );
    }

    if (value == null && strokeCap == null) {
      // Indeterminate
      paint.strokeCap = StrokeCap.square;
    } else {
      // Butt when determinate (value != null) && strokeCap == null;
      paint.strokeCap = strokeCap ?? StrokeCap.butt;
    }

    canvas.drawArc(
      arcBaseOffset & arcActualSize,
      arcStart,
      arcSweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressIndicatorPainter oldPainter) {
    return oldPainter.backgroundColor != backgroundColor
        || oldPainter.valueColor != valueColor
        || oldPainter.value != value
        || oldPainter.headValue != headValue
        || oldPainter.tailValue != tailValue
        || oldPainter.offsetValue != offsetValue
        || oldPainter.rotationValue != rotationValue
        || oldPainter.strokeWidth != strokeWidth
        || oldPainter.strokeAlign != strokeAlign
        || oldPainter.strokeCap != strokeCap;
  }
}

class CircularProgressIndicator extends ProgressIndicator {
  const CircularProgressIndicator({
    super.key,
    super.value,
    super.backgroundColor,
    super.color,
    super.valueColor,
    this.strokeWidth = 4.0,
    this.strokeAlign = strokeAlignCenter,
    super.semanticsLabel,
    super.semanticsValue,
    this.strokeCap,
  }) : _indicatorType = _ActivityIndicatorType.material;

  const CircularProgressIndicator.adaptive({
    super.key,
    super.value,
    super.backgroundColor,
    super.valueColor,
    this.strokeWidth = 4.0,
    super.semanticsLabel,
    super.semanticsValue,
    this.strokeCap,
    this.strokeAlign = strokeAlignCenter,
  }) : _indicatorType = _ActivityIndicatorType.adaptive;

  final _ActivityIndicatorType _indicatorType;

  @override
  Color? get backgroundColor => super.backgroundColor;

  final double strokeWidth;

  final double strokeAlign;

  final StrokeCap? strokeCap;

  static const double strokeAlignInside = -1.0;

  static const double strokeAlignCenter = 0.0;

  static const double strokeAlignOutside = 1.0;

  @override
  State<CircularProgressIndicator> createState() => _CircularProgressIndicatorState();
}

class _CircularProgressIndicatorState extends State<CircularProgressIndicator> with SingleTickerProviderStateMixin {
  static const int _pathCount = _kIndeterminateCircularDuration ~/ 1333;
  static const int _rotationCount = _kIndeterminateCircularDuration ~/ 2222;

  static final Animatable<double> _strokeHeadTween = CurveTween(
    curve: const Interval(0.0, 0.5, curve: Curves.fastOutSlowIn),
  ).chain(CurveTween(
    curve: const SawTooth(_pathCount),
  ));
  static final Animatable<double> _strokeTailTween = CurveTween(
    curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
  ).chain(CurveTween(
    curve: const SawTooth(_pathCount),
  ));
  static final Animatable<double> _offsetTween = CurveTween(curve: const SawTooth(_pathCount));
  static final Animatable<double> _rotationTween = CurveTween(curve: const SawTooth(_rotationCount));

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _kIndeterminateCircularDuration),
      vsync: this,
    );
    if (widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.value != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCupertinoIndicator(BuildContext context) {
    final Color? tickColor = widget.backgroundColor;
    return CupertinoActivityIndicator(key: widget.key, color: tickColor);
  }

  Widget _buildMaterialIndicator(BuildContext context, double headValue, double tailValue, double offsetValue, double rotationValue) {
    final ProgressIndicatorThemeData defaults = Theme.of(context).useMaterial3
      ? _CircularProgressIndicatorDefaultsM3(context)
      : _CircularProgressIndicatorDefaultsM2(context);
    final Color? trackColor = widget.backgroundColor ?? ProgressIndicatorTheme.of(context).circularTrackColor;

    return widget._buildSemanticsWrapper(
      context: context,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: _kMinCircularProgressIndicatorSize,
          minHeight: _kMinCircularProgressIndicatorSize,
        ),
        child: CustomPaint(
          painter: _CircularProgressIndicatorPainter(
            backgroundColor: trackColor,
            valueColor: widget._getValueColor(context, defaultColor: defaults.color),
            value: widget.value, // may be null
            headValue: headValue, // remaining arguments are ignored if widget.value is not null
            tailValue: tailValue,
            offsetValue: offsetValue,
            rotationValue: rotationValue,
            strokeWidth: widget.strokeWidth,
            strokeAlign: widget.strokeAlign,
            strokeCap: widget.strokeCap,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return _buildMaterialIndicator(
          context,
          _strokeHeadTween.evaluate(_controller),
          _strokeTailTween.evaluate(_controller),
          _offsetTween.evaluate(_controller),
          _rotationTween.evaluate(_controller),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget._indicatorType) {
      case _ActivityIndicatorType.material:
        if (widget.value != null) {
          return _buildMaterialIndicator(context, 0.0, 0.0, 0, 0.0);
        }
        return _buildAnimation();
      case _ActivityIndicatorType.adaptive:
        final ThemeData theme = Theme.of(context);
        switch (theme.platform) {
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            return _buildCupertinoIndicator(context);
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            if (widget.value != null) {
              return _buildMaterialIndicator(context, 0.0, 0.0, 0, 0.0);
            }
            return _buildAnimation();
        }
    }
  }
}

class _RefreshProgressIndicatorPainter extends _CircularProgressIndicatorPainter {
  _RefreshProgressIndicatorPainter({
    required super.valueColor,
    required super.value,
    required super.headValue,
    required super.tailValue,
    required super.offsetValue,
    required super.rotationValue,
    required super.strokeWidth,
    required super.strokeAlign,
    required this.arrowheadScale,
    required super.strokeCap,
  });

  final double arrowheadScale;

  void paintArrowhead(Canvas canvas, Size size) {
    // ux, uy: a unit vector whose direction parallels the base of the arrowhead.
    // (So ux, -uy points in the direction the arrowhead points.)
    final double arcEnd = arcStart + arcSweep;
    final double ux = math.cos(arcEnd);
    final double uy = math.sin(arcEnd);

    assert(size.width == size.height);
    final double radius = size.width / 2.0;
    final double arrowheadPointX = radius + ux * radius + -uy * strokeWidth * 2.0 * arrowheadScale;
    final double arrowheadPointY = radius + uy * radius +  ux * strokeWidth * 2.0 * arrowheadScale;
    final double arrowheadRadius = strokeWidth * 2.0 * arrowheadScale;
    final double innerRadius = radius - arrowheadRadius;
    final double outerRadius = radius + arrowheadRadius;

    final Path path = Path()
      ..moveTo(radius + ux * innerRadius, radius + uy * innerRadius)
      ..lineTo(radius + ux * outerRadius, radius + uy * outerRadius)
      ..lineTo(arrowheadPointX, arrowheadPointY)
      ..close();

    final Paint paint = Paint()
      ..color = valueColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);
    if (arrowheadScale > 0.0) {
      paintArrowhead(canvas, size);
    }
  }
}

class RefreshProgressIndicator extends CircularProgressIndicator {
  const RefreshProgressIndicator({
    super.key,
    super.value,
    super.backgroundColor,
    super.color,
    super.valueColor,
    super.strokeWidth = defaultStrokeWidth, // Different default than CircularProgressIndicator.
    super.strokeAlign,
    super.semanticsLabel,
    super.semanticsValue,
    super.strokeCap,
  });

  static const double defaultStrokeWidth = 2.5;

  @override
  Color? get backgroundColor => super.backgroundColor;

  @override
  State<CircularProgressIndicator> createState() => _RefreshProgressIndicatorState();
}

class _RefreshProgressIndicatorState extends _CircularProgressIndicatorState {
  static const double _indicatorSize = 41.0;

  static const double _strokeHeadInterval = 0.33;

  late final Animatable<double> _convertTween = CurveTween(
    curve: const Interval(0.1, _strokeHeadInterval),
  );

  late final Animatable<double> _additionalRotationTween = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      // Makes arrow to expand a little bit earlier, to match the Android look.
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.1, end: -0.2),
        weight: _strokeHeadInterval,
      ),
      // Additional rotation after the arrow expanded
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.2, end: 1.35),
        weight: 1 - _strokeHeadInterval,
      ),
    ],
  );

  // Last value received from the widget before null.
  double? _lastValue;

  // Always show the indeterminate version of the circular progress indicator.
  //
  // When value is non-null the sweep of the progress indicator arrow's arc
  // varies from 0 to about 300 degrees.
  //
  // When value is null the arrow animation starting from wherever we left it.
  @override
  Widget build(BuildContext context) {
    final double? value = widget.value;
    if (value != null) {
      _lastValue = value;
      _controller.value = _convertTween.transform(value)
        * (1333 / 2 / _kIndeterminateCircularDuration);
    }
    return _buildAnimation();
  }

  @override
  Widget _buildAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return _buildMaterialIndicator(
          context,
          // Lengthen the arc a little
          1.05 * _CircularProgressIndicatorState._strokeHeadTween.evaluate(_controller),
          _CircularProgressIndicatorState._strokeTailTween.evaluate(_controller),
          _CircularProgressIndicatorState._offsetTween.evaluate(_controller),
          _CircularProgressIndicatorState._rotationTween.evaluate(_controller),
        );
      },
    );
  }

  @override
  Widget _buildMaterialIndicator(BuildContext context, double headValue, double tailValue, double offsetValue, double rotationValue) {
    final double? value = widget.value;
    final double arrowheadScale = value == null ? 0.0 : const Interval(0.1, _strokeHeadInterval).transform(value);
    final double rotation;

    if (value == null && _lastValue == null) {
      rotation = 0.0;
    } else {
      rotation = math.pi * _additionalRotationTween.transform(value ?? _lastValue!);
    }

    Color valueColor = widget._getValueColor(context);
    final double opacity = valueColor.opacity;
    valueColor = valueColor.withOpacity(1.0);

    final Color backgroundColor =
      widget.backgroundColor ??
      ProgressIndicatorTheme.of(context).refreshBackgroundColor ??
      Theme.of(context).canvasColor;

    return widget._buildSemanticsWrapper(
      context: context,
      child: Container(
        width: _indicatorSize,
        height: _indicatorSize,
        margin: const EdgeInsets.all(4.0), // accommodate the shadow
        child: Material(
          type: MaterialType.circle,
          color: backgroundColor,
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: rotation,
                child: CustomPaint(
                  painter: _RefreshProgressIndicatorPainter(
                    valueColor: valueColor,
                    value: null, // Draw the indeterminate progress indicator.
                    headValue: headValue,
                    tailValue: tailValue,
                    offsetValue: offsetValue,
                    rotationValue: rotationValue,
                    strokeWidth: widget.strokeWidth,
                    strokeAlign: widget.strokeAlign,
                    arrowheadScale: arrowheadScale,
                    strokeCap: widget.strokeCap,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Hand coded defaults based on Material Design 2.
class _CircularProgressIndicatorDefaultsM2 extends ProgressIndicatorThemeData {
  _CircularProgressIndicatorDefaultsM2(this.context);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color get color => _colors.primary;
}

class _LinearProgressIndicatorDefaultsM2 extends ProgressIndicatorThemeData {
  _LinearProgressIndicatorDefaultsM2(this.context);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color get color => _colors.primary;

  @override
  Color get linearTrackColor => _colors.background;

  @override
  double get linearMinHeight => 4.0;
}

// BEGIN GENERATED TOKEN PROPERTIES - ProgressIndicator

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _CircularProgressIndicatorDefaultsM3 extends ProgressIndicatorThemeData {
  _CircularProgressIndicatorDefaultsM3(this.context);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color get color => _colors.primary;
}

class _LinearProgressIndicatorDefaultsM3 extends ProgressIndicatorThemeData {
  _LinearProgressIndicatorDefaultsM3(this.context);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color get color => _colors.primary;

  @override
  Color get linearTrackColor => _colors.surfaceVariant;

  @override
  double get linearMinHeight => 4.0;
}

// END GENERATED TOKEN PROPERTIES - ProgressIndicator