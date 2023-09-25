// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class FilledButtonThemeData with Diagnosticable {
  const FilledButtonThemeData({ this.style });

  final ButtonStyle? style;

  static FilledButtonThemeData? lerp(FilledButtonThemeData? a, FilledButtonThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return FilledButtonThemeData(
      style: ButtonStyle.lerp(a?.style, b?.style, t),
    );
  }

  @override
  int get hashCode => style.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FilledButtonThemeData && other.style == style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
  }
}

class FilledButtonTheme extends InheritedTheme {
  const FilledButtonTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final FilledButtonThemeData data;

  static FilledButtonThemeData of(BuildContext context) {
    final FilledButtonTheme? buttonTheme = context.dependOnInheritedWidgetOfExactType<FilledButtonTheme>();
    return buttonTheme?.data ?? Theme.of(context).filledButtonTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return FilledButtonTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(FilledButtonTheme oldWidget) => data != oldWidget.data;
}