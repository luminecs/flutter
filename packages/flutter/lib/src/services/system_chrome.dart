import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'binding.dart';
import 'system_channels.dart';

export 'dart:ui' show Brightness, Color;

export 'binding.dart' show SystemUiChangeCallback;

enum DeviceOrientation {
  portraitUp,

  landscapeLeft,

  portraitDown,

  landscapeRight,
}

@immutable
class ApplicationSwitcherDescription {
  const ApplicationSwitcherDescription({this.label, this.primaryColor});

  final String? label;

  final int? primaryColor;
}

enum SystemUiOverlay {
  top,

  bottom,
}

enum SystemUiMode {
  leanBack,

  immersive,

  immersiveSticky,

  edgeToEdge,

  manual,
}

@immutable
class SystemUiOverlayStyle {
  const SystemUiOverlayStyle({
    this.systemNavigationBarColor,
    this.systemNavigationBarDividerColor,
    this.systemNavigationBarIconBrightness,
    this.systemNavigationBarContrastEnforced,
    this.statusBarColor,
    this.statusBarBrightness,
    this.statusBarIconBrightness,
    this.systemStatusBarContrastEnforced,
  });

  final Color? systemNavigationBarColor;

  final Color? systemNavigationBarDividerColor;

  final Brightness? systemNavigationBarIconBrightness;

  final bool? systemNavigationBarContrastEnforced;

  final Color? statusBarColor;

  final Brightness? statusBarBrightness;

  final Brightness? statusBarIconBrightness;

  final bool? systemStatusBarContrastEnforced;

  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  Map<String, dynamic> _toMap() {
    return <String, dynamic>{
      'systemNavigationBarColor': systemNavigationBarColor?.value,
      'systemNavigationBarDividerColor': systemNavigationBarDividerColor?.value,
      'systemStatusBarContrastEnforced': systemStatusBarContrastEnforced,
      'statusBarColor': statusBarColor?.value,
      'statusBarBrightness': statusBarBrightness?.toString(),
      'statusBarIconBrightness': statusBarIconBrightness?.toString(),
      'systemNavigationBarIconBrightness':
          systemNavigationBarIconBrightness?.toString(),
      'systemNavigationBarContrastEnforced':
          systemNavigationBarContrastEnforced,
    };
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'SystemUiOverlayStyle')}(${_toMap()})';

  SystemUiOverlayStyle copyWith({
    Color? systemNavigationBarColor,
    Color? systemNavigationBarDividerColor,
    bool? systemNavigationBarContrastEnforced,
    Color? statusBarColor,
    Brightness? statusBarBrightness,
    Brightness? statusBarIconBrightness,
    bool? systemStatusBarContrastEnforced,
    Brightness? systemNavigationBarIconBrightness,
  }) {
    return SystemUiOverlayStyle(
      systemNavigationBarColor:
          systemNavigationBarColor ?? this.systemNavigationBarColor,
      systemNavigationBarDividerColor: systemNavigationBarDividerColor ??
          this.systemNavigationBarDividerColor,
      systemNavigationBarContrastEnforced:
          systemNavigationBarContrastEnforced ??
              this.systemNavigationBarContrastEnforced,
      statusBarColor: statusBarColor ?? this.statusBarColor,
      statusBarIconBrightness:
          statusBarIconBrightness ?? this.statusBarIconBrightness,
      statusBarBrightness: statusBarBrightness ?? this.statusBarBrightness,
      systemStatusBarContrastEnforced: systemStatusBarContrastEnforced ??
          this.systemStatusBarContrastEnforced,
      systemNavigationBarIconBrightness: systemNavigationBarIconBrightness ??
          this.systemNavigationBarIconBrightness,
    );
  }

  @override
  int get hashCode => Object.hash(
        systemNavigationBarColor,
        systemNavigationBarDividerColor,
        systemNavigationBarContrastEnforced,
        statusBarColor,
        statusBarBrightness,
        statusBarIconBrightness,
        systemStatusBarContrastEnforced,
        systemNavigationBarIconBrightness,
      );

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SystemUiOverlayStyle &&
        other.systemNavigationBarColor == systemNavigationBarColor &&
        other.systemNavigationBarDividerColor ==
            systemNavigationBarDividerColor &&
        other.systemNavigationBarContrastEnforced ==
            systemNavigationBarContrastEnforced &&
        other.statusBarColor == statusBarColor &&
        other.statusBarIconBrightness == statusBarIconBrightness &&
        other.statusBarBrightness == statusBarBrightness &&
        other.systemStatusBarContrastEnforced ==
            systemStatusBarContrastEnforced &&
        other.systemNavigationBarIconBrightness ==
            systemNavigationBarIconBrightness;
  }
}

List<String> _stringify(List<dynamic> list) => <String>[
      for (final dynamic item in list) item.toString(),
    ];

abstract final class SystemChrome {
  static Future<void> setPreferredOrientations(
      List<DeviceOrientation> orientations) async {
    await SystemChannels.platform.invokeMethod<void>(
      'SystemChrome.setPreferredOrientations',
      _stringify(orientations),
    );
  }

  static Future<void> setApplicationSwitcherDescription(
      ApplicationSwitcherDescription description) async {
    await SystemChannels.platform.invokeMethod<void>(
      'SystemChrome.setApplicationSwitcherDescription',
      <String, dynamic>{
        'label': description.label,
        'primaryColor': description.primaryColor,
      },
    );
  }

  static Future<void> setEnabledSystemUIMode(SystemUiMode mode,
      {List<SystemUiOverlay>? overlays}) async {
    if (mode != SystemUiMode.manual) {
      await SystemChannels.platform.invokeMethod<void>(
        'SystemChrome.setEnabledSystemUIMode',
        mode.toString(),
      );
    } else {
      assert(mode == SystemUiMode.manual && overlays != null);
      await SystemChannels.platform.invokeMethod<void>(
        'SystemChrome.setEnabledSystemUIOverlays',
        _stringify(overlays!),
      );
    }
  }

  static Future<void> setSystemUIChangeCallback(
      SystemUiChangeCallback? callback) async {
    ServicesBinding.instance.setSystemUiChangeCallback(callback);
    // Skip setting up the listener if there is no callback.
    if (callback != null) {
      await SystemChannels.platform.invokeMethod<void>(
        'SystemChrome.setSystemUIChangeListener',
      );
    }
  }

  static Future<void> restoreSystemUIOverlays() async {
    await SystemChannels.platform.invokeMethod<void>(
      'SystemChrome.restoreSystemUIOverlays',
    );
  }

  static void setSystemUIOverlayStyle(SystemUiOverlayStyle style) {
    if (_pendingStyle != null) {
      // The microtask has already been queued; just update the pending value.
      _pendingStyle = style;
      return;
    }
    if (style == _latestStyle) {
      // Trivial success: no microtask has been queued and the given style is
      // already in effect, so no need to queue a microtask.
      return;
    }
    _pendingStyle = style;
    scheduleMicrotask(() {
      assert(_pendingStyle != null);
      if (_pendingStyle != _latestStyle) {
        SystemChannels.platform.invokeMethod<void>(
          'SystemChrome.setSystemUIOverlayStyle',
          _pendingStyle!._toMap(),
        );
        _latestStyle = _pendingStyle;
      }
      _pendingStyle = null;
    });
  }

  static SystemUiOverlayStyle? _pendingStyle;

  @visibleForTesting
  static SystemUiOverlayStyle? get latestStyle => _latestStyle;
  static SystemUiOverlayStyle? _latestStyle;
}
