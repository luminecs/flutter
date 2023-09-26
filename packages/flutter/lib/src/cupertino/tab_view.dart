import 'package:flutter/widgets.dart';

import 'app.dart' show CupertinoApp;
import 'route.dart';

class CupertinoTabView extends StatefulWidget {
  const CupertinoTabView({
    super.key,
    this.builder,
    this.navigatorKey,
    this.defaultTitle,
    this.routes,
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.restorationScopeId,
  });

  final WidgetBuilder? builder;

  final GlobalKey<NavigatorState>? navigatorKey;

  final String? defaultTitle;

  final Map<String, WidgetBuilder>? routes;

  final RouteFactory? onGenerateRoute;

  final RouteFactory? onUnknownRoute;

  final List<NavigatorObserver> navigatorObservers;

  final String? restorationScopeId;

  @override
  State<CupertinoTabView> createState() => _CupertinoTabViewState();
}

class _CupertinoTabViewState extends State<CupertinoTabView> {
  late HeroController _heroController;
  late List<NavigatorObserver> _navigatorObservers;

  @override
  void initState() {
    super.initState();
    _heroController = CupertinoApp.createCupertinoHeroController();
    _updateObservers();
  }

  @override
  void didUpdateWidget(CupertinoTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigatorKey != oldWidget.navigatorKey ||
        widget.navigatorObservers != oldWidget.navigatorObservers) {
      _updateObservers();
    }
  }

  void _updateObservers() {
    _navigatorObservers = List<NavigatorObserver>.of(widget.navigatorObservers)
      ..add(_heroController);
  }

  GlobalKey<NavigatorState>? _ownedNavigatorKey;
  GlobalKey<NavigatorState> get _navigatorKey {
    if (widget.navigatorKey != null) {
      return widget.navigatorKey!;
    }
    _ownedNavigatorKey ??= GlobalKey<NavigatorState>();
    return _ownedNavigatorKey!;
  }

  // Whether this tab is currently the active tab.
  bool get _isActive => TickerMode.of(context);

  @override
  Widget build(BuildContext context) {
    final Widget child = Navigator(
      key: _navigatorKey,
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: _onUnknownRoute,
      observers: _navigatorObservers,
      restorationScopeId: widget.restorationScopeId,
    );

    // Handle system back gestures only if the tab is currently active.
    return NavigatorPopHandler(
      enabled: _isActive,
      onPop: () {
        if (!_isActive) {
          return;
        }
        _navigatorKey.currentState!.pop();
      },
      child: child,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final WidgetBuilder? routeBuilder;
    String? title;
    if (name == Navigator.defaultRouteName && widget.builder != null) {
      routeBuilder = widget.builder;
      title = widget.defaultTitle;
    } else {
      routeBuilder = widget.routes?[name];
    }
    if (routeBuilder != null) {
      return CupertinoPageRoute<dynamic>(
        builder: routeBuilder,
        title: title,
        settings: settings,
      );
    }
    return widget.onGenerateRoute?.call(settings);
  }

  Route<dynamic>? _onUnknownRoute(RouteSettings settings) {
    assert(() {
      if (widget.onUnknownRoute == null) {
        throw FlutterError(
          'Could not find a generator for route $settings in the $runtimeType.\n'
          'Generators for routes are searched for in the following order:\n'
          ' 1. For the "/" route, the "builder" property, if non-null, is used.\n'
          ' 2. Otherwise, the "routes" table is used, if it has an entry for '
          'the route.\n'
          ' 3. Otherwise, onGenerateRoute is called. It should return a '
          'non-null value for any valid route not handled by "builder" and "routes".\n'
          ' 4. Finally if all else fails onUnknownRoute is called.\n'
          'Unfortunately, onUnknownRoute was not set.',
        );
      }
      return true;
    }());
    final Route<dynamic>? result = widget.onUnknownRoute!(settings);
    assert(() {
      if (result == null) {
        throw FlutterError(
          'The onUnknownRoute callback returned null.\n'
          'When the $runtimeType requested the route $settings from its '
          'onUnknownRoute callback, the callback returned null. Such callbacks '
          'must never return null.',
        );
      }
      return true;
    }());
    return result;
  }
}
