// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'action_buttons.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ActionIconThemeData with Diagnosticable {
  const ActionIconThemeData({ this.backButtonIconBuilder, this.closeButtonIconBuilder, this.drawerButtonIconBuilder, this.endDrawerButtonIconBuilder });

  final WidgetBuilder? backButtonIconBuilder;

  final WidgetBuilder? closeButtonIconBuilder;

  final WidgetBuilder? drawerButtonIconBuilder;

  final WidgetBuilder? endDrawerButtonIconBuilder;

  ActionIconThemeData copyWith({
    WidgetBuilder? backButtonIconBuilder,
    WidgetBuilder? closeButtonIconBuilder,
    WidgetBuilder? drawerButtonIconBuilder,
    WidgetBuilder? endDrawerButtonIconBuilder,
  }) {
    return ActionIconThemeData(
      backButtonIconBuilder: backButtonIconBuilder ?? this.backButtonIconBuilder,
      closeButtonIconBuilder: closeButtonIconBuilder ?? this.closeButtonIconBuilder,
      drawerButtonIconBuilder: drawerButtonIconBuilder ?? this.drawerButtonIconBuilder,
      endDrawerButtonIconBuilder: endDrawerButtonIconBuilder ?? this.endDrawerButtonIconBuilder,
    );
  }

  static ActionIconThemeData? lerp(ActionIconThemeData? a, ActionIconThemeData? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    return ActionIconThemeData(
      backButtonIconBuilder: t < 0.5 ? a?.backButtonIconBuilder : b?.backButtonIconBuilder,
      closeButtonIconBuilder: t < 0.5 ? a?.closeButtonIconBuilder : b?.closeButtonIconBuilder,
      drawerButtonIconBuilder: t < 0.5 ? a?.drawerButtonIconBuilder : b?.drawerButtonIconBuilder,
      endDrawerButtonIconBuilder: t < 0.5 ? a?.endDrawerButtonIconBuilder : b?.endDrawerButtonIconBuilder,
    );
  }

  @override
  int get hashCode {
    final List<Object?> values = <Object?>[
      backButtonIconBuilder,
      closeButtonIconBuilder,
      drawerButtonIconBuilder,
      endDrawerButtonIconBuilder,
    ];
    return Object.hashAll(values);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ActionIconThemeData
        && other.backButtonIconBuilder == backButtonIconBuilder
        && other.closeButtonIconBuilder == closeButtonIconBuilder
        && other.drawerButtonIconBuilder == drawerButtonIconBuilder
        && other.endDrawerButtonIconBuilder == endDrawerButtonIconBuilder;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<WidgetBuilder>('backButtonIconBuilder', backButtonIconBuilder, defaultValue: null));
    properties.add(DiagnosticsProperty<WidgetBuilder>('closeButtonIconBuilder', closeButtonIconBuilder, defaultValue: null));
    properties.add(DiagnosticsProperty<WidgetBuilder>('drawerButtonIconBuilder', drawerButtonIconBuilder, defaultValue: null));
    properties.add(DiagnosticsProperty<WidgetBuilder>('endDrawerButtonIconBuilder', endDrawerButtonIconBuilder, defaultValue: null));
  }
}

class ActionIconTheme extends InheritedTheme {
  const ActionIconTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ActionIconThemeData data;

  static ActionIconThemeData? of(BuildContext context) {
    final ActionIconTheme? actionIconTheme = context.dependOnInheritedWidgetOfExactType<ActionIconTheme>();
    return actionIconTheme?.data ?? Theme.of(context).actionIconTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ActionIconTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ActionIconTheme oldWidget) => data != oldWidget.data;
}