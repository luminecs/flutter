// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';

const double _kOffset = 40.0; // distance to bottom of banner, at a 45 degree angle inwards
const double _kHeight = 12.0; // height of banner
const double _kBottomOffset = _kOffset + 0.707 * _kHeight; // offset plus sqrt(2)/2 * banner height
const Rect _kRect = Rect.fromLTWH(-_kOffset, _kOffset - _kHeight, _kOffset * 2.0, _kHeight);

const Color _kColor = Color(0xA0B71C1C);
const TextStyle _kTextStyle = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: _kHeight * 0.85,
  fontWeight: FontWeight.w900,
  height: 1.0,
);

enum BannerLocation {
  topStart,

  topEnd,

  bottomStart,

  bottomEnd,
}

class BannerPainter extends CustomPainter {
  BannerPainter({
    required this.message,
    required this.textDirection,
    required this.location,
    required this.layoutDirection,
    this.color = _kColor,
    this.textStyle = _kTextStyle,
  }) : super(repaint: PaintingBinding.instance.systemFonts);

  final String message;

  final TextDirection textDirection;

  final BannerLocation location;

  final TextDirection layoutDirection;

  final Color color;

  final TextStyle textStyle;

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x7F000000),
    blurRadius: 6.0,
  );

  bool _prepared = false;
  TextPainter? _textPainter;
  late Paint _paintShadow;
  late Paint _paintBanner;

  void dispose() {
    _textPainter?.dispose();
    _textPainter = null;
  }

  void _prepare() {
    _paintShadow = _shadow.toPaint();
    _paintBanner = Paint()
      ..color = color;
    _textPainter?.dispose();
    _textPainter = TextPainter(
      text: TextSpan(style: textStyle, text: message),
      textAlign: TextAlign.center,
      textDirection: textDirection,
    );
    _prepared = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!_prepared) {
      _prepare();
    }
    canvas
      ..translate(_translationX(size.width), _translationY(size.height))
      ..rotate(_rotation)
      ..drawRect(_kRect, _paintShadow)
      ..drawRect(_kRect, _paintBanner);
    const double width = _kOffset * 2.0;
    _textPainter!.layout(minWidth: width, maxWidth: width);
    _textPainter!.paint(canvas, _kRect.topLeft + Offset(0.0, (_kRect.height - _textPainter!.height) / 2.0));
  }

  @override
  bool shouldRepaint(BannerPainter oldDelegate) {
    return message != oldDelegate.message
        || location != oldDelegate.location
        || color != oldDelegate.color
        || textStyle != oldDelegate.textStyle;
  }

  @override
  bool hitTest(Offset position) => false;

  double _translationX(double width) {
    switch (layoutDirection) {
      case TextDirection.rtl:
        switch (location) {
          case BannerLocation.bottomEnd:
            return _kBottomOffset;
          case BannerLocation.topEnd:
            return 0.0;
          case BannerLocation.bottomStart:
            return width - _kBottomOffset;
          case BannerLocation.topStart:
            return width;
        }
      case TextDirection.ltr:
        switch (location) {
          case BannerLocation.bottomEnd:
            return width - _kBottomOffset;
          case BannerLocation.topEnd:
            return width;
          case BannerLocation.bottomStart:
            return _kBottomOffset;
          case BannerLocation.topStart:
            return 0.0;
        }
    }
  }

  double _translationY(double height) {
    switch (location) {
      case BannerLocation.bottomStart:
      case BannerLocation.bottomEnd:
        return height - _kBottomOffset;
      case BannerLocation.topStart:
      case BannerLocation.topEnd:
        return 0.0;
    }
  }

  double get _rotation {
    switch (layoutDirection) {
      case TextDirection.rtl:
        switch (location) {
          case BannerLocation.bottomStart:
          case BannerLocation.topEnd:
            return -math.pi / 4.0;
          case BannerLocation.bottomEnd:
          case BannerLocation.topStart:
            return math.pi / 4.0;
        }
      case TextDirection.ltr:
        switch (location) {
          case BannerLocation.bottomStart:
          case BannerLocation.topEnd:
            return math.pi / 4.0;
          case BannerLocation.bottomEnd:
          case BannerLocation.topStart:
            return -math.pi / 4.0;
        }
    }
  }
}

class Banner extends StatelessWidget {
  const Banner({
    super.key,
    this.child,
    required this.message,
    this.textDirection,
    required this.location,
    this.layoutDirection,
    this.color = _kColor,
    this.textStyle = _kTextStyle,
  });

  final Widget? child;

  final String message;

  final TextDirection? textDirection;

  final BannerLocation location;

  final TextDirection? layoutDirection;

  final Color color;

  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    assert((textDirection != null && layoutDirection != null) || debugCheckHasDirectionality(context));
    return CustomPaint(
      foregroundPainter: BannerPainter(
        message: message,
        textDirection: textDirection ?? Directionality.of(context),
        location: location,
        layoutDirection: layoutDirection ?? Directionality.of(context),
        color: color,
        textStyle: textStyle,
      ),
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message, showName: false));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(EnumProperty<BannerLocation>('location', location));
    properties.add(EnumProperty<TextDirection>('layoutDirection', layoutDirection, defaultValue: null));
    properties.add(ColorProperty('color', color, showName: false));
    textStyle.debugFillProperties(properties, prefix: 'text ');
  }
}

class CheckedModeBanner extends StatelessWidget {
  const CheckedModeBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    assert(() {
      result = Banner(
        message: 'DEBUG',
        textDirection: TextDirection.ltr,
        location: BannerLocation.topEnd,
        child: result,
      );
      return true;
    }());
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    String message = 'disabled';
    assert(() {
      message = '"DEBUG"';
      return true;
    }());
    properties.add(DiagnosticsNode.message(message));
  }
}