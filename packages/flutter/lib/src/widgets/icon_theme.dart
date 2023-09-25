// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'framework.dart';
import 'icon_theme_data.dart';
import 'inherited_theme.dart';

// Examples can assume:
// late BuildContext context;

class IconTheme extends InheritedTheme {
  const IconTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static Widget merge({
    Key? key,
    required IconThemeData data,
    required Widget child,
  }) {
    return Builder(
      builder: (BuildContext context) {
        return IconTheme(
          key: key,
          data: _getInheritedIconThemeData(context).merge(data),
          child: child,
        );
      },
    );
  }

  final IconThemeData data;

  static IconThemeData of(BuildContext context) {
    final IconThemeData iconThemeData = _getInheritedIconThemeData(context).resolve(context);
    return iconThemeData.isConcrete
      ? iconThemeData
      : iconThemeData.copyWith(
        size: iconThemeData.size ?? const IconThemeData.fallback().size,
        fill: iconThemeData.fill ?? const IconThemeData.fallback().fill,
        weight: iconThemeData.weight ?? const IconThemeData.fallback().weight,
        grade: iconThemeData.grade ?? const IconThemeData.fallback().grade,
        opticalSize: iconThemeData.opticalSize ?? const IconThemeData.fallback().opticalSize,
        color: iconThemeData.color ?? const IconThemeData.fallback().color,
        opacity: iconThemeData.opacity ?? const IconThemeData.fallback().opacity,
        shadows: iconThemeData.shadows ?? const IconThemeData.fallback().shadows,
      );
  }

  static IconThemeData _getInheritedIconThemeData(BuildContext context) {
    final IconTheme? iconTheme = context.dependOnInheritedWidgetOfExactType<IconTheme>();
    return iconTheme?.data ?? const IconThemeData.fallback();
  }

  @override
  bool updateShouldNotify(IconTheme oldWidget) => data != oldWidget.data;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return IconTheme(data: data, child: child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    data.debugFillProperties(properties);
  }
}