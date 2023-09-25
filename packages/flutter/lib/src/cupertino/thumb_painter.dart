// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';

import 'colors.dart';

const Color _kThumbBorderColor = Color(0x0A000000);

const List<BoxShadow> _kSwitchBoxShadows = <BoxShadow> [
  BoxShadow(
    color: Color(0x26000000),
    offset: Offset(0, 3),
    blurRadius: 8.0,
  ),
  BoxShadow(
    color: Color(0x0F000000),
    offset: Offset(0, 3),
    blurRadius: 1.0,
  ),
];

const List<BoxShadow> _kSliderBoxShadows = <BoxShadow> [
  BoxShadow(
    color: Color(0x26000000),
    offset: Offset(0, 3),
    blurRadius: 8.0,
  ),
  BoxShadow(
    color: Color(0x29000000),
    offset: Offset(0, 1),
    blurRadius: 1.0,
  ),
  BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 3),
    blurRadius: 1.0,
  ),
];

class CupertinoThumbPainter {
  const CupertinoThumbPainter({
    this.color = CupertinoColors.white,
    this.shadows = _kSliderBoxShadows,
  });

  const CupertinoThumbPainter.switchThumb({
    Color color = CupertinoColors.white,
    List<BoxShadow> shadows = _kSwitchBoxShadows,
  }) : this(color: color, shadows: shadows);

  final Color color;

  final List<BoxShadow> shadows;

  static const double radius = 14.0;

  static const double extension = 7.0;

  void paint(Canvas canvas, Rect rect) {
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide / 2.0),
    );

    for (final BoxShadow shadow in shadows) {
      canvas.drawRRect(rrect.shift(shadow.offset), shadow.toPaint());
    }

    canvas.drawRRect(
      rrect.inflate(0.5),
      Paint()..color = _kThumbBorderColor,
    );
    canvas.drawRRect(rrect, Paint()..color = color);
  }
}