
import 'package:flutter/foundation.dart';

import 'events.dart';

export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'events.dart' show PointerEvent;

typedef PointerRoute = void Function(PointerEvent event);

class PointerRouter {
  final Map<int, Map<PointerRoute, Matrix4?>> _routeMap = <int, Map<PointerRoute, Matrix4?>>{};
  final Map<PointerRoute, Matrix4?> _globalRoutes = <PointerRoute, Matrix4?>{};

  void addRoute(int pointer, PointerRoute route, [Matrix4? transform]) {
    final Map<PointerRoute, Matrix4?> routes = _routeMap.putIfAbsent(
      pointer,
      () => <PointerRoute, Matrix4?>{},
    );
    assert(!routes.containsKey(route));
    routes[route] = transform;
  }

  void removeRoute(int pointer, PointerRoute route) {
    assert(_routeMap.containsKey(pointer));
    final Map<PointerRoute, Matrix4?> routes = _routeMap[pointer]!;
    assert(routes.containsKey(route));
    routes.remove(route);
    if (routes.isEmpty) {
      _routeMap.remove(pointer);
    }
  }

  void addGlobalRoute(PointerRoute route, [Matrix4? transform]) {
    assert(!_globalRoutes.containsKey(route));
    _globalRoutes[route] = transform;
  }

  void removeGlobalRoute(PointerRoute route) {
    assert(_globalRoutes.containsKey(route));
    _globalRoutes.remove(route);
  }

  int get debugGlobalRouteCount {
    int? count;
    assert(() {
      count = _globalRoutes.length;
      return true;
    }());
    if (count != null) {
      return count!;
    }
    throw UnsupportedError('debugGlobalRouteCount is not supported in release builds');
  }

  @pragma('vm:notify-debugger-on-exception')
  void _dispatch(PointerEvent event, PointerRoute route, Matrix4? transform) {
    try {
      event = event.transformed(transform);
      route(event);
    } catch (exception, stack) {
      InformationCollector? collector;
      assert(() {
        collector = () => <DiagnosticsNode>[
          DiagnosticsProperty<PointerRouter>('router', this, level: DiagnosticLevel.debug),
          DiagnosticsProperty<PointerRoute>('route', route, level: DiagnosticLevel.debug),
          DiagnosticsProperty<PointerEvent>('event', event, level: DiagnosticLevel.debug),
        ];
        return true;
      }());
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'gesture library',
        context: ErrorDescription('while routing a pointer event'),
        informationCollector: collector,
      ));
    }
  }

  void route(PointerEvent event) {
    final Map<PointerRoute, Matrix4?>? routes = _routeMap[event.pointer];
    final Map<PointerRoute, Matrix4?> copiedGlobalRoutes = Map<PointerRoute, Matrix4?>.of(_globalRoutes);
    if (routes != null) {
      _dispatchEventToRoutes(
        event,
        routes,
        Map<PointerRoute, Matrix4?>.of(routes),
      );
    }
    _dispatchEventToRoutes(event, _globalRoutes, copiedGlobalRoutes);
  }

  void _dispatchEventToRoutes(
    PointerEvent event,
    Map<PointerRoute, Matrix4?> referenceRoutes,
    Map<PointerRoute, Matrix4?> copiedRoutes,
  ) {
    copiedRoutes.forEach((PointerRoute route, Matrix4? transform) {
      if (referenceRoutes.containsKey(route)) {
        _dispatch(event, route, transform);
      }
    });
  }
}