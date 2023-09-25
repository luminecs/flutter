// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../widgets/framework.dart';

enum CupertinoUserInterfaceLevelData {
  base,

  elevated,
}

class CupertinoUserInterfaceLevel extends InheritedWidget {
  const CupertinoUserInterfaceLevel({
    super.key,
    required CupertinoUserInterfaceLevelData data,
    required super.child,
  }) : _data = data;

  final CupertinoUserInterfaceLevelData _data;

  @override
  bool updateShouldNotify(CupertinoUserInterfaceLevel oldWidget) => oldWidget._data != _data;

  static CupertinoUserInterfaceLevelData of(BuildContext context) {
    final CupertinoUserInterfaceLevel? query = context.dependOnInheritedWidgetOfExactType<CupertinoUserInterfaceLevel>();
    if (query != null) {
      return query._data;
    }
    throw FlutterError(
      'CupertinoUserInterfaceLevel.of() called with a context that does not contain a CupertinoUserInterfaceLevel.\n'
      'No CupertinoUserInterfaceLevel ancestor could be found starting from the context that was passed '
      'to CupertinoUserInterfaceLevel.of(). This can happen because you do not have a WidgetsApp or '
      'MaterialApp widget (those widgets introduce a CupertinoUserInterfaceLevel), or it can happen '
      'if the context you use comes from a widget above those widgets.\n'
      'The context used was:\n'
      '  $context',
    );
  }

  static CupertinoUserInterfaceLevelData? maybeOf(BuildContext context) {
    final CupertinoUserInterfaceLevel? query = context.dependOnInheritedWidgetOfExactType<CupertinoUserInterfaceLevel>();
    if (query != null) {
      return query._data;
    }
    return null;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<CupertinoUserInterfaceLevelData>('user interface level', _data));
  }
}