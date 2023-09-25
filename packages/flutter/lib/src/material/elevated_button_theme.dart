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
class ElevatedButtonThemeData with Diagnosticable {
  const ElevatedButtonThemeData({ this.style });

  final ButtonStyle? style;

  static ElevatedButtonThemeData? lerp(ElevatedButtonThemeData? a, ElevatedButtonThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ElevatedButtonThemeData(
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
    return other is ElevatedButtonThemeData && other.style == style;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
  }
}

class ElevatedButtonTheme extends InheritedTheme {
  const ElevatedButtonTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ElevatedButtonThemeData data;

  static ElevatedButtonThemeData of(BuildContext context) {
    final ElevatedButtonTheme? buttonTheme = context.dependOnInheritedWidgetOfExactType<ElevatedButtonTheme>();
    return buttonTheme?.data ?? Theme.of(context).elevatedButtonTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ElevatedButtonTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ElevatedButtonTheme oldWidget) => data != oldWidget.data;
}