
import 'package:flutter/widgets.dart';

void main() {
  // Change made in https://github.com/flutter/flutter/pull/128522
  MediaQueryData();
  MediaQueryData(textScaleFactor: 2.0)
    ..copyWith(textScaleFactor: 2.0)
    ..copyWith();
}