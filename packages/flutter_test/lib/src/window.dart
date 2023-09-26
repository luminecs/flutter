import 'dart:ui' hide window;

import 'package:flutter/foundation.dart';

@immutable
// ignore: avoid_implementing_value_types
class FakeAccessibilityFeatures implements AccessibilityFeatures {
  const FakeAccessibilityFeatures({
    this.accessibleNavigation = false,
    this.invertColors = false,
    this.disableAnimations = false,
    this.boldText = false,
    this.reduceMotion = false,
    this.highContrast = false,
    this.onOffSwitchLabels = false,
  });

  static const FakeAccessibilityFeatures allOn = FakeAccessibilityFeatures(
    accessibleNavigation: true,
    invertColors: true,
    disableAnimations: true,
    boldText: true,
    reduceMotion: true,
    highContrast: true,
    onOffSwitchLabels: true,
  );

  @override
  final bool accessibleNavigation;

  @override
  final bool invertColors;

  @override
  final bool disableAnimations;

  @override
  final bool boldText;

  @override
  final bool reduceMotion;

  @override
  final bool highContrast;

  @override
  final bool onOffSwitchLabels;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FakeAccessibilityFeatures &&
        other.accessibleNavigation == accessibleNavigation &&
        other.invertColors == invertColors &&
        other.disableAnimations == disableAnimations &&
        other.boldText == boldText &&
        other.reduceMotion == reduceMotion &&
        other.highContrast == highContrast &&
        other.onOffSwitchLabels == onOffSwitchLabels;
  }

  @override
  int get hashCode {
    return Object.hash(
      accessibleNavigation,
      invertColors,
      disableAnimations,
      boldText,
      reduceMotion,
      highContrast,
      onOffSwitchLabels,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

@immutable
class FakeViewPadding implements ViewPadding {
  const FakeViewPadding({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  FakeViewPadding._wrap(ViewPadding base)
      : left = base.left,
        top = base.top,
        right = base.right,
        bottom = base.bottom;

  static const FakeViewPadding zero = FakeViewPadding();

  @override
  final double left;

  @override
  final double top;

  @override
  final double right;

  @override
  final double bottom;
}

class TestPlatformDispatcher implements PlatformDispatcher {
  TestPlatformDispatcher({
    required PlatformDispatcher platformDispatcher,
  }) : _platformDispatcher = platformDispatcher {
    _updateViewsAndDisplays();
    _platformDispatcher.onMetricsChanged = _handleMetricsChanged;
  }

  final PlatformDispatcher _platformDispatcher;

  @override
  TestFlutterView? get implicitView {
    return _platformDispatcher.implicitView != null
        ? _testViews[_platformDispatcher.implicitView!.viewId]!
        : null;
  }

  final Map<int, TestFlutterView> _testViews = <int, TestFlutterView>{};
  final Map<int, TestDisplay> _testDisplays = <int, TestDisplay>{};

  @override
  VoidCallback? get onMetricsChanged => _platformDispatcher.onMetricsChanged;
  VoidCallback? _onMetricsChanged;
  @override
  set onMetricsChanged(VoidCallback? callback) {
    _onMetricsChanged = callback;
  }

  void _handleMetricsChanged() {
    _updateViewsAndDisplays();
    _onMetricsChanged?.call();
  }

  @override
  Locale get locale => _localeTestValue ?? _platformDispatcher.locale;
  Locale? _localeTestValue;
  set localeTestValue(Locale localeTestValue) {
    // ignore: avoid_setters_without_getters
    _localeTestValue = localeTestValue;
    onLocaleChanged?.call();
  }

  void clearLocaleTestValue() {
    _localeTestValue = null;
    onLocaleChanged?.call();
  }

  @override
  List<Locale> get locales => _localesTestValue ?? _platformDispatcher.locales;
  List<Locale>? _localesTestValue;
  set localesTestValue(List<Locale> localesTestValue) {
    // ignore: avoid_setters_without_getters
    _localesTestValue = localesTestValue;
    onLocaleChanged?.call();
  }

  void clearLocalesTestValue() {
    _localesTestValue = null;
    onLocaleChanged?.call();
  }

  @override
  VoidCallback? get onLocaleChanged => _platformDispatcher.onLocaleChanged;
  @override
  set onLocaleChanged(VoidCallback? callback) {
    _platformDispatcher.onLocaleChanged = callback;
  }

  @override
  String get initialLifecycleState => _initialLifecycleStateTestValue;
  String _initialLifecycleStateTestValue = '';
  set initialLifecycleStateTestValue(String state) {
    // ignore: avoid_setters_without_getters
    _initialLifecycleStateTestValue = state;
  }

  void resetInitialLifecycleState() {
    _initialLifecycleStateTestValue = '';
  }

  @override
  double get textScaleFactor =>
      _textScaleFactorTestValue ?? _platformDispatcher.textScaleFactor;
  double? _textScaleFactorTestValue;
  set textScaleFactorTestValue(double textScaleFactorTestValue) {
    // ignore: avoid_setters_without_getters
    _textScaleFactorTestValue = textScaleFactorTestValue;
    onTextScaleFactorChanged?.call();
  }

  void clearTextScaleFactorTestValue() {
    _textScaleFactorTestValue = null;
    onTextScaleFactorChanged?.call();
  }

  @override
  Brightness get platformBrightness =>
      _platformBrightnessTestValue ?? _platformDispatcher.platformBrightness;
  Brightness? _platformBrightnessTestValue;
  @override
  VoidCallback? get onPlatformBrightnessChanged =>
      _platformDispatcher.onPlatformBrightnessChanged;
  @override
  set onPlatformBrightnessChanged(VoidCallback? callback) {
    _platformDispatcher.onPlatformBrightnessChanged = callback;
  }

  set platformBrightnessTestValue(Brightness platformBrightnessTestValue) {
    // ignore: avoid_setters_without_getters
    _platformBrightnessTestValue = platformBrightnessTestValue;
    onPlatformBrightnessChanged?.call();
  }

  void clearPlatformBrightnessTestValue() {
    _platformBrightnessTestValue = null;
    onPlatformBrightnessChanged?.call();
  }

  @override
  bool get alwaysUse24HourFormat =>
      _alwaysUse24HourFormatTestValue ??
      _platformDispatcher.alwaysUse24HourFormat;
  bool? _alwaysUse24HourFormatTestValue;
  set alwaysUse24HourFormatTestValue(bool alwaysUse24HourFormatTestValue) {
    // ignore: avoid_setters_without_getters
    _alwaysUse24HourFormatTestValue = alwaysUse24HourFormatTestValue;
  }

  void clearAlwaysUse24HourTestValue() {
    _alwaysUse24HourFormatTestValue = null;
  }

  @override
  VoidCallback? get onTextScaleFactorChanged =>
      _platformDispatcher.onTextScaleFactorChanged;
  @override
  set onTextScaleFactorChanged(VoidCallback? callback) {
    _platformDispatcher.onTextScaleFactorChanged = callback;
  }

  @override
  bool get nativeSpellCheckServiceDefined =>
      _nativeSpellCheckServiceDefinedTestValue ??
      _platformDispatcher.nativeSpellCheckServiceDefined;
  bool? _nativeSpellCheckServiceDefinedTestValue;
  set nativeSpellCheckServiceDefinedTestValue(
      bool nativeSpellCheckServiceDefinedTestValue) {
    // ignore: avoid_setters_without_getters
    _nativeSpellCheckServiceDefinedTestValue =
        nativeSpellCheckServiceDefinedTestValue;
  }

  void clearNativeSpellCheckServiceDefined() {
    _nativeSpellCheckServiceDefinedTestValue = null;
  }

  @override
  bool get brieflyShowPassword =>
      _brieflyShowPasswordTestValue ?? _platformDispatcher.brieflyShowPassword;
  bool? _brieflyShowPasswordTestValue;
  set brieflyShowPasswordTestValue(bool brieflyShowPasswordTestValue) {
    // ignore: avoid_setters_without_getters
    _brieflyShowPasswordTestValue = brieflyShowPasswordTestValue;
  }

  void resetBrieflyShowPassword() {
    _brieflyShowPasswordTestValue = null;
  }

  @override
  FrameCallback? get onBeginFrame => _platformDispatcher.onBeginFrame;
  @override
  set onBeginFrame(FrameCallback? callback) {
    _platformDispatcher.onBeginFrame = callback;
  }

  @override
  VoidCallback? get onDrawFrame => _platformDispatcher.onDrawFrame;
  @override
  set onDrawFrame(VoidCallback? callback) {
    _platformDispatcher.onDrawFrame = callback;
  }

  @override
  TimingsCallback? get onReportTimings => _platformDispatcher.onReportTimings;
  @override
  set onReportTimings(TimingsCallback? callback) {
    _platformDispatcher.onReportTimings = callback;
  }

  @override
  PointerDataPacketCallback? get onPointerDataPacket =>
      _platformDispatcher.onPointerDataPacket;
  @override
  set onPointerDataPacket(PointerDataPacketCallback? callback) {
    _platformDispatcher.onPointerDataPacket = callback;
  }

  @override
  String get defaultRouteName =>
      _defaultRouteNameTestValue ?? _platformDispatcher.defaultRouteName;
  String? _defaultRouteNameTestValue;
  set defaultRouteNameTestValue(String defaultRouteNameTestValue) {
    // ignore: avoid_setters_without_getters
    _defaultRouteNameTestValue = defaultRouteNameTestValue;
  }

  void clearDefaultRouteNameTestValue() {
    _defaultRouteNameTestValue = null;
  }

  @override
  void scheduleFrame() {
    _platformDispatcher.scheduleFrame();
  }

  @override
  bool get semanticsEnabled =>
      _semanticsEnabledTestValue ?? _platformDispatcher.semanticsEnabled;
  bool? _semanticsEnabledTestValue;
  set semanticsEnabledTestValue(bool semanticsEnabledTestValue) {
    // ignore: avoid_setters_without_getters
    _semanticsEnabledTestValue = semanticsEnabledTestValue;
    onSemanticsEnabledChanged?.call();
  }

  void clearSemanticsEnabledTestValue() {
    _semanticsEnabledTestValue = null;
    onSemanticsEnabledChanged?.call();
  }

  @override
  VoidCallback? get onSemanticsEnabledChanged =>
      _platformDispatcher.onSemanticsEnabledChanged;
  @override
  set onSemanticsEnabledChanged(VoidCallback? callback) {
    _platformDispatcher.onSemanticsEnabledChanged = callback;
  }

  @override
  SemanticsActionEventCallback? get onSemanticsActionEvent =>
      _platformDispatcher.onSemanticsActionEvent;
  @override
  set onSemanticsActionEvent(SemanticsActionEventCallback? callback) {
    _platformDispatcher.onSemanticsActionEvent = callback;
  }

  @override
  AccessibilityFeatures get accessibilityFeatures =>
      _accessibilityFeaturesTestValue ??
      _platformDispatcher.accessibilityFeatures;
  AccessibilityFeatures? _accessibilityFeaturesTestValue;
  set accessibilityFeaturesTestValue(
      AccessibilityFeatures accessibilityFeaturesTestValue) {
    // ignore: avoid_setters_without_getters
    _accessibilityFeaturesTestValue = accessibilityFeaturesTestValue;
    onAccessibilityFeaturesChanged?.call();
  }

  void clearAccessibilityFeaturesTestValue() {
    _accessibilityFeaturesTestValue = null;
    onAccessibilityFeaturesChanged?.call();
  }

  @override
  VoidCallback? get onAccessibilityFeaturesChanged =>
      _platformDispatcher.onAccessibilityFeaturesChanged;
  @override
  set onAccessibilityFeaturesChanged(VoidCallback? callback) {
    _platformDispatcher.onAccessibilityFeaturesChanged = callback;
  }

  @override
  void setIsolateDebugName(String name) {
    _platformDispatcher.setIsolateDebugName(name);
  }

  @override
  void sendPlatformMessage(
    String name,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    _platformDispatcher.sendPlatformMessage(name, data, callback);
  }

  void clearAllTestValues() {
    clearAccessibilityFeaturesTestValue();
    clearAlwaysUse24HourTestValue();
    clearDefaultRouteNameTestValue();
    clearPlatformBrightnessTestValue();
    clearLocaleTestValue();
    clearLocalesTestValue();
    clearSemanticsEnabledTestValue();
    clearTextScaleFactorTestValue();
    clearNativeSpellCheckServiceDefined();
    resetBrieflyShowPassword();
    resetInitialLifecycleState();
    resetSystemFontFamily();
  }

  @override
  VoidCallback? get onFrameDataChanged =>
      _platformDispatcher.onFrameDataChanged;
  @override
  set onFrameDataChanged(VoidCallback? value) {
    _platformDispatcher.onFrameDataChanged = value;
  }

  @override
  KeyDataCallback? get onKeyData => _platformDispatcher.onKeyData;

  @override
  set onKeyData(KeyDataCallback? onKeyData) {
    _platformDispatcher.onKeyData = onKeyData;
  }

  @override
  VoidCallback? get onPlatformConfigurationChanged =>
      _platformDispatcher.onPlatformConfigurationChanged;

  @override
  set onPlatformConfigurationChanged(
      VoidCallback? onPlatformConfigurationChanged) {
    _platformDispatcher.onPlatformConfigurationChanged =
        onPlatformConfigurationChanged;
  }

  @override
  Locale? computePlatformResolvedLocale(List<Locale> supportedLocales) =>
      _platformDispatcher.computePlatformResolvedLocale(supportedLocales);

  @override
  ByteData? getPersistentIsolateData() =>
      _platformDispatcher.getPersistentIsolateData();

  @override
  Iterable<TestFlutterView> get views => _testViews.values;

  @override
  FlutterView? view({required int id}) => _testViews[id];

  @override
  Iterable<TestDisplay> get displays => _testDisplays.values;

  void _updateViewsAndDisplays() {
    final List<Object> extraDisplayKeys = <Object>[..._testDisplays.keys];
    for (final Display display in _platformDispatcher.displays) {
      extraDisplayKeys.remove(display.id);
      if (!_testDisplays.containsKey(display.id)) {
        _testDisplays[display.id] = TestDisplay(this, display);
      }
    }
    extraDisplayKeys.forEach(_testDisplays.remove);

    final List<Object> extraViewKeys = <Object>[..._testViews.keys];
    for (final FlutterView view in _platformDispatcher.views) {
      // TODO(pdblasi-google): Remove this try-catch once the Display API is stable and supported on all platforms
      late final TestDisplay display;
      try {
        final Display realDisplay = view.display;
        if (_testDisplays.containsKey(realDisplay.id)) {
          display = _testDisplays[view.display.id]!;
        } else {
          display = _UnsupportedDisplay(
            this,
            view,
            'PlatformDispatcher did not contain a Display with id ${realDisplay.id}, '
            'which was expected by FlutterView ($view)',
          );
        }
      } catch (error) {
        display = _UnsupportedDisplay(this, view, error);
      }

      extraViewKeys.remove(view.viewId);
      if (!_testViews.containsKey(view.viewId)) {
        _testViews[view.viewId] = TestFlutterView(
          view: view,
          platformDispatcher: this,
          display: display,
        );
      }
    }

    extraViewKeys.forEach(_testViews.remove);
  }

  @override
  ErrorCallback? get onError => _platformDispatcher.onError;
  @override
  set onError(ErrorCallback? value) {
    _platformDispatcher.onError;
  }

  @override
  VoidCallback? get onSystemFontFamilyChanged =>
      _platformDispatcher.onSystemFontFamilyChanged;
  @override
  set onSystemFontFamilyChanged(VoidCallback? value) {
    _platformDispatcher.onSystemFontFamilyChanged = value;
  }

  @override
  FrameData get frameData => _platformDispatcher.frameData;

  @override
  void registerBackgroundIsolate(RootIsolateToken token) {
    _platformDispatcher.registerBackgroundIsolate(token);
  }

  @override
  void requestDartPerformanceMode(DartPerformanceMode mode) {
    _platformDispatcher.requestDartPerformanceMode(mode);
  }

  @override
  String? get systemFontFamily {
    return _forceSystemFontFamilyToBeNull
        ? null
        : _systemFontFamily ?? _platformDispatcher.systemFontFamily;
  }

  String? _systemFontFamily;
  bool _forceSystemFontFamilyToBeNull = false;
  set systemFontFamily(String? value) {
    _systemFontFamily = value;
    if (value == null) {
      _forceSystemFontFamilyToBeNull = true;
    }
    onSystemFontFamilyChanged?.call();
  }

  void resetSystemFontFamily() {
    _systemFontFamily = null;
    _forceSystemFontFamilyToBeNull = false;
    onSystemFontFamilyChanged?.call();
  }

  @override
  void updateSemantics(SemanticsUpdate update) {
    // Using the deprecated method to maintain backwards compatibility during
    // the multi-view transition window.
    // ignore: deprecated_member_use
    _platformDispatcher.updateSemantics(update);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class TestFlutterView implements FlutterView {
  TestFlutterView({
    required FlutterView view,
    required TestPlatformDispatcher platformDispatcher,
    required TestDisplay display,
  })  : _view = view,
        _platformDispatcher = platformDispatcher,
        _display = display;

  final FlutterView _view;

  @override
  TestPlatformDispatcher get platformDispatcher => _platformDispatcher;
  final TestPlatformDispatcher _platformDispatcher;

  @override
  TestDisplay get display => _display;
  final TestDisplay _display;

  @override
  int get viewId => _view.viewId;

  @override
  double get devicePixelRatio =>
      _display._devicePixelRatio ?? _view.devicePixelRatio;
  set devicePixelRatio(double value) {
    _display.devicePixelRatio = value;
  }

  void resetDevicePixelRatio() {
    _display.resetDevicePixelRatio();
  }

  @override
  List<DisplayFeature> get displayFeatures =>
      _displayFeatures ?? _view.displayFeatures;
  List<DisplayFeature>? _displayFeatures;
  set displayFeatures(List<DisplayFeature> value) {
    _displayFeatures = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetDisplayFeatures() {
    _displayFeatures = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  FakeViewPadding get padding =>
      _padding ?? FakeViewPadding._wrap(_view.padding);
  FakeViewPadding? _padding;
  set padding(FakeViewPadding value) {
    _padding = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetPadding() {
    _padding = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  Rect get physicalGeometry {
    Rect value = _physicalGeometry ?? _view.physicalGeometry;
    if (_physicalSize != null) {
      value = value.topLeft & _physicalSize!;
    }
    return value;
  }

  Rect? _physicalGeometry;
  set physicalGeometry(Rect value) {
    _physicalGeometry = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetPhysicalGeometry() {
    _physicalGeometry = null;
    _physicalSize = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  Size get physicalSize {
    // This has to be able to default to `_view.physicalSize` as web_ui handles
    // `physicalSize` and `physicalGeometry` differently than dart:ui, where
    // the values are both based off of `physicalGeometry`.
    return _physicalSize ?? _physicalGeometry?.size ?? _view.physicalSize;
  }

  Size? _physicalSize;
  set physicalSize(Size value) {
    _physicalSize = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetPhysicalSize() {
    resetPhysicalGeometry();
  }

  @override
  FakeViewPadding get systemGestureInsets =>
      _systemGestureInsets ?? FakeViewPadding._wrap(_view.systemGestureInsets);
  FakeViewPadding? _systemGestureInsets;
  set systemGestureInsets(FakeViewPadding value) {
    _systemGestureInsets = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetSystemGestureInsets() {
    _systemGestureInsets = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  FakeViewPadding get viewInsets =>
      _viewInsets ?? FakeViewPadding._wrap(_view.viewInsets);
  FakeViewPadding? _viewInsets;
  set viewInsets(FakeViewPadding value) {
    _viewInsets = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetViewInsets() {
    _viewInsets = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  FakeViewPadding get viewPadding =>
      _viewPadding ?? FakeViewPadding._wrap(_view.viewPadding);
  FakeViewPadding? _viewPadding;
  set viewPadding(FakeViewPadding value) {
    _viewPadding = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetViewPadding() {
    _viewPadding = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  GestureSettings get gestureSettings =>
      _gestureSettings ?? _view.gestureSettings;
  GestureSettings? _gestureSettings;
  set gestureSettings(GestureSettings value) {
    _gestureSettings = value;
    platformDispatcher.onMetricsChanged?.call();
  }

  void resetGestureSettings() {
    _gestureSettings = null;
    platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void render(Scene scene) {
    _view.render(scene);
  }

  @override
  void updateSemantics(SemanticsUpdate update) {
    _view.updateSemantics(update);
  }

  void reset() {
    resetDevicePixelRatio();
    resetDisplayFeatures();
    resetPadding();
    resetPhysicalGeometry();
    // Skipping resetPhysicalSize because resetPhysicalGeometry resets both values.
    resetSystemGestureInsets();
    resetViewInsets();
    resetViewPadding();
    resetGestureSettings();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class TestDisplay implements Display {
  TestDisplay(TestPlatformDispatcher platformDispatcher, Display display)
      : _platformDispatcher = platformDispatcher,
        _display = display;

  final Display _display;
  final TestPlatformDispatcher _platformDispatcher;

  @override
  int get id => _display.id;

  @override
  double get devicePixelRatio => _devicePixelRatio ?? _display.devicePixelRatio;
  double? _devicePixelRatio;
  set devicePixelRatio(double value) {
    _devicePixelRatio = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  void resetDevicePixelRatio() {
    _devicePixelRatio = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  double get refreshRate => _refreshRate ?? _display.refreshRate;
  double? _refreshRate;
  set refreshRate(double value) {
    _refreshRate = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  void resetRefreshRate() {
    _refreshRate = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  Size get size => _size ?? _display.size;
  Size? _size;
  set size(Size value) {
    _size = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  void resetSize() {
    _size = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  void reset() {
    resetDevicePixelRatio();
    resetRefreshRate();
    resetSize();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

// TODO(pdblasi-google): Remove this once the Display API is stable and supported on all platforms
class _UnsupportedDisplay implements TestDisplay {
  _UnsupportedDisplay(this._platformDispatcher, this._view, this.error);

  final FlutterView _view;
  final Object? error;

  @override
  final TestPlatformDispatcher _platformDispatcher;

  @override
  double get devicePixelRatio => _devicePixelRatio ?? _view.devicePixelRatio;
  @override
  double? _devicePixelRatio;
  @override
  set devicePixelRatio(double value) {
    _devicePixelRatio = value;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  void resetDevicePixelRatio() {
    _devicePixelRatio = null;
    _platformDispatcher.onMetricsChanged?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'The Display API is unsupported in this context. '
      'As of the last metrics change on PlatformDispatcher, this was the error '
      'given when trying to prepare the display for testing: $error',
    );
  }
}

@Deprecated(
    'Use TestPlatformDispatcher (via WidgetTester.platformDispatcher) or TestFlutterView (via WidgetTester.view) instead. '
    'Deprecated to prepare for the upcoming multi-window support. '
    'This feature was deprecated after v3.9.0-0.1.pre.')
class TestWindow implements SingletonFlutterWindow {
  @Deprecated(
      'Use TestPlatformDispatcher (via WidgetTester.platformDispatcher) or TestFlutterView (via WidgetTester.view) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  TestWindow({
    required SingletonFlutterWindow window,
  }) : platformDispatcher = TestPlatformDispatcher(
            platformDispatcher: window.platformDispatcher);

  @Deprecated(
      'Use TestPlatformDispatcher (via WidgetTester.platformDispatcher) or TestFlutterView (via WidgetTester.view) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  TestWindow.fromPlatformDispatcher({
    @Deprecated('Use WidgetTester.platformDispatcher instead. '
        'Deprecated to prepare for the upcoming multi-window support. '
        'This feature was deprecated after v3.9.0-0.1.pre.')
    required this.platformDispatcher,
  });

  @Deprecated('Use WidgetTester.platformDispatcher instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  final TestPlatformDispatcher platformDispatcher;

  TestFlutterView get _view => platformDispatcher.implicitView!;

  @Deprecated('Use WidgetTester.view.devicePixelRatio instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  double get devicePixelRatio => _view.devicePixelRatio;
  @Deprecated('Use WidgetTester.view.devicePixelRatio instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set devicePixelRatioTestValue(double devicePixelRatio) {
    // ignore: avoid_setters_without_getters
    _view.devicePixelRatio = devicePixelRatio;
  }

  @Deprecated('Use WidgetTester.view.resetDevicePixelRatio() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearDevicePixelRatioTestValue() {
    _view.resetDevicePixelRatio();
  }

  @Deprecated('Use WidgetTester.view.physicalSize instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  Size get physicalSize => _view.physicalSize;
  @Deprecated('Use WidgetTester.view.physicalSize instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set physicalSizeTestValue(Size physicalSizeTestValue) {
    // ignore: avoid_setters_without_getters
    _view.physicalSize = physicalSizeTestValue;
  }

  @Deprecated('Use WidgetTester.view.resetPhysicalSize() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearPhysicalSizeTestValue() {
    _view.resetPhysicalSize();
  }

  @Deprecated('Use WidgetTester.view.viewInsets instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  ViewPadding get viewInsets => _view.viewInsets;
  @Deprecated('Use WidgetTester.view.viewInsets instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set viewInsetsTestValue(ViewPadding value) {
    // ignore: avoid_setters_without_getters
    _view.viewInsets =
        value is FakeViewPadding ? value : FakeViewPadding._wrap(value);
  }

  @Deprecated('Use WidgetTester.view.resetViewInsets() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearViewInsetsTestValue() {
    _view.resetViewInsets();
  }

  @Deprecated('Use WidgetTester.view.viewPadding instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  ViewPadding get viewPadding => _view.viewPadding;
  @Deprecated('Use WidgetTester.view.viewPadding instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set viewPaddingTestValue(ViewPadding value) {
    // ignore: avoid_setters_without_getters
    _view.viewPadding =
        value is FakeViewPadding ? value : FakeViewPadding._wrap(value);
  }

  @Deprecated('Use WidgetTester.view.resetViewPadding() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearViewPaddingTestValue() {
    _view.resetViewPadding();
  }

  @Deprecated('Use WidgetTester.view.padding instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  ViewPadding get padding => _view.padding;
  @Deprecated('Use WidgetTester.view.padding instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set paddingTestValue(ViewPadding value) {
    // ignore: avoid_setters_without_getters
    _view.padding =
        value is FakeViewPadding ? value : FakeViewPadding._wrap(value);
  }

  @Deprecated('Use WidgetTester.view.resetPadding() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearPaddingTestValue() {
    _view.resetPadding();
  }

  @Deprecated('Use WidgetTester.view.gestureSettings instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  GestureSettings get gestureSettings => _view.gestureSettings;
  @Deprecated('Use WidgetTester.view.gestureSettings instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set gestureSettingsTestValue(GestureSettings gestureSettingsTestValue) {
    // ignore: avoid_setters_without_getters
    _view.gestureSettings = gestureSettingsTestValue;
  }

  @Deprecated('Use WidgetTester.view.resetGestureSettings() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearGestureSettingsTestValue() {
    _view.resetGestureSettings();
  }

  @Deprecated('Use WidgetTester.view.displayFeatures instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  List<DisplayFeature> get displayFeatures => _view.displayFeatures;
  @Deprecated('Use WidgetTester.view.displayFeatures instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set displayFeaturesTestValue(List<DisplayFeature> displayFeaturesTestValue) {
    // ignore: avoid_setters_without_getters
    _view.displayFeatures = displayFeaturesTestValue;
  }

  @Deprecated('Use WidgetTester.view.resetDisplayFeatures() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearDisplayFeaturesTestValue() {
    _view.resetDisplayFeatures();
  }

  @Deprecated('Use WidgetTester.view.systemGestureInsets instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  ViewPadding get systemGestureInsets => _view.systemGestureInsets;
  @Deprecated('Use WidgetTester.view.systemGestureInsets instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set systemGestureInsetsTestValue(ViewPadding value) {
    // ignore: avoid_setters_without_getters
    _view.systemGestureInsets =
        value is FakeViewPadding ? value : FakeViewPadding._wrap(value);
  }

  @Deprecated('Use WidgetTester.view.resetSystemGestureInsets() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearSystemGestureInsetsTestValue() {
    _view.resetSystemGestureInsets();
  }

  @Deprecated('Use WidgetTester.platformDispatcher.onMetricsChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onMetricsChanged => platformDispatcher.onMetricsChanged;
  @Deprecated('Use WidgetTester.platformDispatcher.onMetricsChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onMetricsChanged(VoidCallback? callback) {
    platformDispatcher.onMetricsChanged = callback;
  }

  @Deprecated('Use WidgetTester.platformDispatcher.locale instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  Locale get locale => platformDispatcher.locale;

  @Deprecated('Use WidgetTester.platformDispatcher.locales instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  List<Locale> get locales => platformDispatcher.locales;

  @Deprecated('Use WidgetTester.platformDispatcher.onLocaleChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onLocaleChanged => platformDispatcher.onLocaleChanged;
  @Deprecated('Use WidgetTester.platformDispatcher.onLocaleChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onLocaleChanged(VoidCallback? callback) {
    platformDispatcher.onLocaleChanged = callback;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.initialLifecycleState instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  String get initialLifecycleState => platformDispatcher.initialLifecycleState;

  @Deprecated('Use WidgetTester.platformDispatcher.textScaleFactor instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  double get textScaleFactor => platformDispatcher.textScaleFactor;

  @Deprecated('Use WidgetTester.platformDispatcher.platformBrightness instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  Brightness get platformBrightness => platformDispatcher.platformBrightness;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onPlatformBrightnessChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onPlatformBrightnessChanged =>
      platformDispatcher.onPlatformBrightnessChanged;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onPlatformBrightnessChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onPlatformBrightnessChanged(VoidCallback? callback) {
    platformDispatcher.onPlatformBrightnessChanged = callback;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.alwaysUse24HourFormat instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  bool get alwaysUse24HourFormat => platformDispatcher.alwaysUse24HourFormat;

  @Deprecated(
      'Use WidgetTester.platformDispatcher.onTextScaleFactorChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onTextScaleFactorChanged =>
      platformDispatcher.onTextScaleFactorChanged;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onTextScaleFactorChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onTextScaleFactorChanged(VoidCallback? callback) {
    platformDispatcher.onTextScaleFactorChanged = callback;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.nativeSpellCheckServiceDefined instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  bool get nativeSpellCheckServiceDefined =>
      platformDispatcher.nativeSpellCheckServiceDefined;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  set nativeSpellCheckServiceDefinedTestValue(
      bool nativeSpellCheckServiceDefinedTestValue) {
    // ignore: avoid_setters_without_getters
    platformDispatcher.nativeSpellCheckServiceDefinedTestValue =
        nativeSpellCheckServiceDefinedTestValue;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.brieflyShowPassword instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  bool get brieflyShowPassword => platformDispatcher.brieflyShowPassword;

  @Deprecated('Use WidgetTester.platformDispatcher.onBeginFrame instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  FrameCallback? get onBeginFrame => platformDispatcher.onBeginFrame;
  @Deprecated('Use WidgetTester.platformDispatcher.onBeginFrame instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onBeginFrame(FrameCallback? callback) {
    platformDispatcher.onBeginFrame = callback;
  }

  @Deprecated('Use WidgetTester.platformDispatcher.onDrawFrame instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onDrawFrame => platformDispatcher.onDrawFrame;
  @Deprecated('Use WidgetTester.platformDispatcher.onDrawFrame instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onDrawFrame(VoidCallback? callback) {
    platformDispatcher.onDrawFrame = callback;
  }

  @Deprecated('Use WidgetTester.platformDispatcher.onReportTimings instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  TimingsCallback? get onReportTimings => platformDispatcher.onReportTimings;
  @Deprecated('Use WidgetTester.platformDispatcher.onReportTimings instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onReportTimings(TimingsCallback? callback) {
    platformDispatcher.onReportTimings = callback;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.onPointerDataPacket instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  PointerDataPacketCallback? get onPointerDataPacket =>
      platformDispatcher.onPointerDataPacket;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onPointerDataPacket instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onPointerDataPacket(PointerDataPacketCallback? callback) {
    platformDispatcher.onPointerDataPacket = callback;
  }

  @Deprecated('Use WidgetTester.platformDispatcher.defaultRouteName instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  String get defaultRouteName => platformDispatcher.defaultRouteName;

  @Deprecated('Use WidgetTester.platformDispatcher.scheduleFrame() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  void scheduleFrame() {
    platformDispatcher.scheduleFrame();
  }

  @Deprecated('Use WidgetTester.view.render(scene) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  void render(Scene scene) {
    _view.render(scene);
  }

  @Deprecated('Use WidgetTester.platformDispatcher.semanticsEnabled instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  bool get semanticsEnabled => platformDispatcher.semanticsEnabled;

  @Deprecated(
      'Use WidgetTester.platformDispatcher.onSemanticsEnabledChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onSemanticsEnabledChanged =>
      platformDispatcher.onSemanticsEnabledChanged;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onSemanticsEnabledChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onSemanticsEnabledChanged(VoidCallback? callback) {
    platformDispatcher.onSemanticsEnabledChanged = callback;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.accessibilityFeatures instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  AccessibilityFeatures get accessibilityFeatures =>
      platformDispatcher.accessibilityFeatures;

  @Deprecated(
      'Use WidgetTester.platformDispatcher.onAccessibilityFeaturesChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onAccessibilityFeaturesChanged =>
      platformDispatcher.onAccessibilityFeaturesChanged;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onAccessibilityFeaturesChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onAccessibilityFeaturesChanged(VoidCallback? callback) {
    platformDispatcher.onAccessibilityFeaturesChanged = callback;
  }

  @Deprecated('Use WidgetTester.view.updateSemantics(update) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  void updateSemantics(SemanticsUpdate update) {
    _view.updateSemantics(update);
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.setIsolateDebugName(name) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  void setIsolateDebugName(String name) {
    platformDispatcher.setIsolateDebugName(name);
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.sendPlatformMessage(name, data, callback) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  void sendPlatformMessage(
    String name,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    platformDispatcher.sendPlatformMessage(name, data, callback);
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.clearAllTestValues() and WidgetTester.view.reset() instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  void clearAllTestValues() {
    clearDevicePixelRatioTestValue();
    clearPaddingTestValue();
    clearGestureSettingsTestValue();
    clearDisplayFeaturesTestValue();
    clearPhysicalSizeTestValue();
    clearViewInsetsTestValue();
    platformDispatcher.clearAllTestValues();
  }

  @override
  @Deprecated('Use WidgetTester.platformDispatcher.onFrameDataChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  VoidCallback? get onFrameDataChanged => platformDispatcher.onFrameDataChanged;
  @Deprecated('Use WidgetTester.platformDispatcher.onFrameDataChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onFrameDataChanged(VoidCallback? value) {
    platformDispatcher.onFrameDataChanged = value;
  }

  @Deprecated('Use WidgetTester.platformDispatcher.onKeyData instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  KeyDataCallback? get onKeyData => platformDispatcher.onKeyData;
  @Deprecated('Use WidgetTester.platformDispatcher.onKeyData instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onKeyData(KeyDataCallback? value) {
    platformDispatcher.onKeyData = value;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.onSystemFontFamilyChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  VoidCallback? get onSystemFontFamilyChanged =>
      platformDispatcher.onSystemFontFamilyChanged;
  @Deprecated(
      'Use WidgetTester.platformDispatcher.onSystemFontFamilyChanged instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  set onSystemFontFamilyChanged(VoidCallback? value) {
    platformDispatcher.onSystemFontFamilyChanged = value;
  }

  @Deprecated(
      'Use WidgetTester.platformDispatcher.computePlatformResolvedLocale(supportedLocales) instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  Locale? computePlatformResolvedLocale(List<Locale> supportedLocales) {
    return platformDispatcher.computePlatformResolvedLocale(supportedLocales);
  }

  @Deprecated('Use WidgetTester.platformDispatcher.frameData instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  FrameData get frameData => platformDispatcher.frameData;

  @Deprecated('Use WidgetTester.platformDispatcher.physicalGeometry instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  Rect get physicalGeometry => _view.physicalGeometry;

  @Deprecated('Use WidgetTester.platformDispatcher.systemFontFamily instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  String? get systemFontFamily => platformDispatcher.systemFontFamily;

  @Deprecated('Use WidgetTester.view.viewId instead. '
      'Deprecated to prepare for the upcoming multi-window support. '
      'This feature was deprecated after v3.9.0-0.1.pre.')
  @override
  int get viewId => _view.viewId;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}
