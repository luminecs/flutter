// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'colors.dart';

const double _kDefaultIndicatorRadius = 10.0;

// Extracted from iOS 13.2 Beta.
const Color _kActiveTickColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF3C3C44),
  darkColor: Color(0xFFEBEBF5),
);

class CupertinoActivityIndicator extends StatefulWidget {
  const CupertinoActivityIndicator({
    super.key,
    this.color,
    this.animating = true,
    this.radius = _kDefaultIndicatorRadius,
  })  : assert(radius > 0.0),
        progress = 1.0;

  const CupertinoActivityIndicator.partiallyRevealed({
    super.key,
    this.color,
    this.radius = _kDefaultIndicatorRadius,
    this.progress = 1.0,
  })  : assert(radius > 0.0),
        assert(progress >= 0.0),
        assert(progress <= 1.0),
        animating = false;

  final Color? color;

  final bool animating;

  final double radius;

  final double progress;

  @override
  State<CupertinoActivityIndicator> createState() => _CupertinoActivityIndicatorState();
}

class _CupertinoActivityIndicatorState extends State<CupertinoActivityIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (widget.animating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CupertinoActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating != oldWidget.animating) {
      if (widget.animating) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.radius * 2,
      width: widget.radius * 2,
      child: CustomPaint(
        painter: _CupertinoActivityIndicatorPainter(
          position: _controller,
          activeColor: widget.color ?? CupertinoDynamicColor.resolve(_kActiveTickColor, context),
          radius: widget.radius,
          progress: widget.progress,
        ),
      ),
    );
  }
}

const double _kTwoPI = math.pi * 2.0;

const List<int> _kAlphaValues = <int>[
  47,
  47,
  47,
  47,
  72,
  97,
  122,
  147,
];

const int _partiallyRevealedAlpha = 147;

class _CupertinoActivityIndicatorPainter extends CustomPainter {
  _CupertinoActivityIndicatorPainter({
    required this.position,
    required this.activeColor,
    required this.radius,
    required this.progress,
  })  : tickFundamentalRRect = RRect.fromLTRBXY(
          -radius / _kDefaultIndicatorRadius,
          -radius / 3.0,
          radius / _kDefaultIndicatorRadius,
          -radius,
          radius / _kDefaultIndicatorRadius,
          radius / _kDefaultIndicatorRadius,
        ),
        super(repaint: position);

  final Animation<double> position;
  final Color activeColor;
  final double radius;
  final double progress;

  final RRect tickFundamentalRRect;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    final int tickCount = _kAlphaValues.length;

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);

    final int activeTick = (tickCount * position.value).floor();

    for (int i = 0; i < tickCount * progress; ++i) {
      final int t = (i - activeTick) % tickCount;
      paint.color = activeColor
          .withAlpha(progress < 1 ? _partiallyRevealedAlpha : _kAlphaValues[t]);
      canvas.drawRRect(tickFundamentalRRect, paint);
      canvas.rotate(_kTwoPI / tickCount);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CupertinoActivityIndicatorPainter oldPainter) {
    return oldPainter.position != position ||
        oldPainter.activeColor != activeColor ||
        oldPainter.progress != progress;
  }
}