import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'binding.dart';
import 'framework.dart';
import 'navigator.dart';
import 'restoration.dart';
import 'restoration_properties.dart';

class RouteInformation {
  const RouteInformation({
    @Deprecated('Pass Uri.parse(location) to uri parameter instead. '
        'This feature was deprecated after v3.8.0-3.0.pre.')
    String? location,
    Uri? uri,
    this.state,
  })  : _location = location,
        _uri = uri,
        assert((location != null) != (uri != null));

  @Deprecated('Use uri instead. '
      'This feature was deprecated after v3.8.0-3.0.pre.')
  String get location {
    if (_location != null) {
      return _location;
    }
    return Uri.decodeComponent(
      Uri(
        path: uri.path.isEmpty ? '/' : uri.path,
        queryParameters:
            uri.queryParametersAll.isEmpty ? null : uri.queryParametersAll,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
      ).toString(),
    );
  }

  final String? _location;

  Uri get uri {
    if (_uri != null) {
      return _uri;
    }
    return Uri.parse(_location!);
  }

  final Uri? _uri;

  final Object? state;
}

class RouterConfig<T> {
  const RouterConfig({
    this.routeInformationProvider,
    this.routeInformationParser,
    required this.routerDelegate,
    this.backButtonDispatcher,
  }) : assert((routeInformationProvider == null) ==
            (routeInformationParser == null));

  final RouteInformationProvider? routeInformationProvider;

  final RouteInformationParser<T>? routeInformationParser;

  final RouterDelegate<T> routerDelegate;

  final BackButtonDispatcher? backButtonDispatcher;
}

class Router<T> extends StatefulWidget {
  const Router({
    super.key,
    this.routeInformationProvider,
    this.routeInformationParser,
    required this.routerDelegate,
    this.backButtonDispatcher,
    this.restorationScopeId,
  }) : assert(
          routeInformationProvider == null || routeInformationParser != null,
          'A routeInformationParser must be provided when a routeInformationProvider is specified.',
        );

  factory Router.withConfig({
    Key? key,
    required RouterConfig<T> config,
    String? restorationScopeId,
  }) {
    return Router<T>(
      key: key,
      routeInformationProvider: config.routeInformationProvider,
      routeInformationParser: config.routeInformationParser,
      routerDelegate: config.routerDelegate,
      backButtonDispatcher: config.backButtonDispatcher,
      restorationScopeId: restorationScopeId,
    );
  }

  final RouteInformationProvider? routeInformationProvider;

  final RouteInformationParser<T>? routeInformationParser;

  final RouterDelegate<T> routerDelegate;

  final BackButtonDispatcher? backButtonDispatcher;

  final String? restorationScopeId;

  static Router<T> of<T extends Object?>(BuildContext context) {
    final _RouterScope? scope =
        context.dependOnInheritedWidgetOfExactType<_RouterScope>();
    assert(() {
      if (scope == null) {
        throw FlutterError(
          'Router operation requested with a context that does not include a Router.\n'
          'The context used to retrieve the Router must be that of a widget that '
          'is a descendant of a Router widget.',
        );
      }
      return true;
    }());
    return scope!.routerState.widget as Router<T>;
  }

  static Router<T>? maybeOf<T extends Object?>(BuildContext context) {
    final _RouterScope? scope =
        context.dependOnInheritedWidgetOfExactType<_RouterScope>();
    return scope?.routerState.widget as Router<T>?;
  }

  static void navigate(BuildContext context, VoidCallback callback) {
    final _RouterScope scope = context
        .getElementForInheritedWidgetOfExactType<_RouterScope>()!
        .widget as _RouterScope;
    scope.routerState._setStateWithExplicitReportStatus(
        RouteInformationReportingType.navigate, callback);
  }

  static void neglect(BuildContext context, VoidCallback callback) {
    final _RouterScope scope = context
        .getElementForInheritedWidgetOfExactType<_RouterScope>()!
        .widget as _RouterScope;
    scope.routerState._setStateWithExplicitReportStatus(
        RouteInformationReportingType.neglect, callback);
  }

  @override
  State<Router<T>> createState() => _RouterState<T>();
}

typedef _AsyncPassthrough<Q> = Future<Q> Function(Q);
typedef _RouteSetter<T> = Future<void> Function(T);

enum RouteInformationReportingType {
  none,
  neglect,
  navigate,
}

class _RouterState<T> extends State<Router<T>> with RestorationMixin {
  Object? _currentRouterTransaction;
  RouteInformationReportingType? _currentIntentionToReport;
  final _RestorableRouteInformation _routeInformation =
      _RestorableRouteInformation();
  late bool _routeParsePending;

  @override
  String? get restorationId => widget.restorationScopeId;

  @override
  void initState() {
    super.initState();
    widget.routeInformationProvider
        ?.addListener(_handleRouteInformationProviderNotification);
    widget.backButtonDispatcher
        ?.addCallback(_handleBackButtonDispatcherNotification);
    widget.routerDelegate.addListener(_handleRouterDelegateNotification);
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_routeInformation, 'route');
    if (_routeInformation.value != null) {
      assert(widget.routeInformationParser != null);
      _processRouteInformation(_routeInformation.value!,
          () => widget.routerDelegate.setRestoredRoutePath);
    } else if (widget.routeInformationProvider != null) {
      _processRouteInformation(widget.routeInformationProvider!.value,
          () => widget.routerDelegate.setInitialRoutePath);
    }
  }

  bool _routeInformationReportingTaskScheduled = false;

  void _scheduleRouteInformationReportingTask() {
    if (_routeInformationReportingTaskScheduled ||
        widget.routeInformationProvider == null) {
      return;
    }
    assert(_currentIntentionToReport != null);
    _routeInformationReportingTaskScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(_reportRouteInformation);
  }

  void _reportRouteInformation(Duration timestamp) {
    assert(_routeInformationReportingTaskScheduled);
    _routeInformationReportingTaskScheduled = false;

    if (_routeInformation.value != null) {
      final RouteInformation currentRouteInformation = _routeInformation.value!;
      assert(_currentIntentionToReport != null);
      widget.routeInformationProvider!.routerReportsNewRouteInformation(
          currentRouteInformation,
          type: _currentIntentionToReport!);
    }
    _currentIntentionToReport = RouteInformationReportingType.none;
  }

  RouteInformation? _retrieveNewRouteInformation() {
    final T? configuration = widget.routerDelegate.currentConfiguration;
    if (configuration == null) {
      return null;
    }
    return widget.routeInformationParser
        ?.restoreRouteInformation(configuration);
  }

  void _setStateWithExplicitReportStatus(
    RouteInformationReportingType status,
    VoidCallback fn,
  ) {
    assert(status.index >= RouteInformationReportingType.neglect.index);
    assert(() {
      if (_currentIntentionToReport != null &&
          _currentIntentionToReport != RouteInformationReportingType.none &&
          _currentIntentionToReport != status) {
        FlutterError.reportError(
          const FlutterErrorDetails(
            exception:
                'Both Router.navigate and Router.neglect have been called in this '
                'build cycle, and the Router cannot decide whether to report the '
                'route information. Please make sure only one of them is called '
                'within the same build cycle.',
          ),
        );
      }
      return true;
    }());
    _currentIntentionToReport = status;
    _scheduleRouteInformationReportingTask();
    fn();
  }

  void _maybeNeedToReportRouteInformation() {
    _routeInformation.value = _retrieveNewRouteInformation();
    _currentIntentionToReport ??= RouteInformationReportingType.none;
    _scheduleRouteInformationReportingTask();
  }

  @override
  void didChangeDependencies() {
    _routeParsePending = true;
    super.didChangeDependencies();
    // The super.didChangeDependencies may have parsed the route information.
    // This can happen if the didChangeDependencies is triggered by state
    // restoration or first build.
    if (widget.routeInformationProvider != null && _routeParsePending) {
      _processRouteInformation(widget.routeInformationProvider!.value,
          () => widget.routerDelegate.setNewRoutePath);
    }
    _routeParsePending = false;
    _maybeNeedToReportRouteInformation();
  }

  @override
  void didUpdateWidget(Router<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeInformationProvider != oldWidget.routeInformationProvider ||
        widget.backButtonDispatcher != oldWidget.backButtonDispatcher ||
        widget.routeInformationParser != oldWidget.routeInformationParser ||
        widget.routerDelegate != oldWidget.routerDelegate) {
      _currentRouterTransaction = Object();
    }
    if (widget.routeInformationProvider != oldWidget.routeInformationProvider) {
      oldWidget.routeInformationProvider
          ?.removeListener(_handleRouteInformationProviderNotification);
      widget.routeInformationProvider
          ?.addListener(_handleRouteInformationProviderNotification);
      if (oldWidget.routeInformationProvider?.value !=
          widget.routeInformationProvider?.value) {
        _handleRouteInformationProviderNotification();
      }
    }
    if (widget.backButtonDispatcher != oldWidget.backButtonDispatcher) {
      oldWidget.backButtonDispatcher
          ?.removeCallback(_handleBackButtonDispatcherNotification);
      widget.backButtonDispatcher
          ?.addCallback(_handleBackButtonDispatcherNotification);
    }
    if (widget.routerDelegate != oldWidget.routerDelegate) {
      oldWidget.routerDelegate
          .removeListener(_handleRouterDelegateNotification);
      widget.routerDelegate.addListener(_handleRouterDelegateNotification);
      _maybeNeedToReportRouteInformation();
    }
  }

  @override
  void dispose() {
    widget.routeInformationProvider
        ?.removeListener(_handleRouteInformationProviderNotification);
    widget.backButtonDispatcher
        ?.removeCallback(_handleBackButtonDispatcherNotification);
    widget.routerDelegate.removeListener(_handleRouterDelegateNotification);
    _currentRouterTransaction = null;
    super.dispose();
  }

  void _processRouteInformation(RouteInformation information,
      ValueGetter<_RouteSetter<T>> delegateRouteSetter) {
    assert(_routeParsePending);
    _routeParsePending = false;
    _currentRouterTransaction = Object();
    widget.routeInformationParser!
        .parseRouteInformationWithDependencies(information, context)
        .then<void>(_processParsedRouteInformation(
            _currentRouterTransaction, delegateRouteSetter));
  }

  _RouteSetter<T> _processParsedRouteInformation(
      Object? transaction, ValueGetter<_RouteSetter<T>> delegateRouteSetter) {
    return (T data) async {
      if (_currentRouterTransaction != transaction) {
        return;
      }
      await delegateRouteSetter()(data);
      if (_currentRouterTransaction == transaction) {
        _rebuild();
      }
    };
  }

  void _handleRouteInformationProviderNotification() {
    _routeParsePending = true;
    _processRouteInformation(widget.routeInformationProvider!.value,
        () => widget.routerDelegate.setNewRoutePath);
  }

  Future<bool> _handleBackButtonDispatcherNotification() {
    _currentRouterTransaction = Object();
    return widget.routerDelegate
        .popRoute()
        .then<bool>(_handleRoutePopped(_currentRouterTransaction));
  }

  _AsyncPassthrough<bool> _handleRoutePopped(Object? transaction) {
    return (bool data) {
      if (transaction != _currentRouterTransaction) {
        // A rebuilt was trigger from a different source. Returns true to
        // prevent bubbling.
        return SynchronousFuture<bool>(true);
      }
      _rebuild();
      return SynchronousFuture<bool>(data);
    };
  }

  Future<void> _rebuild([void value]) {
    setState(() {/* routerDelegate is ready to rebuild */});
    _maybeNeedToReportRouteInformation();
    return SynchronousFuture<void>(value);
  }

  void _handleRouterDelegateNotification() {
    setState(() {/* routerDelegate wants to rebuild */});
    _maybeNeedToReportRouteInformation();
  }

  @override
  Widget build(BuildContext context) {
    return UnmanagedRestorationScope(
      bucket: bucket,
      child: _RouterScope(
        routeInformationProvider: widget.routeInformationProvider,
        backButtonDispatcher: widget.backButtonDispatcher,
        routeInformationParser: widget.routeInformationParser,
        routerDelegate: widget.routerDelegate,
        routerState: this,
        child: Builder(
          // Use a Builder so that the build method below will have a
          // BuildContext that contains the _RouterScope. This also prevents
          // dependencies look ups in routerDelegate from rebuilding Router
          // widget that may result in re-parsing the route information.
          builder: widget.routerDelegate.build,
        ),
      ),
    );
  }
}

class _RouterScope extends InheritedWidget {
  const _RouterScope({
    required this.routeInformationProvider,
    required this.backButtonDispatcher,
    required this.routeInformationParser,
    required this.routerDelegate,
    required this.routerState,
    required super.child,
  }) : assert(
            routeInformationProvider == null || routeInformationParser != null);

  final ValueListenable<RouteInformation?>? routeInformationProvider;
  final BackButtonDispatcher? backButtonDispatcher;
  final RouteInformationParser<Object?>? routeInformationParser;
  final RouterDelegate<Object?> routerDelegate;
  final _RouterState<Object?> routerState;

  @override
  bool updateShouldNotify(_RouterScope oldWidget) {
    return routeInformationProvider != oldWidget.routeInformationProvider ||
        backButtonDispatcher != oldWidget.backButtonDispatcher ||
        routeInformationParser != oldWidget.routeInformationParser ||
        routerDelegate != oldWidget.routerDelegate ||
        routerState != oldWidget.routerState;
  }
}

class _CallbackHookProvider<T> {
  final ObserverList<ValueGetter<T>> _callbacks =
      ObserverList<ValueGetter<T>>();

  @protected
  bool get hasCallbacks => _callbacks.isNotEmpty;

  void addCallback(ValueGetter<T> callback) => _callbacks.add(callback);

  void removeCallback(ValueGetter<T> callback) => _callbacks.remove(callback);

  @protected
  @pragma('vm:notify-debugger-on-exception')
  T invokeCallback(T defaultValue) {
    if (_callbacks.isEmpty) {
      return defaultValue;
    }
    try {
      return _callbacks.single();
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widget library',
        context:
            ErrorDescription('while invoking the callback for $runtimeType'),
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<_CallbackHookProvider<T>>(
            'The $runtimeType that invoked the callback was',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ],
      ));
      return defaultValue;
    }
  }
}

abstract class BackButtonDispatcher
    extends _CallbackHookProvider<Future<bool>> {
  late final LinkedHashSet<ChildBackButtonDispatcher> _children =
      <ChildBackButtonDispatcher>{} as LinkedHashSet<ChildBackButtonDispatcher>;

  @override
  bool get hasCallbacks => super.hasCallbacks || (_children.isNotEmpty);

  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) {
    if (_children.isNotEmpty) {
      final List<ChildBackButtonDispatcher> children = _children.toList();
      int childIndex = children.length - 1;

      Future<bool> notifyNextChild(bool result) {
        // If the previous child handles the callback, we return the result.
        if (result) {
          return SynchronousFuture<bool>(result);
        }
        // If the previous child did not handle the callback, we ask the next
        // child to handle the it.
        if (childIndex > 0) {
          childIndex -= 1;
          return children[childIndex]
              .notifiedByParent(defaultValue)
              .then<bool>(notifyNextChild);
        }
        // If none of the child handles the callback, the parent will then handle it.
        return super.invokeCallback(defaultValue);
      }

      return children[childIndex]
          .notifiedByParent(defaultValue)
          .then<bool>(notifyNextChild);
    }
    return super.invokeCallback(defaultValue);
  }

  ChildBackButtonDispatcher createChildBackButtonDispatcher() {
    return ChildBackButtonDispatcher(this);
  }

  void takePriority() => _children.clear();

  void deferTo(ChildBackButtonDispatcher child) {
    assert(hasCallbacks);
    _children.remove(child); // child may or may not be in the set already
    _children.add(child);
  }

  void forget(ChildBackButtonDispatcher child) => _children.remove(child);
}

class RootBackButtonDispatcher extends BackButtonDispatcher
    with WidgetsBindingObserver {
  RootBackButtonDispatcher();

  @override
  void addCallback(ValueGetter<Future<bool>> callback) {
    if (!hasCallbacks) {
      WidgetsBinding.instance.addObserver(this);
    }
    super.addCallback(callback);
  }

  @override
  void removeCallback(ValueGetter<Future<bool>> callback) {
    super.removeCallback(callback);
    if (!hasCallbacks) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  Future<bool> didPopRoute() => invokeCallback(Future<bool>.value(false));
}

class ChildBackButtonDispatcher extends BackButtonDispatcher {
  ChildBackButtonDispatcher(this.parent);

  final BackButtonDispatcher parent;

  @protected
  Future<bool> notifiedByParent(Future<bool> defaultValue) {
    return invokeCallback(defaultValue);
  }

  @override
  void takePriority() {
    parent.deferTo(this);
    super.takePriority();
  }

  @override
  void deferTo(ChildBackButtonDispatcher child) {
    assert(hasCallbacks);
    parent.deferTo(this);
    super.deferTo(child);
  }

  @override
  void removeCallback(ValueGetter<Future<bool>> callback) {
    super.removeCallback(callback);
    if (!hasCallbacks) {
      parent.forget(this);
    }
  }
}

class BackButtonListener extends StatefulWidget {
  const BackButtonListener({
    super.key,
    required this.child,
    required this.onBackButtonPressed,
  });

  final Widget child;

  final ValueGetter<Future<bool>> onBackButtonPressed;

  @override
  State<BackButtonListener> createState() => _BackButtonListenerState();
}

class _BackButtonListenerState extends State<BackButtonListener> {
  BackButtonDispatcher? dispatcher;

  @override
  void didChangeDependencies() {
    dispatcher?.removeCallback(widget.onBackButtonPressed);

    final BackButtonDispatcher? rootBackDispatcher =
        Router.of(context).backButtonDispatcher;
    assert(rootBackDispatcher != null,
        'The parent router must have a backButtonDispatcher to use this widget');

    dispatcher = rootBackDispatcher!.createChildBackButtonDispatcher()
      ..addCallback(widget.onBackButtonPressed)
      ..takePriority();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant BackButtonListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBackButtonPressed != widget.onBackButtonPressed) {
      dispatcher?.removeCallback(oldWidget.onBackButtonPressed);
      dispatcher?.addCallback(widget.onBackButtonPressed);
      dispatcher?.takePriority();
    }
  }

  @override
  void dispose() {
    dispatcher?.removeCallback(widget.onBackButtonPressed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract class RouteInformationParser<T> {
  const RouteInformationParser();

  Future<T> parseRouteInformation(RouteInformation routeInformation) {
    throw UnimplementedError('One of the parseRouteInformation or '
        'parseRouteInformationWithDependencies must be implemented');
  }

  Future<T> parseRouteInformationWithDependencies(
      RouteInformation routeInformation, BuildContext context) {
    return parseRouteInformation(routeInformation);
  }

  RouteInformation? restoreRouteInformation(T configuration) => null;
}

abstract class RouterDelegate<T> extends Listenable {
  Future<void> setInitialRoutePath(T configuration) {
    return setNewRoutePath(configuration);
  }

  Future<void> setRestoredRoutePath(T configuration) {
    return setNewRoutePath(configuration);
  }

  Future<void> setNewRoutePath(T configuration);

  Future<bool> popRoute();

  T? get currentConfiguration => null;

  Widget build(BuildContext context);
}

abstract class RouteInformationProvider
    extends ValueListenable<RouteInformation> {
  void routerReportsNewRouteInformation(RouteInformation routeInformation,
      {RouteInformationReportingType type =
          RouteInformationReportingType.none}) {}
}

class PlatformRouteInformationProvider extends RouteInformationProvider
    with WidgetsBindingObserver, ChangeNotifier {
  PlatformRouteInformationProvider({
    required RouteInformation initialRouteInformation,
  }) : _value = initialRouteInformation {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  static bool _equals(Uri a, Uri b) {
    return a.path == b.path &&
        a.fragment == b.fragment &&
        const DeepCollectionEquality.unordered()
            .equals(a.queryParametersAll, b.queryParametersAll);
  }

  @override
  void routerReportsNewRouteInformation(RouteInformation routeInformation,
      {RouteInformationReportingType type =
          RouteInformationReportingType.none}) {
    final bool replace = type == RouteInformationReportingType.neglect ||
        (type == RouteInformationReportingType.none &&
            _equals(_valueInEngine.uri, routeInformation.uri));
    SystemNavigator.selectMultiEntryHistory();
    SystemNavigator.routeInformationUpdated(
      uri: routeInformation.uri,
      state: routeInformation.state,
      replace: replace,
    );
    _value = routeInformation;
    _valueInEngine = routeInformation;
  }

  @override
  RouteInformation get value => _value;
  RouteInformation _value;

  RouteInformation _valueInEngine = RouteInformation(
      uri: Uri.parse(
          WidgetsBinding.instance.platformDispatcher.defaultRouteName));

  void _platformReportsNewRouteInformation(RouteInformation routeInformation) {
    if (_value == routeInformation) {
      return;
    }
    _value = routeInformation;
    _valueInEngine = routeInformation;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      WidgetsBinding.instance.addObserver(this);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void dispose() {
    // In practice, this will rarely be called. We assume that the listeners
    // will be added and removed in a coherent fashion such that when the object
    // is no longer being used, there's no listener, and so it will get garbage
    // collected.
    if (hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(
      RouteInformation routeInformation) async {
    assert(hasListeners);
    _platformReportsNewRouteInformation(routeInformation);
    return true;
  }
}

mixin PopNavigatorRouterDelegateMixin<T> on RouterDelegate<T> {
  GlobalKey<NavigatorState>? get navigatorKey;

  @override
  Future<bool> popRoute() {
    final NavigatorState? navigator = navigatorKey?.currentState;
    if (navigator == null) {
      return SynchronousFuture<bool>(false);
    }
    return navigator.maybePop();
  }
}

class _RestorableRouteInformation extends RestorableValue<RouteInformation?> {
  @override
  RouteInformation? createDefaultValue() => null;

  @override
  void didUpdateValue(RouteInformation? oldValue) {
    notifyListeners();
  }

  @override
  RouteInformation? fromPrimitives(Object? data) {
    if (data == null) {
      return null;
    }
    assert(data is List<Object?> && data.length == 2);
    final List<Object?> castedData = data as List<Object?>;
    final String? uri = castedData.first as String?;
    if (uri == null) {
      return null;
    }
    return RouteInformation(uri: Uri.parse(uri), state: castedData.last);
  }

  @override
  Object? toPrimitives() {
    return value == null
        ? null
        : <Object?>[value!.uri.toString(), value!.state];
  }
}
