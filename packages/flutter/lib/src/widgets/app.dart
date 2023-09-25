import 'dart:collection' show HashMap;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'banner.dart';
import 'basic.dart';
import 'binding.dart';
import 'default_text_editing_shortcuts.dart';
import 'focus_scope.dart';
import 'focus_traversal.dart';
import 'framework.dart';
import 'localizations.dart';
import 'media_query.dart';
import 'navigator.dart';
import 'notification_listener.dart';
import 'pages.dart';
import 'performance_overlay.dart';
import 'restoration.dart';
import 'router.dart';
import 'scrollable_helpers.dart';
import 'semantics_debugger.dart';
import 'shared_app_data.dart';
import 'shortcuts.dart';
import 'tap_region.dart';
import 'text.dart';
import 'title.dart';
import 'widget_inspector.dart';

export 'dart:ui' show Locale;

// Examples can assume:
// late Widget myWidget;

typedef LocaleListResolutionCallback = Locale? Function(List<Locale>? locales, Iterable<Locale> supportedLocales);

typedef LocaleResolutionCallback = Locale? Function(Locale? locale, Iterable<Locale> supportedLocales);

Locale basicLocaleListResolution(List<Locale>? preferredLocales, Iterable<Locale> supportedLocales) {
  // preferredLocales can be null when called before the platform has had a chance to
  // initialize the locales. Platforms without locale passing support will provide an empty list.
  // We default to the first supported locale in these cases.
  if (preferredLocales == null || preferredLocales.isEmpty) {
    return supportedLocales.first;
  }
  // Hash the supported locales because apps can support many locales and would
  // be expensive to search through them many times.
  final Map<String, Locale> allSupportedLocales = HashMap<String, Locale>();
  final Map<String, Locale> languageAndCountryLocales = HashMap<String, Locale>();
  final Map<String, Locale> languageAndScriptLocales = HashMap<String, Locale>();
  final Map<String, Locale> languageLocales = HashMap<String, Locale>();
  final Map<String?, Locale> countryLocales = HashMap<String?, Locale>();
  for (final Locale locale in supportedLocales) {
    allSupportedLocales['${locale.languageCode}_${locale.scriptCode}_${locale.countryCode}'] ??= locale;
    languageAndScriptLocales['${locale.languageCode}_${locale.scriptCode}'] ??= locale;
    languageAndCountryLocales['${locale.languageCode}_${locale.countryCode}'] ??= locale;
    languageLocales[locale.languageCode] ??= locale;
    countryLocales[locale.countryCode] ??= locale;
  }

  // Since languageCode-only matches are possibly low quality, we don't return
  // it instantly when we find such a match. We check to see if the next
  // preferred locale in the list has a high accuracy match, and only return
  // the languageCode-only match when a higher accuracy match in the next
  // preferred locale cannot be found.
  Locale? matchesLanguageCode;
  Locale? matchesCountryCode;
  // Loop over user's preferred locales
  for (int localeIndex = 0; localeIndex < preferredLocales.length; localeIndex += 1) {
    final Locale userLocale = preferredLocales[localeIndex];
    // Look for perfect match.
    if (allSupportedLocales.containsKey('${userLocale.languageCode}_${userLocale.scriptCode}_${userLocale.countryCode}')) {
      return userLocale;
    }
    // Look for language+script match.
    if (userLocale.scriptCode != null) {
      final Locale? match = languageAndScriptLocales['${userLocale.languageCode}_${userLocale.scriptCode}'];
      if (match != null) {
        return match;
      }
    }
    // Look for language+country match.
    if (userLocale.countryCode != null) {
      final Locale? match = languageAndCountryLocales['${userLocale.languageCode}_${userLocale.countryCode}'];
      if (match != null) {
        return match;
      }
    }
    // If there was a languageCode-only match in the previous iteration's higher
    // ranked preferred locale, we return it if the current userLocale does not
    // have a better match.
    if (matchesLanguageCode != null) {
      return matchesLanguageCode;
    }
    // Look and store language-only match.
    Locale? match = languageLocales[userLocale.languageCode];
    if (match != null) {
      matchesLanguageCode = match;
      // Since first (default) locale is usually highly preferred, we will allow
      // a languageCode-only match to be instantly matched. If the next preferred
      // languageCode is the same, we defer hastily returning until the next iteration
      // since at worst it is the same and at best an improved match.
      if (localeIndex == 0 &&
          !(localeIndex + 1 < preferredLocales.length && preferredLocales[localeIndex + 1].languageCode == userLocale.languageCode)) {
        return matchesLanguageCode;
      }
    }
    // countryCode-only match. When all else except default supported locale fails,
    // attempt to match by country only, as a user is likely to be familiar with a
    // language from their listed country.
    if (matchesCountryCode == null && userLocale.countryCode != null) {
      match = countryLocales[userLocale.countryCode];
      if (match != null) {
        matchesCountryCode = match;
      }
    }
  }
  // When there is no languageCode-only match. Fallback to matching countryCode only. Country
  // fallback only applies on iOS. When there is no countryCode-only match, we return first
  // supported locale.
  final Locale resolvedLocale = matchesLanguageCode ?? matchesCountryCode ?? supportedLocales.first;
  return resolvedLocale;
}

typedef GenerateAppTitle = String Function(BuildContext context);

typedef PageRouteFactory = PageRoute<T> Function<T>(RouteSettings settings, WidgetBuilder builder);

typedef InitialRouteListFactory = List<Route<dynamic>> Function(String initialRoute);

class WidgetsApp extends StatefulWidget {
  WidgetsApp({ // can't be const because the asserts use methods on Iterable :-(
    super.key,
    this.navigatorKey,
    this.onGenerateRoute,
    this.onGenerateInitialRoutes,
    this.onUnknownRoute,
    this.onNavigationNotification,
    List<NavigatorObserver> this.navigatorObservers = const <NavigatorObserver>[],
    this.initialRoute,
    this.pageRouteBuilder,
    this.home,
    Map<String, WidgetBuilder> this.routes = const <String, WidgetBuilder>{},
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.textStyle,
    required this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowWidgetInspector = false,
    this.debugShowCheckedModeBanner = true,
    this.inspectorSelectButtonBuilder,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    @Deprecated(
      'Remove this parameter as it is now ignored. '
      'WidgetsApp never introduces its own MediaQuery; the View widget takes care of that. '
      'This feature was deprecated after v3.7.0-29.0.pre.'
    )
    this.useInheritedMediaQuery = false,
  }) : assert(
         home == null ||
         onGenerateInitialRoutes == null,
         'If onGenerateInitialRoutes is specified, the home argument will be '
         'redundant.',
       ),
       assert(
         home == null ||
         !routes.containsKey(Navigator.defaultRouteName),
         'If the home property is specified, the routes table '
         'cannot include an entry for "/", since it would be redundant.',
       ),
       assert(
         builder != null ||
         home != null ||
         routes.containsKey(Navigator.defaultRouteName) ||
         onGenerateRoute != null ||
         onUnknownRoute != null,
         'Either the home property must be specified, '
         'or the routes table must include an entry for "/", '
         'or there must be on onGenerateRoute callback specified, '
         'or there must be an onUnknownRoute callback specified, '
         'or the builder property must be specified, '
         'because otherwise there is nothing to fall back on if the '
         'app is started with an intent that specifies an unknown route.',
       ),
       assert(
         (home != null ||
          routes.isNotEmpty ||
          onGenerateRoute != null ||
          onUnknownRoute != null)
         ||
         (builder != null &&
          navigatorKey == null &&
          initialRoute == null &&
          navigatorObservers.isEmpty),
         'If no route is provided using '
         'home, routes, onGenerateRoute, or onUnknownRoute, '
         'a non-null callback for the builder property must be provided, '
         'and the other navigator-related properties, '
         'navigatorKey, initialRoute, and navigatorObservers, '
         'must have their initial values '
         '(null, null, and the empty list, respectively).',
       ),
       assert(
         builder != null ||
         onGenerateRoute != null ||
         pageRouteBuilder != null,
         'If neither builder nor onGenerateRoute are provided, the '
         'pageRouteBuilder must be specified so that the default handler '
         'will know what kind of PageRoute transition to build.',
       ),
       assert(supportedLocales.isNotEmpty),
       routeInformationProvider = null,
       routeInformationParser = null,
       routerDelegate = null,
       backButtonDispatcher = null,
       routerConfig = null;

  WidgetsApp.router({
    super.key,
    this.routeInformationProvider,
    this.routeInformationParser,
    this.routerDelegate,
    this.routerConfig,
    this.backButtonDispatcher,
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.onNavigationNotification,
    this.textStyle,
    required this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowWidgetInspector = false,
    this.debugShowCheckedModeBanner = true,
    this.inspectorSelectButtonBuilder,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    @Deprecated(
      'Remove this parameter as it is now ignored. '
      'WidgetsApp never introduces its own MediaQuery; the View widget takes care of that. '
      'This feature was deprecated after v3.7.0-29.0.pre.'
    )
    this.useInheritedMediaQuery = false,
  }) : assert((){
         if (routerConfig != null) {
           assert(
             (routeInformationProvider ?? routeInformationParser ?? routerDelegate ?? backButtonDispatcher) == null,
             'If the routerConfig is provided, all the other router delegates must not be provided',
           );
           return true;
         }
         assert(routerDelegate != null, 'Either one of routerDelegate or routerConfig must be provided');
         assert(
           routeInformationProvider == null || routeInformationParser != null,
           'If routeInformationProvider is provided, routeInformationParser must also be provided',
         );
         return true;
       }()),
       assert(supportedLocales.isNotEmpty),
       navigatorObservers = null,
       navigatorKey = null,
       onGenerateRoute = null,
       pageRouteBuilder = null,
       home = null,
       onGenerateInitialRoutes = null,
       onUnknownRoute = null,
       routes = null,
       initialRoute = null;

  final GlobalKey<NavigatorState>? navigatorKey;

  final RouteFactory? onGenerateRoute;

  final InitialRouteListFactory? onGenerateInitialRoutes;

  final PageRouteFactory? pageRouteBuilder;

  final RouteInformationParser<Object>? routeInformationParser;

  final RouterDelegate<Object>? routerDelegate;

  final BackButtonDispatcher? backButtonDispatcher;

  final RouteInformationProvider? routeInformationProvider;

  final RouterConfig<Object>? routerConfig;

  final Widget? home;

  final Map<String, WidgetBuilder>? routes;

  final RouteFactory? onUnknownRoute;

  final NotificationListenerCallback<NavigationNotification>? onNavigationNotification;

  final String? initialRoute;

  final List<NavigatorObserver>? navigatorObservers;

  final TransitionBuilder? builder;

  final String title;

  final GenerateAppTitle? onGenerateTitle;

  final TextStyle? textStyle;

  final Color color;

  final Locale? locale;

  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  final LocaleListResolutionCallback? localeListResolutionCallback;

  final LocaleResolutionCallback? localeResolutionCallback;

  final Iterable<Locale> supportedLocales;

  final bool showPerformanceOverlay;

  final bool checkerboardRasterCacheImages;

  final bool checkerboardOffscreenLayers;

  final bool showSemanticsDebugger;

  final bool debugShowWidgetInspector;

  final InspectorSelectButtonBuilder? inspectorSelectButtonBuilder;

  final bool debugShowCheckedModeBanner;

  final Map<ShortcutActivator, Intent>? shortcuts;

  final Map<Type, Action<Intent>>? actions;

  final String? restorationScopeId;

  @Deprecated(
    'This setting is now ignored. '
    'WidgetsApp never introduces its own MediaQuery; the View widget takes care of that. '
    'This feature was deprecated after v3.7.0-29.0.pre.'
  )
  final bool useInheritedMediaQuery;

  static bool showPerformanceOverlayOverride = false;

  static bool debugShowWidgetInspectorOverride = false;

  static bool debugAllowBannerOverride = true;

  static const Map<ShortcutActivator, Intent> _defaultShortcuts = <ShortcutActivator, Intent>{
    // Activation
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),

    // Dismissal
    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),

    // Keyboard traversal.
    SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
    SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
    SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
    SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),

    // Scrolling
    SingleActivator(LogicalKeyboardKey.arrowUp, control: true): ScrollIntent(direction: AxisDirection.up),
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true): ScrollIntent(direction: AxisDirection.down),
    SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): ScrollIntent(direction: AxisDirection.left),
    SingleActivator(LogicalKeyboardKey.arrowRight, control: true): ScrollIntent(direction: AxisDirection.right),
    SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    SingleActivator(LogicalKeyboardKey.pageDown): ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
  };

  // Default shortcuts for the web platform.
  static const Map<ShortcutActivator, Intent> _defaultWebShortcuts = <ShortcutActivator, Intent>{
    // Activation
    SingleActivator(LogicalKeyboardKey.space): PrioritizedIntents(
      orderedIntents: <Intent>[
        ActivateIntent(),
        ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
      ],
    ),
    // On the web, enter activates buttons, but not other controls.
    SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ButtonActivateIntent(),

    // Dismissal
    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),

    // Keyboard traversal.
    SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
    SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),

    // Scrolling
    SingleActivator(LogicalKeyboardKey.arrowUp): ScrollIntent(direction: AxisDirection.up),
    SingleActivator(LogicalKeyboardKey.arrowDown): ScrollIntent(direction: AxisDirection.down),
    SingleActivator(LogicalKeyboardKey.arrowLeft): ScrollIntent(direction: AxisDirection.left),
    SingleActivator(LogicalKeyboardKey.arrowRight): ScrollIntent(direction: AxisDirection.right),
    SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    SingleActivator(LogicalKeyboardKey.pageDown): ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
  };

  // Default shortcuts for the macOS platform.
  static const Map<ShortcutActivator, Intent> _defaultAppleOsShortcuts = <ShortcutActivator, Intent>{
    // Activation
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),

    // Dismissal
    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),

    // Keyboard traversal
    SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
    SingleActivator(LogicalKeyboardKey.tab, shift: true): PreviousFocusIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
    SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
    SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),

    // Scrolling
    SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): ScrollIntent(direction: AxisDirection.up),
    SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): ScrollIntent(direction: AxisDirection.down),
    SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true): ScrollIntent(direction: AxisDirection.left),
    SingleActivator(LogicalKeyboardKey.arrowRight, meta: true): ScrollIntent(direction: AxisDirection.right),
    SingleActivator(LogicalKeyboardKey.pageUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
    SingleActivator(LogicalKeyboardKey.pageDown): ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
  };

  static Map<ShortcutActivator, Intent> get defaultShortcuts {
    if (kIsWeb) {
      return _defaultWebShortcuts;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _defaultShortcuts;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _defaultAppleOsShortcuts;
    }
  }

  static Map<Type, Action<Intent>> defaultActions = <Type, Action<Intent>>{
    DoNothingIntent: DoNothingAction(),
    DoNothingAndStopPropagationIntent: DoNothingAction(consumesKey: false),
    RequestFocusIntent: RequestFocusAction(),
    NextFocusIntent: NextFocusAction(),
    PreviousFocusIntent: PreviousFocusAction(),
    DirectionalFocusIntent: DirectionalFocusAction(),
    ScrollIntent: ScrollAction(),
    PrioritizedIntents: PrioritizedAction(),
    VoidCallbackIntent: VoidCallbackAction(),
  };

  @override
  State<WidgetsApp> createState() => _WidgetsAppState();
}

class _WidgetsAppState extends State<WidgetsApp> with WidgetsBindingObserver {
  // STATE LIFECYCLE

  // If window.defaultRouteName isn't '/', we should assume it was set
  // intentionally via `setInitialRoute`, and should override whatever is in
  // [widget.initialRoute].
  String get _initialRouteName => WidgetsBinding.instance.platformDispatcher.defaultRouteName != Navigator.defaultRouteName
    ? WidgetsBinding.instance.platformDispatcher.defaultRouteName
    : widget.initialRoute ?? WidgetsBinding.instance.platformDispatcher.defaultRouteName;

  AppLifecycleState? _appLifecycleState;

  bool _defaultOnNavigationNotification(NavigationNotification notification) {
    switch (_appLifecycleState) {
      case null:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // Avoid updating the engine when the app isn't ready.
        return true;
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        SystemNavigator.setFrameworkHandlesBack(notification.canHandlePop);
        return true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    super.initState();
    _updateRouting();
    _locale = _resolveLocales(WidgetsBinding.instance.platformDispatcher.locales, widget.supportedLocales);
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void didUpdateWidget(WidgetsApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRouting(oldWidget: oldWidget);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _defaultRouteInformationProvider?.dispose();
    super.dispose();
  }

  void _clearRouterResource() {
    _defaultRouteInformationProvider?.dispose();
    _defaultRouteInformationProvider = null;
    _defaultBackButtonDispatcher = null;
  }

  void _clearNavigatorResource() {
    _navigator = null;
  }

  void _updateRouting({WidgetsApp? oldWidget}) {
    if (_usesRouterWithDelegates) {
      assert(!_usesNavigator && !_usesRouterWithConfig);
      _clearNavigatorResource();
      if (widget.routeInformationProvider == null && widget.routeInformationParser != null) {
        _defaultRouteInformationProvider ??= PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(
            uri: Uri.parse(_initialRouteName),
          ),
        );
      } else {
        _defaultRouteInformationProvider?.dispose();
        _defaultRouteInformationProvider = null;
      }
      if (widget.backButtonDispatcher == null) {
        _defaultBackButtonDispatcher ??= RootBackButtonDispatcher();
      }

    } else if (_usesNavigator) {
      assert(!_usesRouterWithDelegates && !_usesRouterWithConfig);
      _clearRouterResource();
      if (_navigator == null || widget.navigatorKey != oldWidget!.navigatorKey) {
        _navigator = widget.navigatorKey ?? GlobalObjectKey<NavigatorState>(this);
      }
      assert(_navigator != null);
    } else {
      assert(widget.builder != null || _usesRouterWithConfig);
      assert(!_usesRouterWithDelegates && !_usesNavigator);
      _clearRouterResource();
      _clearNavigatorResource();
    }
    // If we use a navigator, we have a navigator key.
    assert(_usesNavigator == (_navigator != null));
  }

  bool get _usesRouterWithDelegates => widget.routerDelegate != null;
  bool get _usesRouterWithConfig => widget.routerConfig != null;
  bool get _usesNavigator => widget.home != null
      || (widget.routes?.isNotEmpty ?? false)
      || widget.onGenerateRoute != null
      || widget.onUnknownRoute != null;

  // ROUTER

  RouteInformationProvider? get _effectiveRouteInformationProvider => widget.routeInformationProvider ?? _defaultRouteInformationProvider;
  PlatformRouteInformationProvider? _defaultRouteInformationProvider;
  BackButtonDispatcher get _effectiveBackButtonDispatcher => widget.backButtonDispatcher ?? _defaultBackButtonDispatcher!;
  RootBackButtonDispatcher? _defaultBackButtonDispatcher;

  // NAVIGATOR

  GlobalKey<NavigatorState>? _navigator;

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final WidgetBuilder? pageContentBuilder = name == Navigator.defaultRouteName && widget.home != null
        ? (BuildContext context) => widget.home!
        : widget.routes![name];

    if (pageContentBuilder != null) {
      assert(
        widget.pageRouteBuilder != null,
        'The default onGenerateRoute handler for WidgetsApp must have a '
        'pageRouteBuilder set if the home or routes properties are set.',
      );
      final Route<dynamic> route = widget.pageRouteBuilder!<dynamic>(
        settings,
        pageContentBuilder,
      );
      return route;
    }
    if (widget.onGenerateRoute != null) {
      return widget.onGenerateRoute!(settings);
    }
    return null;
  }

  Route<dynamic> _onUnknownRoute(RouteSettings settings) {
    assert(() {
      if (widget.onUnknownRoute == null) {
        throw FlutterError(
          'Could not find a generator for route $settings in the $runtimeType.\n'
          'Make sure your root app widget has provided a way to generate \n'
          'this route.\n'
          'Generators for routes are searched for in the following order:\n'
          ' 1. For the "/" route, the "home" property, if non-null, is used.\n'
          ' 2. Otherwise, the "routes" table is used, if it has an entry for '
          'the route.\n'
          ' 3. Otherwise, onGenerateRoute is called. It should return a '
          'non-null value for any valid route not handled by "home" and "routes".\n'
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
    return result!;
  }

  // On Android: the user has pressed the back button.
  @override
  Future<bool> didPopRoute() async {
    assert(mounted);
    // The back button dispatcher should handle the pop route if we use a
    // router.
    if (_usesRouterWithDelegates) {
      return false;
    }

    final NavigatorState? navigator = _navigator?.currentState;
    if (navigator == null) {
      return false;
    }
    return navigator.maybePop();
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    assert(mounted);
    // The route name provider should handle the push route if we uses a
    // router.
    if (_usesRouterWithDelegates) {
      return false;
    }

    final NavigatorState? navigator = _navigator?.currentState;
    if (navigator == null) {
      return false;
    }
    final Uri uri = routeInformation.uri;
    navigator.pushNamed(
      Uri.decodeComponent(
        Uri(
          path: uri.path.isEmpty ? '/' : uri.path,
          queryParameters: uri.queryParametersAll.isEmpty ? null : uri.queryParametersAll,
          fragment: uri.fragment.isEmpty ? null : uri.fragment,
        ).toString(),
      ),
    );
    return true;
  }

  // LOCALIZATION

  Locale? _locale;

  Locale _resolveLocales(List<Locale>? preferredLocales, Iterable<Locale> supportedLocales) {
    // Attempt to use localeListResolutionCallback.
    if (widget.localeListResolutionCallback != null) {
      final Locale? locale = widget.localeListResolutionCallback!(preferredLocales, widget.supportedLocales);
      if (locale != null) {
        return locale;
      }
    }
    // localeListResolutionCallback failed, falling back to localeResolutionCallback.
    if (widget.localeResolutionCallback != null) {
      final Locale? locale = widget.localeResolutionCallback!(
        preferredLocales != null && preferredLocales.isNotEmpty ? preferredLocales.first : null,
        widget.supportedLocales,
      );
      if (locale != null) {
        return locale;
      }
    }
    // Both callbacks failed, falling back to default algorithm.
    return basicLocaleListResolution(preferredLocales, supportedLocales);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final Locale newLocale = _resolveLocales(locales, widget.supportedLocales);
    if (newLocale != _locale) {
      setState(() {
        _locale = newLocale;
      });
    }
  }

  // Combine the Localizations for Widgets with the ones contributed
  // by the localizationsDelegates parameter, if any. Only the first delegate
  // of a particular LocalizationsDelegate.type is loaded so the
  // localizationsDelegate parameter can be used to override
  // WidgetsLocalizations.delegate.
  Iterable<LocalizationsDelegate<dynamic>> get _localizationsDelegates {
    return <LocalizationsDelegate<dynamic>>[
      if (widget.localizationsDelegates != null)
        ...widget.localizationsDelegates!,
      DefaultWidgetsLocalizations.delegate,
    ];
  }

  // BUILDER

  bool _debugCheckLocalizations(Locale appLocale) {
    assert(() {
      final Set<Type> unsupportedTypes =
        _localizationsDelegates.map<Type>((LocalizationsDelegate<dynamic> delegate) => delegate.type).toSet();
      for (final LocalizationsDelegate<dynamic> delegate in _localizationsDelegates) {
        if (!unsupportedTypes.contains(delegate.type)) {
          continue;
        }
        if (delegate.isSupported(appLocale)) {
          unsupportedTypes.remove(delegate.type);
        }
      }
      if (unsupportedTypes.isEmpty) {
        return true;
      }

      FlutterError.reportError(FlutterErrorDetails(
        exception: "Warning: This application's locale, $appLocale, is not supported by all of its localization delegates.",
        library: 'widgets',
        informationCollector: () => <DiagnosticsNode>[
          for (final Type unsupportedType in unsupportedTypes)
            ErrorDescription(
              '• A $unsupportedType delegate that supports the $appLocale locale was not found.',
            ),
          ErrorSpacer(),
          if (unsupportedTypes.length == 1 && unsupportedTypes.single.toString() == 'CupertinoLocalizations')
            // We previously explicitly avoided checking for this class so it's not uncommon for applications
            // to have omitted importing the required delegate.
            ...<DiagnosticsNode>[
              ErrorHint(
                'If the application is built using GlobalMaterialLocalizations.delegate, consider using '
                'GlobalMaterialLocalizations.delegates (plural) instead, as that will automatically declare '
                'the appropriate Cupertino localizations.'
              ),
              ErrorSpacer(),
            ],
          ErrorHint(
            'The declared supported locales for this app are: ${widget.supportedLocales.join(", ")}'
          ),
          ErrorSpacer(),
          ErrorDescription(
            'See https://flutter.dev/tutorials/internationalization/ for more '
            "information about configuring an app's locale, supportedLocales, "
            'and localizationsDelegates parameters.',
          ),
        ],
      ));
      return true;
    }());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Widget? routing;
    if (_usesRouterWithDelegates) {
      routing = Router<Object>(
        restorationScopeId: 'router',
        routeInformationProvider: _effectiveRouteInformationProvider,
        routeInformationParser: widget.routeInformationParser,
        routerDelegate: widget.routerDelegate!,
        backButtonDispatcher: _effectiveBackButtonDispatcher,
      );
    } else if (_usesNavigator) {
      assert(_navigator != null);
      routing = FocusScope(
        debugLabel: 'Navigator Scope',
        autofocus: true,
        child: Navigator(
          clipBehavior: Clip.none,
          restorationScopeId: 'nav',
          key: _navigator,
          initialRoute: _initialRouteName,
          onGenerateRoute: _onGenerateRoute,
          onGenerateInitialRoutes: widget.onGenerateInitialRoutes == null
            ? Navigator.defaultGenerateInitialRoutes
            : (NavigatorState navigator, String initialRouteName) {
              return widget.onGenerateInitialRoutes!(initialRouteName);
            },
          onUnknownRoute: _onUnknownRoute,
          observers: widget.navigatorObservers!,
          reportsRouteUpdateToEngine: true,
        ),
      );
    } else if (_usesRouterWithConfig) {
      routing = Router<Object>.withConfig(
        restorationScopeId: 'router',
        config: widget.routerConfig!,
      );
    }

    Widget result;
    if (widget.builder != null) {
      result = Builder(
        builder: (BuildContext context) {
          return widget.builder!(context, routing);
        },
      );
    } else {
      assert(routing != null);
      result = routing!;
    }

    if (widget.textStyle != null) {
      result = DefaultTextStyle(
        style: widget.textStyle!,
        child: result,
      );
    }

    PerformanceOverlay? performanceOverlay;
    // We need to push a performance overlay if any of the display or checkerboarding
    // options are set.
    if (widget.showPerformanceOverlay || WidgetsApp.showPerformanceOverlayOverride) {
      performanceOverlay = PerformanceOverlay.allEnabled(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    } else if (widget.checkerboardRasterCacheImages || widget.checkerboardOffscreenLayers) {
      performanceOverlay = PerformanceOverlay(
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      );
    }
    if (performanceOverlay != null) {
      result = Stack(
        children: <Widget>[
          result,
          Positioned(top: 0.0, left: 0.0, right: 0.0, child: performanceOverlay),
        ],
      );
    }

    if (widget.showSemanticsDebugger) {
      result = SemanticsDebugger(
        child: result,
      );
    }

    assert(() {
      if (widget.debugShowWidgetInspector || WidgetsApp.debugShowWidgetInspectorOverride) {
        result = WidgetInspector(
          selectButtonBuilder: widget.inspectorSelectButtonBuilder,
          child: result,
        );
      }
      if (widget.debugShowCheckedModeBanner && WidgetsApp.debugAllowBannerOverride) {
        result = CheckedModeBanner(
          child: result,
        );
      }
      return true;
    }());

    final Widget title;
    if (widget.onGenerateTitle != null) {
      title = Builder(
        // This Builder exists to provide a context below the Localizations widget.
        // The onGenerateTitle callback can refer to Localizations via its context
        // parameter.
        builder: (BuildContext context) {
          final String title = widget.onGenerateTitle!(context);
          return Title(
            title: title,
            color: widget.color.withOpacity(1.0),
            child: result,
          );
        },
      );
    } else {
      title = Title(
        title: widget.title,
        color: widget.color.withOpacity(1.0),
        child: result,
      );
    }

    final Locale appLocale = widget.locale != null
      ? _resolveLocales(<Locale>[widget.locale!], widget.supportedLocales)
      : _locale!;

    assert(_debugCheckLocalizations(appLocale));

    return RootRestorationScope(
      restorationId: widget.restorationScopeId,
      child: SharedAppData(
        child: NotificationListener<NavigationNotification>(
          onNotification: widget.onNavigationNotification ?? _defaultOnNavigationNotification,
          child: Shortcuts(
            debugLabel: '<Default WidgetsApp Shortcuts>',
            shortcuts: widget.shortcuts ?? WidgetsApp.defaultShortcuts,
            // DefaultTextEditingShortcuts is nested inside Shortcuts so that it can
            // fall through to the defaultShortcuts.
            child: DefaultTextEditingShortcuts(
              child: Actions(
                actions: widget.actions ?? <Type, Action<Intent>>{
                  ...WidgetsApp.defaultActions,
                  ScrollIntent: Action<ScrollIntent>.overridable(context: context, defaultAction: ScrollAction()),
                },
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: TapRegionSurface(
                    child: ShortcutRegistrar(
                      child: Localizations(
                        locale: appLocale,
                        delegates: _localizationsDelegates.toList(),
                        child: title,
                      ),
                    ),
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