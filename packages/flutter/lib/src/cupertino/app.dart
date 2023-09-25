import 'package:flutter/widgets.dart';

import 'button.dart';
import 'colors.dart';
import 'icons.dart';
import 'interface_level.dart';
import 'localizations.dart';
import 'route.dart';
import 'scrollbar.dart';
import 'theme.dart';

class CupertinoApp extends StatefulWidget {
  const CupertinoApp({
    super.key,
    this.navigatorKey,
    this.home,
    this.theme,
    Map<String, Widget Function(BuildContext)> this.routes = const <String, WidgetBuilder>{},
    this.initialRoute,
    this.onGenerateRoute,
    this.onGenerateInitialRoutes,
    this.onUnknownRoute,
    this.onNavigationNotification,
    List<NavigatorObserver> this.navigatorObservers = const <NavigatorObserver>[],
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior,
    @Deprecated(
      'Remove this parameter as it is now ignored. '
      'CupertinoApp never introduces its own MediaQuery; the View widget takes care of that. '
      'This feature was deprecated after v3.7.0-29.0.pre.'
    )
    this.useInheritedMediaQuery = false,
  }) : routeInformationProvider = null,
       routeInformationParser = null,
       routerDelegate = null,
       backButtonDispatcher = null,
       routerConfig = null;

  const CupertinoApp.router({
    super.key,
    this.routeInformationProvider,
    this.routeInformationParser,
    this.routerDelegate,
    this.backButtonDispatcher,
    this.routerConfig,
    this.theme,
    this.builder,
    this.title = '',
    this.onGenerateTitle,
    this.onNavigationNotification,
    this.color,
    this.locale,
    this.localizationsDelegates,
    this.localeListResolutionCallback,
    this.localeResolutionCallback,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.showPerformanceOverlay = false,
    this.checkerboardRasterCacheImages = false,
    this.checkerboardOffscreenLayers = false,
    this.showSemanticsDebugger = false,
    this.debugShowCheckedModeBanner = true,
    this.shortcuts,
    this.actions,
    this.restorationScopeId,
    this.scrollBehavior,
    @Deprecated(
      'Remove this parameter as it is now ignored. '
      'CupertinoApp never introduces its own MediaQuery; the View widget takes care of that. '
      'This feature was deprecated after v3.7.0-29.0.pre.'
    )
    this.useInheritedMediaQuery = false,
  }) : assert(routerDelegate != null || routerConfig != null),
       navigatorObservers = null,
       navigatorKey = null,
       onGenerateRoute = null,
       home = null,
       onGenerateInitialRoutes = null,
       onUnknownRoute = null,
       routes = null,
       initialRoute = null;

  final GlobalKey<NavigatorState>? navigatorKey;

  final Widget? home;

  final CupertinoThemeData? theme;

  final Map<String, WidgetBuilder>? routes;

  final String? initialRoute;

  final RouteFactory? onGenerateRoute;

  final InitialRouteListFactory? onGenerateInitialRoutes;

  final RouteFactory? onUnknownRoute;

  final NotificationListenerCallback<NavigationNotification>? onNavigationNotification;

  final List<NavigatorObserver>? navigatorObservers;

  final RouteInformationProvider? routeInformationProvider;

  final RouteInformationParser<Object>? routeInformationParser;

  final RouterDelegate<Object>? routerDelegate;

  final BackButtonDispatcher? backButtonDispatcher;

  final RouterConfig<Object>? routerConfig;

  final TransitionBuilder? builder;

  final String title;

  final GenerateAppTitle? onGenerateTitle;

  final Color? color;

  final Locale? locale;

  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  final LocaleListResolutionCallback? localeListResolutionCallback;

  final LocaleResolutionCallback? localeResolutionCallback;

  final Iterable<Locale> supportedLocales;

  final bool showPerformanceOverlay;

  final bool checkerboardRasterCacheImages;

  final bool checkerboardOffscreenLayers;

  final bool showSemanticsDebugger;

  final bool debugShowCheckedModeBanner;

  final Map<ShortcutActivator, Intent>? shortcuts;

  final Map<Type, Action<Intent>>? actions;

  final String? restorationScopeId;

  final ScrollBehavior? scrollBehavior;

  @Deprecated(
    'This setting is now ignored. '
    'CupertinoApp never introduces its own MediaQuery; the View widget takes care of that. '
    'This feature was deprecated after v3.7.0-29.0.pre.'
  )
  final bool useInheritedMediaQuery;

  @override
  State<CupertinoApp> createState() => _CupertinoAppState();

  static HeroController createCupertinoHeroController() =>
      HeroController(); // Linear tweening.
}

class CupertinoScrollBehavior extends ScrollBehavior {
  const CupertinoScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context , Widget child, ScrollableDetails details) {
    // When modifying this function, consider modifying the implementation in
    // the base class as well.
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        assert(details.controller != null);
        return CupertinoScrollbar(
          controller: details.controller,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // No overscroll indicator.
    // When modifying this function, consider modifying the implementation in
    // the base class as well.
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // When modifying this function, consider modifying the implementation in
    // the base class ScrollBehavior as well.
    if (getPlatform(context) == TargetPlatform.macOS) {
      return const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast);
    }
    return const BouncingScrollPhysics();
  }
}

class _CupertinoAppState extends State<CupertinoApp> {
  late HeroController _heroController;
  bool get _usesRouter => widget.routerDelegate != null || widget.routerConfig != null;

  @override
  void initState() {
    super.initState();
    _heroController = CupertinoApp.createCupertinoHeroController();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  // Combine the default localization for Cupertino with the ones contributed
  // by the localizationsDelegates parameter, if any. Only the first delegate
  // of a particular LocalizationsDelegate.type is loaded so the
  // localizationsDelegate parameter can be used to override
  // _CupertinoLocalizationsDelegate.
  Iterable<LocalizationsDelegate<dynamic>> get _localizationsDelegates {
    return <LocalizationsDelegate<dynamic>>[
      if (widget.localizationsDelegates != null)
        ...widget.localizationsDelegates!,
      DefaultCupertinoLocalizations.delegate,
    ];
  }

  Widget _inspectorSelectButtonBuilder(BuildContext context, VoidCallback onPressed) {
    return CupertinoButton.filled(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: const Icon(
        CupertinoIcons.search,
        size: 28.0,
        color: CupertinoColors.white,
      ),
    );
  }

  WidgetsApp _buildWidgetApp(BuildContext context) {
    final CupertinoThemeData effectiveThemeData = CupertinoTheme.of(context);
    final Color color = CupertinoDynamicColor.resolve(widget.color ?? effectiveThemeData.primaryColor, context);

    if (_usesRouter) {
      return WidgetsApp.router(
        key: GlobalObjectKey(this),
        routeInformationProvider: widget.routeInformationProvider,
        routeInformationParser: widget.routeInformationParser,
        routerDelegate: widget.routerDelegate,
        routerConfig: widget.routerConfig,
        backButtonDispatcher: widget.backButtonDispatcher,
        builder: widget.builder,
        title: widget.title,
        onGenerateTitle: widget.onGenerateTitle,
        textStyle: effectiveThemeData.textTheme.textStyle,
        color: color,
        locale: widget.locale,
        localizationsDelegates: _localizationsDelegates,
        localeResolutionCallback: widget.localeResolutionCallback,
        localeListResolutionCallback: widget.localeListResolutionCallback,
        supportedLocales: widget.supportedLocales,
        showPerformanceOverlay: widget.showPerformanceOverlay,
        checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
        checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
        showSemanticsDebugger: widget.showSemanticsDebugger,
        debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
        inspectorSelectButtonBuilder: _inspectorSelectButtonBuilder,
        shortcuts: widget.shortcuts,
        actions: widget.actions,
        restorationScopeId: widget.restorationScopeId,
      );
    }

    return WidgetsApp(
      key: GlobalObjectKey(this),
      navigatorKey: widget.navigatorKey,
      navigatorObservers: widget.navigatorObservers!,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return CupertinoPageRoute<T>(settings: settings, builder: builder);
      },
      home: widget.home,
      routes: widget.routes!,
      initialRoute: widget.initialRoute,
      onGenerateRoute: widget.onGenerateRoute,
      onGenerateInitialRoutes: widget.onGenerateInitialRoutes,
      onUnknownRoute: widget.onUnknownRoute,
      onNavigationNotification: widget.onNavigationNotification,
      builder: widget.builder,
      title: widget.title,
      onGenerateTitle: widget.onGenerateTitle,
      textStyle: effectiveThemeData.textTheme.textStyle,
      color: color,
      locale: widget.locale,
      localizationsDelegates: _localizationsDelegates,
      localeResolutionCallback: widget.localeResolutionCallback,
      localeListResolutionCallback: widget.localeListResolutionCallback,
      supportedLocales: widget.supportedLocales,
      showPerformanceOverlay: widget.showPerformanceOverlay,
      checkerboardRasterCacheImages: widget.checkerboardRasterCacheImages,
      checkerboardOffscreenLayers: widget.checkerboardOffscreenLayers,
      showSemanticsDebugger: widget.showSemanticsDebugger,
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      inspectorSelectButtonBuilder: _inspectorSelectButtonBuilder,
      shortcuts: widget.shortcuts,
      actions: widget.actions,
      restorationScopeId: widget.restorationScopeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CupertinoThemeData effectiveThemeData = (widget.theme ?? const CupertinoThemeData()).resolveFrom(context);

    return ScrollConfiguration(
      behavior: widget.scrollBehavior ?? const CupertinoScrollBehavior(),
      child: CupertinoUserInterfaceLevel(
        data: CupertinoUserInterfaceLevelData.base,
        child: CupertinoTheme(
          data: effectiveThemeData,
          child: DefaultSelectionStyle(
            selectionColor: effectiveThemeData.primaryColor.withOpacity(0.2),
            cursorColor: effectiveThemeData.primaryColor,
            child: HeroControllerScope(
              controller: _heroController,
              child: Builder(
                builder: _buildWidgetApp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}