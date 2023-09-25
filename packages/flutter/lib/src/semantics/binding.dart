
import 'dart:ui' as ui show AccessibilityFeatures, SemanticsActionEvent, SemanticsUpdateBuilder;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'debug.dart';

export 'dart:ui' show AccessibilityFeatures, SemanticsActionEvent, SemanticsUpdateBuilder;

mixin SemanticsBinding on BindingBase {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _accessibilityFeatures = platformDispatcher.accessibilityFeatures;
    platformDispatcher
      ..onSemanticsEnabledChanged = _handleSemanticsEnabledChanged
      ..onSemanticsActionEvent = _handleSemanticsActionEvent
      ..onAccessibilityFeaturesChanged = handleAccessibilityFeaturesChanged;
    _handleSemanticsEnabledChanged();
  }

  static SemanticsBinding get instance => BindingBase.checkInstance(_instance);
  static SemanticsBinding? _instance;

  bool get semanticsEnabled {
    assert(_semanticsEnabled.value == (_outstandingHandles > 0));
    return _semanticsEnabled.value;
  }
  late final ValueNotifier<bool> _semanticsEnabled = ValueNotifier<bool>(platformDispatcher.semanticsEnabled);

  void addSemanticsEnabledListener(VoidCallback listener) {
    _semanticsEnabled.addListener(listener);
  }

  void removeSemanticsEnabledListener(VoidCallback listener) {
    _semanticsEnabled.removeListener(listener);
  }

  int get debugOutstandingSemanticsHandles => _outstandingHandles;
  int _outstandingHandles = 0;

  SemanticsHandle ensureSemantics() {
    assert(_outstandingHandles >= 0);
    _outstandingHandles++;
    assert(_outstandingHandles > 0);
    _semanticsEnabled.value = true;
    return SemanticsHandle._(_didDisposeSemanticsHandle);
  }

  void _didDisposeSemanticsHandle() {
    assert(_outstandingHandles > 0);
    _outstandingHandles--;
    assert(_outstandingHandles >= 0);
    _semanticsEnabled.value = _outstandingHandles > 0;
  }

  // Handle for semantics request from the platform.
  SemanticsHandle? _semanticsHandle;

  void _handleSemanticsEnabledChanged() {
    if (platformDispatcher.semanticsEnabled) {
      _semanticsHandle ??= ensureSemantics();
    } else {
      _semanticsHandle?.dispose();
      _semanticsHandle = null;
    }
  }

  void _handleSemanticsActionEvent(ui.SemanticsActionEvent action) {
    final Object? arguments = action.arguments;
    final ui.SemanticsActionEvent decodedAction = arguments is ByteData
      ? action.copyWith(arguments: const StandardMessageCodec().decodeMessage(arguments))
      : action;
    performSemanticsAction(decodedAction);
  }

  @protected
  void performSemanticsAction(ui.SemanticsActionEvent action);

  ui.AccessibilityFeatures get accessibilityFeatures => _accessibilityFeatures;
  late ui.AccessibilityFeatures _accessibilityFeatures;

  @protected
  @mustCallSuper
  void handleAccessibilityFeaturesChanged() {
    _accessibilityFeatures = platformDispatcher.accessibilityFeatures;
  }

  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() {
    return ui.SemanticsUpdateBuilder();
  }

  bool get disableAnimations {
    bool value = _accessibilityFeatures.disableAnimations;
    assert(() {
      if (debugSemanticsDisableAnimations != null) {
        value = debugSemanticsDisableAnimations!;
      }
      return true;
    }());
    return value;
  }
}

class SemanticsHandle {
  SemanticsHandle._(this._onDispose);

  final VoidCallback _onDispose;

  @mustCallSuper
  void dispose() {
    _onDispose();
  }
}