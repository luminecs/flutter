// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'framework.dart';

// Examples can assume:
// TooltipThemeData data = const TooltipThemeData();

abstract class InheritedTheme extends InheritedWidget {

  const InheritedTheme({
    super.key,
    required super.child,
  });

  Widget wrap(BuildContext context, Widget child);

  static Widget captureAll(BuildContext context, Widget child, {BuildContext? to}) {

    return capture(from: context, to: to).wrap(child);
  }

  static CapturedThemes capture({ required BuildContext from, required BuildContext? to }) {

    if (from == to) {
      // Nothing to capture.
      return CapturedThemes._(const <InheritedTheme>[]);
    }

    final List<InheritedTheme> themes = <InheritedTheme>[];
    final Set<Type> themeTypes = <Type>{};
    late bool debugDidFindAncestor;
    assert(() {
      debugDidFindAncestor = to == null;
      return true;
    }());
    from.visitAncestorElements((Element ancestor) {
      if (ancestor == to) {
        assert(() {
          debugDidFindAncestor = true;
          return true;
        }());
        return false;
      }
      if (ancestor is InheritedElement && ancestor.widget is InheritedTheme) {
        final InheritedTheme theme = ancestor.widget as InheritedTheme;
        final Type themeType = theme.runtimeType;
        // Only remember the first theme of any type. This assumes
        // that inherited themes completely shadow ancestors of the
        // same type.
        if (!themeTypes.contains(themeType)) {
          themeTypes.add(themeType);
          themes.add(theme);
        }
      }
      return true;
    });

    assert(debugDidFindAncestor, 'The provided `to` context must be an ancestor of the `from` context.');
    return CapturedThemes._(themes);
  }
}

class CapturedThemes {
  CapturedThemes._(this._themes);

  final List<InheritedTheme> _themes;

  Widget wrap(Widget child) {
    return _CaptureAll(themes: _themes, child: child);
  }
}

class _CaptureAll extends StatelessWidget {
  const _CaptureAll({
    required this.themes,
    required this.child,
  });

  final List<InheritedTheme> themes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget wrappedChild = child;
    for (final InheritedTheme theme in themes) {
      wrappedChild = theme.wrap(context, wrappedChild);
    }
    return wrappedChild;
  }
}