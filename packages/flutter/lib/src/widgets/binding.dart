
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show AccessibilityFeatures, AppExitResponse, AppLifecycleState, FrameTiming, Locale, PlatformDispatcher, TimingsCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'debug.dart';
import 'focus_manager.dart';
import 'framework.dart';
import 'platform_menu_bar.dart';
import 'router.dart';
import 'service_extensions.dart';
import 'view.dart';
import 'widget_inspector.dart';

export 'dart:ui' show AppLifecycleState, Locale;

abstract mixin class WidgetsBindingObserver {
  Future<bool> didPopRoute() => Future<bool>.value(false);

  @Deprecated(
    'Use didPushRouteInformation instead. '
    'This feature was deprecated after v3.8.0-14.0.pre.'
  )
  Future<bool> didPushRoute(String route) => Future<bool>.value(false);

  // TODO(chunhtai): remove the default implementation once `didPushRoute` is
  // removed.
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    final Uri uri = routeInformation.uri;
    return didPushRoute(
      Uri.decodeComponent(
        Uri(
          path: uri.path.isEmpty ? '/' : uri.path,
          queryParameters: uri.queryParametersAll.isEmpty ? null : uri.queryParametersAll,
          fragment: uri.fragment.isEmpty ? null : uri.fragment,
        ).toString(),
      ),
    );
  }

  void didChangeMetrics() { }

  void didChangeTextScaleFactor() { }

  void didChangePlatformBrightness() { }

  void didChangeLocales(List<Locale>? locales) { }

  void didChangeAppLifecycleState(AppLifecycleState state) { }

  Future<AppExitResponse> didRequestAppExit() async {
    return AppExitResponse.exit;
  }

  void didHaveMemoryPressure() { }

  void didChangeAccessibilityFeatures() { }
}

// TODO(goderbauer): Include an example graph showcasing the different zones.
mixin WidgetsBinding on BindingBase, ServicesBinding, SchedulerBinding, GestureBinding, RendererBinding, SemanticsBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;

    assert(() {
      _debugAddStackFilters();
      return true;
    }());

    // Initialization of [_buildOwner] has to be done after
    // [super.initInstances] is called, as it requires [ServicesBinding] to
    // properly setup the [defaultBinaryMessenger] instance.
    _buildOwner = BuildOwner();
    buildOwner!.onBuildScheduled = _handleBuildScheduled;
    platformDispatcher.onLocaleChanged = handleLocaleChanged;
    SystemChannels.navigation.setMethodCallHandler(_handleNavigationInvocation);
    assert(() {
      FlutterErrorDetails.propertiesTransformers.add(debugTransformDebugCreator);
      return true;
    }());
    platformMenuDelegate = DefaultPlatformMenuDelegate();
  }

  static WidgetsBinding get instance => BindingBase.checkInstance(_instance);
  static WidgetsBinding? _instance;

  void _debugAddStackFilters() {
    const PartialStackFrame elementInflateWidget = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'Element', method: 'inflateWidget');
    const PartialStackFrame elementUpdateChild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'Element', method: 'updateChild');
    const PartialStackFrame elementRebuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'Element', method: 'rebuild');
    const PartialStackFrame componentElementPerformRebuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'ComponentElement', method: 'performRebuild');
    const PartialStackFrame componentElementFirstBuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'ComponentElement', method: '_firstBuild');
    const PartialStackFrame componentElementMount = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'ComponentElement', method: 'mount');
    const PartialStackFrame statefulElementFirstBuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'StatefulElement', method: '_firstBuild');
    const PartialStackFrame singleChildMount = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'SingleChildRenderObjectElement', method: 'mount');
    const PartialStackFrame statefulElementRebuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'StatefulElement', method: 'performRebuild');

    const String replacementString = '...     Normal element mounting';

    // ComponentElement variations
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementInflateWidget,
        elementUpdateChild,
        componentElementPerformRebuild,
        elementRebuild,
        componentElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementUpdateChild,
        componentElementPerformRebuild,
        elementRebuild,
        componentElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));

    // StatefulElement variations
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementInflateWidget,
        elementUpdateChild,
        componentElementPerformRebuild,
        statefulElementRebuild,
        elementRebuild,
        componentElementFirstBuild,
        statefulElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementUpdateChild,
        componentElementPerformRebuild,
        statefulElementRebuild,
        elementRebuild,
        componentElementFirstBuild,
        statefulElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));

    // SingleChildRenderObjectElement variations
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementInflateWidget,
        elementUpdateChild,
        singleChildMount,
      ],
      replacement: replacementString,
    ));
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementUpdateChild,
        singleChildMount,
      ],
      replacement: replacementString,
    ));
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    if (!kReleaseMode) {
      registerServiceExtension(
        name: WidgetsServiceExtensions.debugDumpApp.name,
        callback: (Map<String, String> parameters) async {
          final String data = _debugDumpAppString();
          return <String, Object>{
            'data': data,
          };
        },
      );

      registerServiceExtension(
        name: WidgetsServiceExtensions.debugDumpFocusTree.name,
        callback: (Map<String, String> parameters) async {
          final String data = focusManager.toStringDeep();
          return <String, Object>{
            'data': data,
          };
        },
      );

      if (!kIsWeb) {
        registerBoolServiceExtension(
          name: WidgetsServiceExtensions.showPerformanceOverlay.name,
          getter: () =>
          Future<bool>.value(WidgetsApp.showPerformanceOverlayOverride),
          setter: (bool value) {
            if (WidgetsApp.showPerformanceOverlayOverride == value) {
              return Future<void>.value();
            }
            WidgetsApp.showPerformanceOverlayOverride = value;
            return _forceRebuild();
          },
        );
      }

      registerServiceExtension(
        name: WidgetsServiceExtensions.didSendFirstFrameEvent.name,
        callback: (_) async {
          return <String, dynamic>{
            // This is defined to return a STRING, not a boolean.
            // Devtools, the Intellij plugin, and the flutter tool all depend
            // on it returning a string and not a boolean.
            'enabled': _needToReportFirstFrame ? 'false' : 'true',
          };
        },
      );

      registerServiceExtension(
        name: WidgetsServiceExtensions.didSendFirstFrameRasterizedEvent.name,
        callback: (_) async {
          return <String, dynamic>{
            // This is defined to return a STRING, not a boolean.
            // Devtools, the Intellij plugin, and the flutter tool all depend
            // on it returning a string and not a boolean.
            'enabled': firstFrameRasterized ? 'true' : 'false',
          };
        },
      );

      // Expose the ability to send Widget rebuilds as [Timeline] events.
      registerBoolServiceExtension(
        name: WidgetsServiceExtensions.profileWidgetBuilds.name,
        getter: () async => debugProfileBuildsEnabled,
        setter: (bool value) async {
          debugProfileBuildsEnabled = value;
        }
      );
      registerBoolServiceExtension(
        name: WidgetsServiceExtensions.profileUserWidgetBuilds.name,
        getter: () async => debugProfileBuildsEnabledUserWidgets,
        setter: (bool value) async {
          debugProfileBuildsEnabledUserWidgets = value;
        }
      );
    }

    assert(() {
      registerBoolServiceExtension(
        name: WidgetsServiceExtensions.debugAllowBanner.name,
        getter: () => Future<bool>.value(WidgetsApp.debugAllowBannerOverride),
        setter: (bool value) {
          if (WidgetsApp.debugAllowBannerOverride == value) {
            return Future<void>.value();
          }
          WidgetsApp.debugAllowBannerOverride = value;
          return _forceRebuild();
        },
      );

      WidgetInspectorService.instance.initServiceExtensions(registerServiceExtension);

      return true;
    }());
  }

  Future<void> _forceRebuild() {
    if (rootElement != null) {
      buildOwner!.reassemble(rootElement!);
      return endOfFrame;
    }
    return Future<void>.value();
  }

  BuildOwner? get buildOwner => _buildOwner;
  // Initialization of [_buildOwner] has to be done within the [initInstances]
  // method, as it requires [ServicesBinding] to properly setup the
  // [defaultBinaryMessenger] instance.
  BuildOwner? _buildOwner;

  FocusManager get focusManager => _buildOwner!.focusManager;

  late PlatformMenuDelegate platformMenuDelegate;

  final List<WidgetsBindingObserver> _observers = <WidgetsBindingObserver>[];

  void addObserver(WidgetsBindingObserver observer) => _observers.add(observer);

  bool removeObserver(WidgetsBindingObserver observer) => _observers.remove(observer);

  @override
  Future<AppExitResponse> handleRequestAppExit() async {
    bool didCancel = false;
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if ((await observer.didRequestAppExit()) == AppExitResponse.cancel) {
        didCancel = true;
        // Don't early return. For the case where someone is just using the
        // observer to know when exit happens, we want to call all the
        // observers, even if we already know we're going to cancel.
      }
    }
    return didCancel ? AppExitResponse.cancel : AppExitResponse.exit;
  }

  @override
  void handleMetricsChanged() {
    super.handleMetricsChanged();
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangeMetrics();
    }
  }

  @override
  void handleTextScaleFactorChanged() {
    super.handleTextScaleFactorChanged();
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangeTextScaleFactor();
    }
  }

  @override
  void handlePlatformBrightnessChanged() {
    super.handlePlatformBrightnessChanged();
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangePlatformBrightness();
    }
  }

  @override
  void handleAccessibilityFeaturesChanged() {
    super.handleAccessibilityFeaturesChanged();
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangeAccessibilityFeatures();
    }
  }

  @protected
  @mustCallSuper
  @visibleForTesting
  void handleLocaleChanged() {
    dispatchLocalesChanged(platformDispatcher.locales);
  }

  @protected
  @mustCallSuper
  void dispatchLocalesChanged(List<Locale>? locales) {
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangeLocales(locales);
    }
  }

  @protected
  @mustCallSuper
  void dispatchAccessibilityFeaturesChanged() {
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangeAccessibilityFeatures();
    }
  }

  @protected
  @visibleForTesting
  Future<void> handlePopRoute() async {
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if (await observer.didPopRoute()) {
        return;
      }
    }
    SystemNavigator.pop();
  }

  @protected
  @mustCallSuper
  @visibleForTesting
  Future<void> handlePushRoute(String route) async {
    final RouteInformation routeInformation = RouteInformation(uri: Uri.parse(route));
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if (await observer.didPushRouteInformation(routeInformation)) {
        return;
      }
    }
  }

  Future<void> _handlePushRouteInformation(Map<dynamic, dynamic> routeArguments) async {
    final RouteInformation routeInformation = RouteInformation(
      uri: Uri.parse(routeArguments['location'] as String),
      state: routeArguments['state'] as Object?,
    );
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if (await observer.didPushRouteInformation(routeInformation)) {
        return;
      }
    }
  }

  Future<dynamic> _handleNavigationInvocation(MethodCall methodCall) {
    switch (methodCall.method) {
      case 'popRoute':
        return handlePopRoute();
      case 'pushRoute':
        return handlePushRoute(methodCall.arguments as String);
      case 'pushRouteInformation':
        return _handlePushRouteInformation(methodCall.arguments as Map<dynamic, dynamic>);
    }
    return Future<dynamic>.value();
  }

  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    super.handleAppLifecycleStateChanged(state);
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didChangeAppLifecycleState(state);
    }
  }

  @override
  void handleMemoryPressure() {
    super.handleMemoryPressure();
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      observer.didHaveMemoryPressure();
    }
  }

  bool _needToReportFirstFrame = true;

  final Completer<void> _firstFrameCompleter = Completer<void>();

  bool get firstFrameRasterized => _firstFrameCompleter.isCompleted;

  Future<void> get waitUntilFirstFrameRasterized => _firstFrameCompleter.future;

  bool get debugDidSendFirstFrameEvent => !_needToReportFirstFrame;

  void _handleBuildScheduled() {
    // If we're in the process of building dirty elements, then changes
    // should not trigger a new frame.
    assert(() {
      if (debugBuildingDirtyElements) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Build scheduled during frame.'),
          ErrorDescription(
            'While the widget tree was being built, laid out, and painted, '
            'a new frame was scheduled to rebuild the widget tree.',
          ),
          ErrorHint(
            'This might be because setState() was called from a layout or '
            'paint callback. '
            'If a change is needed to the widget tree, it should be applied '
            'as the tree is being built. Scheduling a change for the subsequent '
            'frame instead results in an interface that lags behind by one frame. '
            'If this was done to make your build dependent on a size measured at '
            'layout time, consider using a LayoutBuilder, CustomSingleChildLayout, '
            'or CustomMultiChildLayout. If, on the other hand, the one frame delay '
            'is the desired effect, for example because this is an '
            'animation, consider scheduling the frame in a post-frame callback '
            'using SchedulerBinding.addPostFrameCallback or '
            'using an AnimationController to trigger the animation.',
          ),
        ]);
      }
      return true;
    }());
    ensureVisualUpdate();
  }

  @protected
  bool debugBuildingDirtyElements = false;

  //
  // When editing the above, also update rendering/binding.dart's copy.
  @override
  void drawFrame() {
    assert(!debugBuildingDirtyElements);
    assert(() {
      debugBuildingDirtyElements = true;
      return true;
    }());

    TimingsCallback? firstFrameCallback;
    if (_needToReportFirstFrame) {
      assert(!_firstFrameCompleter.isCompleted);

      firstFrameCallback = (List<FrameTiming> timings) {
        assert(sendFramesToEngine);
        if (!kReleaseMode) {
          // Change the current user tag back to the default tag. At this point,
          // the user tag should be set to "AppStartUp" (originally set in the
          // engine), so we need to change it back to the default tag to mark
          // the end of app start up for CPU profiles.
          developer.UserTag.defaultTag.makeCurrent();
          developer.Timeline.instantSync('Rasterized first useful frame');
          developer.postEvent('Flutter.FirstFrame', <String, dynamic>{});
        }
        SchedulerBinding.instance.removeTimingsCallback(firstFrameCallback!);
        firstFrameCallback = null;
        _firstFrameCompleter.complete();
      };
      // Callback is only invoked when FlutterView.render is called. When
      // sendFramesToEngine is set to false during the frame, it will not be
      // called and we need to remove the callback (see below).
      SchedulerBinding.instance.addTimingsCallback(firstFrameCallback!);
    }

    try {
      if (rootElement != null) {
        buildOwner!.buildScope(rootElement!);
      }
      super.drawFrame();
      buildOwner!.finalizeTree();
    } finally {
      assert(() {
        debugBuildingDirtyElements = false;
        return true;
      }());
    }
    if (!kReleaseMode) {
      if (_needToReportFirstFrame && sendFramesToEngine) {
        developer.Timeline.instantSync('Widgets built first useful frame');
      }
    }
    _needToReportFirstFrame = false;
    if (firstFrameCallback != null && !sendFramesToEngine) {
      // This frame is deferred and not the first frame sent to the engine that
      // should be reported.
      _needToReportFirstFrame = true;
      SchedulerBinding.instance.removeTimingsCallback(firstFrameCallback!);
    }
  }

  Element? get rootElement => _rootElement;
  Element? _rootElement;

  @Deprecated(
    'Use rootElement instead. '
    'This feature was deprecated after v3.9.0-16.0.pre.'
  )
  Element? get renderViewElement => rootElement;

  bool _readyToProduceFrames = false;

  @override
  bool get framesEnabled => super.framesEnabled && _readyToProduceFrames;

  Widget wrapWithDefaultView(Widget rootWidget) {
    return View(
      view: platformDispatcher.implicitView!,
      deprecatedDoNotUseWillBeRemovedWithoutNoticePipelineOwner: pipelineOwner,
      deprecatedDoNotUseWillBeRemovedWithoutNoticeRenderView: renderView,
      child: rootWidget,
    );
  }

  @protected
  void scheduleAttachRootWidget(Widget rootWidget) {
    Timer.run(() {
      attachRootWidget(rootWidget);
    });
  }

  void attachRootWidget(Widget rootWidget) {
    attachToBuildOwner(RootWidget(
      debugShortDescription: '[root]',
      child: rootWidget,
    ));
  }

  void attachToBuildOwner(RootWidget widget) {
    final bool isBootstrapFrame = rootElement == null;
    _readyToProduceFrames = true;
    _rootElement = widget.attach(buildOwner!, rootElement as RootElement?);
    if (isBootstrapFrame) {
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  bool get isRootWidgetAttached => _rootElement != null;

  @override
  Future<void> performReassemble() {
    assert(() {
      WidgetInspectorService.instance.performReassemble();
      return true;
    }());

    if (rootElement != null) {
      buildOwner!.reassemble(rootElement!);
    }
    return super.performReassemble();
  }

  Locale? computePlatformResolvedLocale(List<Locale> supportedLocales) {
    return platformDispatcher.computePlatformResolvedLocale(supportedLocales);
  }
}

void runApp(Widget app) {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  assert(binding.debugCheckZone('runApp'));
  binding
    ..scheduleAttachRootWidget(binding.wrapWithDefaultView(app))
    ..scheduleWarmUpFrame();
}

String _debugDumpAppString() {
  const String mode = kDebugMode ? 'DEBUG MODE' : kReleaseMode ? 'RELEASE MODE' : 'PROFILE MODE';
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('${WidgetsBinding.instance.runtimeType} - $mode');
  if (WidgetsBinding.instance.rootElement != null) {
    buffer.writeln(WidgetsBinding.instance.rootElement!.toStringDeep());
  } else {
    buffer.writeln('<no tree currently mounted>');
  }
  return buffer.toString();
}

void debugDumpApp() {
  debugPrint(_debugDumpAppString());
}

class RootWidget extends Widget {
  const RootWidget({
    super.key,
    this.child,
    this.debugShortDescription,
  });

  final Widget? child;

  final String? debugShortDescription;

  @override
  RootElement createElement() => RootElement(this);

  RootElement attach(BuildOwner owner, [ RootElement? element ]) {
    if (element == null) {
      owner.lockState(() {
        element = createElement();
        assert(element != null);
        element!.assignOwner(owner);
      });
      owner.buildScope(element!, () {
        element!.mount(/* parent */ null, /* slot */ null);
      });
    } else {
      element._newWidget = this;
      element.markNeedsBuild();
    }
    return element!;
  }

  @override
  String toStringShort() => debugShortDescription ?? super.toStringShort();
}

class RootElement extends Element with RootElementMixin {
  RootElement(RootWidget super.widget);

  Element? _child;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    assert(parent == null); // We are the root!
    super.mount(parent, newSlot);
    _rebuild();
    assert(_child != null);
    super.performRebuild(); // clears the "dirty" flag
  }

  @override
  void update(RootWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _rebuild();
  }

  // When we are assigned a new widget, we store it here
  // until we are ready to update to it.
  RootWidget? _newWidget;

  @override
  void performRebuild() {
    if (_newWidget != null) {
      // _newWidget can be null if, for instance, we were rebuilt
      // due to a reassemble.
      final RootWidget newWidget = _newWidget!;
      _newWidget = null;
      update(newWidget);
    }
    super.performRebuild();
    assert(_newWidget == null);
  }

  void _rebuild() {
    try {
      _child = updateChild(_child, (widget as RootWidget).child, /* slot */ null);
    } catch (exception, stack) {
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets library',
        context: ErrorDescription('attaching to the render tree'),
      );
      FlutterError.reportError(details);
      // No error widget possible here since it wouldn't have a view to render into.
      _child = null;
    }

  }

  @override
  bool get debugDoingBuild => false; // This element doesn't have a build phase.

  @override
  // There is no ancestor RenderObjectElement that the render object could be attached to.
  bool debugExpectsRenderObjectForSlot(Object? slot) => false;
}

class WidgetsFlutterBinding extends BindingBase with GestureBinding, SchedulerBinding, ServicesBinding, PaintingBinding, SemanticsBinding, RendererBinding, WidgetsBinding {
  static WidgetsBinding ensureInitialized() {
    if (WidgetsBinding._instance == null) {
      WidgetsFlutterBinding();
    }
    return WidgetsBinding.instance;
  }
}