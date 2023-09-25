// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class TextSelectionThemeData with Diagnosticable {
  const TextSelectionThemeData({
    this.cursorColor,
    this.selectionColor,
    this.selectionHandleColor,
  });

  final Color? cursorColor;

  final Color? selectionColor;

  final Color? selectionHandleColor;

  TextSelectionThemeData copyWith({
    Color? cursorColor,
    Color? selectionColor,
    Color? selectionHandleColor,
  }) {
    return TextSelectionThemeData(
      cursorColor: cursorColor ?? this.cursorColor,
      selectionColor: selectionColor ?? this.selectionColor,
      selectionHandleColor: selectionHandleColor ?? this.selectionHandleColor,
    );
  }

  static TextSelectionThemeData? lerp(TextSelectionThemeData? a, TextSelectionThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return TextSelectionThemeData(
      cursorColor: Color.lerp(a?.cursorColor, b?.cursorColor, t),
      selectionColor: Color.lerp(a?.selectionColor, b?.selectionColor, t),
      selectionHandleColor: Color.lerp(a?.selectionHandleColor, b?.selectionHandleColor, t),
    );
  }

  @override
  int get hashCode => Object.hash(
    cursorColor,
    selectionColor,
    selectionHandleColor,
  );

  @override
  bool operator==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TextSelectionThemeData
      && other.cursorColor == cursorColor
      && other.selectionColor == selectionColor
      && other.selectionHandleColor == selectionHandleColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('cursorColor', cursorColor, defaultValue: null));
    properties.add(ColorProperty('selectionColor', selectionColor, defaultValue: null));
    properties.add(ColorProperty('selectionHandleColor', selectionHandleColor, defaultValue: null));
  }
}

class TextSelectionTheme extends InheritedTheme {
  const TextSelectionTheme({
    super.key,
    required this.data,
    required Widget child,
  }) : _child = child,
       // See `get child` override below.
       super(child: const _NullWidget());

  final TextSelectionThemeData data;

  // Overriding the getter to insert `DefaultSelectionStyle` into the subtree
  // without breaking API. In general, this approach should be avoided
  // because it relies on an implementation detail of ProxyWidget. This
  // workaround is necessary because TextSelectionTheme is const.
  @override
  Widget get child {
    return DefaultSelectionStyle(
      selectionColor: data.selectionColor,
      cursorColor: data.cursorColor,
      child: _child,
    );
  }
  final Widget _child;

  static TextSelectionThemeData of(BuildContext context) {
    final TextSelectionTheme? selectionTheme = context.dependOnInheritedWidgetOfExactType<TextSelectionTheme>();
    return selectionTheme?.data ?? Theme.of(context).textSelectionTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return TextSelectionTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(TextSelectionTheme oldWidget) => data != oldWidget.data;
}

class _NullWidget extends Widget {
  const _NullWidget();

  @override
  Element createElement() => throw UnimplementedError();
}