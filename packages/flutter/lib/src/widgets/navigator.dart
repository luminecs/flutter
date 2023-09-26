import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'binding.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'focus_traversal.dart';
import 'framework.dart';
import 'heroes.dart';
import 'notification_listener.dart';
import 'overlay.dart';
import 'restoration.dart';
import 'restoration_properties.dart';
import 'routes.dart';
import 'ticker_provider.dart';

// Examples can assume:
// typedef MyAppHome = Placeholder;
// typedef MyHomePage = Placeholder;
// typedef MyPage = ListTile; // any const widget with a Widget "title" constructor argument would do
// late NavigatorState navigator;
// late BuildContext context;

typedef RouteFactory = Route<dynamic>? Function(RouteSettings settings);

typedef RouteListFactory = List<Route<dynamic>> Function(
    NavigatorState navigator, String initialRoute);

typedef RestorableRouteBuilder<T> = Route<T> Function(
    BuildContext context, Object? arguments);

typedef RoutePredicate = bool Function(Route<dynamic> route);

@Deprecated(
  'Use PopInvokedCallback instead. '
  'This feature was deprecated after v3.12.0-1.0.pre.',
)
typedef WillPopCallback = Future<bool> Function();

typedef PopPageCallback = bool Function(Route<dynamic> route, dynamic result);

enum RoutePopDisposition {
  pop,

  doNotPop,

  bubble,
}

abstract class Route<T> {
  Route({RouteSettings? settings})
      : _settings = settings ?? const RouteSettings() {
    if (kFlutterMemoryAllocationsEnabled) {
      MemoryAllocations.instance.dispatchObjectCreated(
        library: 'package:flutter/widgets.dart',
        className: '$Route<$T>',
        object: this,
      );
    }
  }

  NavigatorState? get navigator => _navigator;
  NavigatorState? _navigator;

  RouteSettings get settings => _settings;
  RouteSettings _settings;

  ValueListenable<String?> get restorationScopeId => _restorationScopeId;
  final ValueNotifier<String?> _restorationScopeId =
      ValueNotifier<String?>(null);

  void _updateSettings(RouteSettings newSettings) {
    if (_settings != newSettings) {
      _settings = newSettings;
      changedInternalState();
    }
  }

  // ignore: use_setters_to_change_properties, (setters can't be private)
  void _updateRestorationId(String? restorationId) {
    _restorationScopeId.value = restorationId;
  }

  List<OverlayEntry> get overlayEntries => const <OverlayEntry>[];

  @protected
  @mustCallSuper
  void install() {}

  @protected
  @mustCallSuper
  TickerFuture didPush() {
    return TickerFuture.complete()
      ..then<void>((void _) {
        if (navigator?.widget.requestFocus ?? false) {
          navigator!.focusNode.enclosingScope?.requestFocus();
        }
      });
  }

  @protected
  @mustCallSuper
  void didAdd() {
    if (navigator?.widget.requestFocus ?? false) {
      // This TickerFuture serves two purposes. First, we want to make sure that
      // animations triggered by other operations will finish before focusing
      // the navigator. Second, navigator.focusNode might acquire more focused
      // children in Route.install asynchronously. This TickerFuture will wait
      // for it to finish first.
      //
      // The later case can be found when subclasses manage their own focus scopes.
      // For example, ModalRoute creates a focus scope in its overlay entries. The
      // focused child can only be attached to navigator after initState which
      // will be guarded by the asynchronous gap.
      TickerFuture.complete().then<void>((void _) {
        // The route can be disposed before the ticker future completes. This can
        // happen when the navigator is under a TabView that warps from one tab to
        // another, non-adjacent tab, with an animation. The TabView reorders its
        // children before and after the warping completes, and that causes its
        // children to be built and disposed within the same frame. If one of its
        // children contains a navigator, the routes in that navigator are also
        // added and disposed within that frame.
        //
        // Since the reference to the navigator will be set to null after it is
        // disposed, we have to do a null-safe operation in case that happens
        // within the same frame when it is added.
        navigator?.focusNode.enclosingScope?.requestFocus();
      });
    }
  }

  @protected
  @mustCallSuper
  void didReplace(Route<dynamic>? oldRoute) {}

  @Deprecated(
    'Use popDisposition instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  Future<RoutePopDisposition> willPop() async {
    return isFirst ? RoutePopDisposition.bubble : RoutePopDisposition.pop;
  }

  RoutePopDisposition get popDisposition {
    return isFirst ? RoutePopDisposition.bubble : RoutePopDisposition.pop;
  }

  void onPopInvoked(bool didPop) {}

  bool get willHandlePopInternally => false;

  T? get currentResult => null;

  Future<T?> get popped => _popCompleter.future;
  final Completer<T?> _popCompleter = Completer<T?>();

  @mustCallSuper
  bool didPop(T? result) {
    didComplete(result);
    return true;
  }

  @protected
  @mustCallSuper
  void didComplete(T? result) {
    _popCompleter.complete(result ?? currentResult);
  }

  @protected
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {}

  @protected
  @mustCallSuper
  void didChangeNext(Route<dynamic>? nextRoute) {}

  @protected
  @mustCallSuper
  void didChangePrevious(Route<dynamic>? previousRoute) {}

  @protected
  @mustCallSuper
  void changedInternalState() {}

  @protected
  @mustCallSuper
  void changedExternalState() {}

  @mustCallSuper
  @protected
  void dispose() {
    _navigator = null;
    _restorationScopeId.dispose();
    if (kFlutterMemoryAllocationsEnabled) {
      MemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }
  }

  bool get isCurrent {
    if (_navigator == null) {
      return false;
    }
    final _RouteEntry? currentRouteEntry =
        _navigator!._lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
    if (currentRouteEntry == null) {
      return false;
    }
    return currentRouteEntry.route == this;
  }

  bool get isFirst {
    if (_navigator == null) {
      return false;
    }
    final _RouteEntry? currentRouteEntry =
        _navigator!._firstRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
    if (currentRouteEntry == null) {
      return false;
    }
    return currentRouteEntry.route == this;
  }

  @protected
  bool get hasActiveRouteBelow {
    if (_navigator == null) {
      return false;
    }
    for (final _RouteEntry entry in _navigator!._history) {
      if (entry.route == this) {
        return false;
      }
      if (_RouteEntry.isPresentPredicate(entry)) {
        return true;
      }
    }
    return false;
  }

  bool get isActive {
    if (_navigator == null) {
      return false;
    }
    return _navigator!
            ._firstRouteEntryWhereOrNull(_RouteEntry.isRoutePredicate(this))
            ?.isPresent ??
        false;
  }
}

@immutable
class RouteSettings {
  const RouteSettings({
    this.name,
    this.arguments,
  });

  final String? name;

  final Object? arguments;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'RouteSettings')}(${name == null ? 'none' : '"$name"'}, $arguments)';
}

abstract class Page<T> extends RouteSettings {
  const Page({
    this.key,
    super.name,
    super.arguments,
    this.restorationId,
  });

  final LocalKey? key;

  final String? restorationId;

  bool canUpdate(Page<dynamic> other) {
    return other.runtimeType == runtimeType && other.key == key;
  }

  @factory
  Route<T> createRoute(BuildContext context);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'Page')}("$name", $key, $arguments)';
}

class NavigatorObserver {
  NavigatorState? get navigator => _navigators[this];

  // Expando mapping instances of NavigatorObserver to their associated
  // NavigatorState (or `null`, if there is no associated NavigatorState). The
  // reason we don't use a private instance field of type
  // `NavigatorState?` is because as part of implementing
  // https://github.com/dart-lang/language/issues/2020, it will soon become a
  // runtime error to invoke a private member that is mocked in another
  // library. By using an expando rather than an instance field, we ensure
  // that a mocked NavigatorObserver can still properly keep track of its
  // associated NavigatorState.
  static final Expando<NavigatorState> _navigators = Expando<NavigatorState>();

  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {}

  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {}

  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {}

  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {}

  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {}

  void didStopUserGesture() {}
}

class HeroControllerScope extends InheritedWidget {
  const HeroControllerScope({
    super.key,
    required HeroController this.controller,
    required super.child,
  });

  const HeroControllerScope.none({
    super.key,
    required super.child,
  }) : controller = null;

  final HeroController? controller;

  static HeroController? maybeOf(BuildContext context) {
    final HeroControllerScope? host =
        context.dependOnInheritedWidgetOfExactType<HeroControllerScope>();
    return host?.controller;
  }

  static HeroController of(BuildContext context) {
    final HeroController? controller = maybeOf(context);
    assert(() {
      if (controller == null) {
        throw FlutterError(
          'HeroControllerScope.of() was called with a context that does not contain a '
          'HeroControllerScope widget.\n'
          'No HeroControllerScope widget ancestor could be found starting from the '
          'context that was passed to HeroControllerScope.of(). This can happen '
          'because you are using a widget that looks for a HeroControllerScope '
          'ancestor, but no such ancestor exists.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return controller!;
  }

  @override
  bool updateShouldNotify(HeroControllerScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

abstract class RouteTransitionRecord {
  Route<dynamic> get route;

  bool get isWaitingForEnteringDecision;

  bool get isWaitingForExitingDecision;

  void markForPush();

  void markForAdd();

  void markForPop([dynamic result]);

  void markForComplete([dynamic result]);

  void markForRemove();
}

abstract class TransitionDelegate<T> {
  const TransitionDelegate();

  Iterable<RouteTransitionRecord> _transition({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
        pageRouteToPagelessRoutes,
  }) {
    final Iterable<RouteTransitionRecord> results = resolve(
      newPageRouteHistory: newPageRouteHistory,
      locationToExitingPageRoute: locationToExitingPageRoute,
      pageRouteToPagelessRoutes: pageRouteToPagelessRoutes,
    );
    // Verifies the integrity after the decisions have been made.
    //
    // Here are the rules:
    // - All the entering routes in newPageRouteHistory must either be pushed or
    //   added.
    // - All the exiting routes in locationToExitingPageRoute must either be
    //   popped, completed or removed.
    // - All the pageless routes that belong to exiting routes must either be
    //   popped, completed or removed.
    // - All the entering routes in the result must preserve the same order as
    //   the entering routes in newPageRouteHistory, and the result must contain
    //   all exiting routes.
    //     ex:
    //
    //     newPageRouteHistory = [A, B, C]
    //
    //     locationToExitingPageRoute = {A -> D, C -> E}
    //
    //     results = [A, B ,C ,D ,E] is valid
    //     results = [D, A, B ,C ,E] is also valid because exiting route can be
    //     inserted in any place
    //
    //     results = [B, A, C ,D ,E] is invalid because B must be after A.
    //     results = [A, B, C ,E] is invalid because results must include D.
    assert(() {
      final List<RouteTransitionRecord> resultsToVerify =
          results.toList(growable: false);
      final Set<RouteTransitionRecord> exitingPageRoutes =
          locationToExitingPageRoute.values.toSet();
      // Firstly, verifies all exiting routes have been marked.
      for (final RouteTransitionRecord exitingPageRoute in exitingPageRoutes) {
        assert(!exitingPageRoute.isWaitingForExitingDecision);
        if (pageRouteToPagelessRoutes.containsKey(exitingPageRoute)) {
          for (final RouteTransitionRecord pagelessRoute
              in pageRouteToPagelessRoutes[exitingPageRoute]!) {
            assert(!pagelessRoute.isWaitingForExitingDecision);
          }
        }
      }
      // Secondly, verifies the order of results matches the newPageRouteHistory
      // and contains all the exiting routes.
      int indexOfNextRouteInNewHistory = 0;

      for (final _RouteEntry routeEntry
          in resultsToVerify.cast<_RouteEntry>()) {
        assert(!routeEntry.isWaitingForEnteringDecision &&
            !routeEntry.isWaitingForExitingDecision);
        if (indexOfNextRouteInNewHistory >= newPageRouteHistory.length ||
            routeEntry != newPageRouteHistory[indexOfNextRouteInNewHistory]) {
          assert(exitingPageRoutes.contains(routeEntry));
          exitingPageRoutes.remove(routeEntry);
        } else {
          indexOfNextRouteInNewHistory += 1;
        }
      }

      assert(
        indexOfNextRouteInNewHistory == newPageRouteHistory.length &&
            exitingPageRoutes.isEmpty,
        'The merged result from the $runtimeType.resolve does not include all '
        'required routes. Do you remember to merge all exiting routes?',
      );
      return true;
    }());

    return results;
  }

  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
        pageRouteToPagelessRoutes,
  });
}

class DefaultTransitionDelegate<T> extends TransitionDelegate<T> {
  const DefaultTransitionDelegate() : super();

  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>>
        pageRouteToPagelessRoutes,
  }) {
    final List<RouteTransitionRecord> results = <RouteTransitionRecord>[];
    // This method will handle the exiting route and its corresponding pageless
    // route at this location. It will also recursively check if there is any
    // other exiting routes above it and handle them accordingly.
    void handleExitingRoute(RouteTransitionRecord? location, bool isLast) {
      final RouteTransitionRecord? exitingPageRoute =
          locationToExitingPageRoute[location];
      if (exitingPageRoute == null) {
        return;
      }
      if (exitingPageRoute.isWaitingForExitingDecision) {
        final bool hasPagelessRoute =
            pageRouteToPagelessRoutes.containsKey(exitingPageRoute);
        final bool isLastExitingPageRoute =
            isLast && !locationToExitingPageRoute.containsKey(exitingPageRoute);
        if (isLastExitingPageRoute && !hasPagelessRoute) {
          exitingPageRoute.markForPop(exitingPageRoute.route.currentResult);
        } else {
          exitingPageRoute
              .markForComplete(exitingPageRoute.route.currentResult);
        }
        if (hasPagelessRoute) {
          final List<RouteTransitionRecord> pagelessRoutes =
              pageRouteToPagelessRoutes[exitingPageRoute]!;
          for (final RouteTransitionRecord pagelessRoute in pagelessRoutes) {
            // It is possible that a pageless route that belongs to an exiting
            // page-based route does not require exiting decision. This can
            // happen if the page list is updated right after a Navigator.pop.
            if (pagelessRoute.isWaitingForExitingDecision) {
              if (isLastExitingPageRoute &&
                  pagelessRoute == pagelessRoutes.last) {
                pagelessRoute.markForPop(pagelessRoute.route.currentResult);
              } else {
                pagelessRoute
                    .markForComplete(pagelessRoute.route.currentResult);
              }
            }
          }
        }
      }
      results.add(exitingPageRoute);

      // It is possible there is another exiting route above this exitingPageRoute.
      handleExitingRoute(exitingPageRoute, isLast);
    }

    // Handles exiting route in the beginning of list.
    handleExitingRoute(null, newPageRouteHistory.isEmpty);

    for (final RouteTransitionRecord pageRoute in newPageRouteHistory) {
      final bool isLastIteration = newPageRouteHistory.last == pageRoute;
      if (pageRoute.isWaitingForEnteringDecision) {
        if (!locationToExitingPageRoute.containsKey(pageRoute) &&
            isLastIteration) {
          pageRoute.markForPush();
        } else {
          pageRoute.markForAdd();
        }
      }
      results.add(pageRoute);
      handleExitingRoute(pageRoute, isLastIteration);
    }
    return results;
  }
}

const TraversalEdgeBehavior kDefaultRouteTraversalEdgeBehavior = kIsWeb
    ? TraversalEdgeBehavior.leaveFlutterView
    : TraversalEdgeBehavior.closedLoop;

class Navigator extends StatefulWidget {
  const Navigator({
    super.key,
    this.pages = const <Page<dynamic>>[],
    this.onPopPage,
    this.initialRoute,
    this.onGenerateInitialRoutes = Navigator.defaultGenerateInitialRoutes,
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.transitionDelegate = const DefaultTransitionDelegate<dynamic>(),
    this.reportsRouteUpdateToEngine = false,
    this.clipBehavior = Clip.hardEdge,
    this.observers = const <NavigatorObserver>[],
    this.requestFocus = true,
    this.restorationScopeId,
    this.routeTraversalEdgeBehavior = kDefaultRouteTraversalEdgeBehavior,
  });

  final List<Page<dynamic>> pages;

  final PopPageCallback? onPopPage;

  final TransitionDelegate<dynamic> transitionDelegate;

  final String? initialRoute;

  final RouteFactory? onGenerateRoute;

  final RouteFactory? onUnknownRoute;

  final List<NavigatorObserver> observers;

  final String? restorationScopeId;

  final TraversalEdgeBehavior routeTraversalEdgeBehavior;

  static const String defaultRouteName = '/';

  final RouteListFactory onGenerateInitialRoutes;

  final bool reportsRouteUpdateToEngine;

  final Clip clipBehavior;

  final bool requestFocus;

  @optionalTypeArgs
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  @optionalTypeArgs
  static String restorablePushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context)
        .restorablePushNamed<T>(routeName, arguments: arguments);
  }

  @optionalTypeArgs
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(routeName,
        arguments: arguments, result: result);
  }

  @optionalTypeArgs
  static String
      restorablePushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return Navigator.of(context).restorablePushReplacementNamed<T, TO>(
        routeName,
        arguments: arguments,
        result: result);
  }

  @optionalTypeArgs
  static Future<T?> popAndPushNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return Navigator.of(context).popAndPushNamed<T, TO>(routeName,
        arguments: arguments, result: result);
  }

  @optionalTypeArgs
  static String
      restorablePopAndPushNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return Navigator.of(context).restorablePopAndPushNamed<T, TO>(routeName,
        arguments: arguments, result: result);
  }

  @optionalTypeArgs
  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil<T>(
        newRouteName, predicate,
        arguments: arguments);
  }

  @optionalTypeArgs
  static String restorablePushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return Navigator.of(context).restorablePushNamedAndRemoveUntil<T>(
        newRouteName, predicate,
        arguments: arguments);
  }

  @optionalTypeArgs
  static Future<T?> push<T extends Object?>(
      BuildContext context, Route<T> route) {
    return Navigator.of(context).push(route);
  }

  @optionalTypeArgs
  static String restorablePush<T extends Object?>(
      BuildContext context, RestorableRouteBuilder<T> routeBuilder,
      {Object? arguments}) {
    return Navigator.of(context)
        .restorablePush(routeBuilder, arguments: arguments);
  }

  @optionalTypeArgs
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
      BuildContext context, Route<T> newRoute,
      {TO? result}) {
    return Navigator.of(context)
        .pushReplacement<T, TO>(newRoute, result: result);
  }

  @optionalTypeArgs
  static String
      restorablePushReplacement<T extends Object?, TO extends Object?>(
          BuildContext context, RestorableRouteBuilder<T> routeBuilder,
          {TO? result, Object? arguments}) {
    return Navigator.of(context).restorablePushReplacement<T, TO>(routeBuilder,
        result: result, arguments: arguments);
  }

  @optionalTypeArgs
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
      BuildContext context, Route<T> newRoute, RoutePredicate predicate) {
    return Navigator.of(context).pushAndRemoveUntil<T>(newRoute, predicate);
  }

  @optionalTypeArgs
  static String restorablePushAndRemoveUntil<T extends Object?>(
      BuildContext context,
      RestorableRouteBuilder<T> newRouteBuilder,
      RoutePredicate predicate,
      {Object? arguments}) {
    return Navigator.of(context).restorablePushAndRemoveUntil<T>(
        newRouteBuilder, predicate,
        arguments: arguments);
  }

  @optionalTypeArgs
  static void replace<T extends Object?>(BuildContext context,
      {required Route<dynamic> oldRoute, required Route<T> newRoute}) {
    return Navigator.of(context)
        .replace<T>(oldRoute: oldRoute, newRoute: newRoute);
  }

  @optionalTypeArgs
  static String restorableReplace<T extends Object?>(BuildContext context,
      {required Route<dynamic> oldRoute,
      required RestorableRouteBuilder<T> newRouteBuilder,
      Object? arguments}) {
    return Navigator.of(context).restorableReplace<T>(
        oldRoute: oldRoute,
        newRouteBuilder: newRouteBuilder,
        arguments: arguments);
  }

  @optionalTypeArgs
  static void replaceRouteBelow<T extends Object?>(BuildContext context,
      {required Route<dynamic> anchorRoute, required Route<T> newRoute}) {
    return Navigator.of(context)
        .replaceRouteBelow<T>(anchorRoute: anchorRoute, newRoute: newRoute);
  }

  @optionalTypeArgs
  static String restorableReplaceRouteBelow<T extends Object?>(
      BuildContext context,
      {required Route<dynamic> anchorRoute,
      required RestorableRouteBuilder<T> newRouteBuilder,
      Object? arguments}) {
    return Navigator.of(context).restorableReplaceRouteBelow<T>(
        anchorRoute: anchorRoute,
        newRouteBuilder: newRouteBuilder,
        arguments: arguments);
  }

  static bool canPop(BuildContext context) {
    final NavigatorState? navigator = Navigator.maybeOf(context);
    return navigator != null && navigator.canPop();
  }

  @optionalTypeArgs
  static Future<bool> maybePop<T extends Object?>(BuildContext context,
      [T? result]) {
    return Navigator.of(context).maybePop<T>(result);
  }

  @optionalTypeArgs
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }

  static void popUntil(BuildContext context, RoutePredicate predicate) {
    Navigator.of(context).popUntil(predicate);
  }

  static void removeRoute(BuildContext context, Route<dynamic> route) {
    return Navigator.of(context).removeRoute(route);
  }

  static void removeRouteBelow(
      BuildContext context, Route<dynamic> anchorRoute) {
    return Navigator.of(context).removeRouteBelow(anchorRoute);
  }

  static NavigatorState of(
    BuildContext context, {
    bool rootNavigator = false,
  }) {
    // Handles the case where the input context is a navigator element.
    NavigatorState? navigator;
    if (context is StatefulElement && context.state is NavigatorState) {
      navigator = context.state as NavigatorState;
    }
    if (rootNavigator) {
      navigator =
          context.findRootAncestorStateOfType<NavigatorState>() ?? navigator;
    } else {
      navigator =
          navigator ?? context.findAncestorStateOfType<NavigatorState>();
    }

    assert(() {
      if (navigator == null) {
        throw FlutterError(
          'Navigator operation requested with a context that does not include a Navigator.\n'
          'The context used to push or pop routes from the Navigator must be that of a '
          'widget that is a descendant of a Navigator widget.',
        );
      }
      return true;
    }());
    return navigator!;
  }

  static NavigatorState? maybeOf(
    BuildContext context, {
    bool rootNavigator = false,
  }) {
    // Handles the case where the input context is a navigator element.
    NavigatorState? navigator;
    if (context is StatefulElement && context.state is NavigatorState) {
      navigator = context.state as NavigatorState;
    }
    if (rootNavigator) {
      navigator =
          context.findRootAncestorStateOfType<NavigatorState>() ?? navigator;
    } else {
      navigator =
          navigator ?? context.findAncestorStateOfType<NavigatorState>();
    }
    return navigator;
  }

  static List<Route<dynamic>> defaultGenerateInitialRoutes(
      NavigatorState navigator, String initialRouteName) {
    final List<Route<dynamic>?> result = <Route<dynamic>?>[];
    if (initialRouteName.startsWith('/') && initialRouteName.length > 1) {
      initialRouteName = initialRouteName.substring(1); // strip leading '/'
      assert(Navigator.defaultRouteName == '/');
      List<String>? debugRouteNames;
      assert(() {
        debugRouteNames = <String>[Navigator.defaultRouteName];
        return true;
      }());
      result.add(navigator._routeNamed<dynamic>(Navigator.defaultRouteName,
          arguments: null, allowNull: true));
      final List<String> routeParts = initialRouteName.split('/');
      if (initialRouteName.isNotEmpty) {
        String routeName = '';
        for (final String part in routeParts) {
          routeName += '/$part';
          assert(() {
            debugRouteNames!.add(routeName);
            return true;
          }());
          result.add(navigator._routeNamed<dynamic>(routeName,
              arguments: null, allowNull: true));
        }
      }
      if (result.last == null) {
        assert(() {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: 'Could not navigate to initial route.\n'
                  'The requested route name was: "/$initialRouteName"\n'
                  'There was no corresponding route in the app, and therefore the initial route specified will be '
                  'ignored and "${Navigator.defaultRouteName}" will be used instead.',
            ),
          );
          return true;
        }());
        for (final Route<dynamic>? route in result) {
          route?.dispose();
        }
        result.clear();
      }
    } else if (initialRouteName != Navigator.defaultRouteName) {
      // If initialRouteName wasn't '/', then we try to get it with allowNull:true, so that if that fails,
      // we fall back to '/' (without allowNull:true, see below).
      result.add(navigator._routeNamed<dynamic>(initialRouteName,
          arguments: null, allowNull: true));
    }
    // Null route might be a result of gap in initialRouteName
    //
    // For example, routes = ['A', 'A/B/C'], and initialRouteName = 'A/B/C'
    // This should result in result = ['A', null,'A/B/C'] where 'A/B' produces
    // the null. In this case, we want to filter out the null and return
    // result = ['A', 'A/B/C'].
    result.removeWhere((Route<dynamic>? route) => route == null);
    if (result.isEmpty) {
      result.add(navigator._routeNamed<dynamic>(Navigator.defaultRouteName,
          arguments: null));
    }
    return result.cast<Route<dynamic>>();
  }

  @override
  NavigatorState createState() => NavigatorState();
}

// The _RouteLifecycle state machine (only goes down):
//
//                    [creation of a _RouteEntry]
//                                 |
//                                 +
//                                 |\
//                                 | \
//                                 | staging
//                                 | /
//                                 |/
//                    +-+----------+--+-------+
//                   /  |             |       |
//                  /   |             |       |
//                 /    |             |       |
//                /     |             |       |
//               /      |             |       |
//      pushReplace   push*         add*   replace*
//               \       |            |       |
//                \      |            |      /
//                 +--pushing#      adding  /
//                          \        /     /
//                           \      /     /
//                           idle--+-----+
//                           /  \
//                          /    +------+
//                         /     |      |
//                        /      |  complete*
//                        |      |    /
//                       pop*  remove*
//                        /        \
//                       /       removing#
//                     popping#       |
//                      |             |
//                   [finalizeRoute]  |
//                              \     |
//                              dispose*
//                                 |
//                              disposing
//                                 |
//                              disposed
//                                 |
//                                 |
//                  [_RouteEntry garbage collected]
//                          (terminal state)
//
// * These states are transient; as soon as _flushHistoryUpdates is run the
//   route entry will exit that state.
// # These states await futures or other events, then transition automatically.
enum _RouteLifecycle {
  staging, // we will wait for transition delegate to decide what to do with this route.
  //
  // routes that are present:
  //
  add, // we'll want to run install, didAdd, etc; a route created by onGenerateInitialRoutes or by the initial widget.pages
  adding, // we'll waiting for the future from didPush of top-most route to complete
  // routes that are ready for transition.
  push, // we'll want to run install, didPush, etc; a route added via push() and friends
  pushReplace, // we'll want to run install, didPush, etc; a route added via pushReplace() and friends
  pushing, // we're waiting for the future from didPush to complete
  replace, // we'll want to run install, didReplace, etc; a route added via replace() and friends
  idle, // route is being harmless
  //
  // routes that are not present:
  //
  // routes that should be included in route announcement and should still listen to transition changes.
  pop, // we'll want to call didPop
  complete, // we'll want to call didComplete,
  remove, // we'll want to run didReplace/didRemove etc
  // routes should not be included in route announcement but should still listen to transition changes.
  popping, // we're waiting for the route to call finalizeRoute to switch to dispose
  removing, // we are waiting for subsequent routes to be done animating, then will switch to dispose
  // routes that are completely removed from the navigator and overlay.
  dispose, // we will dispose the route momentarily
  disposing, // The entry is waiting for its widget subtree to be disposed
  // first. It is stored in _entryWaitingForSubTreeDisposal while
  // awaiting that.
  disposed, // we have disposed the route
}

typedef _RouteEntryPredicate = bool Function(_RouteEntry entry);

class _NotAnnounced extends Route<void> {
  // A placeholder for the lastAnnouncedPreviousRoute, the
  // lastAnnouncedPoppedNextRoute, and the lastAnnouncedNextRoute before any
  // change has been announced.
}

class _RouteEntry extends RouteTransitionRecord {
  _RouteEntry(
    this.route, {
    required _RouteLifecycle initialState,
    required this.pageBased,
    this.restorationInformation,
  })  : assert(!pageBased || route.settings is Page),
        assert(
          initialState == _RouteLifecycle.staging ||
              initialState == _RouteLifecycle.add ||
              initialState == _RouteLifecycle.push ||
              initialState == _RouteLifecycle.pushReplace ||
              initialState == _RouteLifecycle.replace,
        ),
        currentState = initialState;

  @override
  final Route<dynamic> route;
  final _RestorationInformation? restorationInformation;
  final bool pageBased;

  static const int kDebugPopAttemptLimit = 100;

  static final Route<dynamic> notAnnounced = _NotAnnounced();

  _RouteLifecycle currentState;
  Route<dynamic>? lastAnnouncedPreviousRoute =
      notAnnounced; // last argument to Route.didChangePrevious
  WeakReference<Route<dynamic>> lastAnnouncedPoppedNextRoute =
      WeakReference<Route<dynamic>>(
          notAnnounced); // last argument to Route.didPopNext
  Route<dynamic>? lastAnnouncedNextRoute =
      notAnnounced; // last argument to Route.didChangeNext

  String? get restorationId {
    // User-provided restoration ids of Pages are prefixed with 'p+'. Generated
    // ids for pageless routes are prefixed with 'r+' to avoid clashes.
    if (pageBased) {
      final Page<Object?> page = route.settings as Page<Object?>;
      return page.restorationId != null ? 'p+${page.restorationId}' : null;
    }
    if (restorationInformation != null) {
      return 'r+${restorationInformation!.restorationScopeId}';
    }
    return null;
  }

  bool canUpdateFrom(Page<dynamic> page) {
    if (!willBePresent) {
      return false;
    }
    if (!pageBased) {
      return false;
    }
    final Page<dynamic> routePage = route.settings as Page<dynamic>;
    return page.canUpdate(routePage);
  }

  void handleAdd(
      {required NavigatorState navigator,
      required Route<dynamic>? previousPresent}) {
    assert(currentState == _RouteLifecycle.add);
    assert(navigator._debugLocked);
    assert(route._navigator == null);
    route._navigator = navigator;
    route.install();
    assert(route.overlayEntries.isNotEmpty);
    currentState = _RouteLifecycle.adding;
    navigator._observedRouteAdditions.add(
      _NavigatorPushObservation(route, previousPresent),
    );
  }

  void handlePush(
      {required NavigatorState navigator,
      required bool isNewFirst,
      required Route<dynamic>? previous,
      required Route<dynamic>? previousPresent}) {
    assert(currentState == _RouteLifecycle.push ||
        currentState == _RouteLifecycle.pushReplace ||
        currentState == _RouteLifecycle.replace);
    assert(navigator._debugLocked);
    assert(
      route._navigator == null,
      'The pushed route has already been used. When pushing a route, a new '
      'Route object must be provided.',
    );
    final _RouteLifecycle previousState = currentState;
    route._navigator = navigator;
    route.install();
    assert(route.overlayEntries.isNotEmpty);
    if (currentState == _RouteLifecycle.push ||
        currentState == _RouteLifecycle.pushReplace) {
      final TickerFuture routeFuture = route.didPush();
      currentState = _RouteLifecycle.pushing;
      routeFuture.whenCompleteOrCancel(() {
        if (currentState == _RouteLifecycle.pushing) {
          currentState = _RouteLifecycle.idle;
          assert(!navigator._debugLocked);
          assert(() {
            navigator._debugLocked = true;
            return true;
          }());
          navigator._flushHistoryUpdates();
          assert(() {
            navigator._debugLocked = false;
            return true;
          }());
        }
      });
    } else {
      assert(currentState == _RouteLifecycle.replace);
      route.didReplace(previous);
      currentState = _RouteLifecycle.idle;
    }
    if (isNewFirst) {
      route.didChangeNext(null);
    }

    if (previousState == _RouteLifecycle.replace ||
        previousState == _RouteLifecycle.pushReplace) {
      navigator._observedRouteAdditions.add(
        _NavigatorReplaceObservation(route, previousPresent),
      );
    } else {
      assert(previousState == _RouteLifecycle.push);
      navigator._observedRouteAdditions.add(
        _NavigatorPushObservation(route, previousPresent),
      );
    }
  }

  void handleDidPopNext(Route<dynamic> poppedRoute) {
    route.didPopNext(poppedRoute);
    lastAnnouncedPoppedNextRoute = WeakReference<Route<dynamic>>(poppedRoute);
  }

  bool handlePop(
      {required NavigatorState navigator,
      required Route<dynamic>? previousPresent}) {
    assert(navigator._debugLocked);
    assert(route._navigator == navigator);
    currentState = _RouteLifecycle.popping;
    if (route._popCompleter.isCompleted) {
      // This is a page-based route popped through the Navigator.pop. The
      // didPop should have been called. No further action is needed.
      assert(pageBased);
      assert(pendingResult == null);
      return true;
    }
    if (!route.didPop(pendingResult)) {
      currentState = _RouteLifecycle.idle;
      return false;
    }
    pendingResult = null;
    return true;
  }

  void handleComplete() {
    route.didComplete(pendingResult);
    pendingResult = null;
    assert(route._popCompleter.isCompleted); // implies didComplete was called
    currentState = _RouteLifecycle.remove;
  }

  void handleRemoval(
      {required NavigatorState navigator,
      required Route<dynamic>? previousPresent}) {
    assert(navigator._debugLocked);
    assert(route._navigator == navigator);
    currentState = _RouteLifecycle.removing;
    if (_reportRemovalToObserver) {
      navigator._observedRouteDeletions.add(
        _NavigatorRemoveObservation(route, previousPresent),
      );
    }
  }

  void didAdd({required NavigatorState navigator, required bool isNewFirst}) {
    route.didAdd();
    currentState = _RouteLifecycle.idle;
    if (isNewFirst) {
      route.didChangeNext(null);
    }
  }

  Object? pendingResult;

  void pop<T>(T? result) {
    assert(isPresent);
    pendingResult = result;
    currentState = _RouteLifecycle.pop;
    route.onPopInvoked(true);
  }

  bool _reportRemovalToObserver = true;

  // Route is removed without being completed.
  void remove({bool isReplaced = false}) {
    assert(
      !pageBased || isWaitingForExitingDecision,
      'A page-based route cannot be completed using imperative api, provide a '
      'new list without the corresponding Page to Navigator.pages instead. ',
    );
    if (currentState.index >= _RouteLifecycle.remove.index) {
      return;
    }
    assert(isPresent);
    _reportRemovalToObserver = !isReplaced;
    currentState = _RouteLifecycle.remove;
  }

  // Route completes with `result` and is removed.
  void complete<T>(T result, {bool isReplaced = false}) {
    assert(
      !pageBased || isWaitingForExitingDecision,
      'A page-based route cannot be completed using imperative api, provide a '
      'new list without the corresponding Page to Navigator.pages instead. ',
    );
    if (currentState.index >= _RouteLifecycle.remove.index) {
      return;
    }
    assert(isPresent);
    _reportRemovalToObserver = !isReplaced;
    pendingResult = result;
    currentState = _RouteLifecycle.complete;
  }

  void finalize() {
    assert(currentState.index < _RouteLifecycle.dispose.index);
    currentState = _RouteLifecycle.dispose;
  }

  void forcedDispose() {
    assert(currentState.index < _RouteLifecycle.disposed.index);
    currentState = _RouteLifecycle.disposed;
    route.dispose();
  }

  void dispose() {
    assert(currentState.index < _RouteLifecycle.disposing.index);
    currentState = _RouteLifecycle.disposing;

    // If the overlay entries are still mounted, widgets in the route's subtree
    // may still reference resources from the route and we delay disposal of
    // the route until the overlay entries are no longer mounted.
    // Since the overlay entry is the root of the route's subtree it will only
    // get unmounted after every other widget in the subtree has been unmounted.

    final Iterable<OverlayEntry> mountedEntries =
        route.overlayEntries.where((OverlayEntry e) => e.mounted);

    if (mountedEntries.isEmpty) {
      forcedDispose();
      return;
    }

    int mounted = mountedEntries.length;
    assert(mounted > 0);
    final NavigatorState navigator = route._navigator!;
    navigator._entryWaitingForSubTreeDisposal.add(this);
    for (final OverlayEntry entry in mountedEntries) {
      late VoidCallback listener;
      listener = () {
        assert(mounted > 0);
        assert(!entry.mounted);
        mounted--;
        entry.removeListener(listener);
        if (mounted == 0) {
          assert(route.overlayEntries.every((OverlayEntry e) => !e.mounted));
          // This is a listener callback of one of the overlayEntries in this
          // route. Disposing the route also disposes its overlayEntries and
          // violates the rule that a change notifier can't be disposed during
          // its notifying callback.
          //
          // Use a microtask to ensure the overlayEntries have finished
          // notifying their listeners before disposing.
          return scheduleMicrotask(() {
            if (!navigator._entryWaitingForSubTreeDisposal.remove(this)) {
              // This route must have been destroyed as a result of navigator
              // force dispose.
              assert(route._navigator == null && !navigator.mounted);
              return;
            }
            assert(currentState == _RouteLifecycle.disposing);
            forcedDispose();
          });
        }
      };
      entry.addListener(listener);
    }
  }

  bool get willBePresent {
    return currentState.index <= _RouteLifecycle.idle.index &&
        currentState.index >= _RouteLifecycle.add.index;
  }

  bool get isPresent {
    return currentState.index <= _RouteLifecycle.remove.index &&
        currentState.index >= _RouteLifecycle.add.index;
  }

  bool get isPresentForRestoration =>
      currentState.index <= _RouteLifecycle.idle.index;

  bool get suitableForAnnouncement {
    return currentState.index <= _RouteLifecycle.removing.index &&
        currentState.index >= _RouteLifecycle.push.index;
  }

  bool get suitableForTransitionAnimation {
    return currentState.index <= _RouteLifecycle.remove.index &&
        currentState.index >= _RouteLifecycle.push.index;
  }

  bool shouldAnnounceChangeToNext(Route<dynamic>? nextRoute) {
    assert(nextRoute != lastAnnouncedNextRoute);
    // Do not announce if `next` changes from a just popped route to null. We
    // already announced this change by calling didPopNext.
    return !(nextRoute == null &&
        lastAnnouncedPoppedNextRoute.target == lastAnnouncedNextRoute);
  }

  static bool isPresentPredicate(_RouteEntry entry) => entry.isPresent;
  static bool suitableForTransitionAnimationPredicate(_RouteEntry entry) =>
      entry.suitableForTransitionAnimation;
  static bool willBePresentPredicate(_RouteEntry entry) => entry.willBePresent;

  static _RouteEntryPredicate isRoutePredicate(Route<dynamic> route) {
    return (_RouteEntry entry) => entry.route == route;
  }

  @override
  bool get isWaitingForEnteringDecision =>
      currentState == _RouteLifecycle.staging;

  @override
  bool get isWaitingForExitingDecision => _isWaitingForExitingDecision;
  bool _isWaitingForExitingDecision = false;

  void markNeedsExitingDecision() => _isWaitingForExitingDecision = true;

  @override
  void markForPush() {
    assert(
      isWaitingForEnteringDecision && !isWaitingForExitingDecision,
      'This route cannot be marked for push. Either a decision has already been '
      'made or it does not require an explicit decision on how to transition in.',
    );
    currentState = _RouteLifecycle.push;
  }

  @override
  void markForAdd() {
    assert(
      isWaitingForEnteringDecision && !isWaitingForExitingDecision,
      'This route cannot be marked for add. Either a decision has already been '
      'made or it does not require an explicit decision on how to transition in.',
    );
    currentState = _RouteLifecycle.add;
  }

  @override
  void markForPop([dynamic result]) {
    assert(
      !isWaitingForEnteringDecision && isWaitingForExitingDecision && isPresent,
      'This route cannot be marked for pop. Either a decision has already been '
      'made or it does not require an explicit decision on how to transition out.',
    );
    // Remove state that prevents a pop, e.g. LocalHistoryEntry[s].
    int attempt = 0;
    while (route.willHandlePopInternally) {
      assert(
        () {
          attempt += 1;
          return attempt < kDebugPopAttemptLimit;
        }(),
        'Attempted to pop $route $kDebugPopAttemptLimit times, but still failed',
      );
      final bool popResult = route.didPop(result);
      assert(!popResult);
    }
    pop<dynamic>(result);
    _isWaitingForExitingDecision = false;
  }

  @override
  void markForComplete([dynamic result]) {
    assert(
      !isWaitingForEnteringDecision && isWaitingForExitingDecision && isPresent,
      'This route cannot be marked for complete. Either a decision has already '
      'been made or it does not require an explicit decision on how to transition '
      'out.',
    );
    complete<dynamic>(result);
    _isWaitingForExitingDecision = false;
  }

  @override
  void markForRemove() {
    assert(
      !isWaitingForEnteringDecision && isWaitingForExitingDecision && isPresent,
      'This route cannot be marked for remove. Either a decision has already '
      'been made or it does not require an explicit decision on how to transition '
      'out.',
    );
    remove();
    _isWaitingForExitingDecision = false;
  }

  bool get restorationEnabled => route.restorationScopeId.value != null;
  set restorationEnabled(bool value) {
    assert(!value || restorationId != null);
    route._updateRestorationId(value ? restorationId : null);
  }
}

abstract class _NavigatorObservation {
  _NavigatorObservation(
    this.primaryRoute,
    this.secondaryRoute,
  );
  final Route<dynamic> primaryRoute;
  final Route<dynamic>? secondaryRoute;

  void notify(NavigatorObserver observer);
}

class _NavigatorPushObservation extends _NavigatorObservation {
  _NavigatorPushObservation(
    super.primaryRoute,
    super.secondaryRoute,
  );

  @override
  void notify(NavigatorObserver observer) {
    observer.didPush(primaryRoute, secondaryRoute);
  }
}

class _NavigatorPopObservation extends _NavigatorObservation {
  _NavigatorPopObservation(
    super.primaryRoute,
    super.secondaryRoute,
  );

  @override
  void notify(NavigatorObserver observer) {
    observer.didPop(primaryRoute, secondaryRoute);
  }
}

class _NavigatorRemoveObservation extends _NavigatorObservation {
  _NavigatorRemoveObservation(
    super.primaryRoute,
    super.secondaryRoute,
  );

  @override
  void notify(NavigatorObserver observer) {
    observer.didRemove(primaryRoute, secondaryRoute);
  }
}

class _NavigatorReplaceObservation extends _NavigatorObservation {
  _NavigatorReplaceObservation(
    super.primaryRoute,
    super.secondaryRoute,
  );

  @override
  void notify(NavigatorObserver observer) {
    observer.didReplace(newRoute: primaryRoute, oldRoute: secondaryRoute);
  }
}

typedef _IndexWhereCallback = bool Function(_RouteEntry element);

class _History extends Iterable<_RouteEntry> with ChangeNotifier {
  _History() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  final List<_RouteEntry> _value = <_RouteEntry>[];

  int indexWhere(_IndexWhereCallback test, [int start = 0]) {
    return _value.indexWhere(test, start);
  }

  void add(_RouteEntry element) {
    _value.add(element);
    notifyListeners();
  }

  void addAll(Iterable<_RouteEntry> elements) {
    _value.addAll(elements);
    if (elements.isNotEmpty) {
      notifyListeners();
    }
  }

  void clear() {
    final bool valueWasEmpty = _value.isEmpty;
    _value.clear();
    if (!valueWasEmpty) {
      notifyListeners();
    }
  }

  void insert(int index, _RouteEntry element) {
    _value.insert(index, element);
    notifyListeners();
  }

  _RouteEntry removeAt(int index) {
    final _RouteEntry entry = _value.removeAt(index);
    notifyListeners();
    return entry;
  }

  _RouteEntry removeLast() {
    final _RouteEntry entry = _value.removeLast();
    notifyListeners();
    return entry;
  }

  _RouteEntry operator [](int index) {
    return _value[index];
  }

  @override
  Iterator<_RouteEntry> get iterator {
    return _value.iterator;
  }

  @override
  String toString() {
    return _value.toString();
  }
}

class NavigatorState extends State<Navigator>
    with TickerProviderStateMixin, RestorationMixin {
  late GlobalKey<OverlayState> _overlayKey;
  final _History _history = _History();

  final Set<_RouteEntry> _entryWaitingForSubTreeDisposal = <_RouteEntry>{};
  final _HistoryProperty _serializableHistory = _HistoryProperty();
  final Queue<_NavigatorObservation> _observedRouteAdditions =
      Queue<_NavigatorObservation>();
  final Queue<_NavigatorObservation> _observedRouteDeletions =
      Queue<_NavigatorObservation>();

  @Deprecated('Use focusNode.enclosingScope! instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.')
  FocusScopeNode get focusScopeNode => focusNode.enclosingScope!;

  final FocusNode focusNode = FocusNode(debugLabel: 'Navigator');

  bool _debugLocked =
      false; // used to prevent re-entrant calls to push, pop, and friends

  HeroController? _heroControllerFromScope;

  late List<NavigatorObserver> _effectiveObservers;

  bool get _usingPagesAPI => widget.pages != const <Page<dynamic>>[];

  void _handleHistoryChanged() {
    final bool navigatorCanPop = canPop();
    late final bool routeBlocksPop;
    if (!navigatorCanPop) {
      final _RouteEntry? lastEntry =
          _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
      routeBlocksPop = lastEntry != null &&
          lastEntry.route.popDisposition == RoutePopDisposition.doNotPop;
    } else {
      routeBlocksPop = false;
    }
    final NavigationNotification notification = NavigationNotification(
      canHandlePop: navigatorCanPop || routeBlocksPop,
    );
    // Avoid dispatching a notification in the middle of a build.
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.postFrameCallbacks:
        notification.dispatch(context);
      case SchedulerPhase.idle:
      case SchedulerPhase.midFrameMicrotasks:
      case SchedulerPhase.persistentCallbacks:
      case SchedulerPhase.transientCallbacks:
        SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
          if (!mounted) {
            return;
          }
          notification.dispatch(context);
        });
    }
  }

  @override
  void initState() {
    super.initState();
    assert(() {
      if (_usingPagesAPI) {
        if (widget.pages.isEmpty) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                'The Navigator.pages must not be empty to use the '
                'Navigator.pages API',
              ),
              library: 'widget library',
              stack: StackTrace.current,
            ),
          );
        } else if (widget.onPopPage == null) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                'The Navigator.onPopPage must be provided to use the '
                'Navigator.pages API',
              ),
              library: 'widget library',
              stack: StackTrace.current,
            ),
          );
        }
      }
      return true;
    }());
    for (final NavigatorObserver observer in widget.observers) {
      assert(observer.navigator == null);
      NavigatorObserver._navigators[observer] = this;
    }
    _effectiveObservers = widget.observers;

    // We have to manually extract the inherited widget in initState because
    // the current context is not fully initialized.
    final HeroControllerScope? heroControllerScope = context
        .getElementForInheritedWidgetOfExactType<HeroControllerScope>()
        ?.widget as HeroControllerScope?;
    _updateHeroController(heroControllerScope?.controller);

    if (widget.reportsRouteUpdateToEngine) {
      SystemNavigator.selectSingleEntryHistory();
    }

    _history.addListener(_handleHistoryChanged);
  }

  // Use [_nextPagelessRestorationScopeId] to get the next id.
  final RestorableNum<int> _rawNextPagelessRestorationScopeId =
      RestorableNum<int>(0);

  int get _nextPagelessRestorationScopeId =>
      _rawNextPagelessRestorationScopeId.value++;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_rawNextPagelessRestorationScopeId, 'id');
    registerForRestoration(_serializableHistory, 'history');

    // Delete everything in the old history and clear the overlay.
    _forcedDisposeAllRouteEntries();
    assert(_history.isEmpty);
    _overlayKey = GlobalKey<OverlayState>();

    // Populate the new history from restoration data.
    _history.addAll(_serializableHistory.restoreEntriesForPage(null, this));
    for (final Page<dynamic> page in widget.pages) {
      final _RouteEntry entry = _RouteEntry(
        page.createRoute(context),
        pageBased: true,
        initialState: _RouteLifecycle.add,
      );
      assert(
        entry.route.settings == page,
        'The settings getter of a page-based Route must return a Page object. '
        'Please set the settings to the Page in the Page.createRoute method.',
      );
      _history.add(entry);
      _history.addAll(_serializableHistory.restoreEntriesForPage(entry, this));
    }

    // If there was nothing to restore, we need to process the initial route.
    if (!_serializableHistory.hasData) {
      String? initialRoute = widget.initialRoute;
      if (widget.pages.isEmpty) {
        initialRoute = initialRoute ?? Navigator.defaultRouteName;
      }
      if (initialRoute != null) {
        _history.addAll(
          widget
              .onGenerateInitialRoutes(
                this,
                widget.initialRoute ?? Navigator.defaultRouteName,
              )
              .map(
                (Route<dynamic> route) => _RouteEntry(
                  route,
                  pageBased: false,
                  initialState: _RouteLifecycle.add,
                  restorationInformation: route.settings.name != null
                      ? _RestorationInformation.named(
                          name: route.settings.name!,
                          arguments: null,
                          restorationScopeId: _nextPagelessRestorationScopeId,
                        )
                      : null,
                ),
              ),
        );
      }
    }

    assert(
      _history.isNotEmpty,
      'All routes returned by onGenerateInitialRoutes are not restorable. '
      'Please make sure that all routes returned by onGenerateInitialRoutes '
      'have their RouteSettings defined with names that are defined in the '
      "app's routes table.",
    );
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    _flushHistoryUpdates();
    assert(() {
      _debugLocked = false;
      return true;
    }());
  }

  @override
  void didToggleBucket(RestorationBucket? oldBucket) {
    super.didToggleBucket(oldBucket);
    if (bucket != null) {
      _serializableHistory.update(_history);
    } else {
      _serializableHistory.clear();
    }
  }

  @override
  String? get restorationId => widget.restorationScopeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateHeroController(HeroControllerScope.maybeOf(context));
    for (final _RouteEntry entry in _history) {
      entry.route.changedExternalState();
    }
  }

  void _forcedDisposeAllRouteEntries() {
    _entryWaitingForSubTreeDisposal.removeWhere((_RouteEntry entry) {
      entry.forcedDispose();
      return true;
    });
    while (_history.isNotEmpty) {
      _disposeRouteEntry(_history.removeLast(), graceful: false);
    }
  }

  static void _disposeRouteEntry(_RouteEntry entry, {required bool graceful}) {
    for (final OverlayEntry overlayEntry in entry.route.overlayEntries) {
      overlayEntry.remove();
    }
    if (graceful) {
      entry.dispose();
    } else {
      entry.forcedDispose();
    }
  }

  void _updateHeroController(HeroController? newHeroController) {
    if (_heroControllerFromScope != newHeroController) {
      if (newHeroController != null) {
        // Makes sure the same hero controller is not shared between two navigators.
        assert(() {
          // It is possible that the hero controller subscribes to an existing
          // navigator. We are fine as long as that navigator gives up the hero
          // controller at the end of the build.
          if (newHeroController.navigator != null) {
            final NavigatorState previousOwner = newHeroController.navigator!;
            ServicesBinding.instance.addPostFrameCallback((Duration timestamp) {
              // We only check if this navigator still owns the hero controller.
              if (_heroControllerFromScope == newHeroController) {
                final bool hasHeroControllerOwnerShip =
                    _heroControllerFromScope!.navigator == this;
                if (!hasHeroControllerOwnerShip ||
                    previousOwner._heroControllerFromScope ==
                        newHeroController) {
                  final NavigatorState otherOwner = hasHeroControllerOwnerShip
                      ? previousOwner
                      : _heroControllerFromScope!.navigator!;
                  FlutterError.reportError(
                    FlutterErrorDetails(
                      exception: FlutterError(
                        'A HeroController can not be shared by multiple Navigators. '
                        'The Navigators that share the same HeroController are:\n'
                        '- $this\n'
                        '- $otherOwner\n'
                        'Please create a HeroControllerScope for each Navigator or '
                        'use a HeroControllerScope.none to prevent subtree from '
                        'receiving a HeroController.',
                      ),
                      library: 'widget library',
                      stack: StackTrace.current,
                    ),
                  );
                }
              }
            });
          }
          return true;
        }());
        NavigatorObserver._navigators[newHeroController] = this;
      }
      // Only unsubscribe the hero controller when it is currently subscribe to
      // this navigator.
      if (_heroControllerFromScope?.navigator == this) {
        NavigatorObserver._navigators[_heroControllerFromScope!] = null;
      }
      _heroControllerFromScope = newHeroController;
      _updateEffectiveObservers();
    }
  }

  void _updateEffectiveObservers() {
    if (_heroControllerFromScope != null) {
      _effectiveObservers =
          widget.observers + <NavigatorObserver>[_heroControllerFromScope!];
    } else {
      _effectiveObservers = widget.observers;
    }
  }

  @override
  void didUpdateWidget(Navigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(() {
      if (_usingPagesAPI) {
        // This navigator uses page API.
        if (widget.pages.isEmpty) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                'The Navigator.pages must not be empty to use the '
                'Navigator.pages API',
              ),
              library: 'widget library',
              stack: StackTrace.current,
            ),
          );
        } else if (widget.onPopPage == null) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                'The Navigator.onPopPage must be provided to use the '
                'Navigator.pages API',
              ),
              library: 'widget library',
              stack: StackTrace.current,
            ),
          );
        }
      }
      return true;
    }());
    if (oldWidget.observers != widget.observers) {
      for (final NavigatorObserver observer in oldWidget.observers) {
        NavigatorObserver._navigators[observer] = null;
      }
      for (final NavigatorObserver observer in widget.observers) {
        assert(observer.navigator == null);
        NavigatorObserver._navigators[observer] = this;
      }
      _updateEffectiveObservers();
    }
    if (oldWidget.pages != widget.pages && !restorePending) {
      assert(() {
        if (widget.pages.isEmpty) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: FlutterError(
                'The Navigator.pages must not be empty to use the '
                'Navigator.pages API',
              ),
              library: 'widget library',
              stack: StackTrace.current,
            ),
          );
        }
        return true;
      }());
      _updatePages();
    }

    for (final _RouteEntry entry in _history) {
      entry.route.changedExternalState();
    }
  }

  void _debugCheckDuplicatedPageKeys() {
    assert(() {
      final Set<Key> keyReservation = <Key>{};
      for (final Page<dynamic> page in widget.pages) {
        final LocalKey? key = page.key;
        if (key != null) {
          assert(!keyReservation.contains(key));
          keyReservation.add(key);
        }
      }
      return true;
    }());
  }

  @override
  void deactivate() {
    for (final NavigatorObserver observer in _effectiveObservers) {
      NavigatorObserver._navigators[observer] = null;
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    for (final NavigatorObserver observer in _effectiveObservers) {
      assert(observer.navigator == null);
      NavigatorObserver._navigators[observer] = this;
    }
  }

  @override
  void dispose() {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(() {
      for (final NavigatorObserver observer in _effectiveObservers) {
        assert(observer.navigator != this);
      }
      return true;
    }());
    _updateHeroController(null);
    focusNode.dispose();
    _forcedDisposeAllRouteEntries();
    _rawNextPagelessRestorationScopeId.dispose();
    _serializableHistory.dispose();
    userGestureInProgressNotifier.dispose();
    _history.removeListener(_handleHistoryChanged);
    _history.dispose();
    super.dispose();
    // don't unlock, so that the object becomes unusable
    assert(_debugLocked);
  }

  OverlayState? get overlay => _overlayKey.currentState;

  Iterable<OverlayEntry> get _allRouteOverlayEntries {
    return <OverlayEntry>[
      for (final _RouteEntry entry in _history) ...entry.route.overlayEntries,
    ];
  }

  String? _lastAnnouncedRouteName;

  bool _debugUpdatingPage = false;
  void _updatePages() {
    assert(() {
      assert(!_debugUpdatingPage);
      _debugCheckDuplicatedPageKeys();
      _debugUpdatingPage = true;
      return true;
    }());

    // This attempts to diff the new pages list (widget.pages) with
    // the old _RouteEntry(s) list (_history), and produces a new list of
    // _RouteEntry(s) to be the new list of _history. This method roughly
    // follows the same outline of RenderObjectElement.updateChildren.
    //
    // The cases it tries to optimize for are:
    //  - the old list is empty
    //  - All the pages in the new list can match the page-based routes in the old
    //    list, and their orders are the same.
    //  - there is an insertion or removal of one or more page-based route in
    //    only one place in the list
    // If a page-based route with a key is in both lists, it will be synced.
    // Page-based routes without keys might be synced but there is no guarantee.

    // The general approach is to sync the entire new list backwards, as follows:
    // 1. Walk the lists from the bottom, syncing nodes, and record pageless routes,
    //    until you no longer have matching nodes.
    // 2. Walk the lists from the top, without syncing nodes, until you no
    //    longer have matching nodes. We'll sync these nodes at the end. We
    //    don't sync them now because we want to sync all the nodes in order
    //    from beginning to end.
    // At this point we narrowed the old and new lists to the point
    // where the nodes no longer match.
    // 3. Walk the narrowed part of the old list to get the list of
    //    keys.
    // 4. Walk the narrowed part of the new list forwards:
    //     * Create a new _RouteEntry for non-keyed items and record them for
    //       transitionDelegate.
    //     * Sync keyed items with the source if it exists.
    // 5. Walk the narrowed part of the old list again to records the
    //    _RouteEntry(s), as well as pageless routes, needed to be removed for
    //    transitionDelegate.
    // 5. Walk the top of the list again, syncing the nodes and recording
    //    pageless routes.
    // 6. Use transitionDelegate for explicit decisions on how _RouteEntry(s)
    //    transition in or off the screens.
    // 7. Fill pageless routes back into the new history.

    bool needsExplicitDecision = false;
    int newPagesBottom = 0;
    int oldEntriesBottom = 0;
    int newPagesTop = widget.pages.length - 1;
    int oldEntriesTop = _history.length - 1;

    final List<_RouteEntry> newHistory = <_RouteEntry>[];
    final Map<_RouteEntry?, List<_RouteEntry>> pageRouteToPagelessRoutes =
        <_RouteEntry?, List<_RouteEntry>>{};

    // Updates the bottom of the list.
    _RouteEntry? previousOldPageRouteEntry;
    while (oldEntriesBottom <= oldEntriesTop) {
      final _RouteEntry oldEntry = _history[oldEntriesBottom];
      assert(oldEntry.currentState != _RouteLifecycle.disposed);
      // Records pageless route. The bottom most pageless routes will be
      // stored in key = null.
      if (!oldEntry.pageBased) {
        final List<_RouteEntry> pagelessRoutes =
            pageRouteToPagelessRoutes.putIfAbsent(
          previousOldPageRouteEntry,
          () => <_RouteEntry>[],
        );
        pagelessRoutes.add(oldEntry);
        oldEntriesBottom += 1;
        continue;
      }
      if (newPagesBottom > newPagesTop) {
        break;
      }
      final Page<dynamic> newPage = widget.pages[newPagesBottom];
      if (!oldEntry.canUpdateFrom(newPage)) {
        break;
      }
      previousOldPageRouteEntry = oldEntry;
      oldEntry.route._updateSettings(newPage);
      newHistory.add(oldEntry);
      newPagesBottom += 1;
      oldEntriesBottom += 1;
    }

    final List<_RouteEntry> unattachedPagelessRoutes = <_RouteEntry>[];
    // Scans the top of the list until we found a page-based route that cannot be
    // updated.
    while ((oldEntriesBottom <= oldEntriesTop) &&
        (newPagesBottom <= newPagesTop)) {
      final _RouteEntry oldEntry = _history[oldEntriesTop];
      assert(oldEntry.currentState != _RouteLifecycle.disposed);
      if (!oldEntry.pageBased) {
        unattachedPagelessRoutes.add(oldEntry);
        oldEntriesTop -= 1;
        continue;
      }
      final Page<dynamic> newPage = widget.pages[newPagesTop];
      if (!oldEntry.canUpdateFrom(newPage)) {
        break;
      }

      // We found the page for all the consecutive pageless routes below. Attach these
      // pageless routes to the page.
      if (unattachedPagelessRoutes.isNotEmpty) {
        pageRouteToPagelessRoutes.putIfAbsent(
          oldEntry,
          () => List<_RouteEntry>.from(unattachedPagelessRoutes),
        );
        unattachedPagelessRoutes.clear();
      }

      oldEntriesTop -= 1;
      newPagesTop -= 1;
    }
    // Reverts the pageless routes that cannot be updated.
    oldEntriesTop += unattachedPagelessRoutes.length;

    // Scans middle of the old entries and records the page key to old entry map.
    int oldEntriesBottomToScan = oldEntriesBottom;
    final Map<LocalKey, _RouteEntry> pageKeyToOldEntry =
        <LocalKey, _RouteEntry>{};
    // This set contains entries that are transitioning out but are still in
    // the route stack.
    final Set<_RouteEntry> phantomEntries = <_RouteEntry>{};
    while (oldEntriesBottomToScan <= oldEntriesTop) {
      final _RouteEntry oldEntry = _history[oldEntriesBottomToScan];
      oldEntriesBottomToScan += 1;
      assert(
        oldEntry.currentState != _RouteLifecycle.disposed,
      );
      // Pageless routes will be recorded when we update the middle of the old
      // list.
      if (!oldEntry.pageBased) {
        continue;
      }

      final Page<dynamic> page = oldEntry.route.settings as Page<dynamic>;
      if (page.key == null) {
        continue;
      }

      if (!oldEntry.willBePresent) {
        phantomEntries.add(oldEntry);
        continue;
      }
      assert(!pageKeyToOldEntry.containsKey(page.key));
      pageKeyToOldEntry[page.key!] = oldEntry;
    }

    // Updates the middle of the list.
    while (newPagesBottom <= newPagesTop) {
      final Page<dynamic> nextPage = widget.pages[newPagesBottom];
      newPagesBottom += 1;
      if (nextPage.key == null ||
          !pageKeyToOldEntry.containsKey(nextPage.key) ||
          !pageKeyToOldEntry[nextPage.key]!.canUpdateFrom(nextPage)) {
        // There is no matching key in the old history, we need to create a new
        // route and wait for the transition delegate to decide how to add
        // it into the history.
        final _RouteEntry newEntry = _RouteEntry(
          nextPage.createRoute(context),
          pageBased: true,
          initialState: _RouteLifecycle.staging,
        );
        needsExplicitDecision = true;
        assert(
          newEntry.route.settings == nextPage,
          'The settings getter of a page-based Route must return a Page object. '
          'Please set the settings to the Page in the Page.createRoute method.',
        );
        newHistory.add(newEntry);
      } else {
        // Removes the key from pageKeyToOldEntry to indicate it is taken.
        final _RouteEntry matchingEntry =
            pageKeyToOldEntry.remove(nextPage.key)!;
        assert(matchingEntry.canUpdateFrom(nextPage));
        matchingEntry.route._updateSettings(nextPage);
        newHistory.add(matchingEntry);
      }
    }

    // Any remaining old routes that do not have a match will need to be removed.
    final Map<RouteTransitionRecord?, RouteTransitionRecord>
        locationToExitingPageRoute =
        <RouteTransitionRecord?, RouteTransitionRecord>{};
    while (oldEntriesBottom <= oldEntriesTop) {
      final _RouteEntry potentialEntryToRemove = _history[oldEntriesBottom];
      oldEntriesBottom += 1;

      if (!potentialEntryToRemove.pageBased) {
        assert(previousOldPageRouteEntry != null);
        final List<_RouteEntry> pagelessRoutes =
            pageRouteToPagelessRoutes.putIfAbsent(
          previousOldPageRouteEntry,
          () => <_RouteEntry>[],
        );
        pagelessRoutes.add(potentialEntryToRemove);
        if (previousOldPageRouteEntry!.isWaitingForExitingDecision &&
            potentialEntryToRemove.willBePresent) {
          potentialEntryToRemove.markNeedsExitingDecision();
        }
        continue;
      }

      final Page<dynamic> potentialPageToRemove =
          potentialEntryToRemove.route.settings as Page<dynamic>;
      // Marks for transition delegate to remove if this old page does not have
      // a key, was not taken during updating the middle of new page, or is
      // already transitioning out.
      if (potentialPageToRemove.key == null ||
          pageKeyToOldEntry.containsKey(potentialPageToRemove.key) ||
          phantomEntries.contains(potentialEntryToRemove)) {
        locationToExitingPageRoute[previousOldPageRouteEntry] =
            potentialEntryToRemove;
        // We only need a decision if it has not already been popped.
        if (potentialEntryToRemove.willBePresent) {
          potentialEntryToRemove.markNeedsExitingDecision();
        }
      }
      previousOldPageRouteEntry = potentialEntryToRemove;
    }

    // We've scanned the whole list.
    assert(oldEntriesBottom == oldEntriesTop + 1);
    assert(newPagesBottom == newPagesTop + 1);
    newPagesTop = widget.pages.length - 1;
    oldEntriesTop = _history.length - 1;
    // Verifies we either reach the bottom or the oldEntriesBottom must be updatable
    // by newPagesBottom.
    assert(() {
      if (oldEntriesBottom <= oldEntriesTop) {
        return newPagesBottom <= newPagesTop &&
            _history[oldEntriesBottom].pageBased &&
            _history[oldEntriesBottom]
                .canUpdateFrom(widget.pages[newPagesBottom]);
      } else {
        return newPagesBottom > newPagesTop;
      }
    }());

    // Updates the top of the list.
    while ((oldEntriesBottom <= oldEntriesTop) &&
        (newPagesBottom <= newPagesTop)) {
      final _RouteEntry oldEntry = _history[oldEntriesBottom];
      assert(oldEntry.currentState != _RouteLifecycle.disposed);
      if (!oldEntry.pageBased) {
        assert(previousOldPageRouteEntry != null);
        final List<_RouteEntry> pagelessRoutes =
            pageRouteToPagelessRoutes.putIfAbsent(
          previousOldPageRouteEntry,
          () => <_RouteEntry>[],
        );
        pagelessRoutes.add(oldEntry);
        continue;
      }
      previousOldPageRouteEntry = oldEntry;
      final Page<dynamic> newPage = widget.pages[newPagesBottom];
      assert(oldEntry.canUpdateFrom(newPage));
      oldEntry.route._updateSettings(newPage);
      newHistory.add(oldEntry);
      oldEntriesBottom += 1;
      newPagesBottom += 1;
    }

    // Finally, uses transition delegate to make explicit decision if needed.
    needsExplicitDecision =
        needsExplicitDecision || locationToExitingPageRoute.isNotEmpty;
    Iterable<_RouteEntry> results = newHistory;
    if (needsExplicitDecision) {
      results = widget.transitionDelegate
          ._transition(
            newPageRouteHistory: newHistory,
            locationToExitingPageRoute: locationToExitingPageRoute,
            pageRouteToPagelessRoutes: pageRouteToPagelessRoutes,
          )
          .cast<_RouteEntry>();
    }
    _history.clear();
    // Adds the leading pageless routes if there is any.
    if (pageRouteToPagelessRoutes.containsKey(null)) {
      _history.addAll(pageRouteToPagelessRoutes[null]!);
    }
    for (final _RouteEntry result in results) {
      _history.add(result);
      if (pageRouteToPagelessRoutes.containsKey(result)) {
        _history.addAll(pageRouteToPagelessRoutes[result]!);
      }
    }
    assert(() {
      _debugUpdatingPage = false;
      return true;
    }());
    assert(() {
      _debugLocked = true;
      return true;
    }());
    _flushHistoryUpdates();
    assert(() {
      _debugLocked = false;
      return true;
    }());
  }

  bool _flushingHistory = false;

  void _flushHistoryUpdates({bool rearrangeOverlay = true}) {
    assert(_debugLocked && !_debugUpdatingPage);
    _flushingHistory = true;
    // Clean up the list, sending updates to the routes that changed. Notably,
    // we don't send the didChangePrevious/didChangeNext updates to those that
    // did not change at this point, because we're not yet sure exactly what the
    // routes will be at the end of the day (some might get disposed).
    int index = _history.length - 1;
    _RouteEntry? next;
    _RouteEntry? entry = _history[index];
    _RouteEntry? previous = index > 0 ? _history[index - 1] : null;
    bool canRemoveOrAdd =
        false; // Whether there is a fully opaque route on top to silently remove or add route underneath.
    Route<dynamic>?
        poppedRoute; // The route that should trigger didPopNext on the top active route.
    bool seenTopActiveRoute =
        false; // Whether we've seen the route that would get didPopNext.
    final List<_RouteEntry> toBeDisposed = <_RouteEntry>[];
    while (index >= 0) {
      switch (entry!.currentState) {
        case _RouteLifecycle.add:
          assert(rearrangeOverlay);
          entry.handleAdd(
            navigator: this,
            previousPresent:
                _getRouteBefore(index - 1, _RouteEntry.isPresentPredicate)
                    ?.route,
          );
          assert(entry.currentState == _RouteLifecycle.adding);
          continue;
        case _RouteLifecycle.adding:
          if (canRemoveOrAdd || next == null) {
            entry.didAdd(
              navigator: this,
              isNewFirst: next == null,
            );
            assert(entry.currentState == _RouteLifecycle.idle);
            continue;
          }
        case _RouteLifecycle.push:
        case _RouteLifecycle.pushReplace:
        case _RouteLifecycle.replace:
          assert(rearrangeOverlay);
          entry.handlePush(
            navigator: this,
            previous: previous?.route,
            previousPresent:
                _getRouteBefore(index - 1, _RouteEntry.isPresentPredicate)
                    ?.route,
            isNewFirst: next == null,
          );
          assert(entry.currentState != _RouteLifecycle.push);
          assert(entry.currentState != _RouteLifecycle.pushReplace);
          assert(entry.currentState != _RouteLifecycle.replace);
          if (entry.currentState == _RouteLifecycle.idle) {
            continue;
          }
        case _RouteLifecycle
              .pushing: // Will exit this state when animation completes.
          if (!seenTopActiveRoute && poppedRoute != null) {
            entry.handleDidPopNext(poppedRoute);
          }
          seenTopActiveRoute = true;
        case _RouteLifecycle.idle:
          if (!seenTopActiveRoute && poppedRoute != null) {
            entry.handleDidPopNext(poppedRoute);
          }
          seenTopActiveRoute = true;
          // This route is idle, so we are allowed to remove subsequent (earlier)
          // routes that are waiting to be removed silently:
          canRemoveOrAdd = true;
        case _RouteLifecycle.pop:
          if (!entry.handlePop(
              navigator: this,
              previousPresent:
                  _getRouteBefore(index, _RouteEntry.willBePresentPredicate)
                      ?.route)) {
            assert(entry.currentState == _RouteLifecycle.idle);
            continue;
          }
          if (!seenTopActiveRoute) {
            if (poppedRoute != null) {
              entry.handleDidPopNext(poppedRoute);
            }
            poppedRoute = entry.route;
          }
          _observedRouteDeletions.add(
            _NavigatorPopObservation(
                entry.route,
                _getRouteBefore(index, _RouteEntry.willBePresentPredicate)
                    ?.route),
          );
          if (entry.currentState == _RouteLifecycle.dispose) {
            // The pop finished synchronously. This can happen if transition
            // duration is zero.
            continue;
          }
          assert(entry.currentState == _RouteLifecycle.popping);
          canRemoveOrAdd = true;
        case _RouteLifecycle.popping:
          // Will exit this state when animation completes.
          break;
        case _RouteLifecycle.complete:
          entry.handleComplete();
          assert(entry.currentState == _RouteLifecycle.remove);
          continue;
        case _RouteLifecycle.remove:
          if (!seenTopActiveRoute) {
            if (poppedRoute != null) {
              entry.route.didPopNext(poppedRoute);
            }
            poppedRoute = null;
          }
          entry.handleRemoval(
            navigator: this,
            previousPresent:
                _getRouteBefore(index, _RouteEntry.willBePresentPredicate)
                    ?.route,
          );
          assert(entry.currentState == _RouteLifecycle.removing);
          continue;
        case _RouteLifecycle.removing:
          if (!canRemoveOrAdd && next != null) {
            // We aren't allowed to remove this route yet.
            break;
          }
          entry.currentState = _RouteLifecycle.dispose;
          continue;
        case _RouteLifecycle.dispose:
          // Delay disposal until didChangeNext/didChangePrevious have been sent.
          toBeDisposed.add(_history.removeAt(index));
          entry = next;
        case _RouteLifecycle.disposing:
        case _RouteLifecycle.disposed:
        case _RouteLifecycle.staging:
          assert(false);
      }
      index -= 1;
      next = entry;
      entry = previous;
      previous = index > 0 ? _history[index - 1] : null;
    }
    // Informs navigator observers about route changes.
    _flushObserverNotifications();

    // Now that the list is clean, send the didChangeNext/didChangePrevious
    // notifications.
    _flushRouteAnnouncement();

    // Announce route name changes.
    if (widget.reportsRouteUpdateToEngine) {
      final _RouteEntry? lastEntry =
          _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
      final String? routeName = lastEntry?.route.settings.name;
      if (routeName != null && routeName != _lastAnnouncedRouteName) {
        SystemNavigator.routeInformationUpdated(uri: Uri.parse(routeName));
        _lastAnnouncedRouteName = routeName;
      }
    }

    // Lastly, removes the overlay entries of all marked entries and disposes
    // them.
    for (final _RouteEntry entry in toBeDisposed) {
      _disposeRouteEntry(entry, graceful: true);
    }
    if (rearrangeOverlay) {
      overlay?.rearrange(_allRouteOverlayEntries);
    }
    if (bucket != null) {
      _serializableHistory.update(_history);
    }
    _flushingHistory = false;
  }

  void _flushObserverNotifications() {
    if (_effectiveObservers.isEmpty) {
      _observedRouteDeletions.clear();
      _observedRouteAdditions.clear();
      return;
    }
    while (_observedRouteAdditions.isNotEmpty) {
      final _NavigatorObservation observation =
          _observedRouteAdditions.removeLast();
      _effectiveObservers.forEach(observation.notify);
    }

    while (_observedRouteDeletions.isNotEmpty) {
      final _NavigatorObservation observation =
          _observedRouteDeletions.removeFirst();
      _effectiveObservers.forEach(observation.notify);
    }
  }

  void _flushRouteAnnouncement() {
    int index = _history.length - 1;
    while (index >= 0) {
      final _RouteEntry entry = _history[index];
      if (!entry.suitableForAnnouncement) {
        index -= 1;
        continue;
      }
      final _RouteEntry? next = _getRouteAfter(
          index + 1, _RouteEntry.suitableForTransitionAnimationPredicate);

      if (next?.route != entry.lastAnnouncedNextRoute) {
        if (entry.shouldAnnounceChangeToNext(next?.route)) {
          entry.route.didChangeNext(next?.route);
        }
        entry.lastAnnouncedNextRoute = next?.route;
      }
      final _RouteEntry? previous = _getRouteBefore(
          index - 1, _RouteEntry.suitableForTransitionAnimationPredicate);
      if (previous?.route != entry.lastAnnouncedPreviousRoute) {
        entry.route.didChangePrevious(previous?.route);
        entry.lastAnnouncedPreviousRoute = previous?.route;
      }
      index -= 1;
    }
  }

  _RouteEntry? _getRouteBefore(int index, _RouteEntryPredicate predicate) {
    index = _getIndexBefore(index, predicate);
    return index >= 0 ? _history[index] : null;
  }

  int _getIndexBefore(int index, _RouteEntryPredicate predicate) {
    while (index >= 0 && !predicate(_history[index])) {
      index -= 1;
    }
    return index;
  }

  _RouteEntry? _getRouteAfter(int index, _RouteEntryPredicate predicate) {
    while (index < _history.length && !predicate(_history[index])) {
      index += 1;
    }
    return index < _history.length ? _history[index] : null;
  }

  Route<T?>? _routeNamed<T>(String name,
      {required Object? arguments, bool allowNull = false}) {
    assert(!_debugLocked);
    if (allowNull && widget.onGenerateRoute == null) {
      return null;
    }
    assert(() {
      if (widget.onGenerateRoute == null) {
        throw FlutterError(
          'Navigator.onGenerateRoute was null, but the route named "$name" was referenced.\n'
          'To use the Navigator API with named routes (pushNamed, pushReplacementNamed, or '
          'pushNamedAndRemoveUntil), the Navigator must be provided with an '
          'onGenerateRoute handler.\n'
          'The Navigator was:\n'
          '  $this',
        );
      }
      return true;
    }());
    final RouteSettings settings = RouteSettings(
      name: name,
      arguments: arguments,
    );
    Route<T?>? route = widget.onGenerateRoute!(settings) as Route<T?>?;
    if (route == null && !allowNull) {
      assert(() {
        if (widget.onUnknownRoute == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
                'Navigator.onGenerateRoute returned null when requested to build route "$name".'),
            ErrorDescription(
              'The onGenerateRoute callback must never return null, unless an onUnknownRoute '
              'callback is provided as well.',
            ),
            DiagnosticsProperty<NavigatorState>('The Navigator was', this,
                style: DiagnosticsTreeStyle.errorProperty),
          ]);
        }
        return true;
      }());
      route = widget.onUnknownRoute!(settings) as Route<T?>?;
      assert(() {
        if (route == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
                'Navigator.onUnknownRoute returned null when requested to build route "$name".'),
            ErrorDescription(
                'The onUnknownRoute callback must never return null.'),
            DiagnosticsProperty<NavigatorState>('The Navigator was', this,
                style: DiagnosticsTreeStyle.errorProperty),
          ]);
        }
        return true;
      }());
    }
    assert(route != null || allowNull);
    return route;
  }

  @optionalTypeArgs
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return push<T?>(_routeNamed<T>(routeName, arguments: arguments)!);
  }

  @optionalTypeArgs
  String restorablePushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.named(
      name: routeName,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.push);
    _pushEntry(entry);
    return entry.restorationId!;
  }

  @optionalTypeArgs
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return pushReplacement<T?, TO>(
        _routeNamed<T>(routeName, arguments: arguments)!,
        result: result);
  }

  @optionalTypeArgs
  String restorablePushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.named(
      name: routeName,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.pushReplace);
    _pushReplacementEntry(entry, result);
    return entry.restorationId!;
  }

  @optionalTypeArgs
  Future<T?> popAndPushNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    pop<TO>(result);
    return pushNamed<T>(routeName, arguments: arguments);
  }

  @optionalTypeArgs
  String restorablePopAndPushNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    pop<TO>(result);
    return restorablePushNamed(routeName, arguments: arguments);
  }

  @optionalTypeArgs
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return pushAndRemoveUntil<T?>(
        _routeNamed<T>(newRouteName, arguments: arguments)!, predicate);
  }

  @optionalTypeArgs
  String restorablePushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.named(
      name: newRouteName,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.push);
    _pushEntryAndRemoveUntil(entry, predicate);
    return entry.restorationId!;
  }

  @optionalTypeArgs
  Future<T?> push<T extends Object?>(Route<T> route) {
    _pushEntry(_RouteEntry(route,
        pageBased: false, initialState: _RouteLifecycle.push));
    return route.popped;
  }

  bool _debugIsStaticCallback(Function callback) {
    bool result = false;
    assert(() {
      // TODO(goderbauer): remove the kIsWeb check when https://github.com/flutter/flutter/issues/33615 is resolved.
      result = kIsWeb || ui.PluginUtilities.getCallbackHandle(callback) != null;
      return true;
    }());
    return result;
  }

  @optionalTypeArgs
  String restorablePush<T extends Object?>(
      RestorableRouteBuilder<T> routeBuilder,
      {Object? arguments}) {
    assert(_debugIsStaticCallback(routeBuilder),
        'The provided routeBuilder must be a static function.');
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.anonymous(
      routeBuilder: routeBuilder,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.push);
    _pushEntry(entry);
    return entry.restorationId!;
  }

  void _pushEntry(_RouteEntry entry) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(entry.route._navigator == null);
    assert(entry.currentState == _RouteLifecycle.push);
    _history.add(entry);
    _flushHistoryUpdates();
    assert(() {
      _debugLocked = false;
      return true;
    }());
    _afterNavigation(entry.route);
  }

  void _afterNavigation(Route<dynamic>? route) {
    if (!kReleaseMode) {
      // Among other uses, performance tools use this event to ensure that perf
      // stats reflect the time interval since the last navigation event
      // occurred, ensuring that stats only reflect the current page.

      Map<String, dynamic>? routeJsonable;
      if (route != null) {
        routeJsonable = <String, dynamic>{};

        final String description;
        if (route is TransitionRoute<dynamic>) {
          final TransitionRoute<dynamic> transitionRoute = route;
          description = transitionRoute.debugLabel;
        } else {
          description = '$route';
        }
        routeJsonable['description'] = description;

        final RouteSettings settings = route.settings;
        final Map<String, dynamic> settingsJsonable = <String, dynamic>{
          'name': settings.name,
        };
        if (settings.arguments != null) {
          settingsJsonable['arguments'] = jsonEncode(
            settings.arguments,
            toEncodable: (Object? object) => '$object',
          );
        }
        routeJsonable['settings'] = settingsJsonable;
      }

      developer.postEvent('Flutter.Navigation', <String, dynamic>{
        'route': routeJsonable,
      });
    }
    _cancelActivePointers();
  }

  @optionalTypeArgs
  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
      Route<T> newRoute,
      {TO? result}) {
    assert(newRoute._navigator == null);
    _pushReplacementEntry(
        _RouteEntry(newRoute,
            pageBased: false, initialState: _RouteLifecycle.pushReplace),
        result);
    return newRoute.popped;
  }

  @optionalTypeArgs
  String restorablePushReplacement<T extends Object?, TO extends Object?>(
      RestorableRouteBuilder<T> routeBuilder,
      {TO? result,
      Object? arguments}) {
    assert(_debugIsStaticCallback(routeBuilder),
        'The provided routeBuilder must be a static function.');
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.anonymous(
      routeBuilder: routeBuilder,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.pushReplace);
    _pushReplacementEntry(entry, result);
    return entry.restorationId!;
  }

  void _pushReplacementEntry<TO extends Object?>(
      _RouteEntry entry, TO? result) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(entry.route._navigator == null);
    assert(_history.isNotEmpty);
    assert(_history.any(_RouteEntry.isPresentPredicate),
        'Navigator has no active routes to replace.');
    assert(entry.currentState == _RouteLifecycle.pushReplace);
    _history
        .lastWhere(_RouteEntry.isPresentPredicate)
        .complete(result, isReplaced: true);
    _history.add(entry);
    _flushHistoryUpdates();
    assert(() {
      _debugLocked = false;
      return true;
    }());
    _afterNavigation(entry.route);
  }

  @optionalTypeArgs
  Future<T?> pushAndRemoveUntil<T extends Object?>(
      Route<T> newRoute, RoutePredicate predicate) {
    assert(newRoute._navigator == null);
    assert(newRoute.overlayEntries.isEmpty);
    _pushEntryAndRemoveUntil(
        _RouteEntry(newRoute,
            pageBased: false, initialState: _RouteLifecycle.push),
        predicate);
    return newRoute.popped;
  }

  @optionalTypeArgs
  String restorablePushAndRemoveUntil<T extends Object?>(
      RestorableRouteBuilder<T> newRouteBuilder, RoutePredicate predicate,
      {Object? arguments}) {
    assert(_debugIsStaticCallback(newRouteBuilder),
        'The provided routeBuilder must be a static function.');
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.anonymous(
      routeBuilder: newRouteBuilder,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.push);
    _pushEntryAndRemoveUntil(entry, predicate);
    return entry.restorationId!;
  }

  void _pushEntryAndRemoveUntil(_RouteEntry entry, RoutePredicate predicate) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(entry.route._navigator == null);
    assert(entry.route.overlayEntries.isEmpty);
    assert(entry.currentState == _RouteLifecycle.push);
    int index = _history.length - 1;
    _history.add(entry);
    while (index >= 0 && !predicate(_history[index].route)) {
      if (_history[index].isPresent) {
        _history[index].remove();
      }
      index -= 1;
    }
    _flushHistoryUpdates();

    assert(() {
      _debugLocked = false;
      return true;
    }());
    _afterNavigation(entry.route);
  }

  @optionalTypeArgs
  void replace<T extends Object?>(
      {required Route<dynamic> oldRoute, required Route<T> newRoute}) {
    assert(!_debugLocked);
    assert(oldRoute._navigator == this);
    _replaceEntry(
        _RouteEntry(newRoute,
            pageBased: false, initialState: _RouteLifecycle.replace),
        oldRoute);
  }

  @optionalTypeArgs
  String restorableReplace<T extends Object?>(
      {required Route<dynamic> oldRoute,
      required RestorableRouteBuilder<T> newRouteBuilder,
      Object? arguments}) {
    assert(oldRoute._navigator == this);
    assert(_debugIsStaticCallback(newRouteBuilder),
        'The provided routeBuilder must be a static function.');
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.anonymous(
      routeBuilder: newRouteBuilder,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.replace);
    _replaceEntry(entry, oldRoute);
    return entry.restorationId!;
  }

  void _replaceEntry(_RouteEntry entry, Route<dynamic> oldRoute) {
    assert(!_debugLocked);
    if (oldRoute == entry.route) {
      return;
    }
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(entry.currentState == _RouteLifecycle.replace);
    assert(entry.route._navigator == null);
    final int index =
        _history.indexWhere(_RouteEntry.isRoutePredicate(oldRoute));
    assert(
        index >= 0, 'This Navigator does not contain the specified oldRoute.');
    assert(_history[index].isPresent,
        'The specified oldRoute has already been removed from the Navigator.');
    final bool wasCurrent = oldRoute.isCurrent;
    _history.insert(index + 1, entry);
    _history[index].remove(isReplaced: true);
    _flushHistoryUpdates();
    assert(() {
      _debugLocked = false;
      return true;
    }());
    if (wasCurrent) {
      _afterNavigation(entry.route);
    }
  }

  @optionalTypeArgs
  void replaceRouteBelow<T extends Object?>(
      {required Route<dynamic> anchorRoute, required Route<T> newRoute}) {
    assert(newRoute._navigator == null);
    assert(anchorRoute._navigator == this);
    _replaceEntryBelow(
        _RouteEntry(newRoute,
            pageBased: false, initialState: _RouteLifecycle.replace),
        anchorRoute);
  }

  @optionalTypeArgs
  String restorableReplaceRouteBelow<T extends Object?>(
      {required Route<dynamic> anchorRoute,
      required RestorableRouteBuilder<T> newRouteBuilder,
      Object? arguments}) {
    assert(anchorRoute._navigator == this);
    assert(_debugIsStaticCallback(newRouteBuilder),
        'The provided routeBuilder must be a static function.');
    assert(debugIsSerializableForRestoration(arguments),
        'The arguments object must be serializable via the StandardMessageCodec.');
    final _RouteEntry entry = _RestorationInformation.anonymous(
      routeBuilder: newRouteBuilder,
      arguments: arguments,
      restorationScopeId: _nextPagelessRestorationScopeId,
    ).toRouteEntry(this, initialState: _RouteLifecycle.replace);
    _replaceEntryBelow(entry, anchorRoute);
    return entry.restorationId!;
  }

  void _replaceEntryBelow(_RouteEntry entry, Route<dynamic> anchorRoute) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    final int anchorIndex =
        _history.indexWhere(_RouteEntry.isRoutePredicate(anchorRoute));
    assert(anchorIndex >= 0,
        'This Navigator does not contain the specified anchorRoute.');
    assert(_history[anchorIndex].isPresent,
        'The specified anchorRoute has already been removed from the Navigator.');
    int index = anchorIndex - 1;
    while (index >= 0) {
      if (_history[index].isPresent) {
        break;
      }
      index -= 1;
    }
    assert(index >= 0, 'There are no routes below the specified anchorRoute.');
    _history.insert(index + 1, entry);
    _history[index].remove(isReplaced: true);
    _flushHistoryUpdates();
    assert(() {
      _debugLocked = false;
      return true;
    }());
  }

  bool canPop() {
    final Iterator<_RouteEntry> iterator =
        _history.where(_RouteEntry.isPresentPredicate).iterator;
    if (!iterator.moveNext()) {
      // We have no active routes, so we can't pop.
      return false;
    }
    if (iterator.current.route.willHandlePopInternally) {
      // The first route can handle pops itself, so we can pop.
      return true;
    }
    if (!iterator.moveNext()) {
      // There's only one route, so we can't pop.
      return false;
    }
    return true; // there's at least two routes, so we can pop
  }

  @optionalTypeArgs
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    final _RouteEntry? lastEntry =
        _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
    if (lastEntry == null) {
      return false;
    }
    assert(lastEntry.route._navigator == this);

    // TODO(justinmc): When the deprecated willPop method is removed, delete
    // this code and use only popDisposition, below.
    final RoutePopDisposition willPopDisposition =
        await lastEntry.route.willPop();
    if (!mounted) {
      // Forget about this pop, we were disposed in the meantime.
      return true;
    }
    if (willPopDisposition == RoutePopDisposition.doNotPop) {
      return true;
    }
    final _RouteEntry? newLastEntry =
        _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
    if (lastEntry != newLastEntry) {
      // Forget about this pop, something happened to our history in the meantime.
      return true;
    }

    switch (lastEntry.route.popDisposition) {
      case RoutePopDisposition.bubble:
        return false;
      case RoutePopDisposition.pop:
        pop(result);
        return true;
      case RoutePopDisposition.doNotPop:
        lastEntry.route.onPopInvoked(false);
        return true;
    }
  }

  @optionalTypeArgs
  void pop<T extends Object?>([T? result]) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    final _RouteEntry entry =
        _history.lastWhere(_RouteEntry.isPresentPredicate);
    if (entry.pageBased) {
      if (widget.onPopPage!(entry.route, result) &&
          entry.currentState == _RouteLifecycle.idle) {
        // The entry may have been disposed if the pop finishes synchronously.
        assert(entry.route._popCompleter.isCompleted);
        entry.currentState = _RouteLifecycle.pop;
      }
    } else {
      entry.pop<T>(result);
      assert(entry.currentState == _RouteLifecycle.pop);
    }
    if (entry.currentState == _RouteLifecycle.pop) {
      _flushHistoryUpdates(rearrangeOverlay: false);
    }
    assert(entry.currentState == _RouteLifecycle.idle ||
        entry.route._popCompleter.isCompleted);
    assert(() {
      _debugLocked = false;
      return true;
    }());
    _afterNavigation(entry.route);
  }

  void popUntil(RoutePredicate predicate) {
    _RouteEntry? candidate =
        _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
    while (candidate != null) {
      if (predicate(candidate.route)) {
        return;
      }
      pop();
      candidate = _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate);
    }
  }

  void removeRoute(Route<dynamic> route) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(route._navigator == this);
    final bool wasCurrent = route.isCurrent;
    final _RouteEntry entry =
        _history.firstWhere(_RouteEntry.isRoutePredicate(route));
    entry.remove();
    _flushHistoryUpdates(rearrangeOverlay: false);
    assert(() {
      _debugLocked = false;
      return true;
    }());
    if (wasCurrent) {
      _afterNavigation(
        _lastRouteEntryWhereOrNull(_RouteEntry.isPresentPredicate)?.route,
      );
    }
  }

  void removeRouteBelow(Route<dynamic> anchorRoute) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    }());
    assert(anchorRoute._navigator == this);
    final int anchorIndex =
        _history.indexWhere(_RouteEntry.isRoutePredicate(anchorRoute));
    assert(anchorIndex >= 0,
        'This Navigator does not contain the specified anchorRoute.');
    assert(_history[anchorIndex].isPresent,
        'The specified anchorRoute has already been removed from the Navigator.');
    int index = anchorIndex - 1;
    while (index >= 0) {
      if (_history[index].isPresent) {
        break;
      }
      index -= 1;
    }
    assert(index >= 0, 'There are no routes below the specified anchorRoute.');
    _history[index].remove();
    _flushHistoryUpdates(rearrangeOverlay: false);
    assert(() {
      _debugLocked = false;
      return true;
    }());
  }

  void finalizeRoute(Route<dynamic> route) {
    // FinalizeRoute may have been called while we were already locked as a
    // responds to route.didPop(). Make sure to leave in the state we were in
    // before the call.
    bool? wasDebugLocked;
    assert(() {
      wasDebugLocked = _debugLocked;
      _debugLocked = true;
      return true;
    }());
    assert(_history.where(_RouteEntry.isRoutePredicate(route)).length == 1);
    final int index = _history.indexWhere(_RouteEntry.isRoutePredicate(route));
    final _RouteEntry entry = _history[index];
    // For page-based route with zero transition, the finalizeRoute can be
    // called on any life cycle above pop.
    if (entry.pageBased &&
        entry.currentState.index < _RouteLifecycle.pop.index) {
      _observedRouteDeletions.add(_NavigatorPopObservation(
          route,
          _getRouteBefore(index - 1, _RouteEntry.willBePresentPredicate)
              ?.route));
    } else {
      assert(entry.currentState == _RouteLifecycle.popping);
    }
    entry.finalize();
    // finalizeRoute can be called during _flushHistoryUpdates if a pop
    // finishes synchronously.
    if (!_flushingHistory) {
      _flushHistoryUpdates(rearrangeOverlay: false);
    }

    assert(() {
      _debugLocked = wasDebugLocked!;
      return true;
    }());
  }

  @optionalTypeArgs
  Route<T>? _getRouteById<T>(String id) {
    return _firstRouteEntryWhereOrNull(
        (_RouteEntry entry) => entry.restorationId == id)?.route as Route<T>?;
  }

  int get _userGesturesInProgress => _userGesturesInProgressCount;
  int _userGesturesInProgressCount = 0;
  set _userGesturesInProgress(int value) {
    _userGesturesInProgressCount = value;
    userGestureInProgressNotifier.value = _userGesturesInProgress > 0;
  }

  bool get userGestureInProgress => userGestureInProgressNotifier.value;

  final ValueNotifier<bool> userGestureInProgressNotifier =
      ValueNotifier<bool>(false);

  void didStartUserGesture() {
    _userGesturesInProgress += 1;
    if (_userGesturesInProgress == 1) {
      final int routeIndex = _getIndexBefore(
        _history.length - 1,
        _RouteEntry.willBePresentPredicate,
      );
      final Route<dynamic> route = _history[routeIndex].route;
      Route<dynamic>? previousRoute;
      if (!route.willHandlePopInternally && routeIndex > 0) {
        previousRoute = _getRouteBefore(
          routeIndex - 1,
          _RouteEntry.willBePresentPredicate,
        )!
            .route;
      }
      for (final NavigatorObserver observer in _effectiveObservers) {
        observer.didStartUserGesture(route, previousRoute);
      }
    }
  }

  void didStopUserGesture() {
    assert(_userGesturesInProgress > 0);
    _userGesturesInProgress -= 1;
    if (_userGesturesInProgress == 0) {
      for (final NavigatorObserver observer in _effectiveObservers) {
        observer.didStopUserGesture();
      }
    }
  }

  final Set<int> _activePointers = <int>{};

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _cancelActivePointers() {
    // TODO(abarth): This mechanism is far from perfect. See https://github.com/flutter/flutter/issues/4770
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      // If we're between frames (SchedulerPhase.idle) then absorb any
      // subsequent pointers from this frame. The absorbing flag will be
      // reset in the next frame, see build().
      final RenderAbsorbPointer? absorber = _overlayKey.currentContext
          ?.findAncestorRenderObjectOfType<RenderAbsorbPointer>();
      setState(() {
        absorber?.absorbing = true;
        // We do this in setState so that we'll reset the absorbing value back
        // to false on the next frame.
      });
    }
    _activePointers.toList().forEach(WidgetsBinding.instance.cancelPointer);
  }

  _RouteEntry? _firstRouteEntryWhereOrNull(_RouteEntryPredicate test) {
    for (final _RouteEntry element in _history) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }

  _RouteEntry? _lastRouteEntryWhereOrNull(_RouteEntryPredicate test) {
    _RouteEntry? result;
    for (final _RouteEntry element in _history) {
      if (test(element)) {
        result = element;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    assert(!_debugLocked);
    assert(_history.isNotEmpty);

    // Hides the HeroControllerScope for the widget subtree so that the other
    // nested navigator underneath will not pick up the hero controller above
    // this level.
    return HeroControllerScope.none(
      child: NotificationListener<NavigationNotification>(
        onNotification: (NavigationNotification notification) {
          // If the state of this Navigator does not change whether or not the
          // whole framework can pop, propagate the Notification as-is.
          if (notification.canHandlePop || !canPop()) {
            return false;
          }
          // Otherwise, dispatch a new Notification with the correct canPop and
          // stop the propagation of the old Notification.
          const NavigationNotification nextNotification =
              NavigationNotification(
            canHandlePop: true,
          );
          nextNotification.dispatch(context);
          return true;
        },
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUpOrCancel,
          onPointerCancel: _handlePointerUpOrCancel,
          child: AbsorbPointer(
            absorbing:
                false, // it's mutated directly by _cancelActivePointers above
            child: FocusTraversalGroup(
              policy: FocusTraversalGroup.maybeOf(context),
              child: Focus(
                focusNode: focusNode,
                autofocus: true,
                skipTraversal: true,
                includeSemantics: false,
                child: UnmanagedRestorationScope(
                  bucket: bucket,
                  child: Overlay(
                    key: _overlayKey,
                    clipBehavior: widget.clipBehavior,
                    initialEntries: overlay == null
                        ? _allRouteOverlayEntries.toList(growable: false)
                        : const <OverlayEntry>[],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _RouteRestorationType {
  named,
  anonymous,
}

abstract class _RestorationInformation {
  _RestorationInformation(this.type);
  factory _RestorationInformation.named({
    required String name,
    required Object? arguments,
    required int restorationScopeId,
  }) = _NamedRestorationInformation;
  factory _RestorationInformation.anonymous({
    required RestorableRouteBuilder<Object?> routeBuilder,
    required Object? arguments,
    required int restorationScopeId,
  }) = _AnonymousRestorationInformation;

  factory _RestorationInformation.fromSerializableData(Object data) {
    final List<Object?> casted = data as List<Object?>;
    assert(casted.isNotEmpty);
    final _RouteRestorationType type =
        _RouteRestorationType.values[casted[0]! as int];
    switch (type) {
      case _RouteRestorationType.named:
        return _NamedRestorationInformation.fromSerializableData(
            casted.sublist(1));
      case _RouteRestorationType.anonymous:
        return _AnonymousRestorationInformation.fromSerializableData(
            casted.sublist(1));
    }
  }

  final _RouteRestorationType type;
  int get restorationScopeId;
  Object? _serializableData;

  bool get isRestorable => true;

  Object getSerializableData() {
    _serializableData ??= computeSerializableData();
    return _serializableData!;
  }

  @mustCallSuper
  List<Object> computeSerializableData() {
    return <Object>[type.index];
  }

  @protected
  Route<dynamic> createRoute(NavigatorState navigator);

  _RouteEntry toRouteEntry(NavigatorState navigator,
      {_RouteLifecycle initialState = _RouteLifecycle.add}) {
    final Route<Object?> route = createRoute(navigator);
    return _RouteEntry(
      route,
      pageBased: false,
      initialState: initialState,
      restorationInformation: this,
    );
  }
}

class _NamedRestorationInformation extends _RestorationInformation {
  _NamedRestorationInformation({
    required this.name,
    required this.arguments,
    required this.restorationScopeId,
  }) : super(_RouteRestorationType.named);

  factory _NamedRestorationInformation.fromSerializableData(
      List<Object?> data) {
    assert(data.length >= 2);
    return _NamedRestorationInformation(
      restorationScopeId: data[0]! as int,
      name: data[1]! as String,
      arguments: data.length > 2 ? data[2] : null,
    );
  }

  @override
  List<Object> computeSerializableData() {
    return super.computeSerializableData()
      ..addAll(<Object>[
        restorationScopeId,
        name,
        if (arguments != null) arguments!,
      ]);
  }

  @override
  final int restorationScopeId;
  final String name;
  final Object? arguments;

  @override
  Route<dynamic> createRoute(NavigatorState navigator) {
    final Route<dynamic> route =
        navigator._routeNamed<dynamic>(name, arguments: arguments)!;
    return route;
  }
}

class _AnonymousRestorationInformation extends _RestorationInformation {
  _AnonymousRestorationInformation({
    required this.routeBuilder,
    required this.arguments,
    required this.restorationScopeId,
  }) : super(_RouteRestorationType.anonymous);

  factory _AnonymousRestorationInformation.fromSerializableData(
      List<Object?> data) {
    assert(data.length > 1);
    final RestorableRouteBuilder<Object?> routeBuilder =
        ui.PluginUtilities.getCallbackFromHandle(
                ui.CallbackHandle.fromRawHandle(data[1]! as int))!
            as RestorableRouteBuilder;
    return _AnonymousRestorationInformation(
      restorationScopeId: data[0]! as int,
      routeBuilder: routeBuilder,
      arguments: data.length > 2 ? data[2] : null,
    );
  }

  @override
  // TODO(goderbauer): remove the kIsWeb check when https://github.com/flutter/flutter/issues/33615 is resolved.
  bool get isRestorable => !kIsWeb;

  @override
  List<Object> computeSerializableData() {
    assert(isRestorable);
    final ui.CallbackHandle? handle =
        ui.PluginUtilities.getCallbackHandle(routeBuilder);
    assert(handle != null);
    return super.computeSerializableData()
      ..addAll(<Object>[
        restorationScopeId,
        handle!.toRawHandle(),
        if (arguments != null) arguments!,
      ]);
  }

  @override
  final int restorationScopeId;
  final RestorableRouteBuilder<Object?> routeBuilder;
  final Object? arguments;

  @override
  Route<dynamic> createRoute(NavigatorState navigator) {
    final Route<dynamic> result = routeBuilder(navigator.context, arguments);
    return result;
  }
}

class _HistoryProperty extends RestorableProperty<Map<String?, List<Object>>?> {
  // Routes not associated with a page are stored under key 'null'.
  Map<String?, List<Object>>? _pageToPagelessRoutes;

  // Updating.

  void update(_History history) {
    assert(isRegistered);
    final bool wasUninitialized = _pageToPagelessRoutes == null;
    bool needsSerialization = wasUninitialized;
    _pageToPagelessRoutes ??= <String, List<Object>>{};
    _RouteEntry? currentPage;
    List<Object> newRoutesForCurrentPage = <Object>[];
    List<Object> oldRoutesForCurrentPage =
        _pageToPagelessRoutes![null] ?? const <Object>[];
    bool restorationEnabled = true;

    final Map<String?, List<Object>> newMap = <String?, List<Object>>{};
    final Set<String?> removedPages = _pageToPagelessRoutes!.keys.toSet();

    for (final _RouteEntry entry in history) {
      if (!entry.isPresentForRestoration) {
        entry.restorationEnabled = false;
        continue;
      }

      assert(entry.isPresentForRestoration);
      if (entry.pageBased) {
        needsSerialization = needsSerialization ||
            newRoutesForCurrentPage.length != oldRoutesForCurrentPage.length;
        _finalizeEntry(
            newRoutesForCurrentPage, currentPage, newMap, removedPages);
        currentPage = entry;
        restorationEnabled = entry.restorationId != null;
        entry.restorationEnabled = restorationEnabled;
        if (restorationEnabled) {
          assert(entry.restorationId != null);
          newRoutesForCurrentPage = <Object>[];
          oldRoutesForCurrentPage =
              _pageToPagelessRoutes![entry.restorationId] ?? const <Object>[];
        } else {
          newRoutesForCurrentPage = const <Object>[];
          oldRoutesForCurrentPage = const <Object>[];
        }
        continue;
      }

      assert(!entry.pageBased);
      restorationEnabled = restorationEnabled &&
          (entry.restorationInformation?.isRestorable ?? false);
      entry.restorationEnabled = restorationEnabled;
      if (restorationEnabled) {
        assert(entry.restorationId != null);
        assert(currentPage == null || currentPage.restorationId != null);
        assert(entry.restorationInformation != null);
        final Object serializedData =
            entry.restorationInformation!.getSerializableData();
        needsSerialization = needsSerialization ||
            oldRoutesForCurrentPage.length <= newRoutesForCurrentPage.length ||
            oldRoutesForCurrentPage[newRoutesForCurrentPage.length] !=
                serializedData;
        newRoutesForCurrentPage.add(serializedData);
      }
    }
    needsSerialization = needsSerialization ||
        newRoutesForCurrentPage.length != oldRoutesForCurrentPage.length;
    _finalizeEntry(newRoutesForCurrentPage, currentPage, newMap, removedPages);

    needsSerialization = needsSerialization || removedPages.isNotEmpty;

    assert(wasUninitialized ||
        _debugMapsEqual(_pageToPagelessRoutes!, newMap) != needsSerialization);

    if (needsSerialization) {
      _pageToPagelessRoutes = newMap;
      notifyListeners();
    }
  }

  void _finalizeEntry(
    List<Object> routes,
    _RouteEntry? page,
    Map<String?, List<Object>> pageToRoutes,
    Set<String?> pagesToRemove,
  ) {
    assert(page == null || page.pageBased);
    assert(!pageToRoutes.containsKey(page?.restorationId));
    if (routes.isNotEmpty) {
      assert(page == null || page.restorationId != null);
      final String? restorationId = page?.restorationId;
      pageToRoutes[restorationId] = routes;
      pagesToRemove.remove(restorationId);
    }
  }

  bool _debugMapsEqual(
      Map<String?, List<Object>> a, Map<String?, List<Object>> b) {
    if (!setEquals(a.keys.toSet(), b.keys.toSet())) {
      return false;
    }
    for (final String? key in a.keys) {
      if (!listEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }

  void clear() {
    assert(isRegistered);
    if (_pageToPagelessRoutes == null) {
      return;
    }
    _pageToPagelessRoutes = null;
    notifyListeners();
  }

  // Restoration.

  bool get hasData => _pageToPagelessRoutes != null;

  List<_RouteEntry> restoreEntriesForPage(
      _RouteEntry? page, NavigatorState navigator) {
    assert(isRegistered);
    assert(page == null || page.pageBased);
    final List<_RouteEntry> result = <_RouteEntry>[];
    if (_pageToPagelessRoutes == null ||
        (page != null && page.restorationId == null)) {
      return result;
    }
    final List<Object>? serializedData =
        _pageToPagelessRoutes![page?.restorationId];
    if (serializedData == null) {
      return result;
    }
    for (final Object data in serializedData) {
      result.add(_RestorationInformation.fromSerializableData(data)
          .toRouteEntry(navigator));
    }
    return result;
  }

  // RestorableProperty overrides.

  @override
  Map<String?, List<Object>>? createDefaultValue() {
    return null;
  }

  @override
  Map<String?, List<Object>>? fromPrimitives(Object? data) {
    final Map<dynamic, dynamic> casted = data! as Map<dynamic, dynamic>;
    return casted.map<String?, List<Object>>(
        (dynamic key, dynamic value) => MapEntry<String?, List<Object>>(
              key as String?,
              List<Object>.from(value as List<dynamic>),
            ));
  }

  @override
  void initWithValue(Map<String?, List<Object>>? value) {
    _pageToPagelessRoutes = value;
  }

  @override
  Object? toPrimitives() {
    return _pageToPagelessRoutes;
  }

  @override
  bool get enabled => hasData;
}

typedef NavigatorFinderCallback = NavigatorState Function(BuildContext context);

typedef RoutePresentationCallback = String Function(
    NavigatorState navigator, Object? arguments);

typedef RouteCompletionCallback<T> = void Function(T result);

class RestorableRouteFuture<T> extends RestorableProperty<String?> {
  RestorableRouteFuture({
    this.navigatorFinder = _defaultNavigatorFinder,
    required this.onPresent,
    this.onComplete,
  });

  final NavigatorFinderCallback navigatorFinder;

  final RoutePresentationCallback onPresent;

  final RouteCompletionCallback<T>? onComplete;

  void present([Object? arguments]) {
    assert(!isPresent);
    assert(isRegistered);
    final String routeId = onPresent(_navigator, arguments);
    _hookOntoRouteFuture(routeId);
    notifyListeners();
  }

  bool get isPresent => route != null;

  Route<T>? get route => _route;
  Route<T>? _route;

  @override
  String? createDefaultValue() => null;

  @override
  void initWithValue(String? value) {
    if (value != null) {
      _hookOntoRouteFuture(value);
    }
  }

  @override
  Object? toPrimitives() {
    assert(route != null);
    assert(enabled);
    return route?.restorationScopeId.value;
  }

  @override
  String fromPrimitives(Object? data) {
    assert(data != null);
    return data! as String;
  }

  bool _disposed = false;

  @override
  void dispose() {
    super.dispose();
    _route?.restorationScopeId.removeListener(notifyListeners);
    _disposed = true;
  }

  @override
  bool get enabled => route?.restorationScopeId.value != null;

  NavigatorState get _navigator {
    final NavigatorState navigator = navigatorFinder(state.context);
    return navigator;
  }

  void _hookOntoRouteFuture(String id) {
    _route = _navigator._getRouteById<T>(id);
    assert(_route != null);
    route!.restorationScopeId.addListener(notifyListeners);
    route!.popped.then((dynamic result) {
      if (_disposed) {
        return;
      }
      _route?.restorationScopeId.removeListener(notifyListeners);
      _route = null;
      notifyListeners();
      onComplete?.call(result as T);
    });
  }

  static NavigatorState _defaultNavigatorFinder(BuildContext context) =>
      Navigator.of(context);
}

class NavigationNotification extends Notification {
  const NavigationNotification({
    required this.canHandlePop,
  });

  final bool canHandlePop;

  @override
  String toString() {
    return 'NavigationNotification canHandlePop: $canHandlePop';
  }
}
