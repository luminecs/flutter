// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';

import 'page_transitions_theme.dart';
import 'theme.dart';

class MaterialPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  MaterialPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
  }) {
    assert(opaque);
  }

  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  final bool maintainState;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}


mixin MaterialRouteTransitionMixin<T> on PageRoute<T> {
  @protected
  Widget buildContent(BuildContext context);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    // Don't perform outgoing animation if the next route is a fullscreen dialog.
    return (nextRoute is MaterialRouteTransitionMixin && !nextRoute.fullscreenDialog)
      || (nextRoute is CupertinoRouteTransitionMixin && !nextRoute.fullscreenDialog);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget result = buildContent(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: result,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final PageTransitionsTheme theme = Theme.of(context).pageTransitionsTheme;
    return theme.buildTransitions<T>(this, context, animation, secondaryAnimation, child);
  }
}

class MaterialPage<T> extends Page<T> {
  const MaterialPage({
    required this.child,
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.allowSnapshotting = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  final bool maintainState;

  final bool fullscreenDialog;

  final bool allowSnapshotting;

  @override
  Route<T> createRoute(BuildContext context) {
    return _PageBasedMaterialPageRoute<T>(page: this, allowSnapshotting: allowSnapshotting);
  }
}

// A page-based version of MaterialPageRoute.
//
// This route uses the builder from the page to build its content. This ensures
// the content is up to date after page updates.
class _PageBasedMaterialPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _PageBasedMaterialPageRoute({
    required MaterialPage<T> page,
    super.allowSnapshotting,
  }) : super(settings: page) {
    assert(opaque);
  }

  MaterialPage<T> get _page => settings as MaterialPage<T>;

  @override
  Widget buildContent(BuildContext context) {
    return _page.child;
  }

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}