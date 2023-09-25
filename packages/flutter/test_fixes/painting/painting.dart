import 'package:flutter/painting.dart';

void main() {
  // Change made in https://github.com/flutter/flutter/pull/121152
  final EdgeInsets insets = EdgeInsets.fromWindowPadding(ViewPadding.zero, 3.0);

  // Change made in https://github.com/flutter/flutter/pull/128522
  const TextStyle textStyle = TextStyle()
    ..getTextStyle(textScaleFactor: math.min(_kTextScaleFactor, 1.0))
    ..getTextStyle();

  TextPainter(text: inlineSpan);
  TextPainter(textScaleFactor: someValue);

  TextPainter.computeWidth(textScaleFactor: textScaleFactor);
  TextPainter.computeMaxIntrinsicWidth(textScaleFactor: textScaleFactor);
}