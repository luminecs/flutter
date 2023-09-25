import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'basic.dart';
import 'binding.dart';
import 'debug.dart';
import 'framework.dart';
import 'inherited_model.dart';

// Examples can assume:
// late BuildContext context;

enum Orientation {
  portrait,

  landscape
}

enum _MediaQueryAspect {
  size,
  orientation,
  devicePixelRatio,
  textScaleFactor,
  textScaler,
  platformBrightness,
  padding,
  viewInsets,
  systemGestureInsets,
  viewPadding,
  alwaysUse24HourFormat,
  accessibleNavigation,
  invertColors,
  highContrast,
  onOffSwitchLabels,
  disableAnimations,
  boldText,
  navigationMode,
  gestureSettings,
  displayFeatures,
}

@immutable
class MediaQueryData {
  const MediaQueryData({
    this.size = Size.zero,
    this.devicePixelRatio = 1.0,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = _kUnspecifiedTextScaler,
    this.platformBrightness = Brightness.light,
    this.padding = EdgeInsets.zero,
    this.viewInsets = EdgeInsets.zero,
    this.systemGestureInsets = EdgeInsets.zero,
    this.viewPadding = EdgeInsets.zero,
    this.alwaysUse24HourFormat = false,
    this.accessibleNavigation = false,
    this.invertColors = false,
    this.highContrast = false,
    this.onOffSwitchLabels = false,
    this.disableAnimations = false,
    this.boldText = false,
    this.navigationMode = NavigationMode.traditional,
    this.gestureSettings = const DeviceGestureSettings(touchSlop: kTouchSlop),
    this.displayFeatures = const <ui.DisplayFeature>[],
  }) : _textScaleFactor = textScaleFactor,
       _textScaler = textScaler,
       assert(
         identical(textScaler, _kUnspecifiedTextScaler) || textScaleFactor == 1.0,
         'textScaleFactor is deprecated and cannot be specified when textScaler is specified.',
       );

  @Deprecated(
    'Use MediaQueryData.fromView instead. '
    'This constructor was deprecated in preparation for the upcoming multi-window support. '
    'This feature was deprecated after v3.7.0-32.0.pre.'
  )
  factory MediaQueryData.fromWindow(ui.FlutterView window) => MediaQueryData.fromView(window);

  MediaQueryData.fromView(ui.FlutterView view, {MediaQueryData? platformData})
    : size = view.physicalSize / view.devicePixelRatio,
      devicePixelRatio = view.devicePixelRatio,
      _textScaleFactor = 1.0, // _textScaler is the source of truth.
      _textScaler = _textScalerFromView(view, platformData),
      platformBrightness = platformData?.platformBrightness ?? view.platformDispatcher.platformBrightness,
      padding = EdgeInsets.fromViewPadding(view.padding, view.devicePixelRatio),
      viewPadding = EdgeInsets.fromViewPadding(view.viewPadding, view.devicePixelRatio),
      viewInsets = EdgeInsets.fromViewPadding(view.viewInsets, view.devicePixelRatio),
      systemGestureInsets = EdgeInsets.fromViewPadding(view.systemGestureInsets, view.devicePixelRatio),
      accessibleNavigation = platformData?.accessibleNavigation ?? view.platformDispatcher.accessibilityFeatures.accessibleNavigation,
      invertColors = platformData?.invertColors ?? view.platformDispatcher.accessibilityFeatures.invertColors,
      disableAnimations = platformData?.disableAnimations ?? view.platformDispatcher.accessibilityFeatures.disableAnimations,
      boldText = platformData?.boldText ?? view.platformDispatcher.accessibilityFeatures.boldText,
      highContrast = platformData?.highContrast ?? view.platformDispatcher.accessibilityFeatures.highContrast,
      onOffSwitchLabels = platformData?.onOffSwitchLabels ?? view.platformDispatcher.accessibilityFeatures.onOffSwitchLabels,
      alwaysUse24HourFormat = platformData?.alwaysUse24HourFormat ?? view.platformDispatcher.alwaysUse24HourFormat,
      navigationMode = platformData?.navigationMode ?? NavigationMode.traditional,
      gestureSettings = DeviceGestureSettings.fromView(view),
      displayFeatures = view.displayFeatures;

  static TextScaler _textScalerFromView(ui.FlutterView view, MediaQueryData? platformData) {
    final double scaleFactor = platformData?.textScaleFactor ?? view.platformDispatcher.textScaleFactor;
    return scaleFactor == 1.0 ? TextScaler.noScaling : TextScaler.linear(scaleFactor);
  }

  final Size size;

  final double devicePixelRatio;

  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  double get textScaleFactor => textScaler.textScaleFactor;
  // TODO(LongCatIsLooong): remove this after textScaleFactor is removed. To
  // maintain backward compatibility and also keep the const constructor this
  // has to be kept as a private field.
  // https://github.com/flutter/flutter/issues/128825
  final double _textScaleFactor;

  TextScaler get textScaler {
    // The constructor was called with an explicitly specified textScaler value,
    // we assume the caller is migrated and ignore _textScaleFactor.
    if (!identical(_kUnspecifiedTextScaler, _textScaler)) {
      return _textScaler;
    }
    return _textScaleFactor == 1.0
      // textScaleFactor and textScaler from the constructor are consistent.
      ? TextScaler.noScaling
      // The constructor was called with an explicitly specified textScaleFactor,
      // we assume the caller is unmigrated and ignore _textScaler.
      : TextScaler.linear(_textScaleFactor);
  }
  final TextScaler _textScaler;

  final Brightness platformBrightness;

  final EdgeInsets viewInsets;

  final EdgeInsets padding;

  final EdgeInsets viewPadding;

  final EdgeInsets systemGestureInsets;

  final bool alwaysUse24HourFormat;

  final bool accessibleNavigation;

  final bool invertColors;

  final bool highContrast;

  final bool onOffSwitchLabels;

  final bool disableAnimations;

  final bool boldText;

  final NavigationMode navigationMode;

  final DeviceGestureSettings gestureSettings;

  final List<ui.DisplayFeature> displayFeatures;

  Orientation get orientation {
    return size.width > size.height ? Orientation.landscape : Orientation.portrait;
  }

  MediaQueryData copyWith({
    Size? size,
    double? devicePixelRatio,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double? textScaleFactor,
    TextScaler? textScaler,
    Brightness? platformBrightness,
    EdgeInsets? padding,
    EdgeInsets? viewPadding,
    EdgeInsets? viewInsets,
    EdgeInsets? systemGestureInsets,
    bool? alwaysUse24HourFormat,
    bool? highContrast,
    bool? onOffSwitchLabels,
    bool? disableAnimations,
    bool? invertColors,
    bool? accessibleNavigation,
    bool? boldText,
    NavigationMode? navigationMode,
    DeviceGestureSettings? gestureSettings,
    List<ui.DisplayFeature>? displayFeatures,
  }) {
    assert(textScaleFactor == null || textScaler == null);
    if (textScaleFactor != null) {
      textScaler ??= TextScaler.linear(textScaleFactor);
    }
    return MediaQueryData(
      size: size ?? this.size,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      textScaler: textScaler ?? this.textScaler,
      platformBrightness: platformBrightness ?? this.platformBrightness,
      padding: padding ?? this.padding,
      viewPadding: viewPadding ?? this.viewPadding,
      viewInsets: viewInsets ?? this.viewInsets,
      systemGestureInsets: systemGestureInsets ?? this.systemGestureInsets,
      alwaysUse24HourFormat: alwaysUse24HourFormat ?? this.alwaysUse24HourFormat,
      invertColors: invertColors ?? this.invertColors,
      highContrast: highContrast ?? this.highContrast,
      onOffSwitchLabels: onOffSwitchLabels ?? this.onOffSwitchLabels,
      disableAnimations: disableAnimations ?? this.disableAnimations,
      accessibleNavigation: accessibleNavigation ?? this.accessibleNavigation,
      boldText: boldText ?? this.boldText,
      navigationMode: navigationMode ?? this.navigationMode,
      gestureSettings: gestureSettings ?? this.gestureSettings,
      displayFeatures: displayFeatures ?? this.displayFeatures,
    );
  }

  MediaQueryData removePadding({
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
  }) {
    if (!(removeLeft || removeTop || removeRight || removeBottom)) {
      return this;
    }
    return copyWith(
      padding: padding.copyWith(
        left: removeLeft ? 0.0 : null,
        top: removeTop ? 0.0 : null,
        right: removeRight ? 0.0 : null,
        bottom: removeBottom ? 0.0 : null,
      ),
      viewPadding: viewPadding.copyWith(
        left: removeLeft ? math.max(0.0, viewPadding.left - padding.left) : null,
        top: removeTop ? math.max(0.0, viewPadding.top - padding.top) : null,
        right: removeRight ? math.max(0.0, viewPadding.right - padding.right) : null,
        bottom: removeBottom ? math.max(0.0, viewPadding.bottom - padding.bottom) : null,
      ),
    );
  }

  MediaQueryData removeViewInsets({
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
  }) {
    if (!(removeLeft || removeTop || removeRight || removeBottom)) {
      return this;
    }
    return copyWith(
      viewPadding: viewPadding.copyWith(
        left: removeLeft ? math.max(0.0, viewPadding.left - viewInsets.left) : null,
        top: removeTop ? math.max(0.0, viewPadding.top - viewInsets.top) : null,
        right: removeRight ? math.max(0.0, viewPadding.right - viewInsets.right) : null,
        bottom: removeBottom ? math.max(0.0, viewPadding.bottom - viewInsets.bottom) : null,
      ),
      viewInsets: viewInsets.copyWith(
        left: removeLeft ? 0.0 : null,
        top: removeTop ? 0.0 : null,
        right: removeRight ? 0.0 : null,
        bottom: removeBottom ? 0.0 : null,
      ),
    );
  }

  MediaQueryData removeViewPadding({
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
  }) {
    if (!(removeLeft || removeTop || removeRight || removeBottom)) {
      return this;
    }
    return copyWith(
      padding: padding.copyWith(
        left: removeLeft ? 0.0 : null,
        top: removeTop ? 0.0 : null,
        right: removeRight ? 0.0 : null,
        bottom: removeBottom ? 0.0 : null,
      ),
      viewPadding: viewPadding.copyWith(
        left: removeLeft ? 0.0 : null,
        top: removeTop ? 0.0 : null,
        right: removeRight ? 0.0 : null,
        bottom: removeBottom ? 0.0 : null,
      ),
    );
  }

  MediaQueryData removeDisplayFeatures(Rect subScreen) {
    assert(subScreen.left >= 0.0 && subScreen.top >= 0.0 &&
        subScreen.right <= size.width && subScreen.bottom <= size.height,
        "'subScreen' argument cannot be outside the bounds of the screen");
    if (subScreen.size == size && subScreen.topLeft == Offset.zero) {
      return this;
    }
    final double rightInset = size.width - subScreen.right;
    final double bottomInset = size.height - subScreen.bottom;
    return copyWith(
      padding: EdgeInsets.only(
        left: math.max(0.0, padding.left - subScreen.left),
        top: math.max(0.0, padding.top - subScreen.top),
        right: math.max(0.0, padding.right - rightInset),
        bottom: math.max(0.0, padding.bottom - bottomInset),
      ),
      viewPadding: EdgeInsets.only(
        left: math.max(0.0, viewPadding.left - subScreen.left),
        top: math.max(0.0, viewPadding.top - subScreen.top),
        right: math.max(0.0, viewPadding.right - rightInset),
        bottom: math.max(0.0, viewPadding.bottom - bottomInset),
      ),
      viewInsets: EdgeInsets.only(
        left: math.max(0.0, viewInsets.left - subScreen.left),
        top: math.max(0.0, viewInsets.top - subScreen.top),
        right: math.max(0.0, viewInsets.right - rightInset),
        bottom: math.max(0.0, viewInsets.bottom - bottomInset),
      ),
      displayFeatures: displayFeatures.where(
        (ui.DisplayFeature displayFeature) => subScreen.overlaps(displayFeature.bounds)
      ).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MediaQueryData
        && other.size == size
        && other.devicePixelRatio == devicePixelRatio
        && other.textScaleFactor == textScaleFactor
        && other.platformBrightness == platformBrightness
        && other.padding == padding
        && other.viewPadding == viewPadding
        && other.viewInsets == viewInsets
        && other.systemGestureInsets == systemGestureInsets
        && other.alwaysUse24HourFormat == alwaysUse24HourFormat
        && other.highContrast == highContrast
        && other.onOffSwitchLabels == onOffSwitchLabels
        && other.disableAnimations == disableAnimations
        && other.invertColors == invertColors
        && other.accessibleNavigation == accessibleNavigation
        && other.boldText == boldText
        && other.navigationMode == navigationMode
        && other.gestureSettings == gestureSettings
        && listEquals(other.displayFeatures, displayFeatures);
  }

  @override
  int get hashCode => Object.hash(
    size,
    devicePixelRatio,
    textScaleFactor,
    platformBrightness,
    padding,
    viewPadding,
    viewInsets,
    alwaysUse24HourFormat,
    highContrast,
    onOffSwitchLabels,
    disableAnimations,
    invertColors,
    accessibleNavigation,
    boldText,
    navigationMode,
    gestureSettings,
    Object.hashAll(displayFeatures),
  );

  @override
  String toString() {
    final List<String> properties = <String>[
      'size: $size',
      'devicePixelRatio: ${devicePixelRatio.toStringAsFixed(1)}',
      'textScaler: $textScaler',
      'platformBrightness: $platformBrightness',
      'padding: $padding',
      'viewPadding: $viewPadding',
      'viewInsets: $viewInsets',
      'systemGestureInsets: $systemGestureInsets',
      'alwaysUse24HourFormat: $alwaysUse24HourFormat',
      'accessibleNavigation: $accessibleNavigation',
      'highContrast: $highContrast',
      'onOffSwitchLabels: $onOffSwitchLabels',
      'disableAnimations: $disableAnimations',
      'invertColors: $invertColors',
      'boldText: $boldText',
      'navigationMode: ${navigationMode.name}',
      'gestureSettings: $gestureSettings',
      'displayFeatures: $displayFeatures',
    ];
    return '${objectRuntimeType(this, 'MediaQueryData')}(${properties.join(', ')})';
  }
}

class MediaQuery extends InheritedModel<_MediaQueryAspect> {
  const MediaQuery({
    super.key,
    required this.data,
    required super.child,
  });

  factory MediaQuery.removePadding({
    Key? key,
    required BuildContext context,
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
    required Widget child,
  }) {
    return MediaQuery(
      key: key,
      data: MediaQuery.of(context).removePadding(
        removeLeft: removeLeft,
        removeTop: removeTop,
        removeRight: removeRight,
        removeBottom: removeBottom,
      ),
      child: child,
    );
  }

  factory MediaQuery.removeViewInsets({
    Key? key,
    required BuildContext context,
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
    required Widget child,
  }) {
    return MediaQuery(
      key: key,
      data: MediaQuery.of(context).removeViewInsets(
        removeLeft: removeLeft,
        removeTop: removeTop,
        removeRight: removeRight,
        removeBottom: removeBottom,
      ),
      child: child,
    );
  }

  factory MediaQuery.removeViewPadding({
    Key? key,
    required BuildContext context,
    bool removeLeft = false,
    bool removeTop = false,
    bool removeRight = false,
    bool removeBottom = false,
    required Widget child,
  }) {
    return MediaQuery(
      key: key,
      data: MediaQuery.of(context).removeViewPadding(
        removeLeft: removeLeft,
        removeTop: removeTop,
        removeRight: removeRight,
        removeBottom: removeBottom,
      ),
      child: child,
    );
  }

  @Deprecated(
    'Use MediaQuery.fromView instead. '
    'This constructor was deprecated in preparation for the upcoming multi-window support. '
    'This feature was deprecated after v3.7.0-32.0.pre.'
  )
  static Widget fromWindow({
    Key? key,
    required Widget child,
  }) {
    return _MediaQueryFromView(
      key: key,
      view: WidgetsBinding.instance.window,
      ignoreParentData: true,
      child: child,
    );
  }

  static Widget fromView({
    Key? key,
    required FlutterView view,
    required Widget child,
  }) {
    return _MediaQueryFromView(
      key: key,
      view: view,
      child: child,
    );
  }

  static Widget withNoTextScaling({
    Key? key,
    required Widget child,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        assert(debugCheckHasMediaQuery(context));
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child,
        );
      },
    );
  }

  static Widget withClampedTextScaling({
    Key? key,
    double minScaleFactor = 0.0,
    double maxScaleFactor = double.infinity,
    required Widget child,
  }) {
    assert(maxScaleFactor >= minScaleFactor);
    assert(!maxScaleFactor.isNaN);
    assert(minScaleFactor.isFinite);
    assert(minScaleFactor >= 0);

    return Builder(builder: (BuildContext context) {
      assert(debugCheckHasMediaQuery(context));
      final MediaQueryData data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(
          textScaler: data.textScaler.clamp(minScaleFactor: minScaleFactor, maxScaleFactor: maxScaleFactor),
        ),
        child: child,
      );
    });
  }

  final MediaQueryData data;

  static MediaQueryData of(BuildContext context) {
    return _of(context);
  }

  static MediaQueryData _of(BuildContext context, [_MediaQueryAspect? aspect]) {
    assert(debugCheckHasMediaQuery(context));
    return InheritedModel.inheritFrom<MediaQuery>(context, aspect: aspect)!.data;
  }

  static MediaQueryData? maybeOf(BuildContext context) {
    return _maybeOf(context);
  }

  static MediaQueryData? _maybeOf(BuildContext context, [_MediaQueryAspect? aspect]) {
    return InheritedModel.inheritFrom<MediaQuery>(context, aspect: aspect)?.data;
  }

  static Size sizeOf(BuildContext context) => _of(context, _MediaQueryAspect.size).size;

  static Size? maybeSizeOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.size)?.size;

  static Orientation orientationOf(BuildContext context) => _of(context, _MediaQueryAspect.orientation).orientation;

  static Orientation? maybeOrientationOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.orientation)?.orientation;

  static double devicePixelRatioOf(BuildContext context) => _of(context, _MediaQueryAspect.devicePixelRatio).devicePixelRatio;

  static double? maybeDevicePixelRatioOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.devicePixelRatio)?.devicePixelRatio;

  @Deprecated(
    'Use textScalerOf instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  static double textScaleFactorOf(BuildContext context) => maybeTextScaleFactorOf(context) ?? 1.0;

  @Deprecated(
    'Use maybeTextScalerOf instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  static double? maybeTextScaleFactorOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.textScaleFactor)?.textScaleFactor;

  static TextScaler textScalerOf(BuildContext context) => maybeTextScalerOf(context) ?? TextScaler.noScaling;

  static TextScaler? maybeTextScalerOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.textScaler)?.textScaler;

  static Brightness platformBrightnessOf(BuildContext context) => maybePlatformBrightnessOf(context) ?? Brightness.light;

  static Brightness? maybePlatformBrightnessOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.platformBrightness)?.platformBrightness;

  static EdgeInsets paddingOf(BuildContext context) => _of(context, _MediaQueryAspect.padding).padding;

  static EdgeInsets? maybePaddingOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.padding)?.padding;

  static EdgeInsets viewInsetsOf(BuildContext context) => _of(context, _MediaQueryAspect.viewInsets).viewInsets;

  static EdgeInsets? maybeViewInsetsOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.viewInsets)?.viewInsets;

  static EdgeInsets systemGestureInsetsOf(BuildContext context) => _of(context, _MediaQueryAspect.systemGestureInsets).systemGestureInsets;

  static EdgeInsets? maybeSystemGestureInsetsOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.systemGestureInsets)?.systemGestureInsets;

  static EdgeInsets viewPaddingOf(BuildContext context) => _of(context, _MediaQueryAspect.viewPadding).viewPadding;

  static EdgeInsets? maybeViewPaddingOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.viewPadding)?.viewPadding;

  static bool alwaysUse24HourFormatOf(BuildContext context) => _of(context, _MediaQueryAspect.alwaysUse24HourFormat).alwaysUse24HourFormat;

  static bool? maybeAlwaysUse24HourFormatOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.alwaysUse24HourFormat)?.alwaysUse24HourFormat;

  static bool accessibleNavigationOf(BuildContext context) => _of(context, _MediaQueryAspect.accessibleNavigation).accessibleNavigation;

  static bool? maybeAccessibleNavigationOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.accessibleNavigation)?.accessibleNavigation;

  static bool invertColorsOf(BuildContext context) => _of(context, _MediaQueryAspect.invertColors).invertColors;

  static bool? maybeInvertColorsOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.invertColors)?.invertColors;

  static bool highContrastOf(BuildContext context) => maybeHighContrastOf(context) ?? false;

  static bool? maybeHighContrastOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.highContrast)?.highContrast;

  static bool onOffSwitchLabelsOf(BuildContext context) => maybeOnOffSwitchLabelsOf(context) ?? false;

  static bool? maybeOnOffSwitchLabelsOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.onOffSwitchLabels)?.onOffSwitchLabels;

  static bool disableAnimationsOf(BuildContext context) => _of(context, _MediaQueryAspect.disableAnimations).disableAnimations;

  static bool? maybeDisableAnimationsOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.disableAnimations)?.disableAnimations;


  static bool boldTextOf(BuildContext context) => maybeBoldTextOf(context) ?? false;

  @Deprecated(
    'Migrate to boldTextOf. '
    'This feature was deprecated after v3.5.0-9.0.pre.'
  )
  static bool boldTextOverride(BuildContext context) => boldTextOf(context);

  static bool? maybeBoldTextOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.boldText)?.boldText;

  static NavigationMode navigationModeOf(BuildContext context) => _of(context, _MediaQueryAspect.navigationMode).navigationMode;

  static NavigationMode? maybeNavigationModeOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.navigationMode)?.navigationMode;

  static DeviceGestureSettings gestureSettingsOf(BuildContext context) => _of(context, _MediaQueryAspect.gestureSettings).gestureSettings;

  static DeviceGestureSettings? maybeGestureSettingsOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.gestureSettings)?.gestureSettings;

  static List<ui.DisplayFeature> displayFeaturesOf(BuildContext context) => _of(context, _MediaQueryAspect.displayFeatures).displayFeatures;

  static List<ui.DisplayFeature>? maybeDisplayFeaturesOf(BuildContext context) => _maybeOf(context, _MediaQueryAspect.displayFeatures)?.displayFeatures;

  @override
  bool updateShouldNotify(MediaQuery oldWidget) => data != oldWidget.data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MediaQueryData>('data', data, showName: false));
  }

  @override
  bool updateShouldNotifyDependent(MediaQuery oldWidget, Set<Object> dependencies) {
    for (final Object dependency in dependencies) {
      if (dependency is _MediaQueryAspect) {
        switch (dependency) {
          case _MediaQueryAspect.size:
            if (data.size != oldWidget.data.size) {
              return true;
            }
          case _MediaQueryAspect.orientation:
            if (data.orientation != oldWidget.data.orientation) {
              return true;
            }
          case _MediaQueryAspect.devicePixelRatio:
            if (data.devicePixelRatio != oldWidget.data.devicePixelRatio) {
              return true;
            }
          case _MediaQueryAspect.textScaleFactor:
            if (data.textScaleFactor != oldWidget.data.textScaleFactor) {
              return true;
            }
          case _MediaQueryAspect.textScaler:
            if (data.textScaler != oldWidget.data.textScaler) {
              return true;
            }
          case _MediaQueryAspect.platformBrightness:
            if (data.platformBrightness != oldWidget.data.platformBrightness) {
              return true;
            }
          case _MediaQueryAspect.padding:
            if (data.padding != oldWidget.data.padding) {
              return true;
            }
          case _MediaQueryAspect.viewInsets:
            if (data.viewInsets != oldWidget.data.viewInsets) {
              return true;
            }
          case _MediaQueryAspect.systemGestureInsets:
            if (data.systemGestureInsets != oldWidget.data.systemGestureInsets) {
              return true;
            }
          case _MediaQueryAspect.viewPadding:
            if (data.viewPadding != oldWidget.data.viewPadding) {
              return true;
            }
          case _MediaQueryAspect.alwaysUse24HourFormat:
            if (data.alwaysUse24HourFormat != oldWidget.data.alwaysUse24HourFormat) {
              return true;
            }
          case _MediaQueryAspect.accessibleNavigation:
            if (data.accessibleNavigation != oldWidget.data.accessibleNavigation) {
              return true;
            }
          case _MediaQueryAspect.invertColors:
            if (data.invertColors != oldWidget.data.invertColors) {
              return true;
            }
          case _MediaQueryAspect.highContrast:
            if (data.highContrast != oldWidget.data.highContrast) {
              return true;
            }
          case _MediaQueryAspect.onOffSwitchLabels:
            if (data.onOffSwitchLabels != oldWidget.data.onOffSwitchLabels) {
              return true;
            }
          case _MediaQueryAspect.disableAnimations:
            if (data.disableAnimations != oldWidget.data.disableAnimations) {
              return true;
            }
          case _MediaQueryAspect.boldText:
            if (data.boldText != oldWidget.data.boldText) {
              return true;
            }
          case _MediaQueryAspect.navigationMode:
            if (data.navigationMode != oldWidget.data.navigationMode) {
              return true;
            }
          case _MediaQueryAspect.gestureSettings:
            if (data.gestureSettings != oldWidget.data.gestureSettings) {
              return true;
            }
          case _MediaQueryAspect.displayFeatures:
            if (data.displayFeatures != oldWidget.data.displayFeatures) {
              return true;
            }
        }
      }
    }
    return false;
  }
}

enum NavigationMode {
  traditional,

  directional,
}

class _MediaQueryFromView extends StatefulWidget {
  const _MediaQueryFromView({
    super.key,
    required this.view,
    this.ignoreParentData = false,
    required this.child,
  });

  final FlutterView view;
  final bool ignoreParentData;
  final Widget child;

  @override
  State<_MediaQueryFromView> createState() => _MediaQueryFromViewState();
}

class _MediaQueryFromViewState extends State<_MediaQueryFromView> with WidgetsBindingObserver {
  MediaQueryData? _parentData;
  MediaQueryData? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateParentData();
    _updateData();
    assert(_data != null);
  }

  @override
  void didUpdateWidget(_MediaQueryFromView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ignoreParentData != oldWidget.ignoreParentData) {
      _updateParentData();
    }
    if (_data == null || oldWidget.view != widget.view) {
      _updateData();
    }
    assert(_data != null);
  }

  void _updateParentData() {
    _parentData = widget.ignoreParentData ? null : MediaQuery.maybeOf(context);
    _data = null; // _updateData must be called again after changing parent data.
  }

  void _updateData() {
    final MediaQueryData newData = MediaQueryData.fromView(widget.view, platformData: _parentData);
    if (newData != _data) {
      setState(() {
        _data = newData;
      });
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    // If we have a parent, it dictates our accessibility features. If we don't
    // have a parent, we get our accessibility features straight from the
    // PlatformDispatcher and need to update our data in response to the
    // PlatformDispatcher changing its accessibility features setting.
    if (_parentData == null) {
      _updateData();
    }
  }

  @override
  void didChangeMetrics() {
    _updateData();
  }

  @override
  void didChangeTextScaleFactor() {
    // If we have a parent, it dictates our text scale factor. If we don't have
    // a parent, we get our text scale factor from the PlatformDispatcher and
    // need to update our data in response to the PlatformDispatcher changing
    // its text scale factor setting.
    if (_parentData == null) {
      _updateData();
    }
  }

  @override
  void didChangePlatformBrightness() {
    // If we have a parent, it dictates our platform brightness. If we don't
    // have a parent, we get our platform brightness from the PlatformDispatcher
    // and need to update our data in response to the PlatformDispatcher
    // changing its platform brightness setting.
    if (_parentData == null) {
      _updateData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData effectiveData = _data!;
    // If we get our platformBrightness from the PlatformDispatcher (i.e. we have no parentData) replace it
    // with the debugBrightnessOverride in non-release mode.
    if (!kReleaseMode && _parentData == null && effectiveData.platformBrightness != debugBrightnessOverride) {
      effectiveData = effectiveData.copyWith(platformBrightness: debugBrightnessOverride);
    }
    return MediaQuery(
      data: effectiveData,
      child: widget.child,
    );
  }
}

const TextScaler _kUnspecifiedTextScaler = _UnspecifiedTextScaler();
// TODO(LongCatIsLooong): Remove once `MediaQueryData.textScaleFactor` is
// removed: https://github.com/flutter/flutter/issues/128825.
class _UnspecifiedTextScaler implements TextScaler {
  const _UnspecifiedTextScaler();

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) => throw UnimplementedError();

  @override
  double scale(double fontSize) => throw UnimplementedError();

  @override
  double get textScaleFactor => throw UnimplementedError();
}